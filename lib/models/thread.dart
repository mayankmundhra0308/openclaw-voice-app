import 'package:hive/hive.dart';

part 'thread.g.dart';

@HiveType(typeId: 0)
class Thread extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  DateTime createdAt;

  @HiveField(3)
  DateTime updatedAt;

  @HiveField(4)
  String lastMessage;

  Thread({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage = '',
  });
}

@HiveType(typeId: 1)
class Message extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String threadId;

  @HiveField(2)
  bool isUser;

  @HiveField(3)
  String text;

  @HiveField(4)
  String? summary; // AI-generated 1-2 sentence voice summary

  @HiveField(5)
  DateTime timestamp;

  Message({
    required this.id,
    required this.threadId,
    required this.isUser,
    required this.text,
    this.summary,
    required this.timestamp,
  });
}
