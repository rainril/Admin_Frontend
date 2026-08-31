import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/chat_session.dart';
import '../services/chatbot_service.dart';
import '../services/chatbot_history_service.dart';

const double _historySidebarBreakpoint = 760;

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatSession> _sessions = [];
  String? _activeId;
  bool _historyLoaded = false;
  bool _isLoading = false;

  ChatSession? get _active {
    for (final s in _sessions) {
      if (s.id == _activeId) return s;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    final sessions = await ChatbotHistoryService.loadSessions();
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (sessions.isEmpty) {
      sessions.add(ChatSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: 'New Chat',
        messages: [],
      ));
    }
    setState(() {
      _sessions = sessions;
      _activeId = sessions.first.id;
      _historyLoaded = true;
    });
  }

  Future<void> _persist() => ChatbotHistoryService.saveSessions(_sessions);

  void _startNewChat() {
    setState(() {
      _sessions.removeWhere((s) => s.messages.isEmpty);
      final session = ChatSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: 'New Chat',
        messages: [],
      );
      _sessions.insert(0, session);
      _activeId = session.id;
    });
    _persist();
  }

  void _selectSession(String id) {
    if (id == _activeId) return;
    setState(() => _activeId = id);
    _scrollToBottom();
  }

  Future<void> _confirmDeleteSession(ChatSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text('This will permanently delete "${session.title}".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _sessions.removeWhere((s) => s.id == session.id);
      if (_activeId == session.id) {
        if (_sessions.isEmpty) {
          final fresh = ChatSession(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: 'New Chat',
            messages: [],
          );
          _sessions.add(fresh);
          _activeId = fresh.id;
        } else {
          _activeId = _sessions.first.id;
        }
      }
    });
    _persist();
  }

  String _titleFrom(String text) {
    final t = text.trim();
    if (t.length <= 40) return t;
    return '${t.substring(0, 40)}…';
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final session = _active;
    if (text.isEmpty || _isLoading || session == null) return;

    final history = session.messages
        .where((m) => !m.isError)
        .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
        .toList();

    setState(() {
      session.messages.add(ChatMessage(text: text, isUser: true));
      if (session.title == 'New Chat') session.title = _titleFrom(text);
      session.updatedAt = DateTime.now();
      _sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await ChatbotService.sendMessage(text, history);
      setState(() {
        session.messages.add(ChatMessage(text: response, isUser: false));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        session.messages.add(ChatMessage(
          text:
              "Unable to reach the PrimeFit AI assistant. Please ensure the Laravel API is running on port 8000.",
          isUser: false,
          isError: true,
        ));
        _isLoading = false;
      });
    }
    _persist();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_historyLoaded) {
      return const Center(child: CircularProgressIndicator(color: AppColors.cyan));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _historySidebarBreakpoint;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HistorySidebar(
                sessions: _sessions,
                activeId: _activeId,
                onNewChat: _startNewChat,
                onSelect: _selectSession,
                onDelete: _confirmDeleteSession,
              ),
              Expanded(child: _chatColumn(context)),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NarrowTopBar(
              title: _active?.title ?? 'New Chat',
              onNewChat: _startNewChat,
              onOpenHistory: () => _openHistorySheet(context),
            ),
            Expanded(child: _chatColumn(context)),
          ],
        );
      },
    );
  }

  void _openHistorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.6,
        child: _HistorySidebar(
          sessions: _sessions,
          activeId: _activeId,
          onNewChat: () {
            Navigator.pop(ctx);
            _startNewChat();
          },
          onSelect: (id) {
            Navigator.pop(ctx);
            _selectSession(id);
          },
          onDelete: _confirmDeleteSession,
          embedded: true,
        ),
      ),
    );
  }

  Widget _chatColumn(BuildContext context) {
    final messages = _active?.messages ?? const <ChatMessage>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Text(
                    'Ask PrimeFit Assistant anything about your gym',
                    style: TextStyle(color: AppTheme.textMuted(context)),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return Align(
                      alignment:
                          msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                        decoration: BoxDecoration(
                          color: msg.isUser
                              ? AppColors.cyan
                              : (msg.isError
                                  ? AppColors.dangerBg
                                  : Theme.of(context).cardColor),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft: Radius.circular(msg.isUser ? 14 : 4),
                            bottomRight: Radius.circular(msg.isUser ? 4 : 14),
                          ),
                          border: msg.isError
                              ? Border.all(color: AppColors.danger)
                              : (msg.isUser
                                  ? null
                                  : Border.all(color: Theme.of(context).dividerColor)),
                        ),
                        child: Text(
                          msg.text,
                          style: TextStyle(
                            color: msg.isUser
                                ? Colors.white
                                : (msg.isError
                                    ? AppColors.danger
                                    : AppTheme.heading(context)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan),
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Ask PrimeFit Assistant...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isLoading ? null : _sendMessage,
                icon: const Icon(Icons.send_rounded, color: AppColors.cyan),
                style: IconButton.styleFrom(backgroundColor: AppTheme.pageBackground(context)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NarrowTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onNewChat;
  final VoidCallback onOpenHistory;

  const _NarrowTopBar({
    required this.title,
    required this.onNewChat,
    required this.onOpenHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Chat history',
            onPressed: onOpenHistory,
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.heading(context)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, color: AppColors.cyan),
            tooltip: 'New chat',
            onPressed: onNewChat,
          ),
        ],
      ),
    );
  }
}

class _HistorySidebar extends StatelessWidget {
  final List<ChatSession> sessions;
  final String? activeId;
  final VoidCallback onNewChat;
  final ValueChanged<String> onSelect;
  final ValueChanged<ChatSession> onDelete;
  final bool embedded;

  const _HistorySidebar({
    required this.sessions,
    required this.activeId,
    required this.onNewChat,
    required this.onSelect,
    required this.onDelete,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: onNewChat,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyan,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        Expanded(
          child: sessions.isEmpty
              ? Center(
                  child: Text('No chats yet',
                      style: TextStyle(color: AppTheme.textMuted(context))),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: sessions.length,
                  itemBuilder: (context, i) {
                    final s = sessions[i];
                    final active = s.id == activeId;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: active ? AppColors.cyan.withValues(alpha: 0.12) : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        leading: Icon(Icons.chat_bubble_outline,
                            size: 18,
                            color: active ? AppColors.cyan : AppTheme.textMuted(context)),
                        title: Text(
                          s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                            color: active ? AppColors.cyan : AppTheme.heading(context),
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 16, color: AppTheme.textMuted(context)),
                          tooltip: 'Delete chat',
                          onPressed: () => onDelete(s),
                        ),
                        onTap: () => onSelect(s.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );

    if (embedded) return content;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: content,
    );
  }
}
