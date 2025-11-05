import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codequest/features/courses/domain/models/collaborator_model.dart';
import 'package:codequest/services/notification_service.dart';

class CollaboratorRepository {
  final FirebaseFirestore _firestore;

  CollaboratorRepository(this._firestore);

  // Get collaborators for a specific course
  Future<List<CollaboratorModel>> getCourseCollaborators(
      String courseId) async {
    final snapshot = await _firestore
        .collection('courses')
        .doc(courseId)
        .collection('collaborators')
        .where('isActive', isEqualTo: true)
        .orderBy('addedAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => CollaboratorModel.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  // Add a collaborator to a course
  Future<void> addCollaborator(
      String courseId, CollaboratorModel collaborator) async {
    // First, check if user exists and is a teacher
    final userDoc =
        await _firestore.collection('users').doc(collaborator.userId).get();
    if (!userDoc.exists) {
      throw Exception('User not found');
    }

    final userData = userDoc.data()!;
    if (userData['role'] != 'teacher') {
      throw Exception('Only teachers can be added as collaborators');
    }

    // Check if already a collaborator
    final existingCollaborator = await _firestore
        .collection('courses')
        .doc(courseId)
        .collection('collaborators')
        .where('userId', isEqualTo: collaborator.userId)
        .where('isActive', isEqualTo: true)
        .get();

    if (existingCollaborator.docs.isNotEmpty) {
      throw Exception('User is already a collaborator for this course');
    }

    // Add collaborator to course
    await _firestore
        .collection('courses')
        .doc(courseId)
        .collection('collaborators')
        .add(collaborator.toJson());

    // Update course document with collaborator info
    await _firestore.collection('courses').doc(courseId).update({
      'collaboratorIds': FieldValue.arrayUnion([collaborator.userId]),
      'collaborators': FieldValue.arrayUnion([collaborator.toJson()]),
    });

    // Fetch course title and added by user info for notification
    final courseDoc =
        await _firestore.collection('courses').doc(courseId).get();
    final courseTitle = courseDoc.data()?['title'] ?? '';

    final addedByUserDoc =
        await _firestore.collection('users').doc(collaborator.addedBy).get();
    final addedByName = addedByUserDoc.data()?['name'] ?? 'Unknown User';

    // Create teacher notification for collaborator assignment
    await NotificationService.notifyTeacherCollaboratorAssignment(
      teacherId: collaborator.userId,
      courseId: courseId,
      courseTitle: courseTitle,
      assignedBy: collaborator.addedBy,
      assignedByName: addedByName,
      role: collaborator.role.toString().split('.').last,
    );
  }

  // Remove a collaborator from a course
  Future<void> removeCollaborator(
      String courseId, String collaboratorId) async {
    // Get collaborator details
    final collaboratorDoc = await _firestore
        .collection('courses')
        .doc(courseId)
        .collection('collaborators')
        .doc(collaboratorId)
        .get();

    if (!collaboratorDoc.exists) {
      throw Exception('Collaborator not found');
    }

    final collaboratorData = collaboratorDoc.data()!;
    final userId = collaboratorData['userId'] as String;

    // Mark collaborator as inactive
    await _firestore
        .collection('courses')
        .doc(courseId)
        .collection('collaborators')
        .doc(collaboratorId)
        .update({'isActive': false});

    // Remove from course document
    await _firestore.collection('courses').doc(courseId).update({
      'collaboratorIds': FieldValue.arrayRemove([userId]),
    });
  }

  // Update collaborator role and permissions
  Future<void> updateCollaborator(
    String courseId,
    String collaboratorId,
    CollaboratorRole newRole,
    Map<String, bool>? permissions,
  ) async {
    final updateData = <String, dynamic>{
      'role': newRole.toString().split('.').last,
    };

    if (permissions != null) {
      updateData['permissions'] = permissions;
    }

    await _firestore
        .collection('courses')
        .doc(courseId)
        .collection('collaborators')
        .doc(collaboratorId)
        .update(updateData);
  }

  // Check if user is a collaborator for a course
  Future<bool> isUserCollaborator(String courseId, String userId) async {
    final snapshot = await _firestore
        .collection('courses')
        .doc(courseId)
        .collection('collaborators')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  // Get collaborator details for a specific user in a course
  Future<CollaboratorModel?> getCollaboratorDetails(
      String courseId, String userId) async {
    final snapshot = await _firestore
        .collection('courses')
        .doc(courseId)
        .collection('collaborators')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return CollaboratorModel.fromJson(
      snapshot.docs.first.data()..['id'] = snapshot.docs.first.id,
    );
  }

  // Search for teachers to add as collaborators
  Future<List<Map<String, dynamic>>> searchTeachers(String searchQuery) async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', whereIn: ['teacher', 'Teacher']).get();

    final teachers = <Map<String, dynamic>>[];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final name = (data['name'] ?? data['fullName'] ?? '') as String;
      final email = data['email'] ?? '';
      final isActive =
          data['active'] ?? true; // Use 'active' field to match teacher table

      // Only include active teachers that match the search query
      if (isActive &&
          (name.toLowerCase().contains(searchQuery.toLowerCase()) ||
              email.toLowerCase().contains(searchQuery.toLowerCase()))) {
        teachers.add({
          'id': doc.id,
          'name': name,
          'email': email,
          'avatarUrl': data['avatarUrl'],
        });
      }
    }

    return teachers;
  }

  // Get all available teachers
  Future<List<Map<String, dynamic>>> getAllTeachers() async {
    // Avoid composite index requirement: minimal server filters, client-side refine and sort
    final snapshot = await _firestore
        .collection('users')
        .where('role', whereIn: ['teacher', 'Teacher']).get();

    final teachers = snapshot.docs
        .map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'email': data['email'] ?? '',
            'avatarUrl': data['avatarUrl'],
            'active': data['active'] ??
                true, // Use 'active' field to match teacher table
          };
        })
        .where((teacher) => teacher['active'] == true) // Only active teachers
        .toList();

    teachers.sort((a, b) => (a['name'] as String)
        .toLowerCase()
        .compareTo((b['name'] as String).toLowerCase()));

    return teachers;
  }

  // Get courses where user is a collaborator
  Future<List<String>> getCollaboratorCourses(String userId) async {
    final snapshot = await _firestore
        .collectionGroup('collaborators')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs.map((doc) => doc.reference.parent.parent!.id).toList();
  }
}
