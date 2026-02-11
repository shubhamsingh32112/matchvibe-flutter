import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:go_router/go_router.dart';
<<<<<<< HEAD
import '../../../core/services/push_notification_service.dart';
import '../services/chat_service.dart';
=======
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed
import '../../auth/providers/auth_provider.dart';

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
<<<<<<< HEAD
  String? _otherUserImage;
  final ChatService _chatService = ChatService();

  // Quota state
  int _freeRemaining = 3;
  int _costPerMessage = 0;
  int _userCoins = 0;
  bool _isCreator = false;
=======
  bool _isInputBlocked = false; // PHASE 6: Block input when coins insufficient
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed

  @override
  void initState() {
    super.initState();
    // Tell PushNotificationService which channel is currently open
    // so it suppresses notifications for this channel.
    PushNotificationService.activeChannelId = widget.channelId;
    _initializeChannel();
    _checkCoinStatus(); // PHASE 6: Check coin status
  }
  
  /// PHASE 6: Check if user has used free messages and update UI
  void _checkCoinStatus() {
    final authState = ref.read(authProvider);
    final user = authState.user;
    
    if (user != null && user.role == 'user') {
      final freeMessagesRemaining = 3 - user.freeTextUsed;
      if (freeMessagesRemaining <= 0 && user.coins < 5) {
        setState(() {
          _isInputBlocked = true;
        });
      }
    }
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
<<<<<<< HEAD
      final otherUserName =
          otherMember.user?.extraData['username'] as String? ??
              otherMember.user?.name ??
              'User';
      final otherUserImage = otherMember.user?.image;

      // Determine if the current user is a creator
      final authState = ref.read(authProvider);
      final isCreator = authState.user?.role == 'creator' ||
          authState.user?.role == 'admin';

=======
      
      // Get other user's display name - use username from extraData (single source of truth)
      // This is guaranteed to be the username from MongoDB, never an email
      final otherUserName = otherMember.user?.extraData['username'] as String? ??
          otherMember.user?.name ??
          'User';
      
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed
      if (mounted) {
        setState(() {
          _channel = channel;
          _otherUserName = otherUserName;
          _otherUserImage = otherUserImage;
          _isCreator = isCreator;
        });
<<<<<<< HEAD

        // Fetch quota info (only matters for regular users)
        if (!isCreator) {
          _refreshQuota();
        }
=======
        
        // Set up message validation listener
        _setupMessageValidation(channel);
        
        // PHASE 6: Listen for message send events to update coin status
        channel.on(EventType.messageNew).listen((event) {
          // Refresh coin status after message is sent successfully
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkCoinStatus();
          });
        });
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed
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

<<<<<<< HEAD
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

  /// Called BEFORE every message send.
  /// Returns the message if allowed, throws to cancel.
  Future<Message> _onPreSend(Message message) async {
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
=======
  /// PHASE 6: Show coin billing info banner
  Widget _buildCoinBanner() {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    
    if (user == null || user.role != 'user') {
      return const SizedBox.shrink();
    }
    
    final freeMessagesRemaining = 3 - user.freeTextUsed;
    final scheme = Theme.of(context).colorScheme;
    
    if (freeMessagesRemaining > 0) {
      // Show remaining free messages
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: scheme.primaryContainer.withValues(alpha: 0.3),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: scheme.onPrimaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$freeMessagesRemaining free message${freeMessagesRemaining > 1 ? 's' : ''} remaining',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Show "5 coins per message" after free messages used
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: scheme.surfaceContainerHighest,
        child: Row(
          children: [
            Icon(Icons.account_balance_wallet, size: 16, color: scheme.onSurface),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '5 coins per message',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface,
                ),
              ),
            ),
            if (user.coins < 5)
              Text(
                ' (${user.coins} coins)',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      );
    }
  }
  
  /// PHASE 6: Show insufficient coins overlay
  Widget _buildInsufficientCoinsOverlay() {
    if (!_isInputBlocked) return const SizedBox.shrink();
    
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.read(authProvider);
    final user = authState.user;
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: scheme.errorContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, color: scheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Insufficient coins to send message',
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You need 5 coins per message. You currently have ${user?.coins ?? 0} coins.',
            style: TextStyle(
              color: scheme.onErrorContainer,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop(); // Close overlay
              _showBuyCoinsModal(); // Show Buy Coins modal
            },
            icon: const Icon(Icons.shopping_cart),
            label: const Text('Buy Coins'),
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            ),
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed
          ),
        ],
      ),
    );
  }

<<<<<<< HEAD
  /// Build the message input with pre-send interception and role-based rules.
=======
  /// Build message input with validation and role-based permissions
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed
  Widget _buildMessageInput() {
    final client = StreamChat.of(context).client;
    final currentUser = client.state.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    final appRole = currentUser.extraData['appRole'] as String?;
    final canSendMedia = appRole == 'creator' || appRole == 'admin';
<<<<<<< HEAD

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
=======
    
    // PHASE 6: Block input if coins insufficient
    if (_isInputBlocked) {
      return _buildInsufficientCoinsOverlay();
    }
    
    return StreamMessageInput(
      // Enable voice recording for all users
      enableVoiceRecording: true,
      sendVoiceRecordingAutomatically: true,
      
      // Disable attachments for users (only creators can send media)
      disableAttachments: !canSendMedia,
      
      // Note: Backend webhook handles coin validation
      // Frontend will show error via message validation listener
      
      // Note: Backend webhook enforces text validation (0-5 only) and attachment rules
      // Frontend validation above provides UX feedback when messages are rejected
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed
    );
  }
  
  /// PHASE 8: Show Buy Coins modal for insufficient coins
  void _showBuyCoinsModal() {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.read(authProvider);
    final user = authState.user;
    final coins = user?.coins ?? 0;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: scheme.error),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Insufficient Coins'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You need 5 coins to send a message.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'You currently have $coins coins.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to wallet/buy coins screen
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Navigate to wallet to buy coins'),
                  backgroundColor: scheme.primaryContainer,
                ),
              );
            },
            child: const Text('Buy Coins'),
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
<<<<<<< HEAD
=======
                // PHASE 6: Show coin billing info banner
                _buildCoinBanner(),
                // Message input with validation and role-based permissions
                _buildMessageInput(),
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamMessageListView(
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
