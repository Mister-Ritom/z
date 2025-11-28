import 'package:flutter_riverpod/flutter_riverpod.dart';

final bookmarkingProvider = StateProvider.family<bool, String>(
  (ref, zapId) => false,
);

