import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:go_router/go_router.dart';
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
  bool _isInputBlocked = false; // PHASE 6: Block input when coins insufficient

  @override
  void initState() {
    super.initState();
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

  Future<void> _initializeChannel() async {
    try {
      // StreamChat must be in widget tree (wrapped at app root)
      // If it's not, that's a fatal wiring bug, not a runtime state
      final client = StreamChat.of(context).client;
      
      // Get channel by ID
      final channel = client.channel('messaging', id: widget.channelId);
      
      // Watch channel to get latest state
      await channel.watch();
      
      // Extract other user ID and name from channel members
      // FIX: members is a Map<String, Member>, not a List - must convert to list
      final currentUserId = client.state.currentUser!.id;
      // Cast to Map and get values as list
      final members = (channel.state!.members as Map<String, Member>).values.toList();
      
      final otherMember = members.firstWhere(
        (m) => m.userId != currentUserId,
      );
      
      // Get other user's display name - use username from extraData (single source of truth)
      // This is guaranteed to be the username from MongoDB, never an email
      final otherUserName = otherMember.user?.extraData['username'] as String? ??
          otherMember.user?.name ??
          'User';
      
      if (mounted) {
        setState(() {
          _channel = channel;
          _otherUserName = otherUserName;
        });
        
        // Set up message validation listener
        _setupMessageValidation(channel);
        
        // PHASE 6: Listen for message send events to update coin status
        channel.on(EventType.messageNew).listen((event) {
          // Refresh coin status after message is sent successfully
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkCoinStatus();
          });
        });
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


  /// Set up message validation listener on channel
  void _setupMessageValidation(Channel channel) {
    // Listen for new messages and validate them
    // Note: Backend webhook is the authoritative layer - this is for UX feedback
    channel.on(EventType.messageNew).listen((event) {
      if (event.message?.text != null) {
        final text = event.message!.text!;
        final allowedPattern = RegExp(r'^[0-5\s]*$');
        
        // If message has invalid text, show error (backend will reject it anyway)
        if (text.isNotEmpty && !allowedPattern.hasMatch(text)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Message rejected: Only numbers 0 to 5 are allowed'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    });
  }

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
          ),
        ],
      ),
    );
  }

  /// Build message input with validation and role-based permissions
  Widget _buildMessageInput() {
    final client = StreamChat.of(context).client;
    final currentUser = client.state.currentUser;
    
    if (currentUser == null) {
      return const SizedBox.shrink();
    }
    
    // Get app role from user metadata
    final appRole = currentUser.extraData['appRole'] as String?;
    final canSendMedia = appRole == 'creator' || appRole == 'admin';
    
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
        appBar: AppBar(
          title: const Text('Chat'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return StreamChatTheme(
      data: StreamChatThemeData(
        colorTheme: StreamColorTheme.dark(
          accentPrimary: colorScheme.primary,
          accentError: colorScheme.error,
          accentInfo: colorScheme.primary,
          textHighEmphasis: colorScheme.onSurface,
          textLowEmphasis: colorScheme.onSurface.withOpacity(0.6),
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
            // FIX: Use AppBar instead of StreamChannelHeader for full control
            // StreamChannelHeader ignores custom titles and uses its own logic
            appBar: AppBar(
              title: Text(
                _otherUserName ?? 'User',
                overflow: TextOverflow.ellipsis,
              ),
              actions: [],
            ),
            body: Column(
              children: [
                Expanded(
                  child: StreamMessageListView(
                    threadBuilder: (_, parentMessage) {
                      // Thread support can be added later
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                // PHASE 6: Show coin billing info banner
                _buildCoinBanner(),
                // Message input with validation and role-based permissions
                _buildMessageInput(),
              ],
            ),
          ),
        ),
    );
  }
}
