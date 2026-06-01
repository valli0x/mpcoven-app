# MPC Key Generator App

Flutter application for generating shared cryptographic keys using Multi-Party Computation (MPC) protocols.

## Features

- **Generate Participant IDs**: Create unique IDs for key generation ceremony participants
- **ECDSA Key Generation**: Generate Ethereum-compatible shared keys using CMP protocol
- **FROST Key Generation**: Generate Bitcoin Taproot-compatible shared keys using FROST protocol
- **Key History**: View and manage previously generated keys
- **QR Code Display**: Display wallet addresses as QR codes for easy sharing

## Requirements

- Flutter SDK 3.0.0 or higher
- Dart SDK 3.0.0 or higher
- Running MPC key server (from `signature-escrow` project)

## Installation

1. Install Flutter: https://docs.flutter.dev/get-started/install

2. Clone and setup the project:
```bash
cd mpc_keygen_app
flutter pub get
```

3. Run on your device/emulator:
```bash
flutter run
```

## Server Configuration

The app connects to a local MPC key server. Default URL is `http://localhost:8080`.

You can change the server URL in the app settings (gear icon).

### API Endpoints Used

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/keygen/generate-ids` | POST | Generate participant IDs |
| `/v1/keygen/ecdsa` | POST | Generate ECDSA shared key |
| `/v1/keygen/frost` | POST | Generate FROST shared key |

### Request/Response Formats

#### Generate IDs
```json
// Response
{
  "my_id": "abc123...",
  "another_id": "def456..."
}
```

#### Generate ECDSA/FROST Key
```json
// Request
{
  "name": "my-wallet",
  "my_id": "abc123...",
  "another_id": "def456..."
}

// Response
{
  "public_key": "04abc...",
  "address": "0x..." // or Bitcoin address for FROST
}
```

## Usage Flow

1. **Generate IDs**: Go to "Generate IDs" tab and tap "Generate IDs"
2. **Share IDs**: Send the "Another Participant ID" to your co-signer
3. **Enter Co-signer's ID**: Your co-signer's "My ID" becomes your "Another Participant ID"
4. **Generate Key**: Both parties go to "Key Gen" tab and generate the key simultaneously
5. **Get Address**: Both parties receive the same shared address

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   └── keygen_models.dart    # Data models
├── providers/
│   └── keygen_provider.dart  # State management
├── screens/
│   ├── home_screen.dart      # Main screen with tabs
│   ├── keygen_screen.dart    # Key generation form
│   ├── history_screen.dart   # Key history list
│   └── settings_screen.dart  # App settings
├── services/
│   └── api_service.dart      # HTTP API client
└── widgets/
    ├── gradient_button.dart  # Custom button widget
    ├── id_card.dart          # ID display card
    └── key_result_card.dart  # Key result with QR
```

## Building for Release

### Android
```bash
flutter build apk --release
# or for App Bundle
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## Troubleshooting

### Network Error
- Ensure the key server is running
- Check the server URL in settings
- For Android emulator, use `10.0.2.2` instead of `localhost`
- For iOS simulator, `localhost` should work

### Key Generation Fails
- Both parties must run keygen at approximately the same time
- Ensure IDs are correctly shared between parties
- Check server logs for detailed error messages

## License

MIT License
