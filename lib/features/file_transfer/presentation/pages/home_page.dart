import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:peerdrop/features/file_transfer/presentation/pages/widgets/%20progress_bar.dart';

import '../../../../core/webrtc/signaling_service.dart';
import '../../../../core/webrtc/webrtc_service.dart';
import '../bloc/file_bloc.dart';
import '../bloc/file_event.dart';
import '../bloc/file_state.dart';

class HomePage extends StatefulWidget {
  final FileBloc bloc;
  const HomePage(this.bloc, {super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController roomController = TextEditingController();

  final signaling = SignalingService();
  final webrtc = WebRTCService.instance;

  String roomId = "";

  @override
  void initState() {
    super.initState();

    // 🔥 LISTEN SIGNALING EVENTS

    signaling.onOffer = (offer) async {
      await webrtc.setRemote(offer);

      final answer = await webrtc.createAnswer();
      signaling.sendAnswer(answer, roomId);
    };

    signaling.onAnswer = (answer) async {
      await webrtc.setRemote(answer);
    };

    signaling.onIce = (ice) async {
      await webrtc.addIce(ice);
    };

    // 🔥 SEND ICE
    webrtc.pc?.onIceCandidate = (candidate) {
      signaling.sendIce(candidate, roomId);
    };
  }

  void joinRoom() async {
    roomId = roomController.text.trim();

    if (roomId.isEmpty) {
      print("Room ID empty");
      return;
    }

    await webrtc.init(isSender: false); // 🔥 receiver

    signaling.connect(roomId);

    print("Joined room: $roomId");
  }

  Future<void> createConnection() async {
    await webrtc.init(isSender: true); // 🔥 sender
    final offer = await webrtc.createOffer();
    signaling.sendOffer(offer, roomId);
    print("Offer sent");
  }

  Future<void> pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles();

    if (result == null) return;

    final path = result.files.first.path;

    if (path == null) {
      print("File path is null");
      return;
    }

    final file = File(path);
    final bytes = await file.readAsBytes();

    context.read<FileBloc>().add(
      SendFileEvent(bytes),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PeerDrop")),
      // body: BlocProvider(
      //   create: (_) => widget.bloc,
      //   child: BlocBuilder<FileBloc, FileState>(
      //     builder: (context, state) {
      //       return Padding(
      //         padding: const EdgeInsets.all(16),
      //         child: Column(
      //           mainAxisAlignment: MainAxisAlignment.center,
      //           children: [
      //
      //             // 🔗 ROOM INPUT
      //             TextField(
      //               controller: roomController,
      //               decoration: const InputDecoration(
      //                 labelText: "Enter Room ID",
      //                 border: OutlineInputBorder(),
      //               ),
      //             ),
      //
      //             const SizedBox(height: 10),
      //
      //             // 🔌 JOIN ROOM
      //             ElevatedButton(
      //               onPressed: joinRoom,
      //               child: const Text("Join Room"),
      //             ),
      //
      //             const SizedBox(height: 10),
      //
      //             // 🔥 CREATE CONNECTION (ONLY ONE DEVICE PRESSES)
      //             ElevatedButton(
      //               onPressed: createConnection,
      //               child: const Text("Create Connection"),
      //             ),
      //
      //             const SizedBox(height: 20),
      //
      //             // 📁 SEND FILE
      //             ElevatedButton(
      //               onPressed: pickAndSendFile,
      //               child: const Text("Send File"),
      //             ),
      //
      //             const SizedBox(height: 20),
      //
      //             // 📊 STATES
      //             if (state is SendingState) ProgressBar(state.progress),
      //             if (state is ReceivingState) ProgressBar(state.progress),
      //             if (state is CompletedState)
      //               Text("Saved: ${state.path}"),
      //           ],
      //         ),
      //       );
      //     },
      //   ),
      // ),

      body: BlocProvider(
        create: (_) => widget.bloc,
        child: Builder( // 🔥 ADD THIS
          builder: (context) {
            return BlocBuilder<FileBloc, FileState>(
              builder: (context, state) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      TextField(
                        controller: roomController,
                        decoration: const InputDecoration(
                          labelText: "Enter Room ID",
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 10),

                      ElevatedButton(
                        onPressed: joinRoom,
                        child: const Text("Join Room"),
                      ),

                      const SizedBox(height: 10),

                      ElevatedButton(
                        onPressed: createConnection,
                        child: const Text("Create Connection"),
                      ),

                      const SizedBox(height: 20),

                      ElevatedButton(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles();
                          if (result == null) return;

                          final path = result.files.first.path;
                          if (path == null) return;

                          final file = File(path);
                          final bytes = await file.readAsBytes();

                          // ✅ NOW THIS CONTEXT IS CORRECT
                          context.read<FileBloc>().add(
                            SendFileEvent(bytes),
                          );
                        },
                        child: const Text("Send File"),
                      ),

                      const SizedBox(height: 20),

                      if (state is SendingState) ...[
                        ProgressBar(state.progress),
                        Text("📤 Sending file..."),
                      ],

                      if (state is ReceivingState) ...[
                        ProgressBar(state.progress),
                        Text("📥 Receiving file..."),
                      ],

                      if (state is CompletedState)
                        Text("Saved: ${state.path}"),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}