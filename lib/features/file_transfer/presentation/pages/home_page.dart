import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

  void _log(String message, {bool isError = false}) {
    bloc.add(LogMessageEvent(message, isError: isError));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: bloc,
      child: Scaffold(
        appBar: AppBar(title: const Text('PeerDrop')),
        body: BlocBuilder<FileBloc, FileState>(
          builder: (context, state) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: roomController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Room ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton(
                        onPressed: joinRoom,
                        child: const Text('Join Room'),
                      ),
                      ElevatedButton(
                        onPressed: createConnection,
                        child: const Text('Create Connection'),
                      ),
                      ElevatedButton(
                        onPressed: pickAndSendFile,
                        child: const Text('Send File'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _TransferStatusCard(state: state),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _LogPanel(logs: state.logs),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TransferStatusCard extends StatelessWidget {
  const _TransferStatusCard({required this.state});

  final FileState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = state.isSending
        ? 'Sharing in progress'
        : state.isReceiving
            ? 'Receiving in progress'
            : 'Transfer status';

    final subtitle = state.activeFileName == null
        ? state.statusMessage
        : '${state.statusMessage}\nFile: ${state.activeFileName}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: 12),
            ProgressBar(state.progress),
            const SizedBox(height: 12),
            Text(
              'Transferred: ${state.bytesTransferred}${state.totalBytes != null ? ' / ${state.totalBytes}' : ''} bytes',
            ),
            if (state.savedPath != null) ...[
              const SizedBox(height: 8),
              Text('Saved at: ${state.savedPath}'),
            ],
            if (state.hasError) ...[
              const SizedBox(height: 8),
              Text(
                'Check the activity log below for the last error.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LogPanel extends StatelessWidget {
  const _LogPanel({required this.logs});

  final List<FileLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity log', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: logs.isEmpty
                  ? const Center(
                      child: Text('No activity yet. Join a room to begin.'),
                    )
                  : ListView.separated(
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (context, index) {
                        final entry = logs[index];
                        final color = entry.isError
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary;

                        final timestamp =
                            '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}';

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              entry.isError ? Icons.error_outline : Icons.info_outline,
                              color: color,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entry.message),
                                  const SizedBox(height: 4),
                                  Text(
                                    timestamp,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
