# mpcoven

Flutter front-end for an **MPC 2-of-2 signature-escrow wallet**. It drives the
[`signature-escrow`](https://github.com/valli0x/signature-escrow) Go backend to
generate and use threshold keys where **no single party ever holds the full
private key**:

- **ECDSA / Ethereum** via the CMP protocol
- **FROST / Bitcoin (Taproot)** via Schnorr threshold signatures

Targets **macOS desktop** and **web**.

## Features

- **Sign in** with MetaMask, WalletConnect, or a manual EIP-191 signature (JWT session).
- **Pairing** — establish a 2-of-2 relationship with another participant.
- **Distributed keygen** — run multiple ECDSA/FROST key generations in parallel,
  each tracked as its own job card; new accounts appear automatically.
- **Accounts** — grouped into partner folders, searchable; view address as a QR code.
- **Balances** — on-chain balance checks in human units (e.g. `0.011`, not wei),
  with live USD quotes.
- **Transactions & withdrawals** — build, co-sign and broadcast.
- **Exchange** — link two escrow addresses for a swap (business logic lives on
  the Go client).
- **Deletion model** — delete a pair and cascade its accounts on *your* client
  only; a participant can never destroy the other party's key material.

## Architecture

The app is a thin UI over two HTTP backends:

| Backend | Default URL | Responsibilities |
|---------|-------------|------------------|
| **Client** (local) | `http://localhost:8080` | keygen, accounts, balances, transactions, exchanges |
| **Server** (host)  | `https://mpcoven.net/api` | auth, pairing, mailbox relay, keygen-session arbitration, escrow |

Both are the same `signature-escrow` Go binary run in different modes. Their full
HTTP APIs are documented via **Swagger UI** at `<base>/swagger/index.html`.

State management is **Provider** (`ChangeNotifier`); all orchestration lives in
`lib/providers/keygen_provider.dart`.

## Requirements

- Flutter SDK 3.x (Dart 3.x)
- A running `signature-escrow` client (and access to a host server + relay)

## Getting started

```bash
flutter pub get

# macOS desktop
flutter run -d macos

# web
flutter run -d chrome
```

Configure the **Client URL** and **Server URL** in Settings (they persist across
restarts). To run two participants on one machine, point a second app instance
at a second client (e.g. `http://localhost:8081`).

## Project layout

```
lib/
  main.dart                  MaterialApp; loads persisted client/server URLs
  models/keygen_models.dart  data models (accounts, pairs, keygen, exchange, ...)
  providers/keygen_provider.dart   AppProvider — all state & orchestration
  services/
    api_service.dart         HTTP client (client + server base URLs)
    metamask_service.dart    window.ethereum (web)
    walletconnect_service.dart   Reown/WalletConnect relay
    price_service.dart       CoinGecko USD quotes
    units.dart               wei/satoshi <-> human-unit conversion
  screens/                   login, home, accounts, keygen, exchange, pairing,
                             balance, tx, withdrawal, notifications, settings
  widgets/                   app background, bottom nav, page scaffold, buttons,
                             amount field, key/QR cards, dialogs
```

## Building for release

```bash
flutter build macos --release
flutter build web --release
```

## License

[MIT](LICENSE)
