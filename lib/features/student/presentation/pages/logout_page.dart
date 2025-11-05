import 'package:flutter/material.dart';
import 'package:codequest/features/auth/data/repositories/auth_repository_impl.dart';

class LogoutPage extends StatelessWidget {
  const LogoutPage({Key? key}) : super(key: key);

  void _logout(BuildContext context) async {
    final authRepository = AuthRepositoryImpl();
    await authRepository.signOut();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logout')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              const Text('Are you sure you want to logout?',
                  style: TextStyle(fontSize: 18)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _logout(context),
                child: const Text('Logout'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
