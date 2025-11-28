import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class VideoCacheManager extends CacheManager {
  static const key = "videoCache";

  VideoCacheManager._()
    : super(
        Config(
          key,
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 20,
          repo: JsonCacheInfoRepository(databaseName: key),
          fileSystem: IOFileSystem(key),
          fileService: HttpFileService(),
        ),
      );

  static final VideoCacheManager instance = VideoCacheManager._();
}
