import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/fcm_service.dart';

final fcmServiceProvider = Provider<FCMService>((ref) {
  return FCMService();
});

