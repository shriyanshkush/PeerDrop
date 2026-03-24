import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/file_utils.dart';
import '../../../../core/webrtc/webrtc_service.dart';
import 'file_event.dart';
import 'file_state.dart';

class FileBloc extends Bloc<FileEvent, FileState> {
  FileBloc(this.webrtc) : super(FileState.initial()) {
    webrtc.onData = (data) {
      add(ReceiveChunkEvent(data));
    };

    webrtc.onControlMessage = (message) {
      final type = message['type'];
      if (type == 'metadata') {
        add(
          BeginReceiveEvent(
            fileName: (message['fileName'] as String?) ?? 'received_file.bin',
            totalBytes: (message['size'] as num?)?.toInt() ?? 0,
          ),
        );
        return;
      }

      if (type == 'complete') {
        add(CompleteReceiveEvent());
      }
    };

    webrtc.onLog = (message) {
      add(LogMessageEvent(message));
    };

    webrtc.onConnectionStateChange = (state) {
      add(LogMessageEvent('Connection state: $state'));
    };

    on<LogMessageEvent>(_onLogMessage);
    on<BeginReceiveEvent>(_onBeginReceive);
    on<ReceiveChunkEvent>(_onReceiveChunk);
    on<CompleteReceiveEvent>(_onCompleteReceive);
    on<SendFileEvent>(_onSendFile);
  }

  final WebRTCService webrtc;

  final List<Uint8List> _chunks = [];
  int _receivedBytes = 0;

  void _onLogMessage(LogMessageEvent event, Emitter<FileState> emit) {
    final entries = List<FileLogEntry>.from(state.logs)
      ..add(
        FileLogEntry(
          message: event.message,
          timestamp: DateTime.now(),
          isError: event.isError,
        ),
      );

    emit(
      state.copyWith(
        logs: entries,
        hasError: event.isError ? true : state.hasError,
        statusMessage: event.isError || (!state.isSending && !state.isReceiving)
            ? event.message
            : state.statusMessage,
      ),
    );
  }

  void _onBeginReceive(BeginReceiveEvent event, Emitter<FileState> emit) {
    _chunks
      ..clear();
    _receivedBytes = 0;

    final entries = List<FileLogEntry>.from(state.logs)
      ..add(
        FileLogEntry(
          message: 'Incoming file detected: ${event.fileName} (${event.totalBytes} bytes).',
          timestamp: DateTime.now(),
        ),
      );

    emit(
      state.copyWith(
        logs: entries,
        isReceiving: true,
        isSending: false,
        progress: 0,
        statusMessage: 'Receiving ${event.fileName}...',
        activeFileName: event.fileName,
        savedPath: null,
        bytesTransferred: 0,
        totalBytes: event.totalBytes,
        hasError: false,
      ),
    );
  }

  void _onReceiveChunk(ReceiveChunkEvent event, Emitter<FileState> emit) {
    _chunks.add(Uint8List.fromList(event.chunk));
    _receivedBytes += event.chunk.length;

    final totalBytes = state.totalBytes;
    final progress = totalBytes == null || totalBytes == 0
        ? 0.0
        : (_receivedBytes / totalBytes).clamp(0.0, 1.0);

    final entries = List<FileLogEntry>.from(state.logs)
      ..add(
        FileLogEntry(
          message: 'Received chunk ${_chunks.length} (${event.chunk.length} bytes).',
          timestamp: DateTime.now(),
        ),
      );

    emit(
      state.copyWith(
        logs: entries,
        isReceiving: true,
        progress: progress,
        bytesTransferred: _receivedBytes,
        statusMessage: 'Receiving ${state.activeFileName ?? 'file'}...',
      ),
    );
  }

  Future<void> _onCompleteReceive(
    CompleteReceiveEvent event,
    Emitter<FileState> emit,
  ) async {
    final fileName = state.activeFileName ?? 'received_file.bin';

    emit(
      state.copyWith(
        statusMessage: 'Saving $fileName...',
        isReceiving: true,
      ),
    );

    final file = await FileUtils.saveFile(_chunks, fileName: fileName);

    final entries = List<FileLogEntry>.from(state.logs)
      ..add(
        FileLogEntry(
          message: 'File saved to ${file.path}.',
          timestamp: DateTime.now(),
        ),
      );

    emit(
      state.copyWith(
        logs: entries,
        isReceiving: false,
        progress: 1,
        savedPath: file.path,
        bytesTransferred: _receivedBytes,
        statusMessage: 'Received $fileName successfully.',
      ),
    );
  }

  Future<void> _onSendFile(SendFileEvent event, Emitter<FileState> emit) async {
    if (!webrtc.isConnected()) {
      add(LogMessageEvent('Cannot send ${event.fileName} because the peer is not connected.', isError: true));
      return;
    }

    final totalBytes = event.bytes.length;
    const chunkSize = 16 * 1024;
    final totalChunks = math.max(1, (totalBytes / chunkSize).ceil());

    webrtc.sendControlMessage({
      'type': 'metadata',
      'fileName': event.fileName,
      'size': totalBytes,
    });

    emit(
      state.copyWith(
        isSending: true,
        isReceiving: false,
        progress: 0,
        activeFileName: event.fileName,
        savedPath: null,
        bytesTransferred: 0,
        totalBytes: totalBytes,
        statusMessage: 'Sending ${event.fileName}...',
        hasError: false,
      ),
    );

    for (var offset = 0; offset < totalBytes; offset += chunkSize) {
      if (!webrtc.isConnected()) {
        add(LogMessageEvent('Transfer interrupted because the data channel closed.', isError: true));
        emit(state.copyWith(isSending: false));
        return;
      }

      final end = math.min(offset + chunkSize, totalBytes);
      final chunk = event.bytes.sublist(offset, end);
      final chunkNumber = (offset / chunkSize).floor() + 1;

      webrtc.sendData(Uint8List.fromList(chunk));

      final sentBytes = end;
      final progress = totalBytes == 0 ? 1.0 : (sentBytes / totalBytes).clamp(0.0, 1.0);
      final entries = List<FileLogEntry>.from(state.logs)
        ..add(
          FileLogEntry(
            message: 'Sent chunk $chunkNumber / $totalChunks (${chunk.length} bytes).',
            timestamp: DateTime.now(),
          ),
        );

      emit(
        state.copyWith(
          logs: entries,
          isSending: true,
          progress: progress,
          bytesTransferred: sentBytes,
          statusMessage: 'Sending ${event.fileName}...',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    webrtc.sendControlMessage({'type': 'complete'});

    final entries = List<FileLogEntry>.from(state.logs)
      ..add(
        FileLogEntry(
          message: 'File sent successfully: ${event.fileName}.',
          timestamp: DateTime.now(),
        ),
      );

    emit(
      state.copyWith(
        logs: entries,
        isSending: false,
        progress: 1,
        bytesTransferred: totalBytes,
        statusMessage: 'Sent ${event.fileName} successfully.',
      ),
    );
  }
}
