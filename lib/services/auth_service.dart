import '../models/user_model.dart';
import 'api_client.dart';

class AuthResult {
  final bool success;
  final UserModel? user;
  final String? message;

  AuthResult({required this.success, this.user, this.message});
}

class AuthService {
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await ApiClient.post('login.php', {
      'email': email.trim().toLowerCase(),
      'password': password,
    });

    if (response['success'] == true && response['user'] != null) {
      return AuthResult(
        success: true,
        user: UserModel.fromJson(response['user']),
      );
    }

    return AuthResult(
      success: false,
      message: response['message'] ?? 'Login failed',
    );
  }
}