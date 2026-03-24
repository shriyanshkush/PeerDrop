import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

class SignalingService {
  SignalingService({String? serverUrl})
      : serverUrl = serverUrl ?? 'http://10.21.8.149:3000';

  final String serverUrl;
  io.Socket? _socket;

  Function(Map<String, dynamic>)? onOffer;
  Function(Map<String, dynamic>)? onAnswer;
  Function(Map<String, dynamic>)? onIce;
  Function(String)? onLog;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect(String roomId) async {
    final completer = Completer<void>();
    if (_socket != null) {
      _socket!.dispose();
      _socket = null;
    }

    _socket = io.io(
      serverUrl,
      io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );

    _socket!.onConnect((_) {
      _log('Connected to signaling server.');
      _socket!.emit('join-room', {'roomId': roomId});
      _log('Joined room $roomId.');
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    _socket!.onConnectError((error) {
      _log('Signaling connect error: $error');
      if (!completer.isCompleted) {
        completer.completeError(error ?? 'Unknown signaling connection error');
      }
    });

    _socket!.onDisconnect((_) {
      _log('Disconnected from signaling server.');
    });

    _socket!.on('offer', (data) {
      _log('Offer received from room peer.');
      onOffer?.call(Map<String, dynamic>.from(data as Map));
    });

    _socket!.on('answer', (data) {
      _log('Answer received from room peer.');
      onAnswer?.call(Map<String, dynamic>.from(data as Map));
    });

    _socket!.on('ice-candidate', (data) {
      _log('ICE candidate received from room peer.');
      onIce?.call(Map<String, dynamic>.from(data as Map));
    });

    _socket!.on('room-members', (data) {
      final payload = Map<String, dynamic>.from(data as Map);
      _log('Room ${payload['roomId']} now has ${payload['occupants']} participant(s).');
    });

    _socket!.connect();
    await completer.future;
  }

  void sendOffer(Map<String, dynamic> offer, String roomId) {
    _socket?.emit('offer', {'roomId': roomId, ...offer});
    _log('Offer sent for room $roomId.');
  }

  void sendAnswer(Map<String, dynamic> answer, String roomId) {
    _socket?.emit('answer', {'roomId': roomId, ...answer});
    _log('Answer sent for room $roomId.');
  }

  void sendIce(dynamic candidate, String roomId) {
    _socket?.emit('ice-candidate', {
      'roomId': roomId,
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    });
    _log('ICE candidate sent for room $roomId.');
  }

  void _log(String message) {
    print('📡 $message');
    onLog?.call(message);
  }
}
