import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../../core/webrtc/webrtc_service.dart';
import 'file_event.dart';
import 'file_state.dart';

class FileBloc extends Bloc<FileEvent, FileState> {
  final WebRTCService webrtc;

  List<Uint8List> chunks = [];
  int received = 0;

  FileBloc(this.webrtc) : super(FileInitial()) {

    webrtc.onData = (data) {
      add(ReceiveChunkEvent(data));
    };

    webrtc.onComplete = () {
      print("🧩 Triggering file reconstruction");
      add(CompleteReceiveEvent());
    };

    on<SendFileEvent>((event, emit) async {
      int total = event.bytes.length;
      const chunkSize = 16 * 1024;

      int totalChunks = (total / chunkSize).ceil();
      int sent = 0;

      for (int i = 0; i < total; i += chunkSize) {
        if (!webrtc.isConnected()) {
          emit(StatusState("❌ Not connected"));
          return;
        }

        final end = (i + chunkSize > total) ? total : i + chunkSize;
        final chunk = event.bytes.sublist(i, end);

        int currentChunk = (i / chunkSize).floor() + 1;

        webrtc.sendData(Uint8List.fromList(chunk));

        sent += chunk.length;

        emit(SendingState(
          sent / total,
          "📤 Sending chunk $currentChunk / $totalChunks",
        ));

        await Future.delayed(const Duration(milliseconds: 10));
      }

      // send END signal
      webrtc.sendData(Uint8List.fromList("END".codeUnits));

      emit(StatusState("✅ File sent successfully"));
    });

    on<ReceiveChunkEvent>((event, emit) {
      chunks.add(Uint8List.fromList(event.chunk));
      received += event.chunk.length;

      int count = chunks.length;

      emit(ReceivingState(
        received / (1024 * 1024),
        "📥 Received chunk $count",
      ));
    });

    on<CompleteReceiveEvent>((event, emit) async {
      emit(StatusState("🧩 Reconstructing file..."));

      final file = await FileUtils.saveFile(chunks);

      emit(CompletedState(file.path));
    });
  }
}
