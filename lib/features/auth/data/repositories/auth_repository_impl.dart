import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codequest/features/auth/domain/models/user_model.dart';
import 'package:codequest/features/auth/domain/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:codequest/services/teacher_email_validation_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final firebase_auth.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRepositoryImpl({
    firebase_auth.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<UserModel> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      if (user == null) {
        throw Exception('User not found');
      }

      final userData = await _getUserData(user.uid);
      if (userData == null) {
        await signOut();
        throw Exception('User data not found');
      }

      // Update last login time
      await _firestore.collection('users').doc(user.uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // If it's a student, update student document
      if (userData.role == UserRole.student) {
        await _firestore.collection('students').doc(user.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
      }

      return userData;
    } catch (e) {
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> signUpWithEmailAndPassword(
    String email,
    String password,
    String name,
    UserRole role,
  ) async {
    try {
      // Validate teacher email if registering as teacher
      if (role == UserRole.teacher) {
        final validationError =
            await TeacherEmailValidationService.validateTeacherEmail(email);
        if (validationError != null) {
          throw Exception(validationError);
        }
      }

      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      if (user == null) {
        throw Exception('User not found');
      }

      // Create user model with additional fields
      final userModel = UserModel(
        id: user.uid,
        email: email,
        name: name,
        role: role,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save user data to Firestore
      await _firestore.collection('users').doc(user.uid).set({
        ...userModel.toFirestore(),
        'fullName': name,
        'lastLogin': FieldValue.serverTimestamp(),
        'isActive': true,
        'registrationPlatform': kIsWeb ? 'web' : 'mobile',
      });

      // If it's a student, create a student-specific document
      if (role == UserRole.student) {
        await _firestore.collection('students').doc(user.uid).set({
          'userId': user.uid,
          'name': name,
          'fullName': name,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'progress': {
            'completedChallenges': 0,
            'totalPoints': 0,
            'currentLevel': 1,
          },
          'enrolledCourses': [],
          'completedCourses': [],
          'achievements': [],
        });
      }

      // Notify admin of new user registration
      await _firestore.collection('notifications').add({
        'userId': userCredential.user!.uid,
        'type': 'new_user',
        'title': 'New User Registered',
        'message':
            'A new user (${name}, ${email}) has registered as ${role.name}.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      return userModel;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        case 'operation-not-allowed':
          message = 'Email/password accounts are not enabled';
          break;
        case 'weak-password':
          message = 'Password is too weak';
          break;
        default:
          message = 'Failed to sign up: ${e.message}';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Failed to sign up: ${e.toString()}');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: ${e.toString()}');
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return null;
      }
      try {
        return await _getUserData(user.uid);
      } catch (e) {
        // If user document doesn't exist, sign out the user
        await signOut();
        return null;
      }
    } catch (e) {
      throw Exception('Failed to get current user: ${e.toString()}');
    }
  }

  @override
  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _firestore
          .collection('users')
          .doc(user.id)
          .update(user.toFirestore());
    } catch (e) {
      throw Exception('Failed to update user profile: ${e.toString()}');
    }
  }

  @override
  Future<void> updatePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw Exception('User not found');
      }

      final credential = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } catch (e) {
      throw Exception('Failed to update password: ${e.toString()}');
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('Failed to reset password: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw Exception('User not found');
      }

      await _firestore.collection('users').doc(user.uid).delete();
      await user.delete();
    } catch (e) {
      throw Exception('Failed to delete account: ${e.toString()}');
    }
  }

  @override
  Stream<UserModel?> get authStateChanges {
    return _firebaseAuth.authStateChanges().asyncMap((user) async {
      if (user == null) {
        return null;
      }
      try {
        final userData = await _getUserData(user.uid);
        if (userData == null) {
          await signOut();
          return null;
        }
        return userData;
      } catch (e) {
        // If user document doesn't exist, sign out and return null
        await signOut();
        return null;
      }
    });
  }

  Future<UserModel?> _getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        return null;
      }
      return UserModel.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }
}
