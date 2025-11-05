import 'package:flutter/material.dart';
import 'package:codequest/features/splash/presentation/pages/splash_page.dart';
import 'package:codequest/features/auth/presentation/pages/login_page.dart';
import 'package:codequest/features/auth/presentation/pages/register_page.dart';
import 'package:codequest/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:codequest/features/admin/presentation/pages/create_admin_page.dart';
import 'package:codequest/features/admin/presentation/pages/first_admin_page.dart';
import 'package:codequest/features/admin/presentation/pages/admin_register_page.dart'
    show TeacherRegisterPage;
import 'package:codequest/features/teacher/presentation/pages/teacher_dashboard_page.dart';
import 'package:codequest/features/auth/presentation/pages/first_admin_register_page.dart';
import 'package:codequest/features/student/presentation/pages/student_dashboard_page.dart';
import 'package:codequest/features/student/presentation/pages/courses_page.dart';
import 'package:codequest/features/admin/presentation/pages/courses_crud_page.dart';
import 'package:codequest/features/teacher/presentation/pages/teacher_notifications_page.dart';
import 'package:codequest/features/auth/presentation/pages/privacy_policy_page.dart';
import 'package:codequest/features/auth/presentation/pages/terms_of_service_page.dart';

class AppRouter {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String firstAdmin = '/register-first-admin';
  static const String createAdmin = '/create-admin';
  static const String adminRegister = '/admin-register';
  static const String adminDashboard = '/admin-dashboard';
  static const String teacherDashboard = '/teacher-dashboard';
  static const String teacherNotifications = '/teacher-notifications';
  static const String firstAdminRegister = '/first-admin-register';
  static const String studentDashboard = '/student-dashboard';
  static const String courses = '/courses';
  static const String coursesCrud = '/courses-crud';
  static const String privacyPolicy = '/privacy-policy';
  static const String termsOfService = '/terms-of-service';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashPage());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());
      case firstAdmin:
        return MaterialPageRoute(builder: (_) => const FirstAdminPage());
      case createAdmin:
        return MaterialPageRoute(builder: (_) => const CreateAdminPage());
      case adminRegister:
        return MaterialPageRoute(builder: (_) => const TeacherRegisterPage());
      case adminDashboard:
        return MaterialPageRoute(builder: (_) => const AdminDashboardPage());
      case teacherDashboard:
        return MaterialPageRoute(builder: (_) => const TeacherDashboardPage());
      case teacherNotifications:
        return MaterialPageRoute(
            builder: (_) => const TeacherNotificationsPage());
      case firstAdminRegister:
        return MaterialPageRoute(
            builder: (_) => const FirstAdminRegisterPage());
      case studentDashboard:
        return MaterialPageRoute(builder: (_) => const StudentDashboardPage());
      case courses:
        return MaterialPageRoute(builder: (_) => const CoursesPage());
      case coursesCrud:
        return MaterialPageRoute(builder: (_) => const CoursesCrudPage());
      case privacyPolicy:
        return MaterialPageRoute(builder: (_) => const PrivacyPolicyPage());
      case termsOfService:
        return MaterialPageRoute(builder: (_) => const TermsOfServicePage());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
