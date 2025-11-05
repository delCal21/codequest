import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/features/auth/domain/repositories/auth_repository.dart';
import 'package:codequest/features/auth/domain/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import 'package:flutter/foundation.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<LoginRequested>(_onLoginRequested);
    on<SignUpRequested>(_onSignUpRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<UpdateProfileRequested>(_onUpdateProfileRequested);
    on<UpdatePasswordRequested>(_onUpdatePasswordRequested);
    on<ResetPasswordRequested>(_onResetPasswordRequested);
    on<DeleteAccountRequested>(_onDeleteAccountRequested);

    // Listen to auth state changes
    _auth.authStateChanges().listen((firebaseUser) async {
      if (firebaseUser != null) {
        // User is logged in, trigger auth check to update state
        add(AuthCheckRequested());
      } else {
        // User is logged out
        add(AuthCheckRequested());
      }
    });

    // Check initial auth state
    add(AuthCheckRequested());
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(AuthLoading());
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        final userDoc =
            await _firestore.collection('users').doc(firebaseUser.uid).get();
        if (userDoc.exists) {
          final userModel =
              UserModel.fromFirestore(userDoc, firebaseUser: firebaseUser);
          emit(Authenticated(userModel));
        } else {
          emit(Unauthenticated());
        }
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(Unauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );

      if (userCredential.user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (!userDoc.exists) {
          emit(const AuthError('User data not found'));
          return;
        }

        final userModel = UserModel.fromFirestore(
          userDoc,
          firebaseUser: userCredential.user,
        );

        // Check if the user is inactive
        if (userDoc.data()?['active'] == false) {
          await _auth.signOut();
          emit(const AuthError(
              'Your account is inactive. Please contact admin.'));
          return;
        }

        // Platform-specific role checks
        if (kIsWeb) {
          // Web platform: Only allow admin and teacher access
          if (userModel.role != UserRole.admin &&
              userModel.role != UserRole.teacher) {
            await _auth.signOut();
            emit(const AuthError(
                'Access denied. Admin/Teacher access only on web platform.'));
            return;
          }
        } else {
          // Mobile platform: Only allow student access
          if (userModel.role != UserRole.student) {
            await _auth.signOut();
            emit(const AuthError(
                'Access denied. Student access only on mobile platform.'));
            return;
          }
        }

        // Update last login time and active status
        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .update({
          'lastLogin': FieldValue.serverTimestamp(),
          'isActive': true,
        });

        emit(Authenticated(userModel));
        print('User authenticated with role: ${userModel.role}');
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found with this email';
          break;
        case 'wrong-password':
          message = 'Wrong password provided';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        case 'user-disabled':
          message = 'This account has been disabled';
          break;
        default:
          message = 'An error occurred. Please try again';
      }
      emit(AuthError(message));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignUpRequested(
    SignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );

      if (userCredential.user != null) {
        final userModel = UserModel(
          id: userCredential.user!.uid,
          name: event.name,
          email: event.email,
          role: event.role,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          firebaseUser: userCredential.user,
        );

        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(userModel.toFirestore());

        emit(Authenticated(userModel));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignOutRequested(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        await _firestore.collection('users').doc(firebaseUser.uid).update({
          'isActive': false,
          'lastLogout': FieldValue.serverTimestamp(),
        });
      }
      await _auth.signOut();
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onUpdateProfileRequested(
    UpdateProfileRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        await firebaseUser.updateDisplayName(event.name);
        await _firestore.collection('users').doc(firebaseUser.uid).update({
          'name': event.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final userDoc =
            await _firestore.collection('users').doc(firebaseUser.uid).get();
        if (userDoc.exists) {
          final userModel =
              UserModel.fromFirestore(userDoc, firebaseUser: firebaseUser);
          emit(Authenticated(userModel));
        } else {
          emit(Unauthenticated());
        }
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onUpdatePasswordRequested(
    UpdatePasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        await firebaseUser.updatePassword(event.newPassword);
        final userDoc =
            await _firestore.collection('users').doc(firebaseUser.uid).get();
        if (userDoc.exists) {
          final userModel =
              UserModel.fromFirestore(userDoc, firebaseUser: firebaseUser);
          emit(Authenticated(userModel));
        } else {
          emit(Unauthenticated());
        }
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onResetPasswordRequested(
    ResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _auth.sendPasswordResetEmail(email: event.email);
      emit(PasswordResetSent());
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found with this email';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        default:
          message = 'An error occurred. Please try again';
      }
      emit(AuthError(message));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onDeleteAccountRequested(
    DeleteAccountRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        await _firestore.collection('users').doc(firebaseUser.uid).delete();
        await firebaseUser.delete();
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
