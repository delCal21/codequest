import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/features/users/presentation/bloc/users_bloc.dart';
import 'package:codequest/features/users/presentation/pages/user_form_page.dart';
import 'package:codequest/features/users/presentation/pages/user_details_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String _searchQuery = '';
  String? _selectedRole;
  String? _selectedStatus;

  // Pagination state
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  int _totalItems = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentMaterialBanner();
      messenger.clearMaterialBanners();
      messenger.clearSnackBars();
    });
  }

  List _filterUsers(List users) {
    return users.where((user) {
      final matchesSearch = _searchQuery.isEmpty ||
          user.fullName.toLowerCase().contains(_searchQuery) ||
          user.email.toLowerCase().contains(_searchQuery);
      final matchesRole = _selectedRole == null ||
          user.role.toString().split('.').last == _selectedRole;
      final matchesStatus = _selectedStatus == null ||
          (_selectedStatus == 'Active' && user.isActive) ||
          (_selectedStatus == 'Inactive' && !user.isActive);
      return matchesSearch && matchesRole && matchesStatus;
    }).toList();
  }

  Future<void> _restoreTeacher(String userId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'deleted': false});
    setState(() {});
  }

  Future<void> _deleteTeacherForever(String userId) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).delete();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Users'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Trash'),
            ],
          ),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const UserFormPage(),
                );
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            BlocBuilder<UsersBloc, UsersState>(
              builder: (context, state) {
                if (state is UsersLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is UsersError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: \u001b[1m${state.message}\u001b[0m',
                            style: TextStyle(fontFamily: 'NotoSans')),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            context.read<UsersBloc>().add(LoadUsers());
                          },
                          child: const Text('Retry',
                              style: TextStyle(fontFamily: 'NotoSans')),
                        ),
                      ],
                    ),
                  );
                }

                if (state is UsersLoaded) {
                  final filteredUsers = _filterUsers(state.users)
                      .where((user) => (user.deleted != true))
                      .toList();

                  // Pagination calculations
                  _totalItems = filteredUsers.length;
                  final startIndex = (_currentPage - 1) * _itemsPerPage;
                  final endIndex = (startIndex + _itemsPerPage) > _totalItems
                      ? _totalItems
                      : (startIndex + _itemsPerPage);
                  final paginatedUsers = startIndex < _totalItems
                      ? filteredUsers.sublist(startIndex, endIndex)
                      : <dynamic>[];

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search...',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    size: 20,
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value.trim().toLowerCase();
                                    _currentPage = 1;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            DropdownButton<String?>(
                              value: _selectedRole,
                              hint: const Text('All Roles'),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('All Roles'),
                                ),
                                ...['admin', 'teacher', 'student'].map(
                                  (role) => DropdownMenuItem<String?>(
                                    value: role,
                                    child: Text(role[0].toUpperCase() +
                                        role.substring(1)),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedRole = value;
                                  _currentPage = 1;
                                });
                              },
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                              ),
                              underline: Container(),
                              borderRadius: BorderRadius.circular(8),
                              dropdownColor: Colors.white,
                            ),
                            const SizedBox(width: 12),
                            DropdownButton<String?>(
                              value: _selectedStatus,
                              hint: const Text('All Status'),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('All Status'),
                                ),
                                const DropdownMenuItem<String?>(
                                  value: 'Active',
                                  child: Text('Active'),
                                ),
                                const DropdownMenuItem<String?>(
                                  value: 'Inactive',
                                  child: Text('Inactive'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedStatus = value;
                                  _currentPage = 1;
                                });
                              },
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                              ),
                              underline: Container(),
                              borderRadius: BorderRadius.circular(8),
                              dropdownColor: Colors.white,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(color: Colors.green[100]!),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: MaterialStateProperty
                                        .resolveWith<Color?>(
                                            (states) => Colors.green[50]),
                                    dataRowColor: MaterialStateProperty
                                        .resolveWith<Color?>((states) =>
                                            states.contains(
                                                    MaterialState.selected)
                                                ? Colors.green[100]
                                                : null),
                                    headingTextStyle: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      fontFamily: 'NotoSans',
                                    ),
                                    columns: const [
                                      DataColumn(label: Text('Profile')),
                                      DataColumn(label: Text('Name')),
                                      DataColumn(label: Text('Email')),
                                      DataColumn(label: Text('Role')),
                                      DataColumn(label: Text('Status')),
                                      DataColumn(label: Text('Actions')),
                                    ],
                                    rows: paginatedUsers
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final index = entry.key;
                                      final user = entry.value;
                                      return DataRow(
                                        color: MaterialStateProperty
                                            .resolveWith<Color?>((states) =>
                                                index % 2 == 0
                                                    ? Colors.white
                                                    : Colors.grey[50]),
                                        cells: [
                                          DataCell(
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundImage:
                                                  user.profileImage != null
                                                      ? NetworkImage(
                                                          user.profileImage!)
                                                      : null,
                                              child: user.profileImage == null
                                                  ? Text(
                                                      user.fullName.isNotEmpty
                                                          ? user.fullName[0]
                                                              .toUpperCase()
                                                          : 'U',
                                                      style: const TextStyle(
                                                          fontSize: 16),
                                                    )
                                                  : null,
                                            ),
                                          ),
                                          DataCell(SizedBox(
                                            width: 120,
                                            child: Text(user.fullName,
                                                style: const TextStyle(
                                                    fontFamily: 'NotoSans')),
                                          )),
                                          DataCell(SizedBox(
                                            width: 180,
                                            child: Text(user.email,
                                                style: const TextStyle(
                                                    fontFamily: 'NotoSans')),
                                          )),
                                          DataCell(Text(
                                              user.role
                                                  .toString()
                                                  .split('.')
                                                  .last,
                                              style: const TextStyle(
                                                  fontFamily: 'NotoSans'))),
                                          DataCell(Row(
                                            children: [
                                              Icon(
                                                user.isActive
                                                    ? Icons.check_circle
                                                    : Icons.cancel,
                                                color: user.isActive
                                                    ? Colors.green
                                                    : Colors.red,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                user.isActive
                                                    ? 'Active'
                                                    : 'Inactive',
                                                style: TextStyle(
                                                  color: user.isActive
                                                      ? Colors.green[700]
                                                      : Colors.red[700],
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          )),
                                          DataCell(Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit,
                                                    color: Colors.green),
                                                tooltip: 'Edit',
                                                onPressed: () {
                                                  showDialog(
                                                    context: context,
                                                    barrierDismissible: false,
                                                    builder: (context) =>
                                                        UserFormPage(
                                                            user: user),
                                                  );
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete,
                                                    color: Colors.red),
                                                tooltip: 'Delete',
                                                onPressed: () async {
                                                  final confirmed =
                                                      await showDialog<bool>(
                                                    context: context,
                                                    builder: (context) =>
                                                        AlertDialog(
                                                      title: const Text(
                                                          'Delete User'),
                                                      content: Text(
                                                        'Are you sure you want to delete "${user.fullName}"?',
                                                        style: const TextStyle(
                                                            fontFamily:
                                                                'NotoSans'),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context,
                                                                  false),
                                                          child: const Text(
                                                              'Cancel',
                                                              style: TextStyle(
                                                                  fontFamily:
                                                                      'NotoSans')),
                                                        ),
                                                        TextButton(
                                                          onPressed: () async {
                                                            await FirebaseFirestore
                                                                .instance
                                                                .collection(
                                                                    'users')
                                                                .doc(user.id)
                                                                .update({
                                                              'deleted': true
                                                            });
                                                            setState(() {});
                                                            Navigator.pop(
                                                                context, true);
                                                          },
                                                          child: const Text(
                                                              'Delete',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .red,
                                                                  fontFamily:
                                                                      'NotoSans')),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          )),
                                        ],
                                        onSelectChanged: (_) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  UserDetailsPage(user: user),
                                            ),
                                          );
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Pagination bar inside container
                                if (_totalItems > 0)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton(
                                        onPressed: _currentPage > 1
                                            ? () =>
                                                setState(() => _currentPage--)
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _currentPage > 1
                                              ? Colors.green[600]
                                              : Colors.grey[300],
                                          foregroundColor: _currentPage > 1
                                              ? Colors.white
                                              : Colors.grey[600],
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 10),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          elevation: _currentPage > 1 ? 2 : 0,
                                        ),
                                        child: const Text('Previous',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF5F5F5),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Page $_currentPage of ${(_totalItems / _itemsPerPage).ceil()}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: Colors.black87),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      ElevatedButton(
                                        onPressed: _currentPage <
                                                (_totalItems / _itemsPerPage)
                                                    .ceil()
                                            ? () =>
                                                setState(() => _currentPage++)
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _currentPage <
                                                  (_totalItems / _itemsPerPage)
                                                      .ceil()
                                              ? Colors.green[600]
                                              : Colors.grey[300],
                                          foregroundColor: _currentPage <
                                                  (_totalItems / _itemsPerPage)
                                                      .ceil()
                                              ? Colors.white
                                              : Colors.grey[600],
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 10),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          elevation: _currentPage <
                                                  (_totalItems / _itemsPerPage)
                                                      .ceil()
                                              ? 2
                                              : 0,
                                        ),
                                        child: const Text('Next',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // Removed external pagination bar (moved inside container)
                      ],
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'teacher')
                  .where('deleted', isEqualTo: true)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final trashed = snapshot.data!.docs;
                if (trashed.isEmpty)
                  return const Center(child: Text('No deleted teachers.'));
                return ListView(
                  children: trashed.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['fullName'] ?? 'No Name'),
                      subtitle: Text(data['email'] ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon:
                                const Icon(Icons.restore, color: Colors.green),
                            onPressed: () => _restoreTeacher(doc.id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_forever,
                                color: Colors.red),
                            onPressed: () => _deleteTeacherForever(doc.id),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
