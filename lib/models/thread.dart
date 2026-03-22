import 'package:hive/hive.dart';

// Simple model classes - no code generation needed
class Thread {
  String id;
  String title;
  DateTime createdAt;
  DateTime updatedAt;
  String lastMessage;

  Thread({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastMessage': lastMessage,
  };

  static Thread fromMap(Map map) => Thread(
    id: map['id'] as String,
    title: map['title'] as String,
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
    lastMessage: (map['lastMessage'] as String?) ?? '',
  );

  void save(Box box) => box.put(id, toMap());
  void delete(Box box) => box.delete(id);
}

class Message {
  String id;
  String threadId;
  bool isUser;
  String text;
  DateTime timestamp;

  Message({
    required this.id,
    required this.threadId,
    required this.isUser,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'threadId': threadId,
    'isUser': isUser,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
  };

  static Message fromMap(Map map) => Message(
    id: map['id'] as String,
    threadId: map['threadId'] as String,
    isUser: map['isUser'] as bool,
    text: map['text'] as String,
    timestamp: DateTime.parse(map['timestamp'] as String),
  );

  void save(Box box) => box.put(id, toMap());
  void delete(Box box) => box.delete(id);
}
