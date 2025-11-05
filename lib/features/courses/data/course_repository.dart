import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codequest/features/courses/domain/models/course_model.dart';
import 'package:codequest/features/courses/data/collaborator_repository.dart';
import 'package:codequest/services/notification_service.dart';
import 'package:codequest/services/activity_service.dart';
import 'package:codequest/features/admin/domain/models/activity_model.dart';

class CourseRepository {
  final FirebaseFirestore _firestore;
  final CollaboratorRepository _collaboratorRepository;

  CourseRepository(this._firestore)
      : _collaboratorRepository = CollaboratorRepository(_firestore);

  // Get all published courses (for students)
  Future<List<CourseModel>> getPublishedCourses() async {
    final snapshot = await _firestore
        .collection('courses')
        .where('isPublished', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => CourseModel.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  // Get courses by teacher (for teachers)
  Future<List<CourseModel>> getTeacherCourses(String teacherId) async {
    final snapshot = await _firestore
        .collection('courses')
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => CourseModel.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  // Get courses where user is a collaborator
  Future<List<CourseModel>> getCollaboratorCourses(String userId) async {
    final collaboratorCourseIds =
        await _collaboratorRepository.getCollaboratorCourses(userId);

    if (collaboratorCourseIds.isEmpty) return [];

    final snapshot = await _firestore
        .collection('courses')
        .where(FieldPath.documentId, whereIn: collaboratorCourseIds)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => CourseModel.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  // Get all courses for a teacher (owned + collaborated)
  Future<List<CourseModel>> getAllTeacherCourses(String teacherId) async {
    final ownedCourses = await getTeacherCourses(teacherId);
    final collaboratorCourses = await getCollaboratorCourses(teacherId);

    // Combine and remove duplicates
    final allCourses = <String, CourseModel>{};
    for (final course in ownedCourses) {
      allCourses[course.id] = course;
    }
    for (final course in collaboratorCourses) {
      allCourses[course.id] = course;
    }

    return allCourses.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Get all courses (for admin)
  Future<List<CourseModel>> getAllCourses() async {
    final snapshot = await _firestore
        .collection('courses')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => CourseModel.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  // Create new course (for admin/teacher)
  Future<String> createCourse(CourseModel course) async {
    final docRef = await _firestore.collection('courses').add(course.toJson());

    // Create teacher notification for course creation
    await NotificationService.notifyTeacherCourseCreated(
      teacherId: course.teacherId,
      courseId: docRef.id,
      courseTitle: course.title,
    );

    // Log activity
    await ActivityService.logCourseActivity(
      activityType: ActivityType.courseCreated,
      courseId: docRef.id,
      courseTitle: course.title,
    );

    return docRef.id;
  }

  // Update course (for admin/teacher)
  Future<void> updateCourse(String courseId, CourseModel course) async {
    await _firestore
        .collection('courses')
        .doc(courseId)
        .update(course.toJson());

    // Log activity
    await ActivityService.logCourseActivity(
      activityType: ActivityType.courseUpdated,
      courseId: courseId,
      courseTitle: course.title,
    );
  }

  // Delete course (for admin)
  Future<void> deleteCourse(String courseId) async {
    // Get course data before deletion for cleanup
    final courseDoc =
        await _firestore.collection('courses').doc(courseId).get();
    final courseData = courseDoc.data();

    await _firestore.collection('courses').doc(courseId).delete();

    // Delete all notifications related to this course
    await NotificationService.deleteCourseNotifications(courseId);

    // Log activity
    if (courseData != null) {
      await ActivityService.logCourseActivity(
        activityType: ActivityType.courseDeleted,
        courseId: courseId,
        courseTitle: courseData['title'] ?? 'Unknown Course',
      );
    }
  }

  // Publish/Unpublish course (for admin/teacher)
  Future<void> toggleCoursePublish(String courseId, bool isPublished) async {
    await _firestore
        .collection('courses')
        .doc(courseId)
        .update({'isPublished': isPublished});
  }

  // Get enrolled courses (for students)
  Future<List<CourseModel>> getEnrolledCourses(String studentId) async {
    final enrollmentsSnapshot = await _firestore
        .collection('enrollments')
        .where('studentId', isEqualTo: studentId)
        .get();

    final courseIds = enrollmentsSnapshot.docs
        .map((doc) => doc.data()['courseId'] as String)
        .toList();

    if (courseIds.isEmpty) return [];

    final coursesSnapshot = await _firestore
        .collection('courses')
        .where(FieldPath.documentId, whereIn: courseIds)
        .get();

    return coursesSnapshot.docs
        .map((doc) => CourseModel.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  // Enroll in course (for students)
  Future<void> enrollInCourse(String studentId, String courseId) async {
    // Check if already enrolled
    final existingEnrollment = await _firestore
        .collection('enrollments')
        .where('studentId', isEqualTo: studentId)
        .where('courseId', isEqualTo: courseId)
        .get();

    if (existingEnrollment.docs.isNotEmpty) {
      throw Exception('Already enrolled in this course');
    }

    // Create enrollment
    await _firestore.collection('enrollments').add({
      'studentId': studentId,
      'courseId': courseId,
      'enrolledAt': FieldValue.serverTimestamp(),
      'progress': 0,
      'status': 'active',
      'completed': false,
    });

    // Update enrollment count
    await _firestore.collection('courses').doc(courseId).update({
      'enrollmentCount': FieldValue.increment(1),
    });
  }

  // Check if user has access to course (owner or collaborator)
  Future<bool> hasCourseAccess(String userId, String courseId) async {
    // Check if user is the owner
    final courseDoc =
        await _firestore.collection('courses').doc(courseId).get();
    if (!courseDoc.exists) return false;

    final courseData = courseDoc.data()!;
    if (courseData['teacherId'] == userId) return true;

    // Check if user is a collaborator
    return await _collaboratorRepository.isUserCollaborator(courseId, userId);
  }

  // Get course with collaborator information
  Future<CourseModel?> getCourseWithCollaborators(String courseId) async {
    final doc = await _firestore.collection('courses').doc(courseId).get();
    if (!doc.exists) return null;

    final course = CourseModel.fromJson(doc.data()!..['id'] = doc.id);
    final collaborators =
        await _collaboratorRepository.getCourseCollaborators(courseId);

    return course.copyWith(
      collaborators: collaborators.map((c) => c.toJson()).toList(),
    );
  }

  // Get course details
  Future<CourseModel?> getCourseById(String courseId) async {
    final doc = await _firestore.collection('courses').doc(courseId).get();
    if (!doc.exists) return null;
    return CourseModel.fromJson(doc.data()!..['id'] = doc.id);
  }

  // Assign course to teacher by admin
  Future<void> assignCourseToTeacher(
    String courseId,
    String teacherId,
    String assignedBy,
    String assignedByName,
  ) async {
    // Update course with new teacher
    await _firestore.collection('courses').doc(courseId).update({
      'teacherId': teacherId,
      'assignedBy': assignedBy,
      'assignedAt': FieldValue.serverTimestamp(),
    });

    // Get course title for notification
    final courseDoc =
        await _firestore.collection('courses').doc(courseId).get();
    final courseTitle = courseDoc.data()?['title'] ?? 'Unknown Course';

    // Create teacher notification for course assignment
    await NotificationService.notifyTeacherCourseAssignment(
      teacherId: teacherId,
      courseId: courseId,
      courseTitle: courseTitle,
      assignedBy: assignedBy,
      assignedByName: assignedByName,
    );
  }
}
