# PeerDrop

PeerDrop is a Flutter-based peer-to-peer file sharing app that transfers files directly between two devices over a WebRTC data channel.

It uses:
- **Flutter UI + BLoC state management** for the client app.
- **WebRTC (`flutter_webrtc`)** for direct binary file transport.
- **Socket.IO signaling server (Node.js + Express)** to exchange offer/answer/ICE messages.

> The signaling server helps peers discover and negotiate a WebRTC connection, but file payloads are sent peer-to-peer through the data channel once connected.

---

## Table of Contents

1. [Project Goals](#project-goals)
2. [High-Level Architecture](#high-level-architecture)
3. [Repository Structure](#repository-structure)
4. [How File Transfer Works (End-to-End)](#how-file-transfer-works-end-to-end)
5. [App Features](#app-features)
6. [Tech Stack](#tech-stack)
7. [Prerequisites](#prerequisites)
8. [Setup & Run](#setup--run)
   - [1) Run signaling server](#1-run-signaling-server)
   - [2) Configure Flutter client signaling URL](#2-configure-flutter-client-signaling-url)
   - [3) Run Flutter app](#3-run-flutter-app)
   - [4) Test transfer with two peers](#4-test-transfer-with-two-peers)
9. [Detailed Component Walkthrough](#detailed-component-walkthrough)
10. [Platform-Specific Notes](#platform-specific-notes)
11. [Operational Notes & Limitations](#operational-notes--limitations)
12. [Troubleshooting](#troubleshooting)
13. [Future Improvements](#future-improvements)
14. [Development Commands](#development-commands)

---

## Project Goals

- Provide a simple way to share files directly between two peers.
- Keep server responsibilities minimal (signaling only).
- Show transfer state clearly with progress and activity logs.
- Persist received files locally (including Android Downloads support).

---

## High-Level Architecture

```text
Sender App (Flutter)                         Receiver App (Flutter)
┌───────────────────────┐                    ┌───────────────────────┐
│ FilePicker + FileBloc │                    │ FileBloc + FileUtils  │
│ WebRTCService         │◄── P2P Data ───►  │ WebRTCService         │
└───────────┬───────────┘     Channel        └───────────┬───────────┘
            │                                             │
            └──── Offer/Answer/ICE via Socket.IO ────────┘
                              │
                    Signaling Server (Node.js)
                    Express + Socket.IO room relay
```

### Data plane vs signaling plane

- **Data plane (file bytes):** WebRTC DataChannel between peers.
- **Signaling plane (connection setup):** Socket.IO events relayed by backend.

---

## Repository Structure

```text
peerdrop/
├── lib/
│   ├── core/
│   │   ├── utils/file_utils.dart
│   │   └── webrtc/
│   │       ├── signaling_service.dart
│   │       └── webrtc_service.dart
│   ├── features/file_transfer/
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   ├── file_bloc.dart
│   │       │   ├── file_event.dart
│   │       │   └── file_state.dart
│   │       └── pages/
│   │           ├── home_page.dart
│   │           └── widgets/progress_bar.dart
│   └── main.dart
├── android/app/src/main/kotlin/com/example/peerdrop/MainActivity.kt
├── Backend/
│   ├── server.js
│   └── package.json
└── pubspec.yaml
```

> Note: `lib/features/file_transfer/domain/*` and `lib/features/file_transfer/data/*` currently contain placeholder files and are not yet implemented.

---

## How File Transfer Works (End-to-End)

1. **Both peers enter the same room ID.**
2. One peer taps **Create Connection** (sender role), the other taps **Join Room** (receiver role).
3. Sender creates a WebRTC **offer** and sends it through the signaling server.
4. Receiver applies offer, creates **answer**, sends answer back through signaling server.
5. Both peers exchange **ICE candidates** through signaling server.
6. Data channel opens.
7. Sender picks a file and sends:
   - A JSON control message with metadata (`type: metadata`, `fileName`, `size`)
   - Binary chunks of file data (16 KB each)
   - A completion control message (`type: complete`)
8. Receiver reconstructs bytes and saves file:
   - Android: via platform `MethodChannel` into Downloads
   - Others: app documents directory via `path_provider`

---

## App Features

- Room-based peer pairing.
- Manual connection creation/join flow.
- Real-time transfer progress (% and bytes).
- File activity log with timestamps and error indicators.
- Chunked send logic with interruption checks.
- Metadata + completion control protocol.
- Android-native save-to-Downloads integration.

---

## Tech Stack

### Flutter app dependencies

- `flutter_bloc` — state management
- `flutter_webrtc` — peer connection and data channels
- `socket_io_client` — signaling client transport
- `file_picker` — selecting files to send
- `path_provider` — local directory resolution

### Backend dependencies

- `express`
- `socket.io`
- `cors`

---

## Prerequisites

### Client

- Flutter SDK compatible with project (`sdk: ^3.10.8` in `pubspec.yaml`)
- Android Studio / Xcode / desktop toolchain as needed

### Server

- Node.js 18+ recommended
- npm

---

## Setup & Run

### 1) Run signaling server

```bash
cd Backend
npm install
node server.js
```

Default server port: **3000**.

---

### 2) Configure Flutter client signaling URL

The signaling URL is currently hardcoded in:

`lib/core/webrtc/signaling_service.dart`

```dart
SignalingService({String? serverUrl})
    : serverUrl = serverUrl ?? 'http://10.21.8.149:3000';
```

Update this value to your reachable backend host (LAN IP / tunnel / domain).

Examples:
- Android emulator to host machine: `http://10.0.2.2:3000`
- Physical device over same Wi-Fi: `http://<your-lan-ip>:3000`
- Remote deployment: `https://<your-domain>` (with matching Socket.IO settings)

---

### 3) Run Flutter app

```bash
flutter pub get
flutter run
```

---

### 4) Test transfer with two peers

1. Launch app on two devices/simulators.
2. Enter identical room ID on both.
3. Device A: tap **Create Connection**.
4. Device B: tap **Join Room**.
5. Wait for connection logs.
6. Device A: tap **Send File** and choose a file.
7. Verify transfer progress and final saved path on receiver.

---

## Detailed Component Walkthrough

### `main.dart`

- Initializes Flutter bindings.
- Creates app root and injects `FileBloc(WebRTCService.instance)` into `HomePage`.

### `HomePage` (UI + orchestration)

Responsibilities:
- Holds room ID input.
- Connects signaling callbacks to WebRTC actions.
- Handles button actions:
  - Join room (receiver mode)
  - Create connection (sender mode)
  - Pick and send file
- Pushes human-readable logs into BLoC.

### `WebRTCService`

Responsibilities:
- Creates/disposes peer connection.
- Sets STUN servers:
  - `stun:stun.l.google.com:19302`
  - `stun:stun1.l.google.com:19302`
- Creates data channel in sender mode.
- Handles incoming data channels in receiver mode.
- Serializes/deserializes control messages (JSON).
- Emits callbacks for:
  - binary data
  - control data
  - ICE candidates
  - connection state/logs

### `SignalingService`

Responsibilities:
- Connects to Socket.IO backend.
- Joins room with `join-room` event.
- Relays and receives:
  - `offer`
  - `answer`
  - `ice-candidate`
  - `room-members`
- Exposes onLog callback for UI/BLoC logging.

### `FileBloc`

Responsibilities:
- Manages app transfer state.
- Reacts to WebRTC callbacks by dispatching events.
- Sending path:
  - validates connection
  - sends metadata
  - chunks bytes (16 KB)
  - updates progress after each chunk
  - sends completion marker
- Receiving path:
  - starts receive session on metadata
  - appends binary chunks
  - finalizes and persists file on complete
- Maintains activity logs and user-visible status message.

### `FileUtils`

Responsibilities:
- Assembles received chunks into one byte array.
- Sanitizes output filename.
- Saves file:
  - Android: `MethodChannel('peerdrop/file_saver')` → Downloads
  - Other platforms: app documents directory

### Android `MainActivity`

Responsibilities:
- Handles `saveToDownloads` method call from Flutter.
- Writes bytes into Downloads:
  - Android 10+ (API 29+): `MediaStore`
  - Older Android: direct file write to public Downloads

### Backend `server.js`

Responsibilities:
- Hosts Socket.IO server.
- Supports room join and relays signaling events to peers in same room.
- Tracks and emits room member counts.
- Logs connection lifecycle and signaling relay actions.

---

## Platform-Specific Notes

### Android permissions

Manifest includes:
- `INTERNET`
- `ACCESS_NETWORK_STATE`
- Legacy external storage permissions for older Android versions

### iOS

The project includes default iOS runner metadata. Depending on future features, you may need to add specific permissions (e.g., if media capture is introduced).

---

## Operational Notes & Limitations

- Current signaling URL is hardcoded and should be externalized for production.
- There is no authentication or encryption key exchange layer beyond default WebRTC transport security.
- No resume support for interrupted transfers.
- Metadata protocol is minimal (`metadata` + `complete` only).
- Current UX assumes one active transfer at a time.
- Error handling is user-visible in log panel, but retry workflows are manual.

---

## Troubleshooting

### Cannot connect to signaling server

- Ensure backend is running on port 3000.
- Verify mobile device can reach host/IP.
- Confirm `serverUrl` in `SignalingService` points to reachable address.
- Check firewall/router restrictions.

### Peers join room but transfer does not start

- Ensure one peer taps **Create Connection** and other taps **Join Room**.
- Check logs for connection state transitions and ICE exchange.
- Verify data channel reaches open state before sending.

### File not saved on receiver

- Check log panel for save errors.
- On Android, verify storage behavior and device-specific restrictions.
- On non-Android, verify app document storage access.

---

## Future Improvements

- Configurable signaling endpoint (env/config screen).
- Better room/session UX (invite links, QR codes).
- Transfer checksum verification.
- Pause/resume/cancel controls.
- Multi-file queue and folder transfer.
- Background transfer reliability improvements.
- Domain/data layer implementation (currently placeholders).
- Automated tests for BLoC and signaling/WebRTC integration boundaries.

---

## Development Commands

### Flutter

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

### Backend

```bash
cd Backend
npm install
node server.js
```

---

If you plan to deploy this project, start by externalizing configuration, hardening signaling security, and adding robust transfer/session lifecycle management.
