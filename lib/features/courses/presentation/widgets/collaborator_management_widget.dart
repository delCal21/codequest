import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codequest/features/courses/domain/models/collaborator_model.dart';
import 'package:codequest/features/courses/data/collaborator_repository.dart';

class CollaboratorManagementWidget extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const CollaboratorManagementWidget({
    Key? key,
    required this.courseId,
    required this.courseTitle,
  }) : super(key: key);

  @override
  State<CollaboratorManagementWidget> createState() =>
      _CollaboratorManagementWidgetState();
}

class _CollaboratorManagementWidgetState
    extends State<CollaboratorManagementWidget> {
  final CollaboratorRepository _collaboratorRepository =
      CollaboratorRepository(FirebaseFirestore.instance);
  final TextEditingController _searchController = TextEditingController();

  List<CollaboratorModel> _collaborators = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _allTeachers = [];
  bool _isLoading = false;
  bool _isSearching = false;
  bool _showAllTeachers = false;

  @override
  void initState() {
    super.initState();
    _loadCollaborators();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCollaborators() async {
    setState(() => _isLoading = true);
    try {
      final collaborators =
          await _collaboratorRepository.getCourseCollaborators(widget.courseId);
      setState(() {
        _collaborators = collaborators;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading collaborators: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadAllTeachers() async {
    setState(() => _isLoading = true);
    try {
      final teachers = await _collaboratorRepository.getAllTeachers();
      print('DEBUG: All teachers loaded from Firestore:');
      for (var t in teachers) {
        print(
            '  Teacher: id=${t['id']}, name=${t['name']}, email=${t['email']}');
      }
      final currentUser = FirebaseAuth.instance.currentUser;
      final collaboratorIds = _collaborators.map((c) => c.userId).toSet();
      print('DEBUG: Collaborator IDs for this course: $collaboratorIds');
      setState(() {
        _allTeachers = (currentUser == null)
            ? teachers.where((t) => !collaboratorIds.contains(t['id'])).toList()
            : teachers
                .where((t) =>
                    t['id'] != currentUser.uid &&
                    !collaboratorIds.contains(t['id']))
                .toList();
        print('DEBUG: Teachers available to add as collaborators:');
        for (var t in _allTeachers) {
          print(
              '  Available: id=${t['id']}, name=${t['name']}, email=${t['email']}');
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading teachers: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _searchTeachers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await _collaboratorRepository.searchTeachers(query);
      print('DEBUG: Search results for "$query":');
      for (var t in results) {
        print(
            '  Teacher: id=${t['id']}, name=${t['name']}, email=${t['email']}');
      }
      final currentUser = FirebaseAuth.instance.currentUser;
      final collaboratorIds = _collaborators.map((c) => c.userId).toSet();
      setState(() {
        _searchResults = (currentUser == null)
            ? results.where((t) => !collaboratorIds.contains(t['id'])).toList()
            : results
                .where((t) =>
                    t['id'] != currentUser.uid &&
                    !collaboratorIds.contains(t['id']))
                .toList();
        print('DEBUG: Teachers available to add as collaborators (search):');
        for (var t in _searchResults) {
          print(
              '  Available: id=${t['id']}, name=${t['name']}, email=${t['email']}');
        }
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching teachers: ${e.toString()}')),
        );
      }
    }
  }

  void _toggleShowAllTeachers() {
    setState(() {
      _showAllTeachers = !_showAllTeachers;
      if (_showAllTeachers) {
        _loadAllTeachers();
      } else {
        _allTeachers = [];
      }
    });
  }

  Future<void> _addCollaborator(Map<String, dynamic> teacher) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final role = await _showRoleSelectionDialog();
    if (role == null) return;

    try {
      // Create a temporary collaborator to get default permissions
      final tempCollaborator = CollaboratorModel(
        id: '',
        userId: teacher['id'],
        userName: teacher['name'],
        userEmail: teacher['email'],
        role: role,
        addedAt: DateTime.now(),
        addedBy: currentUser.uid,
      );

      final collaborator = CollaboratorModel(
        id: '',
        userId: teacher['id'],
        userName: teacher['name'],
        userEmail: teacher['email'],
        role: role,
        addedAt: DateTime.now(),
        addedBy: currentUser.uid,
        permissions: tempCollaborator.defaultPermissions,
      );

      await _collaboratorRepository.addCollaborator(
          widget.courseId, collaborator);
      await _loadCollaborators();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${teacher['name']} added as collaborator')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding collaborator: ${e.toString()}')),
        );
      }
    }
  }

  Future<CollaboratorRole?> _showRoleSelectionDialog() async {
    return showDialog<CollaboratorRole>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: CollaboratorRole.values.map((role) {
            return ListTile(
              title: Text(_getRoleDisplayName(role)),
              subtitle: Text(_getRoleDescription(role)),
              onTap: () => Navigator.pop(context, role),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getRoleDisplayName(CollaboratorRole role) {
    switch (role) {
      case CollaboratorRole.coTeacher:
        return 'Co-Teacher';
      case CollaboratorRole.assistant:
        return 'Assistant';
      case CollaboratorRole.moderator:
        return 'Moderator';
    }
  }

  String _getRoleDescription(CollaboratorRole role) {
    switch (role) {
      case CollaboratorRole.coTeacher:
        return 'Full access to manage course content, students, and collaborators';
      case CollaboratorRole.assistant:
        return 'Can manage content and create challenges, limited student management';
      case CollaboratorRole.moderator:
        return 'Can manage students and view analytics, limited content access';
    }
  }

  Future<void> _removeCollaborator(CollaboratorModel collaborator) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Collaborator'),
        content: Text(
            'Are you sure you want to remove ${collaborator.userName} as a collaborator?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _collaboratorRepository.removeCollaborator(
            widget.courseId, collaborator.id);
        await _loadCollaborators();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('${collaborator.userName} removed as collaborator')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error removing collaborator: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Collaborators - ${widget.courseTitle}'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          // Search section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Collaborator',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search teachers by name or email...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (value) {
                          if (value.length >= 2) {
                            _searchTeachers(value);
                          } else {
                            setState(() {
                              _searchResults = [];
                              _isSearching = false;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _toggleShowAllTeachers,
                      icon: Icon(
                          _showAllTeachers ? Icons.hide_source : Icons.people),
                      label: Text(_showAllTeachers ? 'Hide All' : 'Show All'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _showAllTeachers ? Colors.orange : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Searching...'),
                      ],
                    ),
                  ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final teacher = _searchResults[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green[100],
                            backgroundImage: teacher['avatarUrl'] != null
                                ? NetworkImage(teacher['avatarUrl'])
                                : null,
                            child: teacher['avatarUrl'] == null
                                ? Text(
                                    teacher['name'][0].toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            teacher['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontFamily: 'NotoSans',
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                teacher['email'],
                                style: const TextStyle(
                                  fontFamily: 'NotoSans',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.visibility,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Active',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'NotoSans',
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _addCollaborator(teacher),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Add'),
                          ),
                        );
                      },
                    ),
                  ),
                if (_showAllTeachers && _allTeachers.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            'All Available Teachers (${_allTeachers.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _allTeachers.length,
                            itemBuilder: (context, index) {
                              final teacher = _allTeachers[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green[100],
                                  backgroundImage: teacher['avatarUrl'] != null
                                      ? NetworkImage(teacher['avatarUrl'])
                                      : null,
                                  child: teacher['avatarUrl'] == null
                                      ? Text(
                                          teacher['name'][0].toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  teacher['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'NotoSans',
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      teacher['email'],
                                      style: const TextStyle(
                                        fontFamily: 'NotoSans',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.visibility,
                                          color: Colors.green,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Active',
                                          style: TextStyle(
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'NotoSans',
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () => _addCollaborator(teacher),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[600],
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Add'),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Collaborators list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _collaborators.isEmpty
                    ? const Center(
                        child: Text(
                          'No collaborators yet.\nSearch above to add collaborators.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _collaborators.length,
                        itemBuilder: (context, index) {
                          final collaborator = _collaborators[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    collaborator.userName.isNotEmpty
                                        ? null
                                        : null,
                                child: Text(
                                    collaborator.userName[0].toUpperCase()),
                              ),
                              title: Text(collaborator.userName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(collaborator.userEmail),
                                  Text(
                                    _getRoleDisplayName(collaborator.role),
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'remove') {
                                    _removeCollaborator(collaborator);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Row(
                                      children: [
                                        Icon(Icons.remove_circle,
                                            color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Remove'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
