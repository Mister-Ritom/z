import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:z/utils/logger.dart';
import 'package:z/models/comment_model.dart';
import '../models/zap_model.dart';
import '../models/notification_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'firebase_analytics_service.dart';

part 'zap_service_crud.dart';
part 'zap_service_streams.dart';
part 'zap_service_comments.dart';

class ZapService extends _ZapServiceBase
    with _ZapServiceCrud, _ZapServiceStreams, _ZapServiceComments {
  ZapService({required super.isShort});
}

abstract class _ZapServiceBase {
  _ZapServiceBase({required this.isShort});

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final bool isShort;

  CollectionReference get _collection => _firestore.collection(
    isShort ? AppConstants.shortsCollection : AppConstants.zapsCollection,
  );

  Query _zapQuery({bool parentOnly = true}) {
    Query query = _collection.where('isDeleted', isEqualTo: false);
    if (parentOnly && !isShort) {
      query = query.where('parentZapId', isNull: true);
    }
    return query;
  }
}
