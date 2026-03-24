import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  static final instance = WebRTCService._();
  WebRTCService._();

  RTCPeerConnection? pc;
  RTCDataChannel? dc;

  Function(Uint8List data)? onData;
  Function(Map<String, dynamic> message)? onControlMessage;
  Function(String state)? onConnectionStateChange;
  Function(String message)? onLog;
  Function(RTCIceCandidate candidate)? onIceCandidate;

  bool isSender = false;

  Future<void> init({required bool isSender}) async {
    await _disposeCurrentConnection();

    this.isSender = isSender;

    pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
    });

    _log('Peer connection created (${isSender ? 'sender' : 'receiver'} mode).');

    pc!.onConnectionState = (state) {
      _log('Peer connection state changed to $state.');
      onConnectionStateChange?.call(state.toString());
    };

    pc!.onIceCandidate = (candidate) {
      if ((candidate.candidate ?? '').isEmpty) {
        return;
      }

      _log('Local ICE candidate generated.');
      onIceCandidate?.call(candidate);
    };

    pc!.onDataChannel = (channel) {
      dc = channel;
      _log('Incoming data channel received.');
      _setupDataChannel();
    };

    if (isSender) {
      dc = await pc!.createDataChannel('file', RTCDataChannelInit());
      _log('Outgoing data channel created.');
      _setupDataChannel();
    }
  }

  Future<void> _disposeCurrentConnection() async {
    await dc?.close();
    dc = null;
    await pc?.close();
    pc = null;
  }

  void _setupDataChannel() {
    final channel = dc;
    if (channel == null) {
      return;
    }

    channel.onDataChannelState = (state) {
      _log('Data channel state changed to $state.');
    };

    channel.onMessage = (msg) {
      if (msg.isBinary) {
        final data = msg.binary;
        _log('Received binary chunk (${data.length} bytes).');
        onData?.call(data);
        return;
      }

      final raw = msg.text;
      _log('Received control message: $raw');

      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          onControlMessage?.call(decoded);
        }
      } catch (_) {
        _log('Ignored malformed control message.');
      }
    };
  }

  bool isConnected() {
    return dc != null && dc!.state == RTCDataChannelState.RTCDataChannelOpen;
  }

  Future<Map<String, dynamic>> createOffer() async {
    final offer = await pc!.createOffer();
    await pc!.setLocalDescription(offer);
    _log('Offer created and stored locally.');
    return offer.toMap();
  }

  Future<Map<String, dynamic>> createAnswer() async {
    final answer = await pc!.createAnswer();
    await pc!.setLocalDescription(answer);
    _log('Answer created and stored locally.');
    return answer.toMap();
  }

  Future<void> setRemote(Map data) async {
    await pc!.setRemoteDescription(
      RTCSessionDescription(data['sdp'] as String, data['type'] as String),
    );
    _log('Remote session description applied (${data['type']}).');
  }

  Future<void> addIce(Map data) async {
    await pc!.addCandidate(
      RTCIceCandidate(
        data['candidate'] as String?,
        data['sdpMid'] as String?,
        data['sdpMLineIndex'] as int?,
      ),
    );
    _log('Remote ICE candidate added.');
  }

  void sendData(Uint8List data) {
    if (!isConnected()) {
      _log('Cannot send binary data because the data channel is not open.');
      return;
    }

    dc!.send(RTCDataChannelMessage.fromBinary(data));
  }

  void sendControlMessage(Map<String, dynamic> message) {
    if (!isConnected()) {
      _log('Cannot send control message because the data channel is not open.');
      return;
    }

    final payload = jsonEncode(message);
    dc!.send(RTCDataChannelMessage(payload));
    _log('Sent control message: $payload');
  }

  void _log(String message) {
    print('🌐 $message');
    onLog?.call(message);
  }
}
