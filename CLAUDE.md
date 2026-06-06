# CLAUDE.md

Notes for Claude when working on this repository. **Read this first after a context reset or compaction.**

## What this is

Flutter front-end for the `signature-escrow` Go backend (MPC 2-of-2 signature escrow wallet). Targets: **macOS desktop** (primary test target) and **web** (deployed at `mpcoven.net/app/`). Provider state management.

Backend repo: `../signature-escrow` (sibling dir). Its `CLAUDE.md` has the server/deploy details.

## Design / branding (keep these)

- ETH/ECDSA accent: `#627EEA` (and `#8B5CF6` for gradients). BTC/FROST accent: `#F7931A` (and `#EA580C`).
- App name/title: **mpcoven** (web title, macOS `PRODUCT_NAME`). Branded icons in `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- Gradient background (`widgets/app_background.dart`), custom rounded bottom nav (`widgets/animated_bottom_nav.dart`) — NOT a solid Material bar.
- Screens render their own transparent header (`widgets/page_scaffold.dart`) instead of an AppBar, to avoid a white bar over the gradient. Sliver screens use `floating + snap` app bars (NOT `pinned`) so the title doesn't overlap content.
- Floating bottom nav overlaps content: scrollable screens need ~120px bottom padding so the last card isn't covered.

## Layout

```
lib/
  main.dart            MaterialApp(title:'mpcoven'); defaults:
                       clientUrl='http://localhost:8080', serverUrl='https://mpcoven.net/api'
                       calls provider.restoreSession() at start
  models/keygen_models.dart   AccountMeta, Pair, PendingPairs, MailboxMessage,
                              KeygenRequest/Response, NonceResponse, LoginResponse, ApiError, GeneratedKey,
                              TxHashResponse (hash + tx_data), TxSendResponse, IncompleteSignatureResponse,
                              ExchangeEntry, CosignEvent (activity log)
  providers/keygen_provider.dart   AppProvider (ChangeNotifier) — ALL state & orchestration
  services/
    api_service.dart           HTTP. Two base URLs: clientUrl (local :8080 keygen/accounts/balance/tx/
                               exchanges/cosign), serverUrl (mpcoven.net/api auth/pair/mailbox/session).
                               `useServer:true` picks serverUrl. Error parsing handles {"errors":[...]} array.
    price_service.dart         USD quotes — Coinbase spot primary (CoinGecko fallback, 429-prone),
                               5-min cache, keeps last-known price on failure. Shared kPriceService.
    units.dart                 wei/satoshi <-> human units (BigInt; decimals 18/8); Units.fromBase/toBase/symbol
    metamask_service.dart + _stub/_web   window.ethereum via dart:js_interop (conditional import)
    walletconnect_service.dart           Reown relay, kWalletConnectProjectId='7a217a0a4ff507d0fdfde5749fa97160'
    cache_service.dart + _stub/_web      hardRefresh(): unregister SW + clear caches + reload (web)
  screens/
    login_screen.dart      first screen: MetaMask / WalletConnect / manual sign-in
    home_screen.dart       _RestoringScreen while restoreSession() runs; 4 tabs:
                           Accounts / Keygen / Exchange / Pairing + AnimatedBottomNav, wrapped in AppBackground
    accounts_screen.dart   accounts in collapsible PARTNER FOLDERS + search + delete; AppBar actions =
                           notifications bell (badge IgnorePointer so it doesn't block taps), Activity, Settings.
                           Per-account action sheet (floating rounded card): Check Balance, Send Transaction,
                           Delete (NO Withdrawal entry — co-sign moved to Notifications). Each account row shows
                           AddressBalance (manual refresh).
    keygen_screen.dart     protocol picker, partner tiles, parallel keygen JOB cards
    pairing_screen.dart    create/accept pairs
    exchange_screen.dart   user-defined exchanges (CRUD on the Go client): "New Exchange" creates an empty
                           DRAFT, edit-in-card adds 2 addresses -> Save (update). Per-address AddressBalance
                           (auto-refresh hourly). withBackground:false (HomeScreen paints the gradient).
    notifications_screen.dart  cards for keygen-init (Accept & Generate) AND sign-request (Accept & Sign ->
                           shows complete signature). Pretty details, not raw JSON.
    history_screen.dart    "Activity": co-sign/broadcast log from the Go client (/v1/cosign/history).
                           Acceptor 'completed' rows with tx_data+signature get a "Send Transaction" button.
    settings_screen.dart   Client/Server URL, Force update, Reset all data
    balance/tx/withdrawal_screen.dart
                           tx_screen = "Send for co-signing" ONE button (creates hash+tx_data, notifies
                           partner, sends our incomplete sig — all under the hood; editing To/amount clears
                           stale state). withdrawal_screen = initiator-only "Send Incomplete Signature".
  widgets/  app_background, animated_bottom_nav, page_scaffold (withBackground flag, optional actions),
            gradient_button, amount_field (ETH/USD toggle), address_balance (AddressBalance + kPriceService),
            key_result_card (QR of the wallet ADDRESS), wallet_connect_dialog
```

## Auth flow
`requestNonce(address)` → user signs the `message` field (EIP-191) with MetaMask/WalletConnect/manual → `login(address, signature, nonce)` where **nonce = the `nonce` value, NOT the full message**. JWT (24h) persisted in SharedPreferences (`auth_token`/`auth_address`); `restoreSession()` verifies it by hitting `/v1/pair/pending`.

## Keygen orchestration (provider) — important model

- **Parallel jobs**: `startKeygen()` creates a `KeygenJob` (id=session_id, partner, protocol, network, index, status) added to `keygenJobs`. The Generate button is NEVER disabled — multiple keygens run at once, each as its own card (running/done/failed). `nextFreeIndex` also reserves indices of running jobs so concurrent ETH keygens don't collide.
- **Initiator side**: send `keygen-init` to partner's mailbox, then run own half on the local client (`:8080`).
- **Partner side** (`acceptKeygenInvite`): before running, calls `apiService.claimSession(sessionId)` — server-side atomic guard. If the initiator cancelled, claim=false → abort with "The initiator cancelled this keygen", no dead keygen.
- **Cancel** (`removeKeygenJob` of a running job): calls `apiService.cancelSession(id)` (authoritative) + sends `keygen-cancel` mailbox msg.
- **Cancel propagation**: background poll (`_processCancellations`) drops `keygen-init` whose session was cancelled, and hides partner on `pair-removed`. `keygen-cancel`/`pair-removed` are service messages — never shown.
- After a successful keygen, provider calls `refreshAccounts()` so the new account appears automatically (no manual Save).

## MPC co-signing (withdrawal) — the real flow now
A 2-of-2 transaction is signed jointly; broadcasting needs the full tx, so the party who completes the signature broadcasts.
- **Initiator** (`tx_screen` → ONE "Send for co-signing" button → `provider.startCoSign`):
  1. `POST /v1/tx/hash` → gets `hash` + `tx_data` (RLP of the EXACT unsigned tx).
  2. sends mailbox `sign-request` to partner with `{alg,name,escrow,to,amount,hash_tx,tx_data}`.
  3. `POST /v1/incomplete-signature/send` → its incomplete sig goes to the relay (buffered ~10min by JetStream).
  Records an Activity entry `initiator/sent` ("awaiting partner").
- **Acceptor** (Notifications → "Accept & Sign" → `provider.acceptSignRequest`): `POST /v1/incomplete-signature/accept`
  (with `tx_data`). Completes the **Ethereum-format** signature (`mpccmp.SigEthereum`, low-s + r‖s‖v — NOT GetSigByte).
  Records `acceptor/completed` with signature **and tx_data** → Activity shows a **Send Transaction** button.
- **Broadcast** (Activity → Send Transaction → `provider.broadcastCosign`): `POST /v1/tx/send` with `{network,signature,tx_data}`.
  The client decodes tx_data, `WithSignature`, broadcasts verbatim (chainId forced to 1 — unsigned legacy `tx.ChainId()` is garbage).
- Presignature is single-use: each `send`/`accept` triggers a BACKGROUND interactive re-presign on subject `<id>/rotate/<hash>`
  (per-hash so rounds never collide). Co-sign itself runs on `<id>/cosign/<hash>` (also per-hash — fixed the
  "filtered consumer not unique" hang). On rotation failure the consumed presig is DELETED (never silently reused).

## Delete model (user's explicit rules — NO "hidden" state)
- "скрытых не должно быть либо удален либо есть" — there is NO hide concept. A pair either exists or is deleted.
- **Delete accounts**: permanent, cascade ALL accounts with a partner, on MY client only (`/v1/accounts/delete`,
  confirm dialog + type partner address). Sends `pair-removed` so the partner's side hides the pair — it must NEVER
  destroy the other party's key material ("нельзя чтобы первый мог удалять что то у второго это опасно").

## Backend message types (mailbox `type` field)
`keygen-init` (shown), `sign-request` (shown — co-sign request w/ tx details + tx_data), `sign-result` (service — partner returns the completed signature to the initiator),
`keygen-cancel` (service), `pair-removed` (service). Session endpoints `/v1/session/{claim,cancel}`.

## Running & testing on macOS (two participants on one machine)

```bash
# 1) backend: relay + 2 clients (see ../signature-escrow for the binary).
#    For server relay use COMMUNICATION_ADDR=mpcoven.net:443 COMMUNICATION_TLS=true
#    For local relay use COMMUNICATION_ADDR=:6379 (default) with a local communication+nats.

# 2) build & run app A (native):
flutter build macos --debug
open -n build/macos/Build/Products/Debug/mpcoven.app

# 3) app B = a COPY with a different bundle id (so its storage/login is separate):
rm -rf /tmp/mpcoven-B && mkdir -p /tmp/mpcoven-B
cp -R build/macos/Build/Products/Debug/mpcoven.app /tmp/mpcoven-B/mpcoven.app
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.mpcoven.mpcKeygenApp.b" /tmp/mpcoven-B/mpcoven.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleName mpcoven-B" /tmp/mpcoven-B/mpcoven.app/Contents/Info.plist
codesign --force --deep -s - /tmp/mpcoven-B/mpcoven.app
open -n /tmp/mpcoven-B/mpcoven.app
```

**Critical for two-participant tests:** in ONE window go Settings → Client URL = `http://localhost:8081`; leave the other on `:8080`. Otherwise both halves hit the same client and keygen never converges. **Client/Server URLs now PERSIST** (SharedPreferences keys `client_url`/`server_url`, loaded in `main()` before first build) — set B's `:8081` once and it survives restarts. To preseed window B's `:8081` without the UI, write its sandbox prefs:
`defaults write com.mpcoven.mpcKeygenApp.b client_url 'http://localhost:8081'` (B's bundle id is `…mpcKeygenApp.b`).

I (Claude) cannot click the Flutter UI (it's a single Canvas; computer-use MCP is intermittent). I verify by hitting the HTTP API / reading client logs, or by running a B-side autopilot in Python. The user drives the actual UI.

## Build gotchas
- `withOpacity` deprecation warnings are noise — ignore. Real errors only: `flutter analyze lib/ | grep "error •"`.
- After editing, `flutter build macos --debug` then relaunch both windows (kill old: `pkill -9 -f "mpcoven.app/Contents/MacOS/mpcoven"`).
- WASM build (`--wasm`) hangs Chrome (needs COOP/COEP headers) — use the default JS+CanvasKit build.
- `connectivity_plus` is a transitive dep of walletconnect; it's pinned explicitly in pubspec to fix a web MissingPluginException (regenerate registrant with `flutter clean` if it recurs).

## Convention for site changes
The React marketing site lives elsewhere on the server (`/root/mpcoven/build/`). When a change touches the site (not the app), the user wants me to OUTPUT A PROMPT for a separate agent rather than edit React source directly. Only the "App" button was added to the site.

## Git / GitHub
Both repos are git + pushed to GitHub:
- App → `git@github.com:valli0x/mpcoven-app.git` (branch `master`). MIT LICENSE, README present.
- Backend → `git@github.com:valli0x/signature-escrow.git` (branch `main`). Push from LOCAL (the server's
  remote is https w/o creds; deploy = scp sources + `docker compose build` on the host, then push from here).
Commit message footer: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

## Swagger
Backend serves Swagger UI at `<base>/swagger/index.html` (server :8282 and each client). Spec generated to
`apidocs/` (NOT `docs/` — that's in .dockerignore): `swag init -g docs.go --parseDependency --parseInternal -o apidocs`.
