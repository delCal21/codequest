import 'package:equatable/equatable.dart';
import 'package:codequest/features/auth/domain/models/user_model.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

class SignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String name;
  final UserRole role;

  const SignUpRequested(this.email, this.password, this.name, this.role);

  @override
  List<Object?> get props => [email, password, name, role];
}

class SignOutRequested extends AuthEvent {
  const SignOutRequested();
}

class UpdateProfileRequested extends AuthEvent {
  final String name;

  const UpdateProfileRequested({required this.name});

  @override
  List<Object> get props => [name];
}

class UpdatePasswordRequested extends AuthEvent {
  final String currentPassword;
  final String newPassword;

  const UpdatePasswordRequested(this.currentPassword, this.newPassword);

  @override
  List<Object?> get props => [currentPassword, newPassword];
}

class ResetPasswordRequested extends AuthEvent {
  final String email;

  const ResetPasswordRequested({
    required this.email,
  });

  @override
  List<Object?> get props => [email];
}

class DeleteAccountRequested extends AuthEvent {}
