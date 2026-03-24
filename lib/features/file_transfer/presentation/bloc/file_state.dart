class FileLogEntry {
  final String message;
  final DateTime timestamp;
  final bool isError;

  const FileLogEntry({
    required this.message,
    required this.timestamp,
    this.isError = false,
  });
}

class FileState {
  final String statusMessage;
  final double progress;
  final bool isSending;
  final bool isReceiving;
  final String? savedPath;
  final String? activeFileName;
  final int bytesTransferred;
  final int? totalBytes;
  final List<FileLogEntry> logs;
  final bool hasError;

  const FileState({
    required this.statusMessage,
    required this.progress,
    required this.isSending,
    required this.isReceiving,
    required this.savedPath,
    required this.activeFileName,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.logs,
    required this.hasError,
  });

  factory FileState.initial() {
    return const FileState(
      statusMessage: 'Join a room to start sharing files.',
      progress: 0,
      isSending: false,
      isReceiving: false,
      savedPath: null,
      activeFileName: null,
      bytesTransferred: 0,
      totalBytes: null,
      logs: [],
      hasError: false,
    );
  }

  FileState copyWith({
    String? statusMessage,
    double? progress,
    bool? isSending,
    bool? isReceiving,
    String? savedPath,
    bool clearSavedPath = false,
    String? activeFileName,
    bool clearActiveFileName = false,
    int? bytesTransferred,
    int? totalBytes,
    bool clearTotalBytes = false,
    List<FileLogEntry>? logs,
    bool? hasError,
  }) {
    return FileState(
      statusMessage: statusMessage ?? this.statusMessage,
      progress: progress ?? this.progress,
      isSending: isSending ?? this.isSending,
      isReceiving: isReceiving ?? this.isReceiving,
      savedPath: clearSavedPath ? null : (savedPath ?? this.savedPath),
      activeFileName: clearActiveFileName ? null : (activeFileName ?? this.activeFileName),
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: clearTotalBytes ? null : (totalBytes ?? this.totalBytes),
      logs: logs ?? this.logs,
      hasError: hasError ?? this.hasError,
    );
  }
}
