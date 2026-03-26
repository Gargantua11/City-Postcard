import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_oss_aliyun/flutter_oss_aliyun.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/city_location_helper.dart';
import '../models/postcard_element_layer.dart';
import 'backend_api_client.dart';

class EditedPostcard {
  final String draftId;
  final String imageUrl;
  final DateTime editedAt;
  final bool isPublished;
  final bool isDraft;
  final double? latitude;
  final double? longitude;
  final String? cityName;
  final String? cityCode;
  final String? provinceName;
  final String? locationDetail;
  final List<PostcardElementLayer> layers;

  const EditedPostcard({
    required this.draftId,
    required this.imageUrl,
    required this.editedAt,
    this.isPublished = false,
    this.isDraft = false,
    this.latitude,
    this.longitude,
    this.cityName,
    this.cityCode,
    this.provinceName,
    this.locationDetail,
    this.layers = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'draftId': draftId,
      'imageUrl': imageUrl,
      'editedAt': editedAt.toIso8601String(),
      'isPublished': isPublished,
      'isDraft': isDraft,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (cityName != null && cityName!.trim().isNotEmpty)
        'cityName': cityName!.trim(),
      if (cityCode != null && cityCode!.trim().isNotEmpty)
        'cityCode': cityCode!.trim(),
      if (provinceName != null && provinceName!.trim().isNotEmpty)
        'provinceName': provinceName!.trim(),
      if (locationDetail != null && locationDetail!.trim().isNotEmpty)
        'locationDetail': locationDetail!.trim(),
      if (layers.isNotEmpty)
        'layers': layers.map((item) => item.toJson()).toList(growable: false),
    };
  }

  factory EditedPostcard.fromJson(Map<String, dynamic> json) {
    final rawTime = json['editedAt']?.toString() ?? '';
    final parsedTime = DateTime.tryParse(rawTime);
    final editedAt = parsedTime ?? DateTime.now();
    final imageUrl = json['imageUrl']?.toString() ?? '';
    final draftId = _toDraftId(
      raw: json['draftId'],
      editedAt: editedAt,
      imageUrl: imageUrl,
    );
    return EditedPostcard(
      draftId: draftId,
      imageUrl: imageUrl,
      editedAt: editedAt,
      isPublished: _toBool(json['isPublished']) ?? false,
      isDraft: _toBool(json['isDraft']) ?? false,
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      cityName: _toNullableTrimmedString(json['cityName']),
      cityCode: _toNullableCodeString(json['cityCode']),
      provinceName: _toNullableTrimmedString(json['provinceName']),
      locationDetail: _toNullableTrimmedString(
        json['locationDetail'] ??
            json['detailAddress'] ??
            json['addressDetail'],
      ),
      layers: _toElementLayers(json['layers']),
    );
  }
}

class EditedPostcardService {
  static const String _storageKey = 'edited_postcards';
  static const String _configuredOssEndpoint = String.fromEnvironment(
    'OSS_ENDPOINT',
  );
  static const String _configuredOssBucketName = String.fromEnvironment(
    'OSS_BUCKET_NAME',
  );

  EditedPostcardService({BackendApiClient? apiClient})
    : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;

  static String? _cachedOssEndpoint;
  static String? _cachedBucketName;

  Future<List<EditedPostcard>> getEditedPostcards() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final postcards = <EditedPostcard>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          postcards.add(EditedPostcard.fromJson(item));
        } else if (item is Map) {
          postcards.add(EditedPostcard.fromJson(item.cast<String, dynamic>()));
        }
      }

      final normalized = await _normalizePostcardImageSources(postcards);
      normalized.sort((a, b) => b.editedAt.compareTo(a.editedAt));
      return normalized;
    } catch (_) {
      return [];
    }
  }

  Future<List<EditedPostcard>> getDraftPostcards() async {
    final postcards = await getEditedPostcards();
    return postcards
        .where((item) => item.isDraft && !item.isPublished)
        .toList(growable: false);
  }

  Future<int> syncOwnedPostcardsFromBackendOnLogin({
    required String? userId,
    required String? username,
    int maxPages = 8,
    int pageSize = 20,
  }) async {
    final normalizedUserId = userId?.trim() ?? '';
    final normalizedUsername = username?.trim() ?? '';
    if (normalizedUserId.isEmpty && normalizedUsername.isEmpty) {
      return 0;
    }

    final remoteRecords = await _fetchOwnedDiscussionRecords(
      userId: normalizedUserId,
      username: normalizedUsername,
      maxPages: maxPages,
      pageSize: pageSize,
    );
    if (remoteRecords.isEmpty) {
      return 0;
    }

    final local = await getEditedPostcards();
    final localByDraftId = <String, EditedPostcard>{
      for (final card in local) card.draftId: card,
    };

    var changedCount = 0;
    for (var i = 0; i < remoteRecords.length; i++) {
      final map = remoteRecords[i];
      final postcard = await _mapOwnedRemoteRecordToEditedPostcard(
        map,
        fallbackIndex: i,
      );
      if (postcard == null) continue;

      final key = postcard.draftId.trim();
      if (key.isEmpty) continue;
      final existing = localByDraftId[key];
      if (existing == null || postcard.editedAt.isAfter(existing.editedAt)) {
        localByDraftId[key] = postcard;
        changedCount += 1;
      }
    }

    if (changedCount <= 0) {
      return 0;
    }

    final merged = localByDraftId.values.toList(growable: false)
      ..sort((a, b) => b.editedAt.compareTo(a.editedAt));
    await _savePostcards(merged);
    return changedCount;
  }

  Future<List<EditedPostcard>> getTopLikedPostcards({int limit = 5}) async {
    final safeLimit = limit <= 0 ? 5 : limit;
    final records = await _fetchTopLikedRecordsFromTopLikedEndpoint(safeLimit);
    if (records.isEmpty) {
      return const <EditedPostcard>[];
    }

    final templates = <EditedPostcard>[];
    final seenIds = <String>{};
    for (var i = 0; i < records.length; i++) {
      final rawMap = BackendApiClient.asMap(records[i]);
      if (rawMap == null) continue;
      final map = await _enrichTopLikedRecord(rawMap);
      if (map == null) continue;

      final postcard = await _mapTopLikedRecordToEditedPostcard(
        map,
        fallbackIndex: i,
      );
      if (postcard == null) continue;
      if (!seenIds.add(postcard.draftId)) continue;

      templates.add(postcard);
      if (templates.length >= safeLimit) {
        break;
      }
    }
    return templates;
  }

  Future<Map<String, dynamic>?> _enrichTopLikedRecord(
    Map<String, dynamic> record,
  ) async {
    final postcardId = _extractTopLikedPostcardId(record);
    if (postcardId == null || postcardId <= 0) {
      return record;
    }

    try {
      final body = await _apiClient.get(
        '/postcard/$postcardId',
        requireAuth: true,
      );
      final data = BackendApiClient.extractData(body);
      final detailMap = BackendApiClient.asMap(data);
      if (detailMap == null || detailMap.isEmpty) {
        return record;
      }

      // Keep top-liked list ordering/count semantics, and enrich with detail
      // fields such as imageUrl/elements for stable template rendering.
      return <String, dynamic>{
        ...record,
        ...detailMap,
        'id': postcardId,
        'postcardId': postcardId,
      };
    } on BackendApiException catch (_) {
      return record;
    } catch (_) {
      return record;
    }
  }

  int? _extractTopLikedPostcardId(Map<String, dynamic> record) {
    return _readDeepInt(record, const <String>[
      'postcardId',
      'id',
      'cardId',
      'postId',
    ]);
  }

  Future<List<dynamic>> _fetchTopLikedRecordsFromTopLikedEndpoint(
    int limit,
  ) async {
    final body = await _apiClient.get(
      '/postcard/top-liked',
      queryParameters: <String, String>{'limit': '$limit'},
      requireAuth: true,
    );
    final data = BackendApiClient.extractData(body);
    final records = BackendApiClient.extractList(data);
    if (records.isEmpty) {
      return const <dynamic>[];
    }

    final sorted = List<dynamic>.from(records);
    sorted.sort(_compareTopLikedRecords);
    return sorted;
  }

  Future<List<Map<String, dynamic>>> _fetchOwnedDiscussionRecords({
    required String userId,
    required String username,
    required int maxPages,
    required int pageSize,
  }) async {
    final effectiveMaxPages = maxPages <= 0 ? 1 : maxPages;
    final effectivePageSize = pageSize <= 0 ? 20 : pageSize;
    var cursor = DateTime.now();

    final records = <Map<String, dynamic>>[];
    final seenPostcardIds = <int>{};
    for (var page = 0; page < effectiveMaxPages; page++) {
      final body = await _apiClient.get(
        '/discussion/postcards',
        queryParameters: <String, String>{
          'lastTime': _formatDiscussionCursorTime(cursor),
          'size': '$effectivePageSize',
        },
        requireAuth: true,
      );
      final data = BackendApiClient.extractData(body);
      final pageList = BackendApiClient.extractList(data);
      if (pageList.isEmpty) {
        break;
      }

      var oldest = cursor;
      for (final raw in pageList) {
        final map = BackendApiClient.asMap(raw);
        if (map == null) continue;

        final createdAt = _extractCreatedAtForTopLiked(map);
        if (createdAt.isBefore(oldest)) {
          oldest = createdAt;
        }
        final matchedFromList = _matchesOwnedRecord(
          map,
          userId: userId,
          username: username,
        );

        final postcardId = _extractTopLikedPostcardId(map);
        if (postcardId == null || postcardId <= 0) continue;
        if (!seenPostcardIds.add(postcardId)) continue;

        final detail = await _fetchPostcardDetailForSync(postcardId);
        if (detail == null) continue;
        final matchedFromDetail = _matchesOwnedRecord(
          detail,
          userId: userId,
          username: username,
        );
        if (!matchedFromDetail && !matchedFromList) {
          continue;
        }

        records.add(detail);
      }

      if (pageList.length < effectivePageSize) {
        break;
      }
      cursor = oldest.subtract(const Duration(seconds: 1));
    }

    return records;
  }

  Future<Map<String, dynamic>?> _fetchPostcardDetailForSync(
    int postcardId,
  ) async {
    try {
      final body = await _apiClient.get(
        '/postcard/$postcardId',
        requireAuth: true,
      );
      final data = BackendApiClient.extractData(body);
      final detailMap = BackendApiClient.asMap(data);
      if (detailMap == null || detailMap.isEmpty) {
        return null;
      }
      return <String, dynamic>{
        ...detailMap,
        'id': postcardId,
        'postcardId': postcardId,
      };
    } on BackendApiException catch (_) {
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _matchesOwnedRecord(
    Map<String, dynamic> map, {
    required String userId,
    required String username,
  }) {
    final mapUserId =
        _readDeepString(map, const <String>[
          'userId',
          'uid',
          'authorId',
          'creatorId',
        ])?.trim() ??
        '';
    if (userId.isNotEmpty && mapUserId.isNotEmpty && mapUserId == userId) {
      return true;
    }

    final mapUsername =
        _readDeepString(map, const <String>[
          'username',
          'userName',
          'nickname',
          'nickName',
        ])?.trim() ??
        '';
    if (username.isNotEmpty &&
        mapUsername.isNotEmpty &&
        mapUsername == username) {
      return true;
    }

    if (userId.isNotEmpty && mapUserId.isNotEmpty) {
      return false;
    }
    if (username.isNotEmpty && mapUsername.isNotEmpty) {
      return false;
    }
    return false;
  }

  Future<EditedPostcard?> _mapOwnedRemoteRecordToEditedPostcard(
    Map<String, dynamic> record, {
    required int fallbackIndex,
  }) async {
    final base = await _mapTopLikedRecordToEditedPostcard(
      record,
      fallbackIndex: fallbackIndex,
    );
    if (base == null) return null;

    final remoteId =
        BackendApiClient.readString(record, const [
          'id',
          'postcardId',
          'cardId',
          'postId',
        ])?.trim() ??
        '';

    return EditedPostcard(
      draftId: remoteId.isEmpty ? base.draftId : remoteId,
      imageUrl: base.imageUrl,
      editedAt: base.editedAt,
      isPublished: true,
      isDraft: false,
      latitude: base.latitude,
      longitude: base.longitude,
      cityName: base.cityName,
      cityCode: base.cityCode,
      provinceName: base.provinceName,
      locationDetail: base.locationDetail,
      layers: base.layers,
    );
  }

  String _formatDiscussionCursorTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }

  int _compareTopLikedRecords(dynamic leftRaw, dynamic rightRaw) {
    final left = BackendApiClient.asMap(leftRaw);
    final right = BackendApiClient.asMap(rightRaw);

    final leftLikes = _extractLikeCountForTopLiked(left);
    final rightLikes = _extractLikeCountForTopLiked(right);
    final likeCompare = rightLikes.compareTo(leftLikes);
    if (likeCompare != 0) {
      return likeCompare;
    }

    final leftTime = _extractCreatedAtForTopLiked(left);
    final rightTime = _extractCreatedAtForTopLiked(right);
    return rightTime.compareTo(leftTime);
  }

  int _extractLikeCountForTopLiked(Map<String, dynamic>? record) {
    if (record == null) return 0;
    return _readDeepInt(record, const <String>[
          'likeCount',
          'likes',
          'likeNum',
          'upCount',
          'thumbsUpCount',
          'praiseCount',
        ]) ??
        0;
  }

  DateTime _extractCreatedAtForTopLiked(Map<String, dynamic>? record) {
    if (record == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    final text =
        _readDeepString(record, const <String>[
          'createdAt',
          'createTime',
          'updatedAt',
          'updateTime',
          'editedAt',
        ]) ??
        '';
    if (text.trim().isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return _parseLooseDateTime(text);
  }

  Future<void> addEditedPostcard(
    String imageUrl, {
    double? latitude,
    double? longitude,
    String? cityName,
    String? cityCode,
    String? provinceName,
    String? locationDetail,
    List<PostcardElementLayer>? layers,
  }) async {
    await saveEditedPostcard(
      imageUrl: imageUrl,
      latitude: latitude,
      longitude: longitude,
      cityName: cityName,
      cityCode: cityCode,
      provinceName: provinceName,
      locationDetail: locationDetail,
      layers: layers,
    );
  }

  Future<String> saveEditedPostcard({
    String? draftId,
    required String imageUrl,
    double? latitude,
    double? longitude,
    String? cityName,
    String? cityCode,
    String? provinceName,
    String? locationDetail,
    List<PostcardElementLayer>? layers,
    bool syncToBackend = false,
    bool publishToDiscussion = false,
  }) async {
    String finalImageUrl = imageUrl;
    String? remotePostcardId;

    if (syncToBackend) {
      if (publishToDiscussion) {
        final syncResult = await _syncPostcardToBackend(
          imageSource: imageUrl,
          cityName: cityName,
          cityCode: cityCode,
          provinceName: provinceName,
          locationDetail: locationDetail,
          latitude: latitude,
          longitude: longitude,
          layers: layers ?? const <PostcardElementLayer>[],
        );
        finalImageUrl = _resolvePreferredStoredImageSource(
          localSource: imageUrl,
          remoteSource: syncResult.imageUrl,
        );
        remotePostcardId = syncResult.remotePostcardId;
      } else {
        final uploadedImageUrl = await _syncImageOnlyToBackend(
          imageSource: imageUrl,
          cityCode: cityCode,
        );
        finalImageUrl = _resolvePreferredStoredImageSource(
          localSource: imageUrl,
          remoteSource: uploadedImageUrl,
        );
      }
    }

    return _savePostcard(
      draftId: draftId,
      imageUrl: finalImageUrl,
      remotePostcardId: remotePostcardId,
      isDraft: false,
      latitude: latitude,
      longitude: longitude,
      cityName: cityName,
      cityCode: cityCode,
      provinceName: provinceName,
      locationDetail: locationDetail,
      layers: layers,
    );
  }

  String _resolvePreferredStoredImageSource({
    required String localSource,
    required String remoteSource,
  }) {
    final local = localSource.trim();
    final remote = remoteSource.trim();

    if (local.isEmpty) return remote;
    if (_looksLikeLocalFilePath(local) || local.startsWith('file://')) {
      return local;
    }
    if (remote.isNotEmpty) return remote;
    return local;
  }

  Future<String> _syncImageOnlyToBackend({
    required String imageSource,
    required String? cityCode,
  }) async {
    final normalizedSource = imageSource.trim();
    if (normalizedSource.isEmpty) {
      throw const BackendApiException('请先选择明信片图片。');
    }

    final uploadedImage = await _resolveImageForBackend(
      normalizedSource,
      cityCode: cityCode,
    );
    final createImageKey =
        _tryResolveImageKeyForCreate(uploadedImage) ??
        _normalizeObjectKey(uploadedImage.imageUrl).trim();
    return _resolveImageUrlForCreate(uploadedImage, imageKey: createImageKey);
  }

  Future<String> saveDraftPostcard({
    String? draftId,
    required String imageUrl,
    double? latitude,
    double? longitude,
    String? cityName,
    String? cityCode,
    String? provinceName,
    String? locationDetail,
    List<PostcardElementLayer>? layers,
  }) {
    return _savePostcard(
      draftId: draftId,
      imageUrl: imageUrl,
      isDraft: true,
      latitude: latitude,
      longitude: longitude,
      cityName: cityName,
      cityCode: cityCode,
      provinceName: provinceName,
      locationDetail: locationDetail,
      layers: layers,
    );
  }

  Future<String> _savePostcard({
    String? draftId,
    required String imageUrl,
    String? remotePostcardId,
    required bool isDraft,
    double? latitude,
    double? longitude,
    String? cityName,
    String? cityCode,
    String? provinceName,
    String? locationDetail,
    List<PostcardElementLayer>? layers,
  }) async {
    final postcards = await getEditedPostcards();
    final normalizedId = draftId?.trim() ?? '';
    final normalizedRemoteId = remotePostcardId?.trim() ?? '';
    final targetId = normalizedRemoteId.isNotEmpty
        ? normalizedRemoteId
        : (normalizedId.isEmpty ? _createDraftId() : normalizedId);

    if (normalizedId.isNotEmpty) {
      postcards.removeWhere((item) => item.draftId == normalizedId);
    }

    postcards.insert(
      0,
      EditedPostcard(
        draftId: targetId,
        imageUrl: await _normalizeStoredImageSource(imageUrl),
        editedAt: DateTime.now(),
        isPublished: false,
        isDraft: isDraft,
        latitude: latitude,
        longitude: longitude,
        cityName: cityName?.trim(),
        cityCode: _toNullableCodeString(cityCode),
        provinceName: provinceName?.trim(),
        locationDetail: locationDetail?.trim(),
        layers: List<PostcardElementLayer>.from(layers ?? const []),
      ),
    );

    await _savePostcards(postcards);
    return targetId;
  }

  Future<List<EditedPostcard>> _normalizePostcardImageSources(
    List<EditedPostcard> postcards,
  ) async {
    if (postcards.isEmpty) return postcards;

    final normalized = <EditedPostcard>[];
    var changed = false;
    for (final card in postcards) {
      final next = await _normalizePostcardImageSource(card);
      if (next.imageUrl != card.imageUrl) {
        changed = true;
      }
      normalized.add(next);
    }

    if (changed) {
      await _savePostcards(normalized);
    }
    return normalized;
  }

  Future<EditedPostcard> _normalizePostcardImageSource(
    EditedPostcard card,
  ) async {
    final normalizedImageUrl = await _normalizeStoredImageSource(card.imageUrl);
    if (normalizedImageUrl == card.imageUrl) {
      return card;
    }
    return EditedPostcard(
      draftId: card.draftId,
      imageUrl: normalizedImageUrl,
      editedAt: card.editedAt,
      isPublished: card.isPublished,
      isDraft: card.isDraft,
      latitude: card.latitude,
      longitude: card.longitude,
      cityName: card.cityName,
      cityCode: card.cityCode,
      provinceName: card.provinceName,
      locationDetail: card.locationDetail,
      layers: card.layers,
    );
  }

  Future<String> _normalizeStoredImageSource(String source) async {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return trimmed;

    if (_isHttpSource(trimmed) || _isAssetSource(trimmed)) {
      return trimmed;
    }
    if (_looksLikeRelativeApiPath(trimmed) ||
        _looksLikeLocalFilePath(trimmed)) {
      return trimmed;
    }

    final key = trimmed.replaceFirst(RegExp(r'^/+'), '');
    if (key.isEmpty) return trimmed;

    try {
      final context = await _resolveOssUploadContext();
      if (context.endpoint.isNotEmpty && context.bucketName.isNotEmpty) {
        return _buildOssObjectUrl(
          objectKey: key,
          endpoint: context.endpoint,
          bucketName: context.bucketName,
        );
      }
    } catch (_) {}

    final endpoint = _normalizeEndpointHost(
      _firstNonEmpty(<String?>[_cachedOssEndpoint, _configuredOssEndpoint]),
    );
    final bucketName = _firstNonEmpty(<String?>[
      _cachedBucketName,
      _configuredOssBucketName,
    ]);
    if (endpoint.isNotEmpty && bucketName.isNotEmpty) {
      return _buildOssObjectUrl(
        objectKey: key,
        endpoint: endpoint,
        bucketName: bucketName,
      );
    }
    return '/$key';
  }

  Future<_PostcardSyncResult> _syncPostcardToBackend({
    required String imageSource,
    required String? cityName,
    required String? cityCode,
    required String? provinceName,
    required String? locationDetail,
    required double? latitude,
    required double? longitude,
    required List<PostcardElementLayer> layers,
  }) async {
    final normalizedSource = imageSource.trim();
    if (normalizedSource.isEmpty) {
      throw const BackendApiException('请先选择明信片图片。');
    }

    final uploadedImage = await _resolveImageForBackend(
      normalizedSource,
      cityCode: cityCode,
    );
    final createImageKey =
        _tryResolveImageKeyForCreate(uploadedImage) ??
        _normalizeObjectKey(uploadedImage.imageUrl).trim();
    final createImageUrl = await _resolveImageUrlForCreate(
      uploadedImage,
      imageKey: createImageKey,
    );
    _debugPostcardSync('已准备', <String, dynamic>{
      'source': normalizedSource,
      'uploadedImageUrl': uploadedImage.imageUrl,
      'uploadedImageKey': uploadedImage.objectKey,
      'createImageKey': createImageKey,
      'createImageUrl': createImageUrl,
    });
    final payload = _buildCreatePayload(
      imageKey: createImageKey,
      imageUrl: createImageUrl,
      cityName: cityName,
      cityCode: cityCode,
      provinceName: provinceName,
      locationDetail: locationDetail,
      latitude: latitude,
      longitude: longitude,
      layers: layers,
    );
    final response = await _createPostcardRemote(payload);
    final remotePostcardId = _extractRemotePostcardId(response);
    final remoteImageUrl = _extractRemoteImageUrl(response);
    final remoteImageKey = _extractRemoteImageKey(response);
    _debugPostcardSync('响应', <String, dynamic>{
      'remotePostcardId': remotePostcardId,
      'remoteImageUrl': remoteImageUrl,
      'remoteImageKey': remoteImageKey,
    });
    final finalImageUrl = await _resolveFinalImageUrl(
      remoteImageUrl: remoteImageUrl,
      remoteImageKey: remoteImageKey,
      fallbackUrl: uploadedImage.imageUrl,
      fallbackKey: uploadedImage.objectKey,
    );

    return _PostcardSyncResult(
      imageUrl: finalImageUrl,
      remotePostcardId: remotePostcardId,
    );
  }

  Future<_UploadedPostcardImage> _resolveImageForBackend(
    String source, {
    required String? cityCode,
  }) async {
    if (_isHttpSource(source)) {
      final keyFromHttp = _normalizeObjectKey(source);
      return _UploadedPostcardImage(
        imageUrl: source,
        objectKey: keyFromHttp.isEmpty ? null : keyFromHttp,
      );
    }
    if (_isAssetSource(source)) {
      throw const BackendApiException('请先上传本地图片后再保存明信片。');
    }
    if (_looksLikeLocalFilePath(source)) {
      final localPath = _normalizeLocalUploadPath(source);
      return _uploadLocalImageViaOss(localPath, cityCode: cityCode);
    }
    if (_looksLikeRelativeApiPath(source) &&
        !_looksLikeApiEndpointValue(source)) {
      final keyFromPath = _normalizeObjectKey(source);
      return _UploadedPostcardImage(
        imageUrl: _toAbsoluteApiUrl(source),
        objectKey: keyFromPath.isEmpty ? null : keyFromPath,
      );
    }

    final normalizedKey = source.replaceFirst(RegExp(r'^/+'), '');
    if (normalizedKey.isEmpty) {
      throw const BackendApiException('明信片图片无效，请重新选择。');
    }

    try {
      final context = await _resolveOssUploadContext();
      final url = _buildOssObjectUrl(
        objectKey: normalizedKey,
        endpoint: context.endpoint,
        bucketName: context.bucketName,
      );
      return _UploadedPostcardImage(imageUrl: url, objectKey: normalizedKey);
    } catch (_) {
      return _UploadedPostcardImage(imageUrl: normalizedKey);
    }
  }

  Future<_UploadedPostcardImage> _uploadLocalImageViaOss(
    String filePath, {
    required String? cityCode,
  }) async {
    final normalizedPath = filePath.trim();
    if (normalizedPath.isEmpty) {
      throw const BackendApiException('明信片图片路径不能为空。');
    }

    final file = File(normalizedPath);
    if (!file.existsSync()) {
      throw const BackendApiException('明信片图片不存在，请重新选择。');
    }

    final objectKey = _normalizeObjectKey(
      await _requestPostcardObjectKey(file, cityCode: cityCode),
    );
    if (objectKey.isEmpty) {
      throw const BackendApiException('获取明信片底图键值失败。');
    }

    final context = await _resolveOssUploadContext();
    _initOssClient(endpoint: context.endpoint, bucketName: context.bucketName);
    try {
      await Client().putObjectFile(file, fileKey: objectKey);
    } catch (error) {
      final message = _buildOssUploadFailureMessage(error);
      throw BackendApiException(message);
    }

    return _UploadedPostcardImage(
      imageUrl: _buildOssObjectUrl(
        objectKey: objectKey,
        endpoint: context.endpoint,
        bucketName: context.bucketName,
      ),
      objectKey: objectKey,
    );
  }

  String _resolveImageKeyForCreate(_UploadedPostcardImage uploadedImage) {
    final key = (uploadedImage.objectKey?.trim() ?? '').replaceFirst(
      RegExp(r'^/+'),
      '',
    );
    if (key.isNotEmpty) {
      return key;
    }

    final keyFromUrl = _normalizeObjectKey(
      uploadedImage.imageUrl,
    ).replaceFirst(RegExp(r'^/+'), '');
    if (keyFromUrl.isNotEmpty) {
      return keyFromUrl;
    }

    throw const BackendApiException('无法解析明信片图片键值，请重新上传。');
  }

  String? _tryResolveImageKeyForCreate(_UploadedPostcardImage uploadedImage) {
    try {
      return _resolveImageKeyForCreate(uploadedImage);
    } catch (_) {
      return null;
    }
  }

  Future<String> _resolveImageUrlForCreate(
    _UploadedPostcardImage uploadedImage, {
    String? imageKey,
  }) async {
    final url = uploadedImage.imageUrl.trim();
    if (url.isNotEmpty) {
      if (_isHttpSource(url) && !_looksLikeApiEndpointValue(url)) {
        return url;
      }
      if (_looksLikeRelativeApiPath(url) && !_looksLikeApiEndpointValue(url)) {
        return _toAbsoluteApiUrl(url);
      }
    }

    final normalizedKey =
        (imageKey?.trim().isNotEmpty == true
                ? imageKey!.trim()
                : (uploadedImage.objectKey?.trim() ?? ''))
            .replaceFirst(RegExp(r'^/+'), '');
    if (normalizedKey.isNotEmpty) {
      try {
        final context = await _resolveOssUploadContext();
        if (context.endpoint.isNotEmpty && context.bucketName.isNotEmpty) {
          return _buildOssObjectUrl(
            objectKey: normalizedKey,
            endpoint: context.endpoint,
            bucketName: context.bucketName,
          );
        }
      } catch (_) {}

      final endpoint = _normalizeEndpointHost(
        _firstNonEmpty(<String?>[_cachedOssEndpoint, _configuredOssEndpoint]),
      );
      final bucketName = _firstNonEmpty(<String?>[
        _cachedBucketName,
        _configuredOssBucketName,
      ]);
      if (endpoint.isNotEmpty && bucketName.isNotEmpty) {
        return _buildOssObjectUrl(
          objectKey: normalizedKey,
          endpoint: endpoint,
          bucketName: bucketName,
        );
      }
    }

    if (url.isNotEmpty &&
        !_looksLikeLocalFilePath(url) &&
        !_isAssetSource(url)) {
      final path = url.replaceFirst(RegExp(r'^/+'), '');
      if (path.isNotEmpty) {
        return _toAbsoluteApiUrl('/$path');
      }
    }

    throw const BackendApiException('无法解析明信片图片地址，请重新上传。');
  }

  Future<String> _requestPostcardObjectKey(
    File file, {
    required String? cityCode,
  }) async {
    final extension = _readFileExtension(file.path);
    final fileSize = file.lengthSync();
    final normalizedCityCode = _normalizeCityCode(cityCode);

    final bodyCandidates = <Map<String, dynamic>?>[
      if (extension != null)
        <String, dynamic>{
          'ext': extension,
          'size': fileSize,
          ..._singleEntryIfNotNull<dynamic>('cityCode', normalizedCityCode),
        },
      <String, dynamic>{
        'size': fileSize,
        ..._singleEntryIfNotNull<dynamic>('cityCode', normalizedCityCode),
      },
      if (extension != null) <String, dynamic>{'ext': extension},
      null,
    ];
    final queryCandidates = <Map<String, String>>[
      if (normalizedCityCode != null)
        <String, String>{'cityCode': normalizedCityCode},
      if (extension != null) <String, String>{'ext': extension},
      <String, String>{'size': '$fileSize'},
      if (extension != null)
        <String, String>{'ext': extension, 'size': '$fileSize'},
      if (extension != null && normalizedCityCode != null)
        <String, String>{
          'cityCode': normalizedCityCode,
          'ext': extension,
          'size': '$fileSize',
        },
    ];

    BackendApiException? backendError;
    for (final body in bodyCandidates) {
      try {
        final response = await _apiClient.post(
          '/postcard/key',
          body: body,
          requireAuth: true,
        );
        final key = _extractObjectKey(response);
        if (key != null && key.isNotEmpty) {
          return key;
        }
      } on BackendApiException catch (e) {
        backendError = e;
      }
    }

    for (final query in queryCandidates) {
      try {
        final response = await _apiClient.get(
          '/postcard/key',
          queryParameters: query,
          requireAuth: true,
        );
        final key = _extractObjectKey(response);
        if (key != null && key.isNotEmpty) {
          return key;
        }
      } on BackendApiException catch (e) {
        backendError = e;
      }
    }

    if (backendError != null) throw backendError;
    throw const BackendApiException('无法获取明信片底图键值。');
  }

  Map<String, dynamic> _buildCreatePayload({
    required String? imageKey,
    required String imageUrl,
    required String? cityName,
    required String? cityCode,
    required String? provinceName,
    required String? locationDetail,
    required double? latitude,
    required double? longitude,
    required List<PostcardElementLayer> layers,
  }) {
    final normalizedCityName = cityName?.trim() ?? '';
    final normalizedProvinceName = provinceName?.trim() ?? '';
    final normalizedLocationDetail = locationDetail?.trim() ?? '';
    final normalizedCityCode = _normalizeCityCode(cityCode);
    final cityCodeAsNumber = normalizedCityCode == null
        ? null
        : int.tryParse(normalizedCityCode);
    final address = _resolveAddressText(
      cityName: normalizedCityName,
      provinceName: normalizedProvinceName,
      cityCode: normalizedCityCode,
      locationDetail: normalizedLocationDetail,
    );
    final title = normalizedCityName.isNotEmpty
        ? '$normalizedCityName 明信片'
        : (normalizedProvinceName.isNotEmpty
              ? '$normalizedProvinceName 明信片'
              : '我的明信片');
    final content = normalizedCityName.isNotEmpty
        ? '来自$normalizedCityName的明信片'
        : (normalizedProvinceName.isNotEmpty
              ? '来自$normalizedProvinceName的明信片'
              : '我的明信片');

    final elements = _buildElementPayload(layers, useLegacyAssetType: false);

    final payload = <String, dynamic>{
      'title': title,
      'content': content,
      'imageUrl': imageUrl.trim(),
      'address': address,
      ..._singleEntryIfNotNull<dynamic>(
        'cityCode',
        cityCodeAsNumber ?? normalizedCityCode,
      ),
      if (normalizedCityName.isNotEmpty) 'cityName': normalizedCityName,
      if (normalizedProvinceName.isNotEmpty)
        'provinceName': normalizedProvinceName,
      ..._singleEntryIfNotNull<dynamic>('latitude', latitude),
      ..._singleEntryIfNotNull<dynamic>('longitude', longitude),
      if (elements.isNotEmpty) 'elements': elements,
      if (imageKey?.trim().isNotEmpty == true) 'imageKey': imageKey!.trim(),
      if (imageKey?.trim().isNotEmpty == true) 'key': imageKey!.trim(),
      if (imageKey?.trim().isNotEmpty == true) 'objectKey': imageKey!.trim(),
    };
    payload.removeWhere(
      (key, value) =>
          value == null || (value is String && value.trim().isEmpty),
    );
    return payload;
  }

  List<Map<String, dynamic>> _buildElementPayload(
    List<PostcardElementLayer> layers, {
    required bool useLegacyAssetType,
  }) {
    if (layers.isEmpty) return const <Map<String, dynamic>>[];
    return layers
        .map(
          (item) => _normalizeElementPayload(
            item,
            useLegacyAssetType: useLegacyAssetType,
          ),
        )
        .toList(growable: false);
  }

  Map<String, dynamic> _normalizeElementPayload(
    PostcardElementLayer layer, {
    required bool useLegacyAssetType,
  }) {
    final json = Map<String, dynamic>.from(layer.toJson());
    json['type'] = layer.isText
        ? 'text'
        : (useLegacyAssetType ? 'assert' : 'asset');

    final elementKey = json['elementKey']?.toString().trim() ?? '';
    if (elementKey.isNotEmpty) {
      json['assetKey'] = elementKey;
      json['asset_key'] = elementKey;
    }
    final assetPath = json['assetPath']?.toString().trim() ?? '';
    if (assetPath.isNotEmpty) {
      json['asset_path'] = assetPath;
    }

    final text = json['text']?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      json['textContent'] = text;
      json['text_content'] = text;
    }

    final style = _toStringDynamicMap(json['style']);
    if (style != null) {
      final normalizedStyle = Map<String, dynamic>.from(style);
      final fontSize = _toRoundedInt(normalizedStyle['fontSize']);
      if (fontSize != null) {
        normalizedStyle['fontSize'] = fontSize;
      }
      final letterSpacing = _toRoundedInt(normalizedStyle['letterSpacing']);
      if (letterSpacing != null) {
        normalizedStyle['letterSpacing'] = letterSpacing;
      }
      final align = normalizedStyle['align']?.toString().trim() ?? '';
      if (align.isNotEmpty) {
        normalizedStyle['textAlign'] = align;
      }
      final fontWeight = normalizedStyle['fontWeight']?.toString().trim() ?? '';
      if (fontWeight.isNotEmpty) {
        normalizedStyle['weight'] = fontWeight;
      }
      json['style'] = normalizedStyle;
    }

    final box =
        _toStringDynamicMap(json['box']) ??
        _toStringDynamicMap(json['textBox']);
    if (box != null) {
      final normalizedBox = Map<String, dynamic>.from(box);
      final maxWidth = _toRoundedInt(normalizedBox['maxWidth']);
      if (maxWidth != null) {
        normalizedBox['maxWidth'] = maxWidth;
        normalizedBox['width'] = maxWidth;
      }
      final padding = _toRoundedInt(normalizedBox['padding']);
      if (padding != null) {
        normalizedBox['padding'] = padding;
      }
      final borderRadius = _toRoundedInt(normalizedBox['borderRadius']);
      if (borderRadius != null) {
        normalizedBox['borderRadius'] = borderRadius;
      }
      final backgroundColor =
          normalizedBox['backgroundColor']?.toString().trim() ?? '';
      if (backgroundColor.isNotEmpty) {
        normalizedBox['bgColor'] = backgroundColor;
      }
      json['box'] = normalizedBox;
      json['textBox'] = Map<String, dynamic>.from(normalizedBox);
    }

    json.removeWhere(
      (key, value) =>
          value == null || (value is String && value.trim().isEmpty),
    );
    return json;
  }

  Map<String, dynamic> _rewriteAssetTypeInPayload(
    Map<String, dynamic> source, {
    required bool useLegacyAssetType,
  }) {
    final payload = Map<String, dynamic>.from(source);
    final rawElements = payload['elements'];
    if (rawElements is! List || rawElements.isEmpty) {
      return payload;
    }

    final elements = <Map<String, dynamic>>[];
    for (final item in rawElements) {
      final map = _toStringDynamicMap(item);
      if (map == null) continue;
      final next = Map<String, dynamic>.from(map);
      final type = next['type']?.toString().trim().toLowerCase() ?? '';
      next['type'] = type == 'text'
          ? 'text'
          : (useLegacyAssetType ? 'assert' : 'asset');
      elements.add(next);
    }
    if (elements.isNotEmpty) {
      payload['elements'] = elements;
    }
    return payload;
  }

  Map<String, dynamic>? _toStringDynamicMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      try {
        return raw.cast<String, dynamic>();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  int? _toRoundedInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  String _resolveAddressText({
    required String cityName,
    required String provinceName,
    required String? cityCode,
    required String locationDetail,
  }) {
    final normalized = CityLocationHelper.resolveProvinceCityText(
      cityName: cityName,
      cityCode: cityCode,
      provinceName: provinceName,
    );
    if (normalized != null && normalized.isNotEmpty) {
      return CityLocationHelper.mergeWithDetail(
        base: normalized,
        detail: locationDetail,
      );
    }

    if (cityName.isNotEmpty) {
      return _mergeAddressText(cityName, locationDetail);
    }
    if (provinceName.isNotEmpty) {
      return _mergeAddressText(provinceName, locationDetail);
    }
    if (cityCode != null && cityCode.isNotEmpty) {
      return _mergeAddressText('城市代码$cityCode', locationDetail);
    }
    if (locationDetail.isNotEmpty) return locationDetail;
    return '未知地点';
  }

  String _mergeAddressText(String mainPart, String detailPart) {
    final normalizedMain = mainPart.trim();
    final normalizedDetail = detailPart.trim();
    if (normalizedMain.isEmpty) return normalizedDetail;
    if (normalizedDetail.isEmpty) return normalizedMain;
    if (normalizedDetail.contains(normalizedMain)) return normalizedDetail;
    if (normalizedMain.contains(normalizedDetail)) return normalizedMain;
    return '$normalizedMain$normalizedDetail';
  }

  Future<Map<String, dynamic>> _createPostcardRemote(
    Map<String, dynamic> payload,
  ) async {
    final title = payload["title"]?.toString().trim() ?? "";
    final content = payload["content"]?.toString().trim() ?? "";
    final imageUrl = payload["imageUrl"]?.toString().trim() ?? "";
    final imageKey = payload["imageKey"]?.toString().trim() ?? "";
    final cityCode = payload["cityCode"]?.toString().trim() ?? "";
    final cityCodeNumber = int.tryParse(cityCode);
    final address = payload["address"]?.toString().trim() ?? "";
    final cityName = payload["cityName"];
    final provinceName = payload["provinceName"];
    final latitude = payload["latitude"];
    final longitude = payload["longitude"];

    final fullPayload = Map<String, dynamic>.from(payload);
    final legacyTypePayload = _rewriteAssetTypeInPayload(
      fullPayload,
      useLegacyAssetType: true,
    );
    final noElementsPayload = <String, dynamic>{
      if (title.isNotEmpty) "title": title,
      if (content.isNotEmpty) "content": content,
      if (imageKey.isNotEmpty) "imageKey": imageKey,
      if (imageUrl.isNotEmpty) "imageUrl": imageUrl,
      ..._singleEntryIfNotNull<dynamic>("cityName", cityName),
      ..._singleEntryIfNotNull<dynamic>("provinceName", provinceName),
      if (cityCode.isNotEmpty) "cityCode": cityCodeNumber ?? cityCode,
      ..._singleEntryIfNotNull<dynamic>("latitude", latitude),
      ..._singleEntryIfNotNull<dynamic>("longitude", longitude),
      if (address.isNotEmpty) "address": address,
    };
    final keyCorePayload = <String, dynamic>{
      if (title.isNotEmpty) "title": title,
      if (content.isNotEmpty) "content": content,
      if (imageKey.isNotEmpty) "imageKey": imageKey,
      if (cityCode.isNotEmpty) "cityCode": cityCodeNumber ?? cityCode,
      if (address.isNotEmpty) "address": address,
    };
    final keyCoreWithHttpUrlPayload = <String, dynamic>{
      ...keyCorePayload,
      if (imageUrl.isNotEmpty) "imageUrl": imageUrl,
    };
    final keyCoreWithKeyUrlPayload = <String, dynamic>{
      ...keyCorePayload,
      if (imageKey.isNotEmpty) "imageUrl": imageKey,
    };
    final aliasPayload = <String, dynamic>{
      ...noElementsPayload,
      if (imageKey.isNotEmpty) "imageKey": imageKey,
      if (imageUrl.isNotEmpty) "image": imageUrl,
      if (imageUrl.isNotEmpty) "url": imageUrl,
    };
    final minimalPayload = <String, dynamic>{
      if (imageKey.isNotEmpty) "imageKey": imageKey,
      if (cityCode.isNotEmpty) "cityCode": cityCodeNumber ?? cityCode,
      if (address.isNotEmpty) "address": address,
    };

    final attempts = <_CreateAttempt>[
      _CreateAttempt(name: "完整参数-兼容元素类型", body: legacyTypePayload),
      _CreateAttempt(name: "完整参数", body: fullPayload),
      _CreateAttempt(name: "去除元素", body: noElementsPayload),
      _CreateAttempt(name: "核心字段+HTTP地址", body: keyCoreWithHttpUrlPayload),
      _CreateAttempt(name: "核心字段+Key地址", body: keyCoreWithKeyUrlPayload),
      _CreateAttempt(name: "核心字段", body: keyCorePayload),
      _CreateAttempt(name: "别名字段", body: aliasPayload),
      _CreateAttempt(name: "最小字段", body: minimalPayload),
    ];
    final endpoints = <String>["/postcard/create"];

    final errors = <String>[];
    for (final endpoint in endpoints) {
      for (final attempt in attempts) {
        try {
          _debugCreateAttempt(endpoint, attempt);
          return await _apiClient.post(
            endpoint,
            body: attempt.body,
            requireAuth: true,
          );
        } on BackendApiException catch (e) {
          _debugCreateFailure(endpoint, attempt, e);
          errors.add(
            "$endpoint:${attempt.name}:status=${e.statusCode ?? "-"} msg=${e.message}",
          );
        }
      }
    }

    final summary = errors.isEmpty ? "明信片创建失败" : errors.join(" | ");
    throw BackendApiException("明信片创建失败: $summary");
  }

  void _debugPostcardSync(String stage, Map<String, dynamic> data) {
    if (!kDebugMode) return;
    debugPrint('[明信片同步][$stage] ${jsonEncode(data)}');
  }

  void _debugCreateAttempt(String endpoint, _CreateAttempt attempt) {
    if (!kDebugMode) return;
    final body = attempt.body;
    debugPrint(
      '[明信片创建][尝试] endpoint=$endpoint mode=${attempt.name} '
      'imageUrl=${body["imageUrl"] ?? ""} imageKey=${body["imageKey"] ?? ""} '
      'cityCode=${body["cityCode"] ?? ""} keys=${body.keys.toList()}',
    );
  }

  void _debugCreateFailure(
    String endpoint,
    _CreateAttempt attempt,
    BackendApiException error,
  ) {
    if (!kDebugMode) return;
    debugPrint(
      '[明信片创建][失败] endpoint=$endpoint mode=${attempt.name} '
      'status=${error.statusCode ?? "-"} apiCode=${error.apiCode ?? "-"} '
      'msg=${error.message}',
    );
  }

  Future<String> _resolveFinalImageUrl({
    required String? remoteImageUrl,
    required String? remoteImageKey,
    required String fallbackUrl,
    required String? fallbackKey,
  }) async {
    final candidateUrl = remoteImageUrl?.trim() ?? '';
    if (candidateUrl.isNotEmpty) {
      if (_isHttpSource(candidateUrl) &&
          !_looksLikeApiEndpointValue(candidateUrl)) {
        return candidateUrl;
      }
      if (_looksLikeRelativeApiPath(candidateUrl) &&
          !_looksLikeApiEndpointValue(candidateUrl)) {
        return _toAbsoluteApiUrl(candidateUrl);
      }
    }

    final key =
        (remoteImageKey?.trim().isNotEmpty == true
                ? remoteImageKey!.trim()
                : (fallbackKey?.trim() ?? ''))
            .replaceFirst(RegExp(r'^/+'), '');
    if (key.isNotEmpty) {
      try {
        final context = await _resolveOssUploadContext();
        if (context.endpoint.isNotEmpty && context.bucketName.isNotEmpty) {
          return _buildOssObjectUrl(
            objectKey: key,
            endpoint: context.endpoint,
            bucketName: context.bucketName,
          );
        }
      } catch (_) {}

      final endpoint = _normalizeEndpointHost(
        _firstNonEmpty(<String?>[_cachedOssEndpoint, _configuredOssEndpoint]),
      );
      final bucketName = _firstNonEmpty(<String?>[
        _cachedBucketName,
        _configuredOssBucketName,
      ]);
      if (endpoint.isNotEmpty && bucketName.isNotEmpty) {
        return _buildOssObjectUrl(
          objectKey: key,
          endpoint: endpoint,
          bucketName: bucketName,
        );
      }
    }

    final fallback = fallbackUrl.trim();
    if (fallback.isNotEmpty) {
      if (_isHttpSource(fallback) && !_looksLikeApiEndpointValue(fallback)) {
        return fallback;
      }
      if (_looksLikeRelativeApiPath(fallback) &&
          !_looksLikeApiEndpointValue(fallback)) {
        return _toAbsoluteApiUrl(fallback);
      }
    }

    if (candidateUrl.isNotEmpty) {
      return candidateUrl;
    }
    if (key.isNotEmpty) {
      return '/$key';
    }
    return fallback;
  }

  String? _extractRemotePostcardId(Map<String, dynamic> body) {
    final data = BackendApiClient.extractData(body);
    final idFromString = BackendApiClient.readString(data, const [
      'postcardId',
      'cardId',
      'id',
      'postId',
    ]);
    if (idFromString != null && idFromString.isNotEmpty) {
      return idFromString;
    }

    final idFromInt = BackendApiClient.readInt(data, const [
      'postcardId',
      'cardId',
      'id',
      'postId',
    ]);
    if (idFromInt != null) {
      return '$idFromInt';
    }
    return null;
  }

  String? _extractRemoteImageUrl(Map<String, dynamic> body) {
    final data = BackendApiClient.extractData(body);
    final value = BackendApiClient.readString(data, const [
      'imageUrl',
      'url',
      'image',
      'coverUrl',
      'postcardUrl',
    ]);
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim();
    if (_looksLikeApiEndpointValue(normalized)) {
      return null;
    }
    if (!_isHttpSource(normalized) && !_looksLikeRelativeApiPath(normalized)) {
      return null;
    }
    return normalized;
  }

  String? _extractRemoteImageKey(Map<String, dynamic> body) {
    final data = BackendApiClient.extractData(body);
    final value = BackendApiClient.readString(data, const [
      'imageKey',
      'key',
      'objectKey',
      'fileKey',
      'path',
    ]);
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim();
    if (_looksLikeApiEndpointValue(normalized)) {
      return null;
    }
    if (_isHttpSource(normalized) || _looksLikeRelativeApiPath(normalized)) {
      final fromUrl = _normalizeObjectKey(normalized);
      if (fromUrl.isEmpty) return null;
      if (_looksLikeApiEndpointValue('/$fromUrl')) {
        return null;
      }
      return fromUrl;
    }
    return normalized.replaceFirst(RegExp(r'^/+'), '');
  }

  String? _extractObjectKey(Map<String, dynamic> body) {
    final data = BackendApiClient.extractData(body);
    final direct = data is String || data is num ? data.toString().trim() : '';
    if (direct.isNotEmpty && !_isHttpSource(direct)) {
      return direct.replaceFirst(RegExp(r'^/+'), '');
    }

    final key = _readDeepString(data, const <String>[
      'key',
      'objectKey',
      'fileKey',
      'path',
      'value',
      'imageKey',
      'image_path',
    ]);
    if (key == null || key.isEmpty) return null;
    return key.replaceFirst(RegExp(r'^/+'), '');
  }

  Future<_OssUploadContext> _resolveOssUploadContext() async {
    final cachedEndpoint = _cachedOssEndpoint?.trim() ?? '';
    final cachedBucket = _cachedBucketName?.trim() ?? '';
    if (cachedEndpoint.isNotEmpty && cachedBucket.isNotEmpty) {
      return _OssUploadContext(
        endpoint: cachedEndpoint,
        bucketName: cachedBucket,
      );
    }

    final stsBody = await _requestOssSts();
    final endpointFromSts = _readDeepString(stsBody, const <String>[
      'ossEndpoint',
      'endpoint',
      'ossHost',
      'host',
      'domain',
    ]);
    final bucketFromSts = _readDeepString(stsBody, const <String>[
      'bucketName',
      'bucket',
      'ossBucketName',
      'bucket_name',
    ]);

    var endpoint = _normalizeEndpointHost(
      _firstNonEmpty(<String?>[endpointFromSts, _configuredOssEndpoint]),
    );
    var bucketName = _firstNonEmpty(<String?>[
      bucketFromSts,
      _configuredOssBucketName,
    ]);

    if (bucketName.isEmpty && endpoint.contains('.oss-')) {
      bucketName = endpoint.split('.').first;
    }
    if (bucketName.isNotEmpty && endpoint.startsWith('$bucketName.')) {
      endpoint = endpoint.substring(bucketName.length + 1);
    }

    if (endpoint.isEmpty || bucketName.isEmpty) {
      throw const BackendApiException('对象存储配置缺失：终端地址或存储桶名称为空。');
    }

    _cachedOssEndpoint = endpoint;
    _cachedBucketName = bucketName;
    return _OssUploadContext(endpoint: endpoint, bucketName: bucketName);
  }

  void _initOssClient({required String endpoint, required String bucketName}) {
    Client.init(
      ossEndpoint: endpoint,
      bucketName: bucketName,
      tokenGetter: _fetchStsTokenJson,
    );
  }

  Future<String> _fetchStsTokenJson() async {
    final stsBody = await _requestOssSts();
    final tokenMap = _extractStsToken(stsBody);
    return jsonEncode(tokenMap);
  }

  Future<Map<String, dynamic>> _requestOssSts() async {
    BackendApiException? backendError;
    for (final request in <Future<Map<String, dynamic>> Function()>[
      () => _apiClient.post('/oss/sts', requireAuth: true),
      () => _apiClient.get('/oss/sts', requireAuth: true),
      () => _apiClient.post('/oss/sts/token', requireAuth: true),
      () => _apiClient.get('/oss/sts/token', requireAuth: true),
    ]) {
      try {
        return await request();
      } on BackendApiException catch (e) {
        backendError = e;
      }
    }

    if (backendError != null) throw backendError;
    throw const BackendApiException('无法获取对象存储临时凭证。');
  }

  Map<String, dynamic> _extractStsToken(Map<String, dynamic> body) {
    final accessKeyId = _readDeepString(body, const <String>[
      'AccessKeyId',
      'accessKeyId',
      'accessKey',
    ]);
    final accessKeySecret = _readDeepString(body, const <String>[
      'AccessKeySecret',
      'accessKeySecret',
      'accessSecret',
    ]);
    final securityToken = _readDeepString(body, const <String>[
      'SecurityToken',
      'securityToken',
      'security_token',
      'stsToken',
    ]);
    final expirationValue = _readDeepValue(body, const <String>[
      'Expiration',
      'expiration',
      'expireAt',
      'expiresAt',
      'expiredTime',
    ]);

    final expiration = _normalizeExpiration(expirationValue);
    if (accessKeyId == null ||
        accessKeySecret == null ||
        securityToken == null ||
        expiration == null) {
      throw const BackendApiException('对象存储临时凭证返回格式无效。');
    }

    return <String, dynamic>{
      'AccessKeyId': accessKeyId,
      'AccessKeySecret': accessKeySecret,
      'SecurityToken': securityToken,
      'Expiration': expiration,
    };
  }

  String _buildOssUploadFailureMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('403')) {
      return '明信片图片上传被拒绝（403），请检查对象存储临时凭证策略。';
    }
    if (text.contains('401')) {
      return '明信片图片上传凭证已过期或无效（401）。';
    }
    if (text.contains('socket') ||
        text.contains('timed out') ||
        text.contains('network')) {
      return '明信片图片上传网络异常。';
    }
    return '明信片图片上传失败。';
  }

  String _normalizeObjectKey(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    if (_isHttpSource(text)) {
      final uri = Uri.tryParse(text);
      if (uri == null) return text.replaceFirst(RegExp(r'^/+'), '');
      final segments = uri.pathSegments
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      if (segments.isEmpty) return '';
      final bucketName = _cachedBucketName?.trim() ?? '';
      if (bucketName.isNotEmpty &&
          segments.length > 1 &&
          segments.first.toLowerCase() == bucketName.toLowerCase()) {
        return segments.skip(1).join('/');
      }
      return segments.join('/');
    }
    return text.replaceFirst(RegExp(r'^/+'), '');
  }

  String _buildOssObjectUrl({
    required String objectKey,
    required String endpoint,
    required String bucketName,
  }) {
    final normalizedKey = objectKey.trim().replaceFirst(RegExp(r'^/+'), '');
    return 'https://$bucketName.$endpoint/$normalizedKey';
  }

  static bool _isHttpSource(String source) {
    final uri = Uri.tryParse(source.trim());
    return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  }

  static bool _isAssetSource(String source) {
    return source.trim().startsWith('assets/');
  }

  static bool _looksLikeRelativeApiPath(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return false;
    if (!trimmed.startsWith('/')) return false;
    if (trimmed.startsWith('//')) return false;
    return !_looksLikeLocalFilePath(trimmed);
  }

  static String _toAbsoluteApiUrl(String relativePath) {
    final base = BackendApiClient.baseUrl.trim().replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    final path = relativePath.trim();
    if (base.isEmpty) return path;
    return '$base$path';
  }

  static bool _looksLikeLocalFilePath(String source) {
    final text = source.trim();
    if (text.isEmpty) return false;
    if (_isHttpSource(text)) return false;
    if (text.startsWith('assets/')) return false;
    if (text.startsWith('file://')) return true;
    final windowsPath = RegExp(r'^[a-zA-Z]:[\\/]');
    if (windowsPath.hasMatch(text)) return true;
    return _looksLikeUnixLocalPath(text);
  }

  static bool _looksLikeUnixLocalPath(String source) {
    if (!source.startsWith('/')) return false;
    final localPrefixes = const <String>[
      '/storage/',
      '/sdcard/',
      '/data/',
      '/var/',
      '/private/var/',
      '/tmp/',
      '/home/',
      '/Users/',
      '/mnt/',
      '/proc/',
      '/system/',
    ];
    for (final prefix in localPrefixes) {
      if (source.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }

  static bool _looksLikeApiEndpointValue(String source) {
    final text = source.trim();
    if (text.isEmpty) return false;

    String path;
    if (text.startsWith('/')) {
      path = text;
    } else {
      final uri = Uri.tryParse(text);
      if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
        return false;
      }
      path = uri.path;
    }

    final normalizedPath = path.trim().toLowerCase().replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    if (normalizedPath.isEmpty) return false;
    if (_looksLikeImagePath(normalizedPath)) return false;
    if (normalizedPath.endsWith('/me/avatar')) return true;

    for (final prefix in const <String>[
      '/postcard/',
      '/discussion/',
      '/map/',
      '/oss/',
      '/me/',
      '/auth/',
      '/comment/',
      '/favorite/',
    ]) {
      if (normalizedPath.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }

  static bool _looksLikeImagePath(String path) {
    return RegExp(
      r'\.(jpg|jpeg|png|webp|gif|bmp|svg|avif)(\?.*)?$',
      caseSensitive: false,
    ).hasMatch(path);
  }

  static String _normalizeLocalUploadPath(String source) {
    final text = source.trim();
    if (!text.startsWith('file://')) return text;
    final uri = Uri.tryParse(text);
    if (uri == null || uri.scheme != 'file') return text;
    return uri.toFilePath();
  }

  String? _normalizeCityCode(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    if (digits.length == 2) return '${digits}0000';
    if (digits.length == 4) return '${digits}00';
    return digits;
  }

  String? _readFileExtension(String path) {
    final filename = path.split(Platform.pathSeparator).last.trim();
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == filename.length - 1) {
      return null;
    }
    final extension = filename.substring(dotIndex + 1).trim();
    if (extension.isEmpty) return null;
    return extension.toLowerCase();
  }

  String _normalizeEndpointHost(String raw) {
    var endpoint = raw.trim();
    if (endpoint.isEmpty) return '';

    final uri = Uri.tryParse(endpoint);
    if (uri != null &&
        (uri.isScheme('http') || uri.isScheme('https')) &&
        uri.host.trim().isNotEmpty) {
      endpoint = uri.host.trim();
    } else {
      endpoint = endpoint
          .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
          .split('/')
          .first
          .trim();
    }

    return endpoint
        .replaceFirst(RegExp(r'^/+'), '')
        .replaceFirst(RegExp(r'/+$'), '');
  }

  String _firstNonEmpty(Iterable<String?> candidates) {
    for (final candidate in candidates) {
      final text = candidate?.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  Map<String, T> _singleEntryIfNotNull<T>(String key, T? value) {
    if (value == null) return <String, T>{};
    return <String, T>{key: value};
  }

  String? _normalizeExpiration(dynamic raw) {
    if (raw == null) return null;

    if (raw is num) {
      final millis = raw > 1000000000000 ? raw.toInt() : raw.toInt() * 1000;
      return DateTime.fromMillisecondsSinceEpoch(
        millis,
        isUtc: true,
      ).toIso8601String();
    }

    final text = raw.toString().trim();
    if (text.isEmpty) return null;

    final directParsed = DateTime.tryParse(text);
    if (directParsed != null) {
      return directParsed.toUtc().toIso8601String();
    }

    final numberValue = int.tryParse(text);
    if (numberValue != null) {
      final millis = numberValue > 1000000000000
          ? numberValue
          : numberValue * 1000;
      return DateTime.fromMillisecondsSinceEpoch(
        millis,
        isUtc: true,
      ).toIso8601String();
    }

    return null;
  }

  dynamic _readDeepValue(dynamic raw, List<String> keys) {
    final normalizedKeys = keys
        .map((item) => item.toLowerCase())
        .toList(growable: false);

    dynamic visit(dynamic node) {
      if (node == null) return null;

      final map = BackendApiClient.asMap(node);
      if (map != null) {
        for (final key in normalizedKeys) {
          for (final entry in map.entries) {
            if (entry.key.toLowerCase() == key) {
              return entry.value;
            }
          }
        }
        for (final value in map.values) {
          final candidate = visit(value);
          if (candidate != null) return candidate;
        }
      }

      if (node is List) {
        for (final value in node) {
          final candidate = visit(value);
          if (candidate != null) return candidate;
        }
      }

      return null;
    }

    return visit(raw);
  }

  String? _readDeepString(dynamic raw, List<String> keys) {
    final value = _readDeepValue(raw, keys);
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }

  int? _readDeepInt(dynamic raw, List<String> keys) {
    final value = _readDeepValue(raw, keys);
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  Future<EditedPostcard?> _mapTopLikedRecordToEditedPostcard(
    Map<String, dynamic> record, {
    required int fallbackIndex,
  }) async {
    final imageSource = _resolveTopLikedImageSource(record);
    if (imageSource.isEmpty) return null;
    final normalizedImageSource = await _normalizeStoredImageSource(
      imageSource,
    );
    if (normalizedImageSource.trim().isEmpty) return null;

    final createdAtText =
        BackendApiClient.readString(record, const [
          'createdAt',
          'createTime',
          'updatedAt',
          'updateTime',
          'editedAt',
        ]) ??
        '';
    final createdAt = _parseLooseDateTime(createdAtText);
    final remoteId =
        BackendApiClient.readString(record, const [
          'id',
          'postcardId',
          'cardId',
          'postId',
        ]) ??
        '';
    final draftId = remoteId.isEmpty
        ? 'top_liked_${fallbackIndex}_${createdAt.microsecondsSinceEpoch}'
        : 'top_liked_$remoteId';

    final locationText =
        BackendApiClient.readString(record, const [
          'address',
          'location',
          'detailAddress',
          'addressDetail',
        ]) ??
        '';
    final layers = _extractTopLikedLayers(record, fallbackIndex: fallbackIndex);

    return EditedPostcard(
      draftId: draftId,
      imageUrl: normalizedImageSource,
      editedAt: createdAt,
      isPublished: true,
      isDraft: false,
      latitude: BackendApiClient.readDouble(record, const ['latitude', 'lat']),
      longitude: BackendApiClient.readDouble(record, const [
        'longitude',
        'lng',
        'lon',
      ]),
      cityName: _toNullableTrimmedString(
        BackendApiClient.readString(record, const ['cityName', 'city']),
      ),
      cityCode: _toNullableCodeString(
        BackendApiClient.readString(record, const ['cityCode', 'city_code']),
      ),
      provinceName: _toNullableTrimmedString(
        BackendApiClient.readString(record, const ['provinceName', 'province']),
      ),
      locationDetail: _toNullableTrimmedString(locationText),
      layers: layers,
    );
  }

  String _resolveTopLikedImageSource(Map<String, dynamic> record) {
    final directUrl =
        _readDeepString(record, const [
          'imageUrl',
          'image',
          'url',
          'coverUrl',
          'postcardUrl',
          'postcardImageUrl',
          'postcardImage',
        ]) ??
        '';
    final normalizedDirectUrl = directUrl.trim();
    if (normalizedDirectUrl.isNotEmpty &&
        !_looksLikeApiEndpointValue(normalizedDirectUrl)) {
      return normalizedDirectUrl;
    }

    final keySource =
        _readDeepString(record, const [
          'imageKey',
          'key',
          'objectKey',
          'fileKey',
          'coverKey',
          'path',
        ]) ??
        '';
    final normalizedKey = keySource.trim();
    if (normalizedKey.isNotEmpty &&
        !_looksLikeApiEndpointValue(normalizedKey)) {
      return normalizedKey;
    }
    return '';
  }

  static const List<String> _topLikedLayerPayloadKeys = <String>[
    'elements',
    'layers',
    'elementList',
    'layerList',
    'elementVOList',
    'layerVOList',
    'postcardElements',
    'postcardElementList',
    'postcardElementVOList',
    'elementsJson',
    'layersJson',
    'postcardElementsJson',
    'postcardElementJson',
    'elementJson',
    'layerJson',
    'elementsData',
    'layersData',
  ];

  static const List<String> _topLikedLayerContainerKeys = <String>[
    'data',
    'postcard',
    'postcardInfo',
    'postcardDetail',
    'postcardDto',
    'postcardVO',
    'postcardVo',
    'detail',
    'card',
    'record',
    'item',
  ];

  List<PostcardElementLayer> _extractTopLikedLayers(
    Map<String, dynamic> record, {
    required int fallbackIndex,
  }) {
    final layers = <PostcardElementLayer>[];
    final fingerprints = <String>{};

    void append(List<PostcardElementLayer> incoming) {
      _appendUniqueTopLikedLayers(layers, fingerprints, incoming);
    }

    append(
      _parseTopLikedLayersRaw(record, fallbackPrefix: 'top_$fallbackIndex'),
    );

    for (final key in _topLikedLayerPayloadKeys) {
      append(
        _parseTopLikedLayersRaw(
          record[key],
          fallbackPrefix: 'top_$fallbackIndex',
        ),
      );
    }

    for (final key in _topLikedLayerContainerKeys) {
      append(
        _parseTopLikedLayersRaw(
          record[key],
          fallbackPrefix: 'top_$fallbackIndex',
        ),
      );
      append(
        _parseTopLikedLayersRaw(
          _decodeJsonIfStringDeep(record[key]),
          fallbackPrefix: 'top_$fallbackIndex',
        ),
      );
    }

    for (final entry in record.entries) {
      final key = entry.key.trim().toLowerCase();
      if (!(key.contains('element') || key.contains('layer'))) {
        continue;
      }
      append(
        _parseTopLikedLayersRaw(
          entry.value,
          fallbackPrefix: 'top_$fallbackIndex',
        ),
      );
    }

    return layers;
  }

  List<PostcardElementLayer> _parseTopLikedLayersRaw(
    dynamic raw, {
    required String fallbackPrefix,
    int depth = 0,
  }) {
    if (raw == null || depth > 4) return const <PostcardElementLayer>[];

    final decoded = _decodeJsonIfStringDeep(raw);
    if (decoded is String && decoded.trim().isEmpty) {
      return const <PostcardElementLayer>[];
    }

    final sourceMap = BackendApiClient.asMap(decoded);
    if (sourceMap != null) {
      final layers = <PostcardElementLayer>[];
      final fingerprints = <String>{};

      void append(List<PostcardElementLayer> incoming) {
        _appendUniqueTopLikedLayers(layers, fingerprints, incoming);
      }

      for (final key in _topLikedLayerPayloadKeys) {
        append(
          _parseTopLikedLayersRaw(
            sourceMap[key],
            fallbackPrefix: fallbackPrefix,
            depth: depth + 1,
          ),
        );
      }

      for (final key in _topLikedLayerContainerKeys) {
        append(
          _parseTopLikedLayersRaw(
            sourceMap[key],
            fallbackPrefix: fallbackPrefix,
            depth: depth + 1,
          ),
        );
      }

      for (final entry in sourceMap.entries) {
        final key = entry.key.trim().toLowerCase();
        if (!(key.contains('element') || key.contains('layer'))) {
          continue;
        }
        append(
          _parseTopLikedLayersRaw(
            entry.value,
            fallbackPrefix: fallbackPrefix,
            depth: depth + 1,
          ),
        );
      }

      if (layers.isNotEmpty) {
        return layers;
      }
      if (!_looksLikeLayerMap(sourceMap)) {
        return const <PostcardElementLayer>[];
      }

      final layer = PostcardElementLayer.fromJson(
        sourceMap,
        fallbackId: '${fallbackPrefix}_layer',
      );
      if (!_isRenderableTopLikedLayer(layer)) {
        return const <PostcardElementLayer>[];
      }
      return <PostcardElementLayer>[layer];
    }

    if (decoded is! List) return const <PostcardElementLayer>[];

    final layers = <PostcardElementLayer>[];
    final fingerprints = <String>{};
    for (var i = 0; i < decoded.length; i++) {
      final item = _decodeJsonIfStringDeep(decoded[i]);
      final map = BackendApiClient.asMap(item);
      if (map == null) continue;

      if (!_looksLikeLayerMap(map)) {
        _appendUniqueTopLikedLayers(
          layers,
          fingerprints,
          _parseTopLikedLayersRaw(
            map,
            fallbackPrefix: '${fallbackPrefix}_nested_$i',
            depth: depth + 1,
          ),
        );
        continue;
      }

      final layer = PostcardElementLayer.fromJson(
        map,
        fallbackId: '${fallbackPrefix}_layer_$i',
      );
      if (_isRenderableTopLikedLayer(layer)) {
        _appendUniqueTopLikedLayers(
          layers,
          fingerprints,
          <PostcardElementLayer>[layer],
        );
      }
    }
    return layers;
  }

  void _appendUniqueTopLikedLayers(
    List<PostcardElementLayer> target,
    Set<String> fingerprints,
    Iterable<PostcardElementLayer> incoming,
  ) {
    for (final layer in incoming) {
      final fingerprint = _topLikedLayerFingerprint(layer);
      if (!fingerprints.add(fingerprint)) {
        continue;
      }
      target.add(layer);
    }
  }

  String _topLikedLayerFingerprint(PostcardElementLayer layer) {
    return [
      layer.id,
      layer.normalizedType,
      layer.elementKey.trim(),
      layer.assetPath.trim(),
      layer.text?.trim() ?? '',
      layer.x.toString(),
      layer.y.toString(),
      layer.zIndex.toString(),
    ].join('|');
  }

  bool _isRenderableTopLikedLayer(PostcardElementLayer layer) {
    if (layer.isText) {
      return layer.normalizedText.trim().isNotEmpty;
    }
    return layer.assetPath.trim().isNotEmpty ||
        layer.elementKey.trim().isNotEmpty;
  }

  dynamic _decodeJsonIfString(dynamic raw) {
    if (raw is! String) return raw;
    final text = raw.trim();
    if (text.isEmpty) return raw;
    if (!(text.startsWith('{') || text.startsWith('['))) {
      return raw;
    }
    try {
      return jsonDecode(text);
    } catch (_) {
      if (text.contains(r'\"')) {
        final unescaped = text.replaceAll(r'\"', '"').replaceAll(r'\\/', '/');
        try {
          return jsonDecode(unescaped);
        } catch (_) {}
      }
      return raw;
    }
  }

  dynamic _decodeJsonIfStringDeep(dynamic raw) {
    dynamic current = raw;
    for (var i = 0; i < 3; i++) {
      final decoded = _decodeJsonIfString(current);
      if (decoded == current) {
        break;
      }
      current = decoded;
    }
    return current;
  }

  DateTime _parseLooseDateTime(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return DateTime.now();

    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;

    final normalized = text.replaceFirst(' ', 'T');
    final parsedNormalized = DateTime.tryParse(normalized);
    if (parsedNormalized != null) return parsedNormalized;

    return DateTime.now();
  }

  bool _looksLikeLayerMap(Map<String, dynamic> map) {
    bool hasAny(Iterable<String> keys) {
      for (final key in keys) {
        if (map.containsKey(key)) {
          return true;
        }
      }
      return false;
    }

    final hasAssetIdentity = hasAny(const <String>[
      'assetPath',
      'asset_path',
      'assetUrl',
      'asset_url',
      'elementPath',
      'element_path',
      'resourcePath',
      'resource_path',
      'materialPath',
      'material_path',
      'elementKey',
      'element_key',
      'elementCode',
      'element_code',
      'elementName',
      'materialKey',
      'material_key',
      'materialCode',
      'material_code',
    ]);
    if (hasAssetIdentity) {
      return true;
    }

    final hasLayerType = hasAny(const <String>[
      'type',
      'layerType',
      'layer_type',
      'elementType',
      'element_type',
    ]);

    final hasTransform = hasAny(const <String>[
      'x',
      'y',
      'left',
      'top',
      'positionX',
      'position_x',
      'positionY',
      'position_y',
      'scale',
      'rotation2d',
      'rotation_2d',
      'rotation',
      'angle',
      'zIndex',
      'z_index',
      'z',
      'is3dEnabled',
      'is_3d_enabled',
      'rotateX',
      'rotate_x',
      'rotateY',
      'rotate_y',
    ]);

    final hasTextIdentity = hasAny(const <String>[
      'text',
      'textContent',
      'text_content',
      'style',
      'box',
    ]);
    if (hasTextIdentity && (hasTransform || hasLayerType)) {
      return true;
    }

    if (hasLayerType && hasTransform) {
      return true;
    }

    return false;
  }

  Future<bool> deleteEditedPostcardAt(int index) async {
    final postcards = await getEditedPostcards();
    if (index < 0 || index >= postcards.length) {
      return false;
    }
    return (await deleteEditedPostcardsByIds([postcards[index].draftId])) > 0;
  }

  Future<bool> deleteEditedPostcardById(String draftId) async {
    final normalizedId = draftId.trim();
    if (normalizedId.isEmpty) return false;
    return (await deleteEditedPostcardsByIds([normalizedId])) > 0;
  }

  Future<int> deleteEditedPostcardsByIds(Iterable<String> draftIds) async {
    final normalizedIds = draftIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    if (normalizedIds.isEmpty) return 0;

    final postcards = await getEditedPostcards();
    final matchedPostcards = postcards
        .where((item) => normalizedIds.contains(item.draftId.trim()))
        .toList(growable: false);
    if (matchedPostcards.isEmpty) {
      return 0;
    }

    for (final postcard in matchedPostcards) {
      if (postcard.isPublished && postcard.draftId.trim().isNotEmpty) {
        await _deleteRemotePostcard(postcard.draftId);
      }
    }

    final nextPostcards = postcards
        .where((item) => !normalizedIds.contains(item.draftId.trim()))
        .toList(growable: false);
    await _savePostcards(nextPostcards);
    return matchedPostcards.length;
  }

  Future<void> _deleteRemotePostcard(String postcardId) async {
    final normalizedId = postcardId.trim();
    if (normalizedId.isEmpty) {
      throw const BackendApiException('明信片ID不能为空。');
    }

    await _apiClient.delete('/postcard/$normalizedId', requireAuth: true);
  }

  Future<bool> markPostcardPublished(String draftId) async {
    final normalizedId = draftId.trim();
    if (normalizedId.isEmpty) return false;

    final postcards = await getEditedPostcards();
    final index = postcards.indexWhere((item) => item.draftId == normalizedId);
    if (index < 0) return false;

    final target = postcards[index];
    if (target.isPublished) return true;

    postcards[index] = EditedPostcard(
      draftId: target.draftId,
      imageUrl: target.imageUrl,
      editedAt: target.editedAt,
      isPublished: true,
      isDraft: false,
      latitude: target.latitude,
      longitude: target.longitude,
      cityName: target.cityName,
      cityCode: target.cityCode,
      provinceName: target.provinceName,
      locationDetail: target.locationDetail,
      layers: target.layers,
    );

    await _savePostcards(postcards);
    return true;
  }

  String _createDraftId() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    return 'draft_$micros';
  }

  Future<void> _savePostcards(List<EditedPostcard> postcards) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(postcards.map((item) => item.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}

class _PostcardSyncResult {
  const _PostcardSyncResult({required this.imageUrl, this.remotePostcardId});

  final String imageUrl;
  final String? remotePostcardId;
}

class _UploadedPostcardImage {
  const _UploadedPostcardImage({required this.imageUrl, this.objectKey});

  final String imageUrl;
  final String? objectKey;
}

class _CreateAttempt {
  const _CreateAttempt({required this.name, required this.body});

  final String name;
  final Map<String, dynamic> body;
}

class _OssUploadContext {
  const _OssUploadContext({required this.endpoint, required this.bucketName});

  final String endpoint;
  final String bucketName;
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString());
}

String? _toNullableTrimmedString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  return text;
}

String? _toNullableCodeString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return digits;
}

String _toDraftId({
  required dynamic raw,
  required DateTime editedAt,
  required String imageUrl,
}) {
  final text = raw?.toString().trim() ?? '';
  if (text.isNotEmpty) return text;

  final safeUrl = imageUrl.trim().isEmpty ? '空值' : imageUrl.trim();
  return 'legacy_${editedAt.microsecondsSinceEpoch}_$safeUrl';
}

bool? _toBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase() ?? '';
  if (text.isEmpty) return null;
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return null;
}

List<PostcardElementLayer> _toElementLayers(dynamic value) {
  if (value is! List) return const [];

  final layers = <PostcardElementLayer>[];
  for (var i = 0; i < value.length; i++) {
    final item = value[i];
    if (item is Map<String, dynamic>) {
      layers.add(
        PostcardElementLayer.fromJson(item, fallbackId: 'legacy_layer_$i'),
      );
      continue;
    }
    if (item is Map) {
      layers.add(
        PostcardElementLayer.fromJson(
          item.cast<String, dynamic>(),
          fallbackId: 'legacy_layer_$i',
        ),
      );
    }
  }
  return layers;
}
