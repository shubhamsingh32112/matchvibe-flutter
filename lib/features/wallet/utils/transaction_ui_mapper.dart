import 'package:flutter/material.dart';

import '../models/transaction_model.dart';
import '../models/wallet_pricing_model.dart';

enum TransactionFilter {
  all,
  credits,
  debits,
  purchases,
  calls,
  referrals,
}

extension TransactionFilterLabel on TransactionFilter {
  String get label {
    switch (this) {
      case TransactionFilter.all:
        return 'All';
      case TransactionFilter.credits:
        return 'Credits';
      case TransactionFilter.debits:
        return 'Debits';
      case TransactionFilter.purchases:
        return 'Purchases';
      case TransactionFilter.calls:
        return 'Calls';
      case TransactionFilter.referrals:
        return 'Referrals';
    }
  }
}

class TransactionOverviewStats {
  final int totalPurchased;
  final int totalSpent;
  final int referralEarnings;

  const TransactionOverviewStats({
    required this.totalPurchased,
    required this.totalSpent,
    required this.referralEarnings,
  });

  static const empty = TransactionOverviewStats(
    totalPurchased: 0,
    totalSpent: 0,
    referralEarnings: 0,
  );
}

class TransactionDisplayInfo {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const TransactionDisplayInfo({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });
}

class TransactionUiMapper {
  static const Color creditGreen = Color(0xFF43A047);
  static const Color debitRed = Color(0xFFE53935);
  static const Color referralPurple = Color(0xFF7B1FA2);

  static TransactionOverviewStats computeOverviewStats(
    List<TransactionModel> transactions,
  ) {
    var purchased = 0;
    var spent = 0;
    var referral = 0;

    for (final tx in transactions) {
      if (tx.type == 'credit' && tx.source == 'payment_gateway') {
        purchased += tx.amount;
      } else if (tx.type == 'debit') {
        spent += tx.amount;
      } else if (tx.type == 'credit' && tx.source == 'referral_reward') {
        referral += tx.amount;
      }
    }

    return TransactionOverviewStats(
      totalPurchased: purchased,
      totalSpent: spent,
      referralEarnings: referral,
    );
  }

  static int computeTodayNet(List<TransactionModel> transactions) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    var net = 0;
    for (final tx in transactions) {
      if (!tx.createdAt.isAfter(todayStart.subtract(const Duration(seconds: 1)))) {
        continue;
      }
      if (tx.type == 'credit') {
        net += tx.amount;
      } else {
        net -= tx.amount;
      }
    }
    return net;
  }

  static double? estimateInrValue(int coins, List<WalletCoinPack> packs) {
    if (coins <= 0 || packs.isEmpty) return null;

    WalletCoinPack? cheapest;
    for (final pack in packs) {
      if (pack.coins <= 0 || pack.priceInr <= 0) continue;
      if (cheapest == null ||
          pack.priceInr / pack.coins < cheapest.priceInr / cheapest.coins) {
        cheapest = pack;
      }
    }
    if (cheapest == null) return null;

    return coins * (cheapest.priceInr / cheapest.coins);
  }

  static int? matchPackPriceInr(int coinAmount, List<WalletCoinPack> packs) {
    for (final pack in packs) {
      if (pack.coins == coinAmount) return pack.priceInr;
    }
    return null;
  }

  static List<TransactionModel> applyFilter(
    List<TransactionModel> transactions,
    TransactionFilter filter,
  ) {
    switch (filter) {
      case TransactionFilter.all:
        return transactions;
      case TransactionFilter.credits:
        return transactions.where((t) => t.type == 'credit').toList();
      case TransactionFilter.debits:
        return transactions.where((t) => t.type == 'debit').toList();
      case TransactionFilter.purchases:
        return transactions
            .where((t) => t.source == 'payment_gateway')
            .toList();
      case TransactionFilter.calls:
        return transactions.where((t) => t.source == 'video_call').toList();
      case TransactionFilter.referrals:
        return transactions
            .where((t) => t.source == 'referral_reward')
            .toList();
    }
  }

  static Map<String, List<TransactionModel>> groupByDateHeader(
    List<TransactionModel> transactions,
  ) {
    final grouped = <String, List<TransactionModel>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final tx in transactions) {
      final local = tx.createdAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final String header;
      if (day == today) {
        header = 'TODAY';
      } else if (day == yesterday) {
        header = 'YESTERDAY';
      } else {
        header = _formatDateHeader(local);
      }
      grouped.putIfAbsent(header, () => []).add(tx);
    }
    return grouped;
  }

  static String _formatDateHeader(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}'.toUpperCase();
  }

  static TransactionDisplayInfo displayInfo(
    TransactionModel transaction, {
    required bool isCreator,
  }) {
    final isCredit = transaction.type == 'credit';
    final accent = isCredit ? creditGreen : debitRed;

    if (isCreator) {
      return TransactionDisplayInfo(
        title: transaction.description ?? 'Video call earnings',
        subtitle: transaction.callerUsername != null
            ? 'With ${transaction.callerUsername}'
            : 'Earnings from call',
        icon: Icons.videocam_outlined,
        accentColor: creditGreen,
      );
    }

    switch (transaction.source) {
      case 'admin':
      case 'manual':
        return TransactionDisplayInfo(
          title: 'Admin Reward',
          subtitle: transaction.description ?? 'Bonus coins added',
          icon: Icons.card_giftcard_outlined,
          accentColor: creditGreen,
        );
      case 'payment_gateway':
        return TransactionDisplayInfo(
          title: 'Coin Purchase',
          subtitle: transaction.description ??
              'Purchase ${transaction.amount} Coins',
          icon: Icons.shopping_cart_outlined,
          accentColor: creditGreen,
        );
      case 'referral_reward':
        return TransactionDisplayInfo(
          title: 'Referral Bonus',
          subtitle: transaction.description ?? 'Referral reward',
          icon: Icons.people_outline,
          accentColor: referralPurple,
        );
      case 'welcome_bonus':
        return TransactionDisplayInfo(
          title: 'Welcome Bonus',
          subtitle: transaction.description ?? 'Welcome bonus coins',
          icon: Icons.card_giftcard_outlined,
          accentColor: creditGreen,
        );
      case 'video_call':
        return TransactionDisplayInfo(
          title: 'Video Call',
          subtitle: transaction.description ?? 'Call with host',
          icon: Icons.videocam_outlined,
          accentColor: debitRed,
        );
      case 'chat_message':
        return TransactionDisplayInfo(
          title: 'Chat Message',
          subtitle: transaction.description ?? 'Paid chat message',
          icon: Icons.chat_bubble_outline,
          accentColor: debitRed,
        );
      case 'creator_task':
        return TransactionDisplayInfo(
          title: 'Task Reward',
          subtitle: transaction.description ?? 'Creator task reward',
          icon: Icons.star_outline,
          accentColor: creditGreen,
        );
      default:
        return TransactionDisplayInfo(
          title: transaction.description ?? 'Transaction',
          subtitle: isCredit ? 'Coins added' : 'Coins spent',
          icon: Icons.receipt_long_outlined,
          accentColor: accent,
        );
    }
  }

  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) return 'Just now';
        return '${difference.inMinutes} mins ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      final local = date.toLocal();
      final hour = local.hour > 12 ? local.hour - 12 : local.hour;
      final period = local.hour >= 12 ? 'PM' : 'AM';
      final minute = local.minute.toString().padLeft(2, '0');
      return 'Yesterday, $hour:$minute $period';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      final local = date.toLocal();
      final hour = local.hour > 12 ? local.hour - 12 : local.hour;
      final period = local.hour >= 12 ? 'PM' : 'AM';
      final minute = local.minute.toString().padLeft(2, '0');
      return '${local.day}/${local.month}/${local.year}, $hour:$minute $period';
    }
  }

  static String formatInr(double value) {
    return '₹${value.toStringAsFixed(2)}';
  }
}
