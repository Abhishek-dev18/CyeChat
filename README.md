
# Threads-style P2P Chat (Flutter)

A simple peer-to-peer, end-to-end encrypted chat with a dark UI inspired by Threads and WhatsApp-style message flow.

## What works
- Local identity (X25519 keypair) generated on first launch
- Manual key agreement using X25519 + HKDF -> session key
- ChaCha20-Poly1305 authenticated encryption on messages
- WebRTC data channels for P2P transport
- Manual signaling via QR / copy-paste (no external server required)
- Dark, clean UI

> Security note: This is a **learning/reference** app. It does **not** implement the full Signal/WhatsApp double-ratchet. For serious security, use audited protocols (e.g., libsignal).

## Build prerequisites
- Flutter SDK (3.x+): https://flutter.dev/docs/get-started/install
- Android Studio / SDK, device/emulator with Android 7.0+ (API 24+)

## Install dependencies
```bash
flutter pub get
```

## Run on device
```bash
flutter run
```

## Build APK (to share)
```bash
flutter build apk --release
# APK will be at: build/app/outputs/flutter-apk/app-release.apk
```

## How to connect peers (no server)
1. On **Host** phone: open app → tap the **cast** icon (Host). A QR with the OFFER + your public key appears.
2. On **Joiner** phone: tap the **QR scan** icon (Join) → scan the host QR (or paste the OFFER JSON). It generates an **ANSWER** QR (or text) containing the answer + your public key.
3. Send the **ANSWER** back to the host (scan or paste into the host card). Once applied, the data channel connects and both sides can chat.
4. All messages are encrypted end-to-end with the derived session key.

## Limitations & tips
- Manual signaling means both devices must exchange the offer/answer blobs once per connection. You can share them via QR, WhatsApp, or any channel.
- NAT traversal: Uses public STUN servers. If your network blocks P2P/UDP, connection may fail.
- No push notifications; the app must be open to receive messages.
- Only **one peer-to-peer session** at a time in this minimal version.
- For a production-secure app, integrate a vetted protocol like **libsignal-client** and add proper safety numbers / key verification UI.

## Customization
- Edit `lib/src/chat_page.dart` for UI tweaks.
- Colors are dark by default to feel like Threads.
