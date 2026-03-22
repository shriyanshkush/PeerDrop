import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  static final instance = WebRTCService._();
  WebRTCService._();

  RTCPeerConnection? pc;
  RTCDataChannel? dc;

  Function(Uint8List)? onData;
  Function(String)? onConnectionStateChange;
  Function()? onComplete;

  bool isSender = false;

  // 🔥 INIT
  Future<void> init({required bool isSender}) async {
    this.isSender = isSender;

    pc = await createPeerConnection({
      "iceServers": [
        {"urls": "stun:stun.l.google.com:19302"},
        {"urls": "stun:stun1.l.google.com:19302"},
      ]
    });

    // 🔗 CONNECTION STATE
    pc!.onConnectionState = (state) {
      print("🔗 PeerConnection State: $state");
      onConnectionStateChange?.call(state.toString());
    };

    // 🧊 ICE
    pc!.onIceCandidate = (candidate) {
      // handled outside
    };

    // 📥 RECEIVER SIDE: gets channel
    pc!.onDataChannel = (channel) {
      print("📡 DataChannel RECEIVED");

      dc = channel;

      _setupDataChannel();
    };

    // 📤 SENDER SIDE: creates channel
    if (isSender) {
      dc = await pc!.createDataChannel(
        "file",
        RTCDataChannelInit(),
      );

      print("📡 DataChannel CREATED (sender)");

      _setupDataChannel();
    }
  }

  // 🔥 COMMON DATA CHANNEL SETUP
  void _setupDataChannel() {
    dc!.onDataChannelState = (state) {
      print("📡 DataChannel State: $state");
    };

    dc!.onMessage = (msg) {
      print("📥 MESSAGE ARRIVED");

      if (msg.isBinary) {
        final data = msg.binary;

        final text = String.fromCharCodes(data);

        // ✅ END SIGNAL
        if (text == "END") {
          print("📦 END RECEIVED");
          onComplete?.call();
          return;
        }

        print("📥 Received ${data.length} bytes");

        onData?.call(data);
      }
    };
  }

  // 🔥 CHECK CONNECTION
  bool isConnected() {
    return dc != null &&
        dc!.state == RTCDataChannelState.RTCDataChannelOpen;
  }

  // 🔥 OFFER
  Future<Map<String, dynamic>> createOffer() async {
    final offer = await pc!.createOffer();
    await pc!.setLocalDescription(offer);
    return offer.toMap();
  }

  // 🔥 ANSWER
  Future<Map<String, dynamic>> createAnswer() async {
    final answer = await pc!.createAnswer();
    await pc!.setLocalDescription(answer);
    return answer.toMap();
  }

  // 🔥 REMOTE
  Future<void> setRemote(Map data) async {
    await pc!.setRemoteDescription(
      RTCSessionDescription(data['sdp'], data['type']),
    );
  }

  // 🔥 ICE
  Future<void> addIce(Map data) async {
    await pc!.addCandidate(
      RTCIceCandidate(
        data['candidate'],
        data['sdpMid'],
        data['sdpMLineIndex'],
      ),
    );
  }

  // 🔥 SEND DATA
  void sendData(Uint8List data) {
    if (!isConnected()) {
      print("❌ Cannot send: DataChannel not open");
      return;
    }

    dc!.send(RTCDataChannelMessage.fromBinary(data));
  }
}