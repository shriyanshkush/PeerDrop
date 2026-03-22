abstract class FileState {}

class FileInitial extends FileState {}

class SendingState extends FileState {
  final double progress;
  final String log;

  SendingState(this.progress, this.log);
}

class ReceivingState extends FileState {
  final double progress;
  final String log;

  ReceivingState(this.progress, this.log);
}

class CompletedState extends FileState {
  final String path;

  CompletedState(this.path);
}

class StatusState extends FileState {
  final String message;

  StatusState(this.message);
}