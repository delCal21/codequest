import 'package:flutter/material.dart';
import 'package:codequest/features/teacher/presentation/widgets/teacher_notifications_widget.dart';

class TeacherNotificationsPage extends StatelessWidget {
  const TeacherNotificationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const TeacherNotificationsWidget(),
    );
  }
}
