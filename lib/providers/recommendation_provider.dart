import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/recommendation_service.dart';

final recommendationServiceProvider = Provider<RecommendationService>(
  (ref) => RecommendationService(),
);
