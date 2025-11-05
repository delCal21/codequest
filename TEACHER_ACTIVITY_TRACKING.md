# Teacher Activity Tracking System

## Overview

The Teacher Activity Tracking System is a comprehensive solution that automatically logs and displays all teacher activities related to course content management. It tracks when teachers upload, update, or delete courses, challenges, videos, and forum posts.

## Features

### Activity Types Tracked

The system tracks the following activities:

#### Courses
- **Created**: When a teacher creates a new course
- **Updated**: When a teacher modifies course details
- **Deleted**: When a teacher removes a course

#### Challenges
- **Created**: When a teacher adds a new challenge to a course
- **Updated**: When a teacher modifies challenge content or settings
- **Deleted**: When a teacher removes a challenge

#### Videos
- **Created**: When a teacher uploads a new video
- **Updated**: When a teacher modifies video details or content
- **Deleted**: When a teacher removes a video

#### Forum Posts
- **Created**: When a teacher creates a new forum post
- **Updated**: When a teacher edits a forum post
- **Deleted**: When a teacher deletes a forum post

### Activity Display

Activities are displayed in the teacher dashboard with:
- **Teacher Name**: Who performed the action
- **Action Type**: Created, Updated, or Deleted (with color coding)
- **Entity Type**: Course, Challenge, Video, or Forum (with emoji icons)
- **Description**: Detailed description of what was done
- **Timestamp**: When the action occurred (relative time)
- **Course Context**: Which course the activity relates to (if applicable)

### Visual Indicators

- **Green**: Created activities
- **Orange**: Updated activities  
- **Red**: Deleted activities
- **Emojis**: 
  - 📚 for Courses
  - 💻 for Challenges
  - 🎥 for Videos
  - 💬 for Forum Posts

## Technical Implementation

### Files Created/Modified

#### New Files
1. `lib/features/admin/domain/models/activity_model.dart` - Activity data model
2. `lib/services/activity_service.dart` - Activity logging service
3. `lib/features/teacher/presentation/widgets/teacher_activity_widget.dart` - Activity display widget
4. `test/teacher_activity_test.dart` - Unit tests for activity model

#### Modified Files
1. `lib/features/courses/data/course_repository.dart` - Added activity logging
2. `lib/features/challenges/data/repositories/challenges_repository_impl.dart` - Added activity logging
3. `lib/features/videos/data/video_repository.dart` - Added activity logging
4. `lib/features/forums/data/repositories/forums_repository_impl.dart` - Added activity logging
5. `lib/features/teacher/presentation/pages/teacher_home_page.dart` - Updated to use new activity widget

### Database Structure

Activities are stored in the `teacher_activities` collection with the following structure:

```json
{
  "id": "activity-id",
  "teacherId": "teacher-user-id",
  "teacherName": "Teacher Name",
  "activityType": "courseCreated|courseUpdated|courseDeleted|challengeCreated|challengeUpdated|challengeDeleted|videoCreated|videoUpdated|videoDeleted|forumCreated|forumUpdated|forumDeleted",
  "entityType": "course|challenge|video|forum",
  "entityId": "entity-document-id",
  "entityTitle": "Entity Title",
  "description": "Human readable description",
  "timestamp": "Firebase Timestamp",
  "courseId": "related-course-id (optional)",
  "metadata": "Additional data (optional)"
}
```

### Activity Service Methods

The `ActivityService` provides the following methods:

- `logActivity()` - Generic activity logging
- `logCourseActivity()` - Course-specific activity logging
- `logChallengeActivity()` - Challenge-specific activity logging
- `logVideoActivity()` - Video-specific activity logging
- `logForumActivity()` - Forum-specific activity logging
- `getTeacherActivities()` - Get activities for a specific teacher
- `getRecentTeacherActivities()` - Get recent activities including course-related ones

## Usage

### For Teachers

1. **View Activities**: Activities are automatically displayed on the teacher dashboard
2. **Real-time Updates**: New activities appear automatically without page refresh
3. **Activity History**: View up to 15 most recent activities
4. **Course Context**: See which course each activity relates to

### For Developers

#### Adding Activity Logging to New Features

```dart
// Example: Logging a course creation
await ActivityService.logCourseActivity(
  activityType: ActivityType.courseCreated,
  courseId: courseId,
  courseTitle: courseTitle,
);
```

#### Custom Activity Descriptions

```dart
// Example: Custom description
await ActivityService.logCourseActivity(
  activityType: ActivityType.courseUpdated,
  courseId: courseId,
  courseTitle: courseTitle,
  description: 'Updated course settings and added new modules',
);
```

#### Adding Metadata

```dart
// Example: Adding metadata
await ActivityService.logChallengeActivity(
  activityType: ActivityType.challengeCreated,
  challengeId: challengeId,
  challengeTitle: challengeTitle,
  courseId: courseId,
  metadata: {
    'difficulty': 'hard',
    'type': 'coding',
    'timeLimit': 30,
  },
);
```

## Benefits

1. **Transparency**: Teachers can see their own activity history
2. **Accountability**: Track changes and modifications
3. **Collaboration**: See activities from course collaborators
4. **Audit Trail**: Maintain records of all content changes
5. **User Experience**: Clear visual feedback for actions performed

## Future Enhancements

Potential improvements for the activity tracking system:

1. **Activity Filters**: Filter by activity type, date range, or course
2. **Activity Export**: Export activity history to CSV/PDF
3. **Activity Notifications**: Real-time notifications for collaborators
4. **Activity Analytics**: Charts and statistics on teacher activity
5. **Bulk Operations**: Track bulk uploads or deletions
6. **Activity Comments**: Allow teachers to add notes to activities

## Testing

Run the activity tracking tests:

```bash
flutter test test/teacher_activity_test.dart
```

The tests verify:
- Activity model creation and serialization
- Activity type and entity type enums
- Copy with functionality
- JSON conversion accuracy 