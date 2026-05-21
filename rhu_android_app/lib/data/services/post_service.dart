import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';
import '../models/post_model.dart';

class PostService {
  PostService({
    ApiClient? apiClient,
    TokenStorageService? tokenStorageService,
  }) : _apiClient = apiClient ??
            ApiClient(
              tokenProvider:
                  (tokenStorageService ?? TokenStorageService()).getToken,
            );

  final ApiClient _apiClient;

  Future<List<PostModel>> getPublicPosts({
    String? type,
    String? rhuId,
    String? barangayId,
    int page = 1,
    int limit = 50,
  }) async {
    final Map<String, dynamic> response = await _apiClient.get(
      ApiConstants.publicPosts,
      requiresAuth: false,
      queryParameters: <String, dynamic>{
        'type': type,
        'rhu': rhuId,
        'barangay': barangayId,
        'page': page,
        'limit': limit,
      },
    );

    final dynamic data = response['data'];

    if (data is! List) {
      return <PostModel>[];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(PostModel.fromJson)
        .toList();
  }

  Future<List<PostModel>> getStaffPosts({
    String? type,
    String? status,
    String? rhuId,
    String? barangayId,
    int page = 1,
    int limit = 50,
  }) async {
    final Map<String, dynamic> response = await _apiClient.get(
      ApiConstants.posts,
      requiresAuth: true,
      queryParameters: <String, dynamic>{
        'type': type,
        'status': status,
        'rhu': rhuId,
        'barangay': barangayId,
        'page': page,
        'limit': limit,
      },
    );

    final dynamic data = response['data'];

    if (data is! List) {
      return <PostModel>[];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(PostModel.fromJson)
        .toList();
  }

  Future<PostModel> createPost({
    required String title,
    required String content,
    required String type,
    required String status,
    required String audienceScope,
    String? rhuId,
    String? barangayId,
    List<String> tags = const <String>[],
    bool isPinned = false,
  }) async {
    if (title.trim().isEmpty) {
      throw const ApiException(
        message: 'Post title is required.',
        statusCode: 400,
      );
    }

    if (content.trim().isEmpty) {
      throw const ApiException(
        message: 'Post content is required.',
        statusCode: 400,
      );
    }

    final Map<String, dynamic> body = <String, dynamic>{
      'title': title.trim(),
      'content': content.trim(),
      'type': type.trim(),
      'status': status.trim(),
      'audienceScope': audienceScope.trim(),
      'tags': tags,
      'isPinned': isPinned,
    };

    if (rhuId != null && rhuId.trim().isNotEmpty) {
      body['rhu'] = rhuId.trim();
    }

    if (barangayId != null && barangayId.trim().isNotEmpty) {
      body['barangay'] = barangayId.trim();
    }

    final Map<String, dynamic> response = await _apiClient.post(
      ApiConstants.posts,
      requiresAuth: true,
      body: body,
    );

    final dynamic data = response['data'];

    if (data is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'Invalid post response from server.',
      );
    }

    return PostModel.fromJson(data);
  }

  Future<void> deletePost(String postId) async {
    if (postId.trim().isEmpty) {
      throw const ApiException(
        message: 'Post ID is required.',
        statusCode: 400,
      );
    }

    await _apiClient.delete(
      '${ApiConstants.posts}/$postId',
      requiresAuth: true,
    );
  }

  Future<PostModel> updatePost({
    required String postId,
    required String title,
    required String content,
    required String type,
    required String status,
    required String audienceScope,
    List<String> tags = const <String>[],
    bool isPinned = false,
  }) async {
    if (postId.trim().isEmpty) {
      throw const ApiException(
        message: 'Post ID is required.',
        statusCode: 400,
      );
    }

    if (title.trim().isEmpty) {
      throw const ApiException(
        message: 'Post title is required.',
        statusCode: 400,
      );
    }

    if (content.trim().isEmpty) {
      throw const ApiException(
        message: 'Post content is required.',
        statusCode: 400,
      );
    }

    final Map<String, dynamic> body = <String, dynamic>{
      'title': title.trim(),
      'content': content.trim(),
      'type': type.trim(),
      'status': status.trim(),
      'audienceScope': audienceScope.trim(),
      'tags': tags,
      'isPinned': isPinned,
    };

    final Map<String, dynamic> response = await _apiClient.patch(
      '${ApiConstants.posts}/$postId',
      requiresAuth: true,
      body: body,
    );

    final dynamic data = response['data'] ?? response['post'];

    if (data is Map<String, dynamic>) {
      return PostModel.fromJson(data);
    }

    if (response.containsKey('_id') || response.containsKey('id')) {
      return PostModel.fromJson(response);
    }

    throw const ApiException(
      message: 'Invalid post response from server.',
    );
  }
}