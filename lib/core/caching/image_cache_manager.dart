import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CustomImageCacheManager extends CacheManager {
  static const key = 'customCacheKey';

  static final CustomImageCacheManager _instance = CustomImageCacheManager._();

  factory CustomImageCacheManager() {
    return _instance;
  }

  CustomImageCacheManager._()
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 30), // الاحتفاظ بالصور لمدة 30 يوماً
            maxNrOfCacheObjects: 500, // تخزين حتى 500 صورة
            repo: JsonCacheInfoRepository(databaseName: key),
            fileService: HttpFileService(),
          ),
        );
}
