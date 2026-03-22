abstract class FileEvent {}

class SendFileEvent extends FileEvent {
  final List<int> bytes;
  SendFileEvent(this.bytes);
}

class ReceiveChunkEvent extends FileEvent {
  final List<int> chunk;
  ReceiveChunkEvent(this.chunk);
}

class CompleteReceiveEvent extends FileEvent {}
