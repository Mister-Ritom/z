import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../services/social/wallet_service.dart';
import 'auth_provider.dart';

final walletServiceProvider = Provider((ref) => WalletService());

final walletProvider = FutureProvider.autoDispose<WalletModel?>((ref) async {
  final user = ref.watch(currentUserModelProvider).value;
  if (user == null) return null;
  return ref.watch(walletServiceProvider).getWallet(user.id);
});

final transactionsProvider = FutureProvider.autoDispose<List<TransactionModel>>((ref) async {
  final user = ref.watch(currentUserModelProvider).value;
  if (user == null) return [];
  return ref.watch(walletServiceProvider).getTransactions(user.id);
});
