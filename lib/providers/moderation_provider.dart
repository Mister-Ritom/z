import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/moderation/block_service.dart';
import '../services/moderation/report_service.dart';

final blockServiceProvider = Provider<BlockService>((ref) {
  return BlockService();
});

final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService();
});

