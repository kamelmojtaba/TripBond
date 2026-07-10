import '../models.dart';
import 'user_service.dart';

class ProfileService {
  final _userService = UserService();

  Future<UserProfile> fetchProfile() async {
    final response = await _userService.getMyProfile();
    return UserProfile.fromJson(response);
  }
}
