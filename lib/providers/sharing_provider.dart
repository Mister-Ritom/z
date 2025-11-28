import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sharing_service.dart';

final sharingServiceProvider = Provider<SharingService>((ref) {
  final service = SharingService();
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});
