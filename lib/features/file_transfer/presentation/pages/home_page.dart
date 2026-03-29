import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/webrtc/signaling_service.dart';
import '../../../../core/webrtc/webrtc_service.dart';
import '../bloc/file_bloc.dart';
import '../bloc/file_event.dart';
import '../bloc/file_state.dart';
import 'widgets/progress_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage(this.bloc, {super.key});

  final FileBloc bloc;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController roomController = TextEditingController();

  final signaling = SignalingService();
  final webrtc = WebRTCService.instance;

  String roomId = '';

  FileBloc get bloc => widget.bloc;

  @override
  void initState() {
    super.initState();

    roomController.text = _generateRoomId();
    roomId = roomController.text;

    signaling.onLog = _log;

    signaling.onOffer = (offer) async {
      _log('Applying remote offer.');
      await webrtc.setRemote(offer);

      final answer = await webrtc.createAnswer();
      signaling.sendAnswer(answer, roomId);
    };

    signaling.onAnswer = (answer) async {
      _log('Applying remote answer.');
      await webrtc.setRemote(answer);
    };

    signaling.onIce = (ice) async {
      await webrtc.addIce(ice);
    };

    webrtc.onIceCandidate = (candidate) {
      signaling.sendIce(candidate, roomId);
    };
  }

  @override
  void dispose() {
    roomController.dispose();
    super.dispose();
  }

  String _generateRoomId() {
    final random = Random();
    final code = 100 + random.nextInt(900);
    return 'PEER-$code-DROP';
  }

  Future<void> joinRoom() async {
    roomId = roomController.text.trim();

    if (roomId.isEmpty) {
      _log('Room ID is required before joining.', isError: true);
      return;
    }

    try {
      await webrtc.init(isSender: false);
      await signaling.connect(roomId);
      _log('Receiver is ready in room $roomId.');
    } catch (error) {
      _log('Unable to join room $roomId: $error', isError: true);
    }
  }

  Future<void> createConnection() async {
    roomId = roomController.text.trim();

    if (roomId.isEmpty) {
      _log('Room ID is required before creating a connection.', isError: true);
      return;
    }

    try {
      await webrtc.init(isSender: true);

      if (!signaling.isConnected) {
        await signaling.connect(roomId);
      }

      final offer = await webrtc.createOffer();
      signaling.sendOffer(offer, roomId);
      _log('Connection offer sent to room $roomId.');
    } catch (error) {
      _log('Unable to create a connection for room $roomId: $error', isError: true);
    }
  }

  Future<void> pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles();

    if (result == null || result.files.isEmpty) {
      _log('File selection cancelled.');
      return;
    }

    final selectedFile = result.files.first;
    final path = selectedFile.path;

    if (path == null) {
      _log('Selected file path is unavailable on this platform.', isError: true);
      return;
    }

    try {
      final file = File(path);
      final bytes = await file.readAsBytes();

      bloc.add(
        SendFileEvent(
          bytes: bytes,
          fileName: selectedFile.name,
        ),
      );
    } catch (error) {
      _log('Unable to read ${selectedFile.name}: $error', isError: true);
    }
  }

  Future<void> _showQrShareSheet() async {
    final currentRoom = roomController.text.trim();

    if (currentRoom.isEmpty) {
      _log('Set a room ID before generating QR.', isError: true);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _QrShareSheet(roomId: currentRoom);
      },
    );
  }

  Future<void> _scanQrAndJoin() async {
    final scannedRoom = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _QrScannerPage()),
    );

    if (!mounted || scannedRoom == null || scannedRoom.trim().isEmpty) {
      return;
    }

    setState(() {
      roomController.text = scannedRoom.trim();
    });

    await joinRoom();
  }

  void _log(String message, {bool isError = false}) {
    bloc.add(LogMessageEvent(message, isError: isError));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: bloc,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F3FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          titleSpacing: 16,
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF2563EB)),
              const SizedBox(width: 10),
              Text(
                'PeerDrop',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF2F4AB9),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: CircleAvatar(
                backgroundColor: Color(0xFFE5E7EB),
                child: Icon(Icons.person, color: Color(0xFF374151)),
              ),
            ),
          ],
        ),
        body: BlocBuilder<FileBloc, FileState>(
          builder: (context, state) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderStatus(state: state),
                  const SizedBox(height: 20),
                  _RoomActionCard(
                    roomController: roomController,
                    onCreateRoom: createConnection,
                    onJoinRoom: joinRoom,
                    onScanQr: _scanQrAndJoin,
                    onShowQr: _showQrShareSheet,
                  ),
                  const SizedBox(height: 20),
                  _TransferStatusCard(state: state, onSendFile: pickAndSendFile),
                  const SizedBox(height: 20),
                  _ActivityStream(logs: state.logs),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeaderStatus extends StatelessWidget {
  const _HeaderStatus({required this.state});

  final FileState state;

  @override
  Widget build(BuildContext context) {
    final isConnected = state.isSending || state.isReceiving || state.statusMessage.contains('ready');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRANSFER STATUS',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                letterSpacing: 1.3,
                color: const Color(0xFF7B7D87),
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              isConnected ? 'Connected' : 'Waiting',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                  ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFDDF8E8),
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: const Row(
                children: [
                  Icon(Icons.circle, size: 10, color: Color(0xFF50C878)),
                  SizedBox(width: 8),
                  Icon(Icons.wifi, size: 18, color: Color(0xFF16A34A)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          state.statusMessage,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: const Color(0xFF4B5563)),
        ),
      ],
    );
  }
}

class _RoomActionCard extends StatelessWidget {
  const _RoomActionCard({
    required this.roomController,
    required this.onCreateRoom,
    required this.onJoinRoom,
    required this.onScanQr,
    required this.onShowQr,
  });

  final TextEditingController roomController;
  final Future<void> Function() onCreateRoom;
  final Future<void> Function() onJoinRoom;
  final Future<void> Function() onScanQr;
  final Future<void> Function() onShowQr;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FA),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: roomController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'PEER-882-DROP',
                    ),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: onShowQr,
                  icon: const Icon(Icons.qr_code_2, size: 28),
                  tooltip: 'Share Room QR',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onCreateRoom,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                    backgroundColor: const Color(0xFF3755D5),
                  ),
                  child: const Text('Create Room', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onJoinRoom,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                    side: const BorderSide(color: Color(0xFFAFC5EA), width: 2),
                  ),
                  child: const Text('Join Room', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onScanQr,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan QR to Join'),
          ),
        ],
      ),
    );
  }
}

class _TransferStatusCard extends StatelessWidget {
  const _TransferStatusCard({required this.state, required this.onSendFile});

  final FileState state;
  final Future<void> Function() onSendFile;

  @override
  Widget build(BuildContext context) {
    final isActive = state.isSending || state.isReceiving;
    final totalBytes = state.totalBytes ?? 0;
    final sizeInMb = totalBytes == 0 ? 0 : totalBytes / (1024 * 1024);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2EBFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.picture_as_pdf, color: Color(0xFF2563EB), size: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.activeFileName ?? 'No file selected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sizeInMb > 0 ? '${sizeInMb.toStringAsFixed(1)} MB' : 'Pick a file to transfer',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: const Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              Text(
                isActive ? (state.isSending ? 'Sending...' : 'Receiving...') : 'Idle',
                style: TextStyle(
                  color: isActive ? const Color(0xFF2563EB) : const Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PROGRESS',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF8B8E97),
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text('${(state.progress * 100).toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 8),
          ProgressBar(state.progress),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${state.bytesTransferred} bytes transferred'),
              Text(state.savedPath != null ? 'Saved' : 'Waiting'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSendFile,
              icon: const Icon(Icons.send),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5E7EF),
                foregroundColor: const Color(0xFF111827),
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              ),
              label: const Text('Send File', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityStream extends StatelessWidget {
  const _ActivityStream({required this.logs});

  final List<FileLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    final entries = logs.reversed.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACTIVITY STREAM',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                letterSpacing: 1.8,
                color: const Color(0xFF7B7D87),
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 14),
        if (entries.isEmpty)
          const Text('No activity yet. Join a room to begin.')
        else
          ...entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: entry.isError ? const Color(0xFFF59E0B) : const Color(0xFF7C3AED),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _QrShareSheet extends StatelessWidget {
  const _QrShareSheet({required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share this QR to join',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(roomId, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            QrImageView(
              data: roomId,
              size: 220,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 12),
            const Text('Scan this code on another device to auto-fill room ID.'),
          ],
        ),
      ),
    );
  }
}

class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) {
      return;
    }

    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.trim().isEmpty) {
      return;
    }

    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Room QR')),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
      ),
    );
  }
}
