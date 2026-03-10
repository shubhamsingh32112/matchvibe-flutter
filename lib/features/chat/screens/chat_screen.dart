import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/api/api_client.dart';
import '../services/chat_service.dart';
import '../utils/chat_utils.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/availability_provider.dart';
import '../../video/controllers/call_connection_controller.dart';
import '../../support/services/support_service.dart';
import '../../../shared/widgets/coin_purchase_popup.dart';
import '../../../shared/widgets/gem_icon.dart';

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
  final ApiClient _apiClient = ApiClient();
  bool _isInitiatingCall = false;
  bool _isBlocking = false;
  bool? _isCreatorBlocked; // null = unknown, true = blocked, false = not blocked

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

      // Extract other user's name using helper function (prioritizes username)
      final currentUserId = client.state.currentUser!.id;
      final otherUser = getOtherUserFromChannel(channel, currentUserId);
      final otherUserName = extractDisplayName(otherUser);
      final otherUserImage = otherUser?.image;
      
      // Get other member's userId (Firebase UID) - need to access members properly
      final channelState = channel.state;
      String? otherUserFirebaseUid;
      if (channelState != null) {
        // channelState.members is a List<Member>, not a Map
        final members = channelState.members;
        List<Member> memberList;
        
        try {
          memberList = members.cast<Member>();
        } catch (e) {
          debugPrint('⚠️ [CHAT] Failed to parse members: $e');
          memberList = [];
        }
        
        if (memberList.isNotEmpty) {
          final otherMember = memberList.firstWhere(
            (m) => m.userId != currentUserId,
            orElse: () => memberList.first,
          );
          otherUserFirebaseUid = otherMember.userId;
        }
      }
      
      final otherUserMongoId = otherUser?.extraData['mongoId'] as String?;
      final otherUserAppRole = otherUser?.extraData['appRole'] as String?;

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
          // Check if creator is blocked (only for regular users chatting with creators)
          if (otherUserAppRole == 'creator' || otherUserAppRole == 'admin') {
            _checkIfCreatorBlocked();
          }
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
      // Optimize: For free messages, we can be more lenient with timeout
      // For paid messages, we need to ensure the check completes
      final hasFreeRemaining = _freeRemaining > 0;
      
      // Send message.id as idempotency key to prevent double-charge on retries
      // Reduced timeout to 5 seconds (Redis cache makes most requests < 100ms)
      // Only cache misses take longer (~200-500ms), so 5s is safe
      final result = await _chatService.preSendMessage(
        widget.channelId,
        messageId: message.id,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          // If timeout and we have free remaining, allow send optimistically
          // Backend will handle quota when message arrives
          if (hasFreeRemaining) {
            debugPrint('⚠️ [CHAT] Pre-send timeout, allowing send (free remaining)');
            return {
              'canSend': true,
              'freeRemaining': _freeRemaining - 1,
              'coinsCharged': 0,
              'userCoins': _userCoins,
            };
          }
          // For paid messages, fail on timeout to prevent double charge
          throw TimeoutException('Pre-send check timed out', const Duration(seconds: 5));
        },
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CoinPurchaseBottomSheet(),
    );
  }

  // ── Video call from chat ───────────────────────────────────────────────

  Widget _buildCallAction(ColorScheme colorScheme, bool isOnline) {
    return IconButton(
      onPressed: _initiateVideoCall, // Always enabled - will check online status inside
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
                  : colorScheme.onSurface.withValues(alpha: 0.5),
            ),
      tooltip: isOnline ? 'Video Call' : 'Video Call',
    );
  }

  /// Whether the video call button should be shown.
  /// Always shown for regular users when we have the other member (so they can
  /// start a call). Creator mongoId is resolved on tap if missing (Stream extraData).
  bool get _showCallButton {
    if (_isCreator) return false; // Creators use different flow
    return _otherUserFirebaseUid != null;
  }


  bool get _canReportCreatorFromChat {
    if (_isCreator) return false;
    final otherRole = _otherUserAppRole;
    return otherRole == 'creator' || otherRole == 'admin';
  }

  Future<void> _checkIfCreatorBlocked() async {
    if (_otherUserMongoId == null || _isCreator) return;
    
    try {
      // For now, we'll check when blocking - this is simpler
      // We can optimize later by storing blocked list in user model
      setState(() {
        _isCreatorBlocked = false; // Default to not blocked, will update on block action
      });
    } catch (e) {
      debugPrint('⚠️ [CHAT] Failed to check blocked status: $e');
    }
  }

  Future<void> _toggleBlockCreator() async {
    if ((_otherUserMongoId == null && _otherUserFirebaseUid == null) || _isCreator || _isBlocking) return;

    setState(() => _isBlocking = true);

    try {
      // Use firebaseUid (preferred) or userId to block (backend will find the creator)
      final response = await _apiClient.post(
        '/user/block-creator',
        data: {
          if (_otherUserFirebaseUid != null) 'firebaseUid': _otherUserFirebaseUid,
          if (_otherUserMongoId != null) 'userId': _otherUserMongoId,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final isBlocked = response.data['data']['isBlocked'] as bool? ?? false;
        
        if (mounted) {
          setState(() {
            _isCreatorBlocked = isBlocked;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isBlocked 
                ? 'Creator blocked. You will no longer see them in your feed.'
                : 'Creator unblocked.'),
              backgroundColor: isBlocked ? Colors.orange : Colors.green,
            ),
          );

          // If blocked, go back to previous screen
          if (isBlocked) {
            // Refresh user data to update blocked count
            await ref.read(authProvider.notifier).refreshUser();
            // Close chat after a short delay
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                context.pop();
              }
            });
          } else {
            // Refresh user data
            await ref.read(authProvider.notifier).refreshUser();
          }
        }
      }
    } catch (e) {
      debugPrint('❌ [CHAT] Failed to block/unblock creator: $e');
      if (mounted) {
        String errorMessage = 'Failed to ${_isCreatorBlocked == true ? "unblock" : "block"} creator';
        
        // Try to extract error message from DioException
        if (e is DioException) {
          try {
            if (e.response?.data != null) {
              final errorData = e.response!.data;
              if (errorData is Map && errorData['error'] != null) {
                errorMessage = errorData['error'] as String;
              }
            }
          } catch (_) {
            // If extraction fails, use default message
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBlocking = false);
      }
    }
  }

  void _showBlockCreatorDialog() {
    final isBlocked = _isCreatorBlocked == true;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isBlocked ? 'Unblock Creator' : 'Block Creator'),
        content: Text(
          isBlocked
              ? 'Are you sure you want to unblock ${_otherUserName ?? "this creator"}? You will be able to see them in your feed again.'
              : 'Are you sure you want to block ${_otherUserName ?? "this creator"}? You will no longer see them in your feed, and this chat will be closed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _toggleBlockCreator();
            },
            style: FilledButton.styleFrom(
              backgroundColor: isBlocked ? Colors.green : Colors.red,
            ),
            child: Text(isBlocked ? 'Unblock' : 'Block'),
          ),
        ],
      ),
    );
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
    if (_otherUserFirebaseUid == null) return;
    if (_isCreator) return;

    String? creatorFirebaseUid = _otherUserFirebaseUid;
    String? creatorMongoId = _otherUserMongoId;

    // Resolve creator mongoId from backend if missing (e.g. Stream extraData not set)
    if (creatorMongoId == null) {
      try {
        final info = await _chatService.getCreatorCallInfo(widget.channelId);
        if (info != null && mounted) {
          creatorFirebaseUid = info['creatorFirebaseUid'] as String?;
          creatorMongoId = info['creatorMongoId'] as String?;
          if (creatorMongoId != null) {
            setState(() {
              _otherUserMongoId = creatorMongoId;
              if (creatorFirebaseUid != null) _otherUserFirebaseUid = creatorFirebaseUid;
            });
          }
        }
      } catch (e) {
        debugPrint('⚠️ [CHAT] Failed to resolve creator call info: $e');
      }
      if (creatorMongoId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to start call. Please try again.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    // Check if creator is online
    final availabilityMap = ref.read(creatorAvailabilityProvider);
    final isCreatorOnline = (availabilityMap[creatorFirebaseUid!] ??
            CreatorAvailability.busy) ==
        CreatorAvailability.online;

    if (!isCreatorOnline) {
      // Show toast that creator is busy
      if (mounted) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.do_not_disturb_alt,
                  color: colorScheme.onErrorContainer,
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Creator is busy'),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: colorScheme.errorContainer,
            margin: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }

    // Check coin balance (for regular users)
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
            creatorFirebaseUid: creatorFirebaseUid,
            creatorMongoId: creatorMongoId,
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
          GemIcon(size: 14, color: Colors.amber[700]),
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

    // Watch call connection state to ensure button visibility updates after calls
    final callState = ref.watch(callConnectionControllerProvider);
    // Reset _isInitiatingCall when call state returns to idle
    if (callState.phase == CallConnectionPhase.idle && _isInitiatingCall) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isInitiatingCall = false;
          });
        }
      });
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
              // Block creator button (only for regular users chatting with creators)
              if (!_isCreator && (_otherUserAppRole == 'creator' || _otherUserAppRole == 'admin'))
                IconButton(
                  onPressed: _isBlocking ? null : _showBlockCreatorDialog,
                  icon: _isBlocking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isCreatorBlocked == true ? Icons.block : Icons.block_outlined,
                          color: _isCreatorBlocked == true ? Colors.red : null,
                        ),
                  tooltip: _isCreatorBlocked == true ? 'Unblock Creator' : 'Block Creator',
                ),
              if (canReportFromChat)
                IconButton(
                  onPressed: _showReportCreatorDialog,
                  icon: const Icon(Icons.flag_outlined),
                  tooltip: 'Report Creator',
                ),
              // Video call button: always visible for users when we have the other member
              if (_showCallButton)
                _buildCallAction(colorScheme, isCreatorOnline),
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
