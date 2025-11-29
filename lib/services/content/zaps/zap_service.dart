import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:z/utils/logger.dart';
import 'package:z/models/comment_model.dart';
import 'package:z/models/zap_model.dart';
import 'package:z/models/notification_model.dart';
import 'package:z/utils/constants.dart';
import 'package:z/utils/helpers.dart';
import '../../analytics/firebase_analytics_service.dart';
import '../../shared/firestore_utils.dart';

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
