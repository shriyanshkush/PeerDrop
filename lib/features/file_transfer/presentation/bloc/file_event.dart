abstract class FileEvent {}

class LogMessageEvent extends FileEvent {
  final String message;
  final bool isError;

  LogMessageEvent(this.message, {this.isError = false});
}

class SendFileEvent extends FileEvent {
  final List<int> bytes;
  final String fileName;

  SendFileEvent({required this.bytes, required this.fileName});
}

class BeginReceiveEvent extends FileEvent {
  final String fileName;
  final int totalBytes;

  BeginReceiveEvent({required this.fileName, required this.totalBytes});
}

class ReceiveChunkEvent extends FileEvent {
  final List<int> chunk;

  ReceiveChunkEvent(this.chunk);
}

class CompleteReceiveEvent extends FileEvent {}
