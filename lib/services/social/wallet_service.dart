import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
import '../../supabase/database.dart';
import '../../utils/logger.dart';

class WalletService {
  final SupabaseClient _db = Database.client;

  Future<WalletModel?> getWallet(String userId) async {
    try {
      final data =
          await _db.from('wallets').select().eq('id', userId).maybeSingle();
      if (data == null) return null;
      return WalletModel.fromMap(data);
    } catch (e, st) {
      AppLogger.error(
        'WalletService',
        'Failed to fetch wallet',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<List<TransactionModel>> getTransactions(String userId) async {
    try {
      final data = await _db
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return data.map<TransactionModel>((t) => TransactionModel.fromMap(t)).toList();
    } catch (e, st) {
      AppLogger.error(
        'WalletService',
        'Failed to fetch transactions',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }
}
