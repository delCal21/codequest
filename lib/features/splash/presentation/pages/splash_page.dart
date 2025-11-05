import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_event.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_state.dart';
import 'package:codequest/config/routes.dart';
import 'package:codequest/features/auth/domain/models/user_model.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    // Trigger auth check
    context.read<AuthBloc>().add(AuthCheckRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          // Route to dashboard based on user role
          if (state.user.role == UserRole.admin) {
            Navigator.pushReplacementNamed(context, AppRouter.adminDashboard);
          } else if (state.user.role == UserRole.teacher) {
            Navigator.pushReplacementNamed(context, AppRouter.teacherDashboard);
          } else if (state.user.role == UserRole.student) {
            Navigator.pushReplacementNamed(context, AppRouter.studentDashboard);
          }
        } else if (state is Unauthenticated) {
          Navigator.pushReplacementNamed(context, AppRouter.login);
        }
      },
      child: const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
