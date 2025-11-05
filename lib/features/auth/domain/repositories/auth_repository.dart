import 'package:codequest/features/auth/domain/models/user_model.dart';

abstract class AuthRepository {
  Future<UserModel> signInWithEmailAndPassword(String email, String password);
  Future<UserModel> signUpWithEmailAndPassword(
    String email,
    String password,
    String name,
    UserRole role,
  );
  Future<void> signOut();
  Future<UserModel?> getCurrentUser();
  Future<void> updateUserProfile(UserModel user);
  Future<void> updatePassword(String currentPassword, String newPassword);
  Future<void> resetPassword(String email);
  Future<void> deleteAccount();
  Stream<UserModel?> get authStateChanges;
}
