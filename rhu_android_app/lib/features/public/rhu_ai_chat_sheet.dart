import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

Future<void> showRhuAiChatSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return const RhuAiChatSheet();
    },
  );
}

class RhuAiChatSheet extends StatefulWidget {
  const RhuAiChatSheet({super.key});

  @override
  State<RhuAiChatSheet> createState() => _RhuAiChatSheetState();
}

class _RhuAiChatSheetState extends State<RhuAiChatSheet> {
  static const String _aiEndpoint = 'https://rhu-ai.onrender.com/api/ai/chat';

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_AiChatMessage> _messages = <_AiChatMessage>[
    _AiChatMessage(
      text:
          "I am your RHU AI Chat. Ask anything about this app and I’ll guide you.",
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];

  bool _isSending = false;
  DateTime? _lastSentAt;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _canSend {
    final String text = _messageController.text.trim();

    return text.isNotEmpty && text.length <= 500 && !_isSending;
  }

  void _refreshUi() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _sendMessage() async {
    final String message = _messageController.text.trim();

    if (message.isEmpty) {
      return;
    }

    if (message.length > 500) {
      _showError('Please keep your question below 500 characters.');
      return;
    }

    final DateTime now = DateTime.now();
    final DateTime? lastSentAt = _lastSentAt;

    if (lastSentAt != null &&
        now.difference(lastSentAt) < const Duration(seconds: 2)) {
      _showError('Please wait a moment before sending another question.');
      return;
    }

    _lastSentAt = now;

    setState(() {
      _messages.add(
        _AiChatMessage(
          text: message,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isSending = true;
      _messageController.clear();
    });

    _scrollToBottom();

    try {
      final http.Response response = await http
          .post(
            Uri.parse(_aiEndpoint),
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'message': message,
            }),
          )
          .timeout(const Duration(seconds: 45));

      final dynamic decoded = jsonDecode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String errorMessage = 'The RHU AI could not answer right now.';

        if (decoded is Map<String, dynamic>) {
          final dynamic serverMessage = decoded['message'];

          if (serverMessage != null &&
              serverMessage.toString().trim().isNotEmpty) {
            errorMessage = serverMessage.toString();
          }
        }

        throw _AiChatException(errorMessage);
      }

      if (decoded is! Map<String, dynamic>) {
        throw const _AiChatException('Invalid AI response.');
      }

      final bool success = decoded['success'] == true;

      final String aiAnswer = _readString(
        decoded,
        <String>['aiAnswer', 'answer', 'message'],
      );

      if (!success || aiAnswer.trim().isEmpty) {
        throw const _AiChatException(
          'The RHU AI did not return an answer.',
        );
      }

      final dynamic source = decoded['source'];
      final String sourceTitle = source is Map<String, dynamic>
          ? _readString(source, <String>['title', 'category'])
          : '';

      final int confidence = _readInt(decoded, 'confidence');

      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(
          _AiChatMessage(
            text: aiAnswer,
            isUser: false,
            timestamp: DateTime.now(),
            sourceTitle: sourceTitle,
            confidence: confidence,
          ),
        );
      });

      _scrollToBottom();
    } on TimeoutException {
      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(
          _AiChatMessage(
            text:
                'The RHU AI is taking too long to respond. Please try again in a moment.',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ),
        );
      });

      _scrollToBottom();
    } on _AiChatException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(
          _AiChatMessage(
            text: error.message,
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ),
        );
      });

      _scrollToBottom();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(
          _AiChatMessage(
            text:
                'Unable to connect to RHU AI Chat. Please check your internet connection and try again.',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ),
        );
      });

      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.42,
        maxChildSize: 0.94,
        builder: (
          BuildContext context,
          ScrollController sheetScrollController,
        ) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                _AiChatHeader(
                  onClose: () {
                    Navigator.of(context).pop();
                  },
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: _messages.length + (_isSending ? 1 : 0),
                    itemBuilder: (BuildContext context, int index) {
                      if (_isSending && index == _messages.length) {
                        return const _TypingBubble();
                      }

                      return _MessageBubble(
                        message: _messages[index],
                      );
                    },
                  ),
                ),
                _InputBar(
                  controller: _messageController,
                  isSending: _isSending,
                  canSend: _canSend,
                  onChanged: (_) {
                    _refreshUi();
                  },
                  onSend: _sendMessage,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AiChatHeader extends StatelessWidget {
  const _AiChatHeader({
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Color(0xFF0EA5E9),
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'RHU AI Chat',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Ask about the app, RHU services, appointments, QR, and guides.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
  });

  final _AiChatMessage message;

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.isUser;

    final Color bubbleColor = message.isError
        ? const Color(0xFFFEF2F2)
        : isUser
            ? const Color(0xFF0EA5E9)
            : Colors.white;

    final Color textColor = message.isError
        ? const Color(0xFF991B1B)
        : isUser
            ? Colors.white
            : const Color(0xFF0F172A);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 20),
          ),
          border: Border.all(
            color: isUser
                ? const Color(0xFF0EA5E9)
                : message.isError
                    ? const Color(0xFFFECACA)
                    : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              message.text,
              style: TextStyle(
                color: textColor,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!isUser &&
                (message.sourceTitle.trim().isNotEmpty ||
                    message.confidence > 0)) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  if (message.sourceTitle.trim().isNotEmpty)
                    _SmallTag(
                      label: message.sourceTitle,
                      color: const Color(0xFF0EA5E9),
                    ),
                  if (message.confidence > 0)
                    _SmallTag(
                      label: 'Confidence ${message.confidence}/10',
                      color: const Color(0xFF16A34A),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              'RHU AI is typing...',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.canSend,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final bool canSend;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Color(0xFFE5E7EB),
            ),
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                maxLength: 500,
                enabled: !isSending,
                onChanged: onChanged,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (canSend) {
                    onSend();
                  }
                },
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Ask about appointments, RHU, QR, messages...',
                  prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(
                      color: Color(0xFFE5E7EB),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(
                      color: Color(0xFFE5E7EB),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FloatingActionButton.small(
              heroTag: 'rhu_ai_send_button',
              backgroundColor:
                  canSend ? const Color(0xFF0EA5E9) : const Color(0xFF94A3B8),
              onPressed: canSend ? onSend : null,
              child: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AiChatMessage {
  const _AiChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.sourceTitle = '',
    this.confidence = 0,
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String sourceTitle;
  final int confidence;
  final bool isError;
}

class _AiChatException implements Exception {
  const _AiChatException(this.message);

  final String message;
}

String _readString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final String key in keys) {
    final dynamic value = json[key];

    if (value == null) {
      continue;
    }

    final String text = value.toString().trim();

    if (text.isNotEmpty && text != 'null') {
      return text;
    }
  }

  return fallback;
}

int _readInt(
  Map<String, dynamic> json,
  String key,
) {
  final dynamic value = json[key];

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value) ?? 0;
  }

  return 0;
}