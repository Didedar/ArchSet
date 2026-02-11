/// Simple Note model without SQL dependencies
class Note {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String? audioPath;
  final String? folderName;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.audioPath,
    this.folderName,
  });

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? date,
    String? audioPath,
    String? folderName,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      date: date ?? this.date,
      audioPath: audioPath ?? this.audioPath,
      folderName: folderName ?? this.folderName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'date': date.toIso8601String(),
      'audioPath': audioPath,
      'folderName': folderName,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      date: DateTime.parse(json['date'] as String),
      audioPath: json['audioPath'] as String?,
      folderName: json['folderName'] as String?,
    );
  }
}
