import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/chat_session.dart';
import '../services/chatbot_service.dart';
import '../services/chatbot_history_service.dart';

const double _historySidebarBreakpoint = 760;

/// A floating live-chat widget (Intercom/Crisp style) that overlays a
/// circular chat FAB in the bottom-right corner of the screen. Tapping it
/// expands a chat panel anchored to the same corner, without navigating
/// away from the current screen.
///
/// Wrap the main content with [FloatingChatbotOverlay] so the FAB + panel
/// sit above every admin screen.
class FloatingChatbotOverlay extends StatefulWidget {
  final Widget child;

  const FloatingChatbotOverlay({super.key, required this.child});

  @override
  State<FloatingChatbotOverlay> createState() => _FloatingChatbotOverlayState();
}

class _FloatingChatbotOverlayState extends State<FloatingChatbotOverlay>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatSession> _sessions = [];
  String? _activeId;
  bool _historyLoaded = false;
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  ChatSession? get _active {
    for (final s in _sessions) {
      if (s.id == _activeId) return s;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _loadSessions();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _animController.dispose();
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
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _activeId = sessions.first.id;
      _historyLoaded = true;
    });
  }

  Future<void> _persist() => ChatbotHistoryService.saveSessions(_sessions);

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
    if (_isOpen) {
      _animController.forward(from: 0);
    } else {
      _animController.reverse();
    }
  }

  void _close() {
    setState(() => _isOpen = false);
    _animController.reverse();
  }

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
      if (!mounted) return;
      setState(() {
        session.messages.add(ChatMessage(text: response, isUser: false));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
    return Stack(
      children: [
        widget.child,
        if (_isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
        Positioned(
          right: 24,
          bottom: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_isOpen)
                FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    alignment: Alignment.bottomRight,
                    child: _buildPanel(context),
                  ),
                ),
              const SizedBox(height: 12),
              _buildFab(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFab(BuildContext context) {
    return FloatingActionButton(
      onPressed: _toggle,
      backgroundColor: AppColors.cyan,
      elevation: 6,
      child: Icon(
        _isOpen ? Icons.close : Icons.chat_bubble_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final panelWidth = size.width < 420 ? size.width - 32.0 : 380.0;
    final panelHeight = size.height < 700 ? size.height * 0.7 : 560.0;

    return SizedBox(
      width: panelWidth,
      height: panelHeight,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: !_historyLoaded
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.cyan),
                )
              : LayoutBuilder(
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
                          Expanded(child: _chatColumn(context, panelWidth)),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPanelHeader(context),
                        Expanded(child: _chatColumn(context, panelWidth)),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildPanelHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cyan.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble_rounded, color: AppColors.cyan, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'PrimeFit Assistant',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.heading(context),
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history, size: 20),
            tooltip: 'Chat history',
            onPressed: () => _openHistorySheet(context),
            color: AppTheme.textMuted(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, size: 20),
            tooltip: 'New chat',
            onPressed: _startNewChat,
            color: AppColors.cyan,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Close',
            onPressed: _close,
            color: AppTheme.textMuted(context),
          ),
        ],
      ),
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

  Widget _chatColumn(BuildContext context, double panelWidth) {
    final messages = _active?.messages ?? const <ChatMessage>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Ask PrimeFit Assistant anything about your gym',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted(context)),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return Align(
                      alignment: msg.isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: panelWidth * 0.7,
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: msg.isUser
                              ? AppColors.cyan
                              : (msg.isError
                                  ? AppColors.dangerBg
                                  : Theme.of(context).cardColor),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: Radius.circular(msg.isUser ? 12 : 4),
                            bottomRight: Radius.circular(msg.isUser ? 4 : 12),
                          ),
                          border: msg.isError
                              ? Border.all(color: AppColors.danger)
                              : (msg.isUser
                                  ? null
                                  : Border.all(
                                      color: Theme.of(context).dividerColor)),
                        ),
                        child: Text(
                          msg.text,
                          style: TextStyle(
                            fontSize: 13,
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
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.cyan),
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Ask PrimeFit Assistant...',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide:
                          BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                  ),
                  style: const TextStyle(fontSize: 13),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: _isLoading ? null : _sendMessage,
                icon: const Icon(Icons.send_rounded, color: AppColors.cyan),
                iconSize: 22,
                style: IconButton.styleFrom(
                    backgroundColor: AppTheme.pageBackground(context),
                    minimumSize: const Size(38, 38)),
              ),
            ],
          ),
        ),
      ],
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
          padding: const EdgeInsets.all(10),
          child: ElevatedButton.icon(
            onPressed: onNewChat,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyan,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 13),
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
                        color: active
                            ? AppColors.cyan.withValues(alpha: 0.12)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        leading: Icon(Icons.chat_bubble_outline,
                            size: 16,
                            color: active
                                ? AppColors.cyan
                                : AppTheme.textMuted(context)),
                        title: Text(
                          s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                active ? FontWeight.w600 : FontWeight.normal,
                            color: active
                                ? AppColors.cyan
                                : AppTheme.heading(context),
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 14,
                              color: AppTheme.textMuted(context)),
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
      width: 220,
      decoration: BoxDecoration(
        border: Border(
            right: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: content,
    );
  }
}
