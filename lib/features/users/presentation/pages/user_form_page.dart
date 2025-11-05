import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/features/users/domain/models/user_model.dart';
import 'package:codequest/features/users/presentation/bloc/users_bloc.dart';

class UserFormPage extends StatefulWidget {
  final UserModel? user;

  const UserFormPage({super.key, this.user});

  @override
  State<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends State<UserFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _profileImageController;
  late UserRole _selectedRole;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.user?.email);
    _fullNameController = TextEditingController(text: widget.user?.fullName);
    _profileImageController =
        TextEditingController(text: widget.user?.profileImage);
    _selectedRole = widget.user?.role ?? UserRole.student;
    _isActive = widget.user?.isActive ?? true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameController.dispose();
    _profileImageController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final user = UserModel(
        id: widget.user?.id ?? '',
        email: _emailController.text,
        fullName: _fullNameController.text,
        role: _selectedRole,
        profileImage: _profileImageController.text.isEmpty
            ? null
            : _profileImageController.text,
        isActive: _isActive,
        enrolledCourses: widget.user?.enrolledCourses ?? [],
        preferences: widget.user?.preferences ?? {},
        createdAt: widget.user?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.user == null) {
        context.read<UsersBloc>().add(CreateUser(user));
      } else {
        context.read<UsersBloc>().add(UpdateUser(user));
      }

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              widget.user == null
                                  ? Icons.person_add
                                  : Icons.edit,
                              color: Colors.green[600],
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.user == null
                                      ? 'Add New Teacher'
                                      : 'Edit Teacher',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  widget.user == null
                                      ? 'Create a new teacher account'
                                      : 'Update teacher information and settings',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Profile Image Section
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.green[300]!, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.green[50],
                                backgroundImage: widget.user?.profileImage !=
                                        null
                                    ? NetworkImage(widget.user!.profileImage!)
                                    : null,
                                child: widget.user?.profileImage == null
                                    ? Icon(Icons.person,
                                        size: 60, color: Colors.green[600])
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Profile Picture',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // User Details
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        child: TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            hintText: 'Enter teacher email address',
                            prefixIcon:
                                Icon(Icons.email, color: Colors.green[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Colors.green[600]!, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        child: TextFormField(
                          controller: _fullNameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            hintText: 'Enter teacher full name',
                            prefixIcon:
                                Icon(Icons.person, color: Colors.green[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Colors.green[600]!, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a full name';
                            }
                            return null;
                          },
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        child: TextFormField(
                          controller: _profileImageController,
                          decoration: InputDecoration(
                            labelText: 'Profile Image URL',
                            hintText: 'Enter profile image URL (optional)',
                            prefixIcon:
                                Icon(Icons.image, color: Colors.green[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Colors.green[600]!, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                          ),
                        ),
                      ),
                      // Role Selection
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        child: DropdownButtonFormField<UserRole>(
                          value: _selectedRole,
                          decoration: InputDecoration(
                            labelText: 'User Role',
                            hintText: 'Select user role',
                            prefixIcon: Icon(Icons.admin_panel_settings,
                                color: Colors.green[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Colors.green[600]!, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                          ),
                          items: UserRole.values.map((UserRole role) {
                            return DropdownMenuItem<UserRole>(
                              value: role,
                              child: Row(
                                children: [
                                  Icon(
                                    _getRoleIcon(role),
                                    color: _getRoleColor(role),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _getRoleDisplayName(role),
                                    style: TextStyle(
                                      color: _getRoleColor(role),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (UserRole? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedRole = newValue;
                              });
                            }
                          },
                        ),
                      ),
                      // Active Status
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isActive ? Icons.check_circle : Icons.cancel,
                              color: _isActive
                                  ? Colors.green[600]
                                  : Colors.red[600],
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Account Status',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    _isActive
                                        ? 'Active - Teacher can access the platform'
                                        : 'Inactive - Teacher access is restricted',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isActive,
                              onChanged: (bool value) {
                                setState(() {
                                  _isActive = value;
                                });
                              },
                              activeColor: Colors.green[600],
                              activeTrackColor: Colors.green[200],
                            ),
                          ],
                        ),
                      ),
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _submitForm,
                          icon: Icon(widget.user == null
                              ? Icons.person_add
                              : Icons.save),
                          label: Text(
                            widget.user == null
                                ? 'Create Teacher'
                                : 'Update Teacher',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.teacher:
        return Icons.school;
      case UserRole.student:
        return Icons.person;
      default:
        return Icons.person;
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red[600]!;
      case UserRole.teacher:
        return Colors.green[600]!;
      case UserRole.student:
        return Colors.blue[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.student:
        return 'Student';
      default:
        return role.toString().split('.').last;
    }
  }
}
