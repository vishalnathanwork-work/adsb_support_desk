import '../config/constants.dart';
import '../models/user_model.dart';

class AuthResult {
  final bool success;
  final UserModel? user;
  final String? message;

  AuthResult({
    required this.success,
    this.user,
    this.message,
  });
}

class AuthService {
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    // Simulate network latency
    await Future.delayed(const Duration(milliseconds: 800));

    final normalizedEmail = email.trim().toLowerCase();
    final expectedPassword = AppConstants.mockPasswords[normalizedEmail];

    if (expectedPassword == null) {
      return AuthResult(
        success: false,
        message: 'No account found with this email',
      );
    }

    if (expectedPassword != password) {
      return AuthResult(
        success: false,
        message: 'Invalid password',
      );
    }

    final user = AppConstants.mockUsers[normalizedEmail];
    return AuthResult(
      success: true,
      user: user,
    );
  }
}
