import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/thread.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Box _threadsBox;

  @override
  void initState() {
    super.initState();
    _threadsBox = Hive.box('threads');
  }

  List<Thread> get _threads {
    return _threadsBox.values
        .whereType<Map>()
        .map((m) => Thread.fromMap(m))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  String _randomId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  void _createNewThread() {
    final thread = Thread(
      id: _randomId(),
      title: 'New conversation',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    thread.save(_threadsBox);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(thread: thread)),
    );
  }

  void _openThread(Thread thread) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(thread: thread)),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.psychology, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('OpenClaw Voice'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _threadsBox.listenable(),
        builder: (context, box, _) {
          final threads = _threads;
          if (threads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_none, color: AppTheme.primaryColor, size: 40),
                  ),
                  const SizedBox(height: 20),
                  const Text('No conversations yet',
                      style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  const Text('Tap + to start talking',
                      style: TextStyle(color: Colors.white38, fontSize: 14)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: threads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final thread = threads[index];
              return Dismissible(
                key: Key(thread.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.red),
                ),
                onDismissed: (_) {
                  thread.delete(_threadsBox);
                  final messagesBox = Hive.box('messages');
                  final toDelete = messagesBox.keys
                      .where((k) => k.toString().startsWith(thread.id))
                      .toList();
                  for (final k in toDelete) messagesBox.delete(k);
                },
                child: InkWell(
                  onTap: () => _openThread(thread),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.psychology, color: AppTheme.primaryColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(thread.title,
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              if (thread.lastMessage.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(thread.lastMessage,
                                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_formatTime(thread.updatedAt),
                            style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewThread,
        icon: const Icon(Icons.add),
        label: const Text('New chat'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }
}
