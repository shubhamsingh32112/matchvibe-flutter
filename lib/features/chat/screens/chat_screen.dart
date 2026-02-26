import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/push_notification_service.dart';
import '../services/chat_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/availability_provider.dart';
import '../../video/controllers/call_connection_controller.dart';
import '../../support/services/support_service.dart';

class _CreatorImageAttachmentBuilder extends StreamAttachmentWidgetBuilder {
  const _CreatorImageAttachmentBuilder();

  @override
  bool canHandle(
    Message message,
    Map<String, List<Attachment>> attachments,
  ) {
    final senderRole = message.user?.extraData['appRole'] as String?;
    final isCreatorSender = senderRole == 'creator' || senderRole == 'admin';
    final imageAttachments = attachments['image'];
    return isCreatorSender &&
        imageAttachments != null &&
        imageAttachments.isNotEmpty;
  }

  @override
  Widget build(
    BuildContext context,
    Message message,
    Map<String, List<Attachment>> attachments,
  ) {
    final imageAttachment = attachments['image']!.first;
    final imageUrl = imageAttachment.imageUrl ??
        imageAttachment.assetUrl ??
        imageAttachment.thumbUrl;

    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final preview = GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          barrierColor: Colors.black87,
          builder: (ctx) => Dialog.fullscreen(
            backgroundColor: Colors.black,
            child: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton.filled(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 280,
          minWidth: 220,
          maxHeight: 360,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );

    return WrapAttachmentWidget(
      attachmentWidget: preview,
      attachmentShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  final String channelId;

  const ChatScreen({
    super.key,
    required this.channelId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  Channel? _channel;
  String? _otherUserName;
  String? _otherUserImage;
  String? _otherUserFirebaseUid;
  String? _otherUserMongoId;
  String? _otherUserAppRole;
  final ChatService _chatService = ChatService();
  final SupportService _supportService = SupportService();
  bool _isInitiatingCall = false;

  // Quota state
  int _freeRemaining = 3;
  int _costPerMessage = 0;
  int _userCoins = 0;
  bool _isCreator = false;

  @override
  void initState() {
    super.initState();
    // Tell PushNotificationService which channel is currently open
    // so it suppresses notifications for this channel.
    PushNotificationService.activeChannelId = widget.channelId;
    _initializeChannel();
  }

  @override
  void dispose() {
    // Clear active channel so notifications resume for this channel
    if (PushNotificationService.activeChannelId == widget.channelId) {
      PushNotificationService.activeChannelId = null;
    }
    super.dispose();
  }

  Future<void> _initializeChannel() async {
    try {
      final client = StreamChat.of(context).client;
      final channel = client.channel('messaging', id: widget.channelId);
      await channel.watch();

      // Extract other user's name
      final currentUserId = client.state.currentUser!.id;
      final members = channel.state!.members;
      final otherMember = members.firstWhere(
        (m) => m.userId != currentUserId,
      );
      final otherUserName =
          otherMember.user?.extraData['username'] as String? ??
              otherMember.user?.name ??
              'User';
      final otherUserImage = otherMember.user?.image;
      final otherUserFirebaseUid = otherMember.userId;
      final otherUserMongoId =
          otherMember.user?.extraData['mongoId'] as String?;
      final otherUserAppRole =
          otherMember.user?.extraData['appRole'] as String?;

      // Determine if the current user is a creator
      final authState = ref.read(authProvider);
      final isCreator = authState.user?.role == 'creator' ||
          authState.user?.role == 'admin';

      if (mounted) {
        setState(() {
          _channel = channel;
          _otherUserName = otherUserName;
          _otherUserImage = otherUserImage;
          _otherUserFirebaseUid = otherUserFirebaseUid;
          _otherUserMongoId = otherUserMongoId;
          _otherUserAppRole = otherUserAppRole;
          _isCreator = isCreator;
        });

        // Fetch quota info (only matters for regular users)
        if (!isCreator) {
          _refreshQuota();
        }
      }
    } catch (e) {
      debugPrint('❌ [CHAT] Failed to initialize channel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load chat: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        context.pop();
      }
    }
  }

  Future<void> _refreshQuota() async {
    try {
      final quota = await _chatService.getMessageQuota(widget.channelId);
      if (mounted) {
        setState(() {
          _freeRemaining = (quota['freeRemaining'] as num?)?.toInt() ?? 0;
          _costPerMessage = (quota['costPerMessage'] as num?)?.toInt() ?? 0;
          _userCoins = (quota['userCoins'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (e) {
      debugPrint('⚠️ [CHAT] Failed to fetch quota: $e');
    }
  }

  // ── Restricted content filter (applies to BOTH users and creators) ──

  static final RegExp _blockedDigits = RegExp(r'[045678]');
  static final RegExp _blockedWords = RegExp(
    r'\b(three|four|six|seven|eight|nine)\b',
    caseSensitive: false,
  );

  /// Returns `true` when the text contains a blocked digit (4-6) or
  /// a blocked number-word (three, four, six, seven, eight, nine).
  bool _containsRestrictedContent(String text) {
    return _blockedDigits.hasMatch(text) || _blockedWords.hasMatch(text);
  }

  bool _containsMediaAttachment(Message message) {
    final attachments = message.attachments;
    if (attachments.isEmpty) return false;

    for (final attachment in attachments) {
      final type = (attachment.type ?? '').toLowerCase();
      if (type == 'image' || type == 'video') {
        return true;
      }
    }

    return false;
  }

  bool _isCallActivityMessage(Message message) {
    final id = message.id;
    final text = message.text ?? '';
    final isCallActivityId = id.startsWith('call_activity_');
    final isLegacyCallActivity =
        message.type == 'system' && text.startsWith('Video call completed');
    return isCallActivityId || isLegacyCallActivity;
  }

  Widget _buildCallActivityCard(
    BuildContext context,
    Message message, {
    required bool showCallAgain,
    required bool isCreatorOnline,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final text = (message.text ?? '').trim();
    final canCallAgain = showCallAgain && isCreatorOnline && !_isInitiatingCall;
    final actionLabel = _isInitiatingCall
        ? 'Calling...'
        : isCreatorOnline
            ? 'Call again'
            : 'Creator offline';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Center(
        child: Material(
          color: scheme.tertiaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: canCallAgain ? _initiateVideoCall : null,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 340),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: scheme.tertiary.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.videocam_rounded,
                        size: 16,
                        color: scheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          text.isEmpty ? 'Video call completed' : text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (showCallAgain) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isInitiatingCall)
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                scheme.onTertiaryContainer,
                              ),
                            ),
                          )
                        else
                          Icon(
                            isCreatorOnline
                                ? Icons.call_made_rounded
                                : Icons.do_not_disturb_alt_rounded,
                            size: 14,
                            color: scheme.onTertiaryContainer
                                .withValues(alpha: isCreatorOnline ? 0.9 : 0.7),
                          ),
                        const SizedBox(width: 6),
                        Text(
                          actionLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: scheme.onTertiaryContainer
                                .withValues(alpha: isCreatorOnline ? 1 : 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRestrictedContentDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.block, color: Colors.red, size: 48),
        title: const Text('Not Allowed'),
        content: const Text('This action is not allowed.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAttachmentBlockedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.image_not_supported, color: Colors.red, size: 48),
        title: const Text('Attachment Not Allowed'),
        content: const Text(
          'Only creators can send images or videos in chat.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Called BEFORE every message send.
  /// Returns the message if allowed, throws to cancel.
  Future<Message> _onPreSend(Message message) async {
    // Non-creators are not allowed to send media attachments.
    if (!_isCreator && _containsMediaAttachment(message)) {
      _showAttachmentBlockedDialog();
      throw Exception('Only creators can send media attachments');
    }

    // ── Content filter (both users & creators) ──────────────────────
    final text = message.text ?? '';
    if (_containsRestrictedContent(text)) {
      _showRestrictedContentDialog();
      throw Exception('Message contains restricted content');
    }

    // Creators always send free
    if (_isCreator) return message;

    try {
      // Send message.id as idempotency key to prevent double-charge on retries
      final result = await _chatService.preSendMessage(
        widget.channelId,
        messageId: message.id,
      );

      final canSend = result['canSend'] as bool? ?? false;

      if (!canSend) {
        // Show insufficient coins dialog
        if (mounted) {
          _showInsufficientCoinsDialog(
            result['error'] as String? ?? 'Not enough coins',
          );
        }
        throw Exception('Cannot send message — insufficient coins');
      }

      // Update local quota state
      if (mounted) {
        setState(() {
          _freeRemaining =
              (result['freeRemaining'] as num?)?.toInt() ?? _freeRemaining;
          _userCoins = (result['userCoins'] as num?)?.toInt() ?? _userCoins;
          _costPerMessage = _freeRemaining > 0 ? 0 : 5;
        });
      }

      // Refresh auth to sync coin balance in AppBar
      if ((result['coinsCharged'] as num?)?.toInt() != null &&
          (result['coinsCharged'] as num).toInt() > 0) {
        ref.read(authProvider.notifier).refreshUser();
      }

      return message;
    } catch (e) {
      debugPrint('❌ [CHAT] Pre-send failed: $e');
      rethrow;
    }
  }

  void _showInsufficientCoinsDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.monetization_on, color: Colors.amber[700], size: 48),
        title: const Text('Not Enough Coins'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push('/wallet');
            },
            icon: const Icon(Icons.shopping_cart),
            label: const Text('Buy Coins'),
          ),
        ],
      ),
    );
  }

  // ── Video call from chat ───────────────────────────────────────────────

  Widget _buildCallAction(ColorScheme colorScheme, bool isOnline) {
    return IconButton(
      onPressed: isOnline ? _initiateVideoCall : null,
      icon: _isInitiatingCall
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            )
          : Icon(
              Icons.videocam,
              color: isOnline
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.3),
            ),
      tooltip: isOnline ? 'Video Call' : 'Offline',
    );
  }

  /// Whether the call button should be shown (regular user chatting with a creator)
  bool get _showCallButton {
    if (_isCreator) return false; // Creators don't call
    if (_otherUserFirebaseUid == null || _otherUserMongoId == null) return false;
    // Only show if the other user is a creator
    final otherRole = _otherUserAppRole;
    return otherRole == 'creator' || otherRole == 'admin';
  }

  bool get _canReportCreatorFromChat {
    if (_isCreator) return false;
    final otherRole = _otherUserAppRole;
    return otherRole == 'creator' || otherRole == 'admin';
  }

  void _showReportCreatorDialog() {
    final controller = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Report Creator'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _otherUserName?.trim().isNotEmpty == true
                      ? 'Tell us what happened with ${_otherUserName!.trim()}.'
                      : 'Tell us what happened.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Write your complaint',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final message = controller.text.trim();
                      if (message.length < 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please write at least 10 characters.'),
                          ),
                        );
                        return;
                      }

                      if (!ctx.mounted) return;
                      setDialogState(() => isSubmitting = true);
                      try {
                        await _supportService.reportCreator(
                          reasonMessage: message,
                          source: 'chat',
                          creatorLookupId: _otherUserMongoId,
                          creatorFirebaseUid: _otherUserFirebaseUid,
                          creatorName: _otherUserName,
                        );
                        if (!mounted || !ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Report submitted to admin team.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!mounted || !ctx.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to send report: $e')),
                        );
                        setDialogState(() => isSubmitting = false);
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send Report'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      // Delay disposal to avoid transient "used after disposed" during route
      // transition / IME teardown on some Android builds.
      Future<void>.delayed(const Duration(milliseconds: 250), controller.dispose);
    });
  }

  Future<void> _initiateVideoCall() async {
    if (_isInitiatingCall) return;
    if (_otherUserFirebaseUid == null || _otherUserMongoId == null) return;

    // Check coin balance
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user != null && user.coins < 10) {
      if (mounted) {
        _showInsufficientCoinsDialog('Minimum 10 coins required to start a call.\nYou currently have ${user.coins} coins.');
      }
      return;
    }

    setState(() => _isInitiatingCall = true);

    try {
      await ref
          .read(callConnectionControllerProvider.notifier)
          .startUserCall(
            creatorFirebaseUid: _otherUserFirebaseUid!,
            creatorMongoId: _otherUserMongoId!,
            creatorImageUrl: _otherUserImage,
          );
    } finally {
      if (mounted) setState(() => _isInitiatingCall = false);
    }
  }

  /// Build the message input with pre-send interception and role-based rules.
  Widget _buildMessageInput() {
    final client = StreamChat.of(context).client;
    final currentUser = client.state.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    final canSendMedia = _isCreator;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Quota bar (only for regular users) ─────────────────────────
        if (!_isCreator) _buildQuotaBar(),

        // ── Message input ──────────────────────────────────────────────
        StreamMessageInput(
          preMessageSending: _onPreSend,
          enableVoiceRecording: true,
          sendVoiceRecordingAutomatically: true,
          disableAttachments: !canSendMedia,
        ),
      ],
    );
  }

  Widget _buildQuotaBar() {
    final scheme = Theme.of(context).colorScheme;

    if (_freeRemaining > 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: scheme.primaryContainer.withValues(alpha: 0.3),
        child: Row(
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 14, color: scheme.onPrimaryContainer),
            const SizedBox(width: 6),
            Text(
              '$_freeRemaining free message${_freeRemaining == 1 ? '' : 's'} remaining',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Beyond free quota — show cost
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.amber.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(Icons.monetization_on, size: 14, color: Colors.amber[700]),
          const SizedBox(width: 6),
          Text(
            '$_costPerMessage coins per message',
            style: TextStyle(
              fontSize: 12,
              color: Colors.amber[800],
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            'Balance: $_userCoins',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_channel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final availabilityMap = ref.watch(creatorAvailabilityProvider);
    final isCreatorOnline = _otherUserFirebaseUid != null &&
        (availabilityMap[_otherUserFirebaseUid!] ??
                CreatorAvailability.busy) ==
            CreatorAvailability.online;
    final canCallFromChat = _showCallButton;
    final canReportFromChat = _canReportCreatorFromChat;

    return StreamChatTheme(
      data: StreamChatThemeData(
        colorTheme: StreamColorTheme.dark(
          accentPrimary: colorScheme.primary,
          accentError: colorScheme.error,
          accentInfo: colorScheme.primary,
          textHighEmphasis: colorScheme.onSurface,
          textLowEmphasis: colorScheme.onSurface.withValues(alpha: 0.6),
          inputBg: colorScheme.surfaceContainerHigh,
        ),
        ownMessageTheme: StreamMessageThemeData(
          messageBackgroundColor: colorScheme.primary,
          messageTextStyle: TextStyle(color: colorScheme.onPrimary),
        ),
        otherMessageTheme: StreamMessageThemeData(
          messageBackgroundColor: colorScheme.surfaceContainerHigh,
          messageTextStyle: TextStyle(color: colorScheme.onSurface),
        ),
      ),
      child: StreamChannel(
        channel: _channel!,
        child: Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: _otherUserImage != null
                      ? NetworkImage(_otherUserImage!)
                      : null,
                  child: _otherUserImage == null
                      ? Icon(Icons.person,
                          size: 20, color: colorScheme.onPrimaryContainer)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _otherUserName ?? 'User',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              if (canReportFromChat)
                IconButton(
                  onPressed: _showReportCreatorDialog,
                  icon: const Icon(Icons.flag_outlined),
                  tooltip: 'Report Creator',
                ),
              if (canCallFromChat) _buildCallAction(colorScheme, isCreatorOnline),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamMessageListView(
                  messageBuilder:
                      (context, details, messageList, defaultMessageWidget) {
                    if (_isCallActivityMessage(details.message)) {
                      return _buildCallActivityCard(
                        context,
                        details.message,
                        showCallAgain: canCallFromChat,
                        isCreatorOnline: isCreatorOnline,
                      );
                    }

                    final senderRole =
                        details.message.user?.extraData['appRole'] as String?;
                    final isCreatorSender =
                        senderRole == 'creator' || senderRole == 'admin';

                    if (!isCreatorSender) {
                      return defaultMessageWidget;
                    }

                    return defaultMessageWidget.copyWith(
                      attachmentBuilders: const [
                        _CreatorImageAttachmentBuilder(),
                      ],
                    );
                  },
                  threadBuilder: (_, parentMessage) {
                    return const SizedBox.shrink();
                  },
                ),
              ),
              _buildMessageInput(),
            ],
          ),
        ),
      ),
    );
  }
}
