import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/logger.dart';

final analyticsServiceProvider = Provider((ref) => AnalyticsService());

class AnalyticsService {
  final Posthog _posthog = Posthog();

  Future<void> capture({
    required String eventName,
    Map<String, Object>? properties,
  }) async {
    try {
      await _posthog.capture(eventName: eventName, properties: properties);
      AppLogger.info('AnalyticsService', 'Event captured: $eventName');
    } catch (e, stackTrace) {
      AppLogger.error(
        'AnalyticsService',
        'Failed to capture event: $eventName',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> identify(
    String userId, {
    Map<String, Object>? userProperties,
  }) async {
    try {
      await _posthog.identify(userId: userId, userProperties: userProperties);
      AppLogger.info('AnalyticsService', 'User identified: $userId');
    } catch (e, stackTrace) {
      AppLogger.error(
        'AnalyticsService',
        'Failed to identify user: $userId',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> reset() async {
    try {
      await _posthog.reset();
      AppLogger.info('AnalyticsService', 'PostHog reset');
    } catch (e, stackTrace) {
      AppLogger.error(
        'AnalyticsService',
        'Failed to reset PostHog',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> screen({
    required String screenName,
    Map<String, Object>? properties,
  }) async {
    try {
      await _posthog.screen(screenName: screenName, properties: properties);
      AppLogger.info('AnalyticsService', 'Screen tracked: $screenName');
    } catch (e, stackTrace) {
      AppLogger.error(
        'AnalyticsService',
        'Failed to track screen: $screenName',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
