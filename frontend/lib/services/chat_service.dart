import '../core/api_config.dart';
import '../core/api_service.dart';
import 'auth_service.dart';

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String content;
  final String createdAt;
  final String? readAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
    this.readAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] ?? '').toString(),
      conversationId: (json['conversation_id'] ?? '').toString(),
      senderId: (json['sender_id'] ?? '').toString(),
      receiverId: (json['receiver_id'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      readAt: json['read_at']?.toString(),
    );
  }
}

class ConversationPreview {
  final String conversationId;
  final String partnerId;
  final String partnerName;
  final String? partnerAvatarUrl;
  final String? lastMessage;
  final String? lastMessageAt;
  final int unreadCount;

  ConversationPreview({
    required this.conversationId,
    required this.partnerId,
    required this.partnerName,
    this.partnerAvatarUrl,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory ConversationPreview.fromJson(Map<String, dynamic> json) {
    return ConversationPreview(
      conversationId: (json['conversation_id'] ?? '').toString(),
      partnerId: (json['partner_id'] ?? '').toString(),
      partnerName: (json['partner_name'] ?? 'TripBond User').toString(),
      partnerAvatarUrl: json['partner_avatar_url']?.toString(),
      lastMessage: json['last_message']?.toString(),
      lastMessageAt: json['last_message_at']?.toString(),
      unreadCount: json['unread_count'] is int
          ? json['unread_count'] as int
          : int.tryParse('${json['unread_count'] ?? 0}') ?? 0,
    );
  }
}

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final _apiService = ApiService();
  final _authService = AuthService();

  Future<String> _requireToken() async {
    final token = await _authService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }
    return token;
  }

  Future<List<ConversationPreview>> getConversationPreviews() async {
    final token = await _requireToken();
    final response = await _apiService.get(
      '${ApiConfig.chatPath}/conversations',
      token: token,
    );

    if (response is! List) {
      throw Exception('Invalid response format for conversations');
    }

    return response
        .whereType<Map<String, dynamic>>()
        .map(ConversationPreview.fromJson)
        .toList();
  }

  Future<List<ChatMessage>> getMessagesWithUser(
    String otherUserId, {
    int limit = 100,
  }) async {
    final token = await _requireToken();
    final response = await _apiService.get(
      '${ApiConfig.chatPath}/messages/$otherUserId',
      queryParams: {'limit': '$limit'},
      token: token,
    );

    if (response is! List) {
      throw Exception('Invalid response format for messages');
    }

    return response
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
  }

  Future<ChatMessage> sendMessage({
    required String otherUserId,
    required String content,
  }) async {
    final token = await _requireToken();
    final response = await _apiService.post(
      '${ApiConfig.chatPath}/messages/$otherUserId',
      {'content': content},
      token: token,
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('Invalid response format for sent message');
    }

    return ChatMessage.fromJson(response);
  }

  Future<int> markMessagesAsRead(String otherUserId) async {
    final token = await _requireToken();
    final response = await _apiService.post(
      '${ApiConfig.chatPath}/messages/$otherUserId/read',
      {},
      token: token,
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('Invalid response format for mark read');
    }

    if (response['marked_count'] is int) {
      return response['marked_count'] as int;
    }

    return int.tryParse('${response['marked_count'] ?? 0}') ?? 0;
  }
}
