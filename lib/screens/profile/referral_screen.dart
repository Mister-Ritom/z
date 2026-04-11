import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/supabase/database.dart';
import 'package:z/utils/logger.dart';
import 'package:cooler_ui/cooler_ui.dart';

class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  int _referralCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchReferralStats();
  }

  Future<void> _fetchReferralStats() async {
    try {
      final user = Database.client.auth.currentUser;
      if (user == null) return;

      final referrals = await Database.client
          .from('referrals')
          .select('id')
          .eq('referrer_id', user.id);

      if (mounted) {
        setState(() {
          _referralCount = referrals.length;
        });
      }
    } catch (e) {
      AppLogger.error('ReferralScreen', 'Failed to fetch stats', error: e);
    }
  }

  void _copyLink(String username) {
    final link = 'https://z.com/?ref=$username'; // Use real URL if available
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Referral link copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareLink(String username) {
    final link = 'https://z.com/?ref=$username';
    Share.share(
      'Join me on Z and start earning from your very first post! $link',
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserModelProvider);

    return CoolScaffold(
      appBar: const CoolAppBar(
        title: Text('Referrals'),
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) return const Center(child: Text('Profile not found'));
          
          final username = profile.username;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Illustration or Icon
                const Icon(
                  LucideIcons.users,
                  size: 80,
                  color: Colors.blue,
                ),
                const SizedBox(height: 24),
                
                Text(
                  'Invite friends, earn together!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'You earn 10% of the Z-Coins your friends earn, forever. Helping creators grow helps you too!',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 48),
                
                // Stats Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.blue.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Friends Invited', _referralCount.toString()),
                      _buildStatItem('Bonus Earned', '0 Z'), // To implement later
                    ],
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Referral Link Section
                const Text(
                  'Your referral link',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'z.com/?ref=$username',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Colors.blue,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.copy, size: 20),
                        onPressed: () => _copyLink(username),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                ElevatedButton.icon(
                  onPressed: () => _shareLink(username),
                  icon: const Icon(LucideIcons.share2),
                  label: const Text('Share Link'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // How it works
                const Text(
                  'How it works',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 16),
                _buildStep(
                  '1', 
                  'Share your link', 
                  'Send your referral link to friends or post it on other platforms.',
                ),
                _buildStep(
                  '2', 
                  'They join Z', 
                  'When they sign up using your link, they are automatically linked to you.',
                ),
                _buildStep(
                  '3', 
                  'Earn Z-Coins', 
                  'You get a 10% bonus based on their creator earnings, credited monthly.',
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStep(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
