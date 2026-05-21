import '../models/post_model.dart';
import '../services/post_service.dart';

class PostRepository {
  PostRepository({
    PostService? postService,
  }) : _postService = postService ?? PostService();

  final PostService _postService;

  Future<List<PostModel>> getPublicPosts({
    String? type,
    String? rhuId,
    String? barangayId,
    int page = 1,
    int limit = 50,
  }) {
    return _postService.getPublicPosts(
      type: type,
      rhuId: rhuId,
      barangayId: barangayId,
      page: page,
      limit: limit,
    );
  }

  Future<List<PostModel>> getStaffPosts({
    String? type,
    String? status,
    String? rhuId,
    String? barangayId,
    int page = 1,
    int limit = 50,
  }) {
    return _postService.getStaffPosts(
      type: type,
      status: status,
      rhuId: rhuId,
      barangayId: barangayId,
      page: page,
      limit: limit,
    );
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
  }) {
    return _postService.createPost(
      title: title,
      content: content,
      type: type,
      status: status,
      audienceScope: audienceScope,
      rhuId: rhuId,
      barangayId: barangayId,
      tags: tags,
      isPinned: isPinned,
    );
  }
  Future<void> deletePost(String postId) {
    return _postService.deletePost(postId);
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
  }) {
    return _postService.updatePost(
      postId: postId,
      title: title,
      content: content,
      type: type,
      status: status,
      audienceScope: audienceScope,
      tags: tags,
      isPinned: isPinned,
    );
  }



}