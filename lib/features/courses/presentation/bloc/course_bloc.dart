import 'package:bloc/bloc.dart';
import 'package:codequest/features/courses/data/course_repository.dart';
import 'package:codequest/features/courses/domain/models/course_model.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Events
abstract class CourseEvent extends Equatable {
  const CourseEvent();

  @override
  List<Object?> get props => [];
}

class LoadCourses extends CourseEvent {
  final String? teacherId;
  final bool isAdmin;

  const LoadCourses({this.teacherId, this.isAdmin = false});

  @override
  List<Object?> get props => [teacherId, isAdmin];
}

class LoadAllTeacherCourses extends CourseEvent {
  final String teacherId;

  const LoadAllTeacherCourses(this.teacherId);

  @override
  List<Object?> get props => [teacherId];
}

class LoadEnrolledCourses extends CourseEvent {
  final String studentId;

  const LoadEnrolledCourses(this.studentId);

  @override
  List<Object?> get props => [studentId];
}

class CreateCourse extends CourseEvent {
  final CourseModel course;
  final PlatformFile? selectedFile;

  const CreateCourse(this.course, this.selectedFile);

  @override
  List<Object?> get props => [course, selectedFile];
}

class UpdateCourse extends CourseEvent {
  final String courseId;
  final CourseModel course;
  final PlatformFile? selectedFile;

  const UpdateCourse(this.courseId, this.course, {this.selectedFile});

  @override
  List<Object?> get props => [courseId, course, selectedFile];
}

class DeleteCourse extends CourseEvent {
  final String courseId;

  const DeleteCourse(this.courseId);

  @override
  List<Object?> get props => [courseId];
}

class ToggleCoursePublish extends CourseEvent {
  final String courseId;
  final bool isPublished;

  const ToggleCoursePublish(this.courseId, this.isPublished);

  @override
  List<Object?> get props => [courseId, isPublished];
}

class EnrollInCourse extends CourseEvent {
  final String studentId;
  final String courseId;

  const EnrollInCourse(this.studentId, this.courseId);

  @override
  List<Object?> get props => [studentId, courseId];
}

// States
abstract class CourseState extends Equatable {
  const CourseState();

  @override
  List<Object?> get props => [];
}

class CourseInitial extends CourseState {}

class CourseLoading extends CourseState {}

class CourseLoaded extends CourseState {
  final List<CourseModel> courses;

  const CourseLoaded(this.courses);

  @override
  List<Object?> get props => [courses];
}

class CourseError extends CourseState {
  final String message;

  const CourseError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class CourseBloc extends Bloc<CourseEvent, CourseState> {
  final CourseRepository _courseRepository;

  CourseBloc(this._courseRepository) : super(CourseInitial()) {
    on<LoadCourses>(_onLoadCourses);
    on<LoadAllTeacherCourses>(_onLoadAllTeacherCourses);
    on<LoadEnrolledCourses>(_onLoadEnrolledCourses);
    on<CreateCourse>(_onCreateCourse);
    on<UpdateCourse>(_onUpdateCourse);
    on<DeleteCourse>(_onDeleteCourse);
    on<ToggleCoursePublish>(_onToggleCoursePublish);
    on<EnrollInCourse>(_onEnrollInCourse);
  }

  Future<void> _onLoadCourses(
      LoadCourses event, Emitter<CourseState> emit) async {
    try {
      emit(CourseLoading());
      List<CourseModel> courses;
      if (event.isAdmin) {
        courses = await _courseRepository.getAllCourses();
      } else if (event.teacherId != null) {
        courses = await _courseRepository.getTeacherCourses(event.teacherId!);
      } else {
        courses = await _courseRepository.getPublishedCourses();
      }
      emit(CourseLoaded(courses));
    } catch (e) {
      emit(CourseError(e.toString()));
    }
  }

  Future<void> _onLoadAllTeacherCourses(
      LoadAllTeacherCourses event, Emitter<CourseState> emit) async {
    try {
      emit(CourseLoading());
      final courses =
          await _courseRepository.getAllTeacherCourses(event.teacherId);
      emit(CourseLoaded(courses));
    } catch (e) {
      emit(CourseError(e.toString()));
    }
  }

  Future<void> _onLoadEnrolledCourses(
      LoadEnrolledCourses event, Emitter<CourseState> emit) async {
    try {
      emit(CourseLoading());
      final courses =
          await _courseRepository.getEnrolledCourses(event.studentId);
      emit(CourseLoaded(courses));
    } catch (e) {
      emit(CourseError(e.toString()));
    }
  }

  Future<void> _onCreateCourse(
      CreateCourse event, Emitter<CourseState> emit) async {
    try {
      emit(CourseLoading());
      // If event.selectedFile is not null, upload and wrap in files array
      List<Map<String, dynamic>> files = [];
      if (event.selectedFile != null && event.selectedFile!.bytes != null) {
        final file = event.selectedFile!;
        final fileName = file.name;
        final ref = FirebaseStorage.instance.ref().child('courses/$fileName');
        final uploadTask = ref.putData(file.bytes!);
        await uploadTask;
        final fileUrl = await ref.getDownloadURL();
        files.add({
          'url': fileUrl,
          'name': fileName,
          'type': fileName.split('.').last,
        });
      }
      // Create course with files array
      final course = event.course.copyWith(
        files: files,
        createdAt: DateTime.now(),
      );
      await _courseRepository.createCourse(course);
      // Load updated course list
      if (course.teacherId.isNotEmpty) {
        final courses =
            await _courseRepository.getTeacherCourses(course.teacherId);
        emit(CourseLoaded(courses));
      } else {
        final courses = await _courseRepository.getAllCourses();
        emit(CourseLoaded(courses));
      }
    } catch (e) {
      emit(CourseError(e.toString()));
    }
  }

  Future<void> _onUpdateCourse(
      UpdateCourse event, Emitter<CourseState> emit) async {
    try {
      emit(CourseLoading());
      CourseModel updatedCourse = event.course;
      if (event.selectedFile != null && event.selectedFile!.bytes != null) {
        // Upload new file and add to files array
        final file = event.selectedFile!;
        final fileName = file.name;
        final ref = FirebaseStorage.instance.ref().child('courses/$fileName');
        final uploadTask = ref.putData(file.bytes!);
        await uploadTask;
        final fileUrl = await ref.getDownloadURL();
        // Add to files array (append or replace as needed)
        final files = List<Map<String, dynamic>>.from(event.course.files);
        files.add({
          'url': fileUrl,
          'name': fileName,
          'type': fileName.split('.').last,
        });
        updatedCourse = event.course.copyWith(files: files);
      }
      await _courseRepository.updateCourse(event.courseId, updatedCourse);
      add(LoadCourses());
    } catch (e) {
      emit(CourseError(e.toString()));
    }
  }

  Future<void> _onDeleteCourse(
      DeleteCourse event, Emitter<CourseState> emit) async {
    try {
      emit(CourseLoading());
      await _courseRepository.deleteCourse(event.courseId);
      add(LoadCourses());
    } catch (e) {
      emit(CourseError(e.toString()));
    }
  }

  Future<void> _onToggleCoursePublish(
      ToggleCoursePublish event, Emitter<CourseState> emit) async {
    try {
      emit(CourseLoading());
      await _courseRepository.toggleCoursePublish(
          event.courseId, event.isPublished);
      add(LoadCourses());
    } catch (e) {
      emit(CourseError(e.toString()));
    }
  }

  Future<void> _onEnrollInCourse(
      EnrollInCourse event, Emitter<CourseState> emit) async {
    try {
      emit(CourseLoading());
      await _courseRepository.enrollInCourse(event.studentId, event.courseId);
      add(LoadEnrolledCourses(event.studentId));
    } catch (e) {
      emit(CourseError(e.toString()));
    }
  }
}
