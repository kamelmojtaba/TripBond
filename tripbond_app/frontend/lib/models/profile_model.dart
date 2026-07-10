class UserProfile {
  final String id;
  final String email;
  final String? fullName;
  final String? username;
  final String? bio;
  final String? avatarUrl;
  final int pastTripsCount;
  final int likedPagesCount;
  final int favoritesCount;
  // --- New Fields Added ---
  final int followers;
  final int following;

  UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.username,
    this.bio,
    this.avatarUrl,
    this.pastTripsCount = 0,
    this.likedPagesCount = 0,
    this.favoritesCount = 0,
    this.followers = 0,
    this.following = 0,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return UserProfile(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      fullName: (json['full_name'] ?? json['fullName'] ?? json['name'])
          ?.toString(),
      username: (json['username'] ?? json['user_name'])?.toString(),
      bio: json['bio']?.toString(),
      avatarUrl: (json['avatar_url'] ?? json['avatarUrl'])?.toString(),
      pastTripsCount: toInt(json['past_trips_count'] ?? json['pastTripsCount']),
      likedPagesCount: toInt(
        json['liked_pages_count'] ?? json['likedPagesCount'],
      ),
      favoritesCount: toInt(json['favorites_count'] ?? json['favoritesCount']),
      // --- Mapping New Fields from JSON ---
      followers: toInt(json['followers_count'] ?? json['followers']),
      following: toInt(json['following_count'] ?? json['following']),
    );
  }
}
