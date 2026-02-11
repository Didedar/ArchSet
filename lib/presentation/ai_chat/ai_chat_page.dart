import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_strings.dart';
import '../providers/audio_provider.dart';
import '../providers/sync_provider.dart';

class AIChatPage extends ConsumerStatefulWidget {
  const AIChatPage({super.key});

  @override
  ConsumerState<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends ConsumerState<AIChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Trigger sync when entering chat to ensure RAG has latest data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncServiceProvider).sync();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final service = ref.read(backendGeminiServiceProvider);

      // Convert messages to history format expected by backend
      final history = _messages
          .where((m) => m['role'] != 'error')
          .map((m) => {'role': m['role'], 'content': m['content']})
          .toList();

      // Remove the last user message from history as it is sent as 'query'
      if (history.isNotEmpty) {
        history.removeLast();
      }

      final response = await service.chatWithDiary(text, history: history);

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response != null) {
            _messages.add({'role': 'assistant', 'content': response});
          } else {
            _messages.add({
              'role': 'error',
              'content': AppStrings.tr(ref, AppStrings.failedToGetResponse),
            });
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _messages.add({
            'role': 'error',
            'content': '${AppStrings.tr(ref, AppStrings.errorLabel)}$e',
          });
        });
      }
    }
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
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final textColor = theme.colorScheme.onSurface;
    final hintColor = theme.colorScheme.onSurface.withOpacity(0.5);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppStrings.tr(ref, AppStrings.aiChat),
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: textColor),
            onPressed: () {}, // Add menu actions if needed
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(cardColor, textColor, hintColor)
                : _buildChatList(textColor),
          ),
          _buildInputArea(cardColor, textColor, hintColor),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color cardColor, Color textColor, Color hintColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildFeatureCard(
            cardColor,
            Icons.storage,
            AppStrings.tr(ref, AppStrings.diaryBase),
            AppStrings.tr(ref, AppStrings.diaryBaseDesc),
            textColor,
            hintColor,
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            cardColor,
            Icons.help_outline,
            AppStrings.tr(ref, AppStrings.askQuestions),
            AppStrings.tr(ref, AppStrings.askQuestionsDesc),
            textColor,
            hintColor,
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            cardColor,
            Icons.school_outlined,
            AppStrings.tr(ref, AppStrings.study),
            AppStrings.tr(ref, AppStrings.studyDesc),
            textColor,
            hintColor,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    Color cardColor,
    IconData icon,
    String title,
    String description,
    Color textColor,
    Color hintColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: hintColor, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(Color textColor) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isUser = msg['role'] == 'user';
        final isError = msg['role'] == 'error';

        // Theme colors
        final theme = Theme.of(context);
        final userBubbleColor = theme.colorScheme.primaryContainer;
        final botBubbleColor = theme.cardColor;
        final errorBubbleColor = theme.colorScheme.errorContainer;

        final bubbleColor = isUser
            ? userBubbleColor
            : (isError ? errorBubbleColor : botBubbleColor);

        // Ensure text is readable on bubble
        final bubbleTextColor = isUser
            ? theme.colorScheme.onPrimaryContainer
            : (isError ? theme.colorScheme.onErrorContainer : textColor);

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              msg['content'] ?? '',
              style: TextStyle(color: bubbleTextColor, fontSize: 15),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea(Color cardColor, Color textColor, Color hintColor) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        30 + MediaQuery.of(context).padding.bottom, // Fix safe area
      ),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: AppStrings.tr(ref, AppStrings.yourText),
                  hintStyle: TextStyle(color: hintColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onSubmitted: _isLoading ? null : _sendMessage,
              ),
            ),
            if (_isLoading)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: textColor,
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                color: textColor,
                onPressed: () => _sendMessage(_controller.text),
              ),
          ],
        ),
      ),
    );
  }
}
