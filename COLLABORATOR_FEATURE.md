# Course Collaborator Feature

## Overview

The Course Collaborator feature allows teachers to add other teachers as collaborators to their courses. Collaborators can help manage course content, monitor student progress, and create challenges for the course they collaborate on.

## Features

### 1. Collaborator Roles
- **Co-Teacher**: Full access to manage course content, students, and collaborators
- **Assistant**: Can manage content and create challenges, limited student management
- **Moderator**: Can manage students and view analytics, limited content access

### 2. Permissions System
Each role comes with predefined permissions:
- `manage_content`: Edit course materials and content
- `manage_students`: View and manage student enrollments
- `create_challenges`: Create and manage course challenges
- `view_analytics`: Access course analytics and progress reports
- `manage_collaborators`: Add/remove collaborators (Co-Teacher only)
- `publish_course`: Publish/unpublish course (Co-Teacher only)

### 3. Key Functionality
- **Add Collaborators**: Search and add teachers as collaborators
- **Remove Collaborators**: Remove collaborators from courses
- **Role Management**: Change collaborator roles and permissions
- **Access Control**: Verify user permissions for course actions
- **Collaborator Dashboard**: View all courses where user is a collaborator

## Implementation Details

### Data Models

#### CourseModel Updates
```dart
class CourseModel {
  // ... existing fields
  final List<String> collaboratorIds;
  final List<Map<String, dynamic>> collaborators;
}
```

#### New CollaboratorModel
```dart
class CollaboratorModel {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final CollaboratorRole role;
  final DateTime addedAt;
  final String addedBy;
  final bool isActive;
  final Map<String, bool> permissions;
}
```

### Database Structure

#### Courses Collection
```json
{
  "id": "course_id",
  "title": "Course Title",
  "teacherId": "owner_teacher_id",
  "collaboratorIds": ["collaborator1_id", "collaborator2_id"],
  "collaborators": [
    {
      "userId": "collaborator1_id",
      "userName": "John Doe",
      "userEmail": "john@example.com",
      "role": "coTeacher",
      "addedAt": "timestamp",
      "addedBy": "owner_teacher_id",
      "isActive": true,
      "permissions": {
        "manage_content": true,
        "manage_students": true,
        "create_challenges": true,
        "view_analytics": true,
        "manage_collaborators": true,
        "publish_course": true
      }
    }
  ]
}
```

#### Collaborators Subcollection
Each course has a `collaborators` subcollection for detailed collaborator management:
```json
{
  "id": "collaborator_doc_id",
  "userId": "teacher_id",
  "userName": "Teacher Name",
  "userEmail": "teacher@example.com",
  "role": "assistant",
  "addedAt": "timestamp",
  "addedBy": "owner_teacher_id",
  "isActive": true,
  "permissions": {
    "manage_content": true,
    "manage_students": false,
    "create_challenges": true,
    "view_analytics": true,
    "manage_collaborators": false,
    "publish_course": false
  }
}
```

### Key Components

#### 1. CollaboratorRepository
Handles all collaborator-related database operations:
- `getCourseCollaborators()`: Get all collaborators for a course
- `addCollaborator()`: Add a new collaborator
- `removeCollaborator()`: Remove a collaborator
- `updateCollaborator()`: Update collaborator role/permissions
- `searchTeachers()`: Search for teachers to add as collaborators
- `isUserCollaborator()`: Check if user is a collaborator

#### 2. CollaboratorManagementWidget
UI component for managing collaborators:
- Search and add teachers as collaborators
- View current collaborators
- Remove collaborators
- Change collaborator roles

#### 3. Updated CourseRepository
Enhanced with collaborator functionality:
- `getCollaboratorCourses()`: Get courses where user is a collaborator
- `getAllTeacherCourses()`: Get owned + collaborated courses
- `hasCourseAccess()`: Check if user has access to course
- `getCourseWithCollaborators()`: Get course with collaborator details

## Usage

### For Course Owners
1. Navigate to Teacher Courses page
2. Click the "Manage Collaborators" button (people icon) on any course
3. Search for teachers by name or email
4. Select a role and add them as collaborators
5. Manage existing collaborators (change roles, remove)

### For Collaborators
1. Collaborators can see courses they collaborate on in their course list
2. Access course management features based on their role permissions
3. Create challenges and monitor student progress as allowed by their role

### Access Control
The system automatically checks permissions before allowing actions:
```dart
// Example: Check if user can manage course content
final hasAccess = await courseRepository.hasCourseAccess(userId, courseId);
if (hasAccess) {
  // Allow content management
}
```

## Security Rules

### Firestore Rules
```javascript
// Courses collection
match /courses/{courseId} {
  allow read: if request.auth != null;
  allow write: if request.auth != null && 
    (resource.data.teacherId == request.auth.uid || 
     request.auth.uid in resource.data.collaboratorIds);
}

// Collaborators subcollection
match /courses/{courseId}/collaborators/{collaboratorId} {
  allow read: if request.auth != null;
  allow write: if request.auth != null && 
    get(/databases/$(database.name)/documents/courses/$(courseId)).data.teacherId == request.auth.uid;
}
```

## Future Enhancements

1. **Collaborator Invitations**: Email-based invitation system
2. **Permission Customization**: Allow custom permission sets
3. **Collaborator Analytics**: Track collaborator contributions
4. **Bulk Operations**: Add/remove multiple collaborators at once
5. **Collaborator Notifications**: Notify collaborators of course changes
6. **Temporary Access**: Time-limited collaborator access

## Testing

### Unit Tests
- Test collaborator role permissions
- Test repository methods
- Test access control logic

### Integration Tests
- Test collaborator addition/removal flow
- Test permission enforcement
- Test course access verification

### Widget Tests
- Test CollaboratorManagementWidget UI
- Test search functionality
- Test role selection

## Migration Notes

For existing courses:
- `collaboratorIds` field will be empty array by default
- `collaborators` field will be empty array by default
- No migration required for existing course data

## Dependencies

- `cloud_firestore`: Database operations
- `firebase_auth`: User authentication
- `equatable`: Value equality for models
- `flutter_bloc`: State management

## Error Handling

The system handles various error scenarios:
- User not found during collaborator addition
- User already a collaborator
- Invalid role assignments
- Permission denied for operations
- Network connectivity issues

All errors are displayed to users via SnackBar notifications with appropriate error messages. 