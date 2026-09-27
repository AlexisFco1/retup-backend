class SocialPost {
  final String id;
  final String userId;
  final String? companyId;
  final String contentType; // 'text', 'image', 'audio', 'poll', 'streak_winner'
  final String? textContent;
  final String? mediaUrl;
  final bool isSystemPost;
  final String createdAt;
  final String? updatedAt;
  // Datos del usuario (vienen del JOIN)
  final String? userName;
  final String? userFirstName;
  // Encuesta
  final List<PollOption>? pollOptions;
  // Likes
  final int likeCount;
  final bool likedByMe;
  // 🆕 Nuevos campos
  final int commentsCount;
  final int viewsCount;
  final bool isPinned;
  final bool isOwnPost;

  SocialPost({
    required this.id,
    required this.userId,
    this.companyId,
    required this.contentType,
    this.textContent,
    this.mediaUrl,
    this.isSystemPost = false,
    required this.createdAt,
    this.updatedAt,
    this.userName,
    this.userFirstName,
    this.pollOptions,
    this.likeCount = 0,
    this.likedByMe = false,
    this.commentsCount = 0,
    this.viewsCount = 0,
    this.isPinned = false,
    this.isOwnPost = false,
  });

  factory SocialPost.fromJson(Map<String, dynamic> json) {
    List<PollOption>? options;
    if (json['poll_options'] != null) {
      options = (json['poll_options'] as List)
          .map((o) => PollOption.fromJson(o))
          .toList();
    }

    return SocialPost(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      companyId: json['company_id'],
      contentType: json['content_type'] ?? 'text',
      textContent: json['text_content'],
      mediaUrl: json['media_url'],
      isSystemPost: json['is_system_post'] ?? false,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'],
      userName: (json['user_name'] != null &&
              json['user_name'].toString().trim().isNotEmpty)
          ? json['user_name']
          : (json['user_full_name'] ?? json['full_name']),
      userFirstName: json['user_first_name'],
      pollOptions: options,
      likeCount: json['like_count'] ?? json['likes_count'] ?? 0,
      likedByMe: json['liked_by_me'] ?? json['liked_by_user'] ?? false,
      commentsCount: json['comments_count'] ?? 0,
      viewsCount: json['views_count'] ?? 0,
      isPinned: json['is_pinned'] ?? false,
      isOwnPost: json['is_own_post'] ?? false,
    );
  }
}

class PollOption {
  final String id;
  final String postId;
  final String optionText;
  final int voteCount;
  final bool votedByMe;

  PollOption({
    required this.id,
    required this.postId,
    required this.optionText,
    this.voteCount = 0,
    this.votedByMe = false,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id'] ?? '',
      postId: json['post_id'] ?? '',
      optionText: json['option_text'] ?? '',
      voteCount: json['vote_count'] ?? 0,
      votedByMe: json['voted_by_me'] ?? false,
    );
  }
}

// 🆕 Modelo para comentarios
class SocialComment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String commentText;
  final String createdAt;

  SocialComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.commentText,
    required this.createdAt,
  });

  factory SocialComment.fromJson(Map<String, dynamic> json) {
    return SocialComment(
      id: json['id'] ?? '',
      postId: json['post_id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? 'Usuario',
      commentText: json['comment_text'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}
