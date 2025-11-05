import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/features/users/domain/models/user_model.dart';
import 'package:codequest/features/users/presentation/bloc/users_bloc.dart';
import 'package:codequest/features/users/presentation/pages/user_form_page.dart';

class UserDetailsPage extends StatelessWidget {
  final UserModel user;

  const UserDetailsPage({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Details'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => UserFormPage(user: user),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete User'),
                  content: Text(
                    'Are you sure you want to delete "${user.fullName}"?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        context.read<UsersBloc>().add(DeleteUser(user.id));
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(context); // Return to users list
                      },
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: user.profileImage != null
                        ? NetworkImage(user.profileImage!)
                        : null,
                    child: user.profileImage == null
                        ? Text(
                            user.fullName.isNotEmpty
                                ? user.fullName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(fontSize: 24),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.fullName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Chip(
                  label: Text(user.role.toString().split('.').last),
                  backgroundColor: Colors.blue[100],
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(user.isActive ? 'Active' : 'Inactive'),
                  backgroundColor:
                      user.isActive ? Colors.green[100] : Colors.orange[100],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Account Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Email', user.email),
            _buildInfoRow('Role', user.role.toString().split('.').last),
            _buildInfoRow('Status', user.isActive ? 'Active' : 'Inactive'),
            _buildInfoRow('Created', user.createdAt.toLocal().toString()),
            _buildInfoRow('Last Updated', user.updatedAt.toLocal().toString()),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement user activity view
                },
                icon: const Icon(Icons.history),
                label: const Text('View Activity'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontFamily: 'NotoSans',
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
