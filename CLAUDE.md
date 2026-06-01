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
                              KeygenRequest/Response, NonceResponse, LoginResponse, ApiError, GeneratedKey
  providers/keygen_provider.dart   AppProvider (ChangeNotifier) — ALL state & orchestration
  services/
    api_service.dart           HTTP. Two base URLs: clientUrl (local :8080 keygen/accounts),
                               serverUrl (mpcoven.net/api auth/pair/mailbox/session). `useServer:true` picks serverUrl.
                               Error parsing handles backend {"errors":[...]} array.
    metamask_service.dart + _stub/_web   window.ethereum via dart:js_interop (conditional import)
    walletconnect_service.dart           Reown relay, kWalletConnectProjectId='7a217a0a4ff507d0fdfde5749fa97160'
    cache_service.dart + _stub/_web      hardRefresh(): unregister SW + clear caches + reload (web)
  screens/
    login_screen.dart      first screen: MetaMask / WalletConnect / manual sign-in
    home_screen.dart       _RestoringScreen while restoreSession() runs (prevents login flash),
                           then Accounts/Keygen/Pairing + AnimatedBottomNav, wrapped in AppBackground
    accounts_screen.dart   accounts grouped into collapsible PARTNER FOLDERS + search + delete
    keygen_screen.dart     protocol picker, partner tiles, parallel keygen JOB cards
    pairing_screen.dart    create/accept pairs; per-pair "Hide pair" (local)
    notifications_screen.dart  pretty keygen-invite cards (not raw JSON) + accept w/ status
    settings_screen.dart   Client/Server URL, Force update, Reset all data
    balance/tx/withdrawal_screen.dart
  widgets/  app_background, animated_bottom_nav, page_scaffold, gradient_button,
            key_result_card (QR of the wallet ADDRESS — it's correct/scannable), wallet_connect_dialog
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

## Delete / hide model (user's explicit rules)
- **Delete accounts**: permanent, cascade ALL accounts with a partner, on MY client only (calls `/v1/accounts/delete`). Requires a confirm dialog + typing the partner address. Then hides partner locally and sends `pair-removed` so the partner HIDES (never deletes — must not destroy the other party's data).
- **Hide pair**: local-only (SharedPreferences `hidden_partners`, lowercased). Server keeps the pair. `accounts`/`pendingPairs` getters filter out hidden partners.

## Backend message types (mailbox `type` field)
`keygen-init` (shown), `keygen-cancel` (service), `pair-removed` (service). Plus session endpoints `/v1/session/{claim,cancel}`.

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

## This repo is NOT a git repo (the app dir). The backend (`../signature-escrow`) is.
