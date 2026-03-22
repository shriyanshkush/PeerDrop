import 'package:socket_io_client/socket_io_client.dart' as IO;

class SignalingService {
  late IO.Socket socket;

  Function(Map)? onOffer;
  Function(Map)? onAnswer;
  Function(Map)? onIce;

  void connect(String roomId) {
    socket = IO.io(
      "http://10.21.8.149:3000",
      IO.OptionBuilder()
          .setTransports(['websocket']) // VERY IMPORTANT
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      print("✅ Connected to server");
      socket.emit("join-room", {"roomId": roomId});
    });

    socket.on("offer", (data) {
      print("📩 OFFER RECEIVED");
      onOffer?.call(Map<String, dynamic>.from(data));
    });

    socket.on("answer", (data) {
      print("📩 ANSWER RECEIVED");
      onAnswer?.call(Map<String, dynamic>.from(data));
    });

    socket.on("ice-candidate", (data) => onIce?.call(Map<String, dynamic>.from(data)));
  }

  void sendOffer(Map offer, String roomId) {
    socket.emit("offer", {"roomId": roomId, ...offer});
  }

  void sendAnswer(Map answer, String roomId) {
    socket.emit("answer", {"roomId": roomId, ...answer});
  }

  void sendIce(candidate, String roomId) {
    socket.emit("ice-candidate", {
      "roomId": roomId,
      "candidate": candidate.candidate,
      "sdpMid": candidate.sdpMid,
      "sdpMLineIndex": candidate.sdpMLineIndex,
    });
  }
}