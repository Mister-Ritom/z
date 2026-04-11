import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cooler_ui/cooler_ui.dart';
import 'package:go_router/go_router.dart';
import '../../providers/wallet_provider.dart';
import '../../models/transaction_model.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);
    final transactionsAsync = ref.watch(transactionsProvider);

    return CoolScaffold(
      appBar: CoolAppBar(
        title: const Text('My Wallet'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: walletAsync.when(
              data: (wallet) => _buildBalanceCard(context, wallet),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildReferralCard(context),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Recent Transactions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          transactionsAsync.when(
            data: (transactions) => SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildTransactionItem(transactions[index]),
                childCount: transactions.length,
              ),
            ),
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Error loading history')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, wallet) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Available Balance',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const Icon(LucideIcons.coins, color: Colors.amber, size: 28),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${wallet?.availableBalance.toStringAsFixed(2) ?? "0.00"} ZC',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildSubBalance('Pending', (wallet?.pendingBalance ?? 0)),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  // Show withdrawal info or navigate to payout setup
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Withdrawals open at 1,000 ZC')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue.shade900,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Withdraw', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCard(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/referrals'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.userPlus, color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Refer & Earn 10% Bonus',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.brown),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Invite friends to Z and earn lifetime bonuses on their creator rewards.',
                    style: TextStyle(fontSize: 13, color: Colors.brown.shade400),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: Colors.amber, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSubBalance(String label, double amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          '${amount.toStringAsFixed(2)} ZC',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(TransactionModel tx) {
    final isNegative = tx.amount < 0;
    final color = tx.status == TransactionStatus.rejected
        ? Colors.red
        : tx.status == TransactionStatus.pending
            ? Colors.orange
            : Colors.green;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(
          _getTransactionIcon(tx.type),
          color: color,
          size: 20,
        ),
      ),
      title: Text(_getTransactionLabel(tx.type)),
      subtitle: Text(
        '${tx.createdAt.day}/${tx.createdAt.month} • ${tx.status.name}',
        style: TextStyle(color: color.withOpacity(0.8)),
      ),
      trailing: Text(
        '${isNegative ? "" : "+"}${tx.amount.toStringAsFixed(2)}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: isNegative ? Colors.red : Colors.green,
        ),
      ),
    );
  }

  IconData _getTransactionIcon(String type) {
    if (type.contains('view')) return LucideIcons.eye;
    if (type.contains('referral')) return LucideIcons.userPlus;
    if (type.contains('payout')) return LucideIcons.externalLink;
    return LucideIcons.arrowUpRight;
  }

  String _getTransactionLabel(String type) {
    if (type.contains('view')) return 'View Reward';
    if (type.contains('referral')) return 'Referral Bonus';
    if (type.contains('payout')) return 'Withdrawal';
    return type.replaceAll('_', ' ').toUpperCase();
  }
}
