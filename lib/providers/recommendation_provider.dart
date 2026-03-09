import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/content/recommendations/recommendation_service.dart';
import '../services/analytics/analytics_service.dart';

final recommendationServiceProvider = Provider<RecommendationService>((ref) {
  final analytics = ref.watch(analyticsServiceProvider);
  return RecommendationService(analytics: analytics);
});
