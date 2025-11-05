# Teacher Email Validation System

## Overview

The Teacher Email Validation System ensures that only users with appropriate email domains can register as teachers in the CodeQuest platform. This helps maintain the integrity of the educational platform by restricting teacher access to legitimate educational institutions and approved domains.

## Features

### 1. Domain Validation
- **Educational Domains**: Automatically allows emails from educational institutions (.edu, .ac, .school, .university, .college, .institute, .academy, .gov, .org)
- **Approved Domains**: Allows specific domains for testing and demo purposes (gmail.com, outlook.com, yahoo.com)
- **Custom Domains**: Admins can add custom domains through the admin interface

### 2. Validation Points
- **Registration**: Validates teacher emails during user registration
- **Admin Creation**: Validates emails when admins create teacher accounts
- **Form Validation**: Real-time validation in registration forms

### 3. Admin Management
- **Domain Management**: Admins can add/remove custom domains
- **Configuration**: Centralized domain configuration stored in Firestore
- **User Interface**: Dedicated admin page for managing email domains

## Implementation Details

### Service Layer
- **TeacherEmailValidationService**: Core validation logic
- **Async/Sync Validation**: Both asynchronous and synchronous validation methods
- **Custom Domain Support**: Dynamic loading of custom domains from Firestore

### Database Structure
```javascript
// Firestore Collection: config/teacher_email_domains
{
  "custom_domains": ["example.com", "test.edu"],
  "updated_at": Timestamp
}
```

### Validation Logic
1. **Basic Email Format**: Validates email format using regex
2. **Domain Extraction**: Extracts domain from email address
3. **Domain Checking**: Checks against allowed domains in order:
   - Specific allowed domains (gmail.com, outlook.com, yahoo.com)
   - Custom domains (from Firestore)
   - Educational domain patterns (.edu, .ac, etc.)

## Usage

### For Developers

#### Basic Validation
```dart
// Synchronous validation (for form validation)
String? error = TeacherEmailValidationService.validateTeacherEmailSync(email);
if (error != null) {
  // Handle validation error
}

// Asynchronous validation (for registration)
String? error = await TeacherEmailValidationService.validateTeacherEmail(email);
if (error != null) {
  // Handle validation error
}
```

#### Adding Custom Domains
```dart
// Add a new allowed domain
TeacherEmailValidationService.addAllowedDomain('example.com');

// Remove an allowed domain
TeacherEmailValidationService.removeAllowedDomain('example.com');
```

### For Admins

#### Managing Email Domains
1. Navigate to Admin Dashboard
2. Click on "Email Domains" in the navigation menu
3. Add new domains using the form
4. Remove domains by clicking the delete icon on domain chips

#### Domain Configuration
- **Default Domains**: Cannot be removed (educational patterns)
- **Custom Domains**: Can be added/removed by admins
- **Specific Domains**: Pre-configured for testing (gmail.com, etc.)

## Allowed Domains

### Default Educational Domains
- `.edu` - Educational institutions
- `.ac` - Academic institutions  
- `.school` - Schools
- `.university` - Universities
- `.college` - Colleges
- `.institute` - Institutes
- `.academy` - Academies
- `.gov` - Government institutions
- `.org` - Non-profit organizations

### Pre-approved Domains
- `gmail.com` - For testing/demo purposes
- `outlook.com` - For testing/demo purposes
- `yahoo.com` - For testing/demo purposes

### Custom Domains
- Admins can add any domain through the admin interface
- Stored in Firestore for persistence
- Automatically loaded when validation service initializes

## Error Messages

### Validation Messages
- **Empty Email**: "Email is required"
- **Invalid Format**: "Please enter a valid email address"
- **Unauthorized Domain**: "Please use an educational institution email or approved domain"

### User-Friendly Messages
- **Short Message**: "Please use an educational institution email or approved domain"
- **Full Message**: Detailed explanation of requirements with examples

## Security Considerations

### Domain Validation
- Case-insensitive domain matching
- Proper email format validation
- Protection against common email injection patterns

### Admin Access
- Only admin users can modify domain configuration
- Changes are logged in Firestore with timestamps
- Validation occurs on both client and server side

## Testing

### Unit Tests
Run the validation tests:
```bash
flutter test test/teacher_email_validation_test.dart
```

### Test Cases Covered
- Educational domain validation
- Specific domain validation
- Invalid domain rejection
- Email format validation
- Error message verification

## Future Enhancements

### Potential Improvements
1. **Domain Verification**: Verify domain ownership before adding
2. **Bulk Import**: Import multiple domains from CSV
3. **Domain Categories**: Categorize domains (university, school, etc.)
4. **Expiration Dates**: Set expiration dates for temporary domains
5. **Audit Logging**: Track domain changes and usage

### Integration Opportunities
1. **Email Verification**: Send verification emails to new domains
2. **Domain Analytics**: Track which domains are most used
3. **Auto-approval**: Automatically approve domains from known educational institutions

## Troubleshooting

### Common Issues

#### Domain Not Working
1. Check if domain is in the allowed list
2. Verify domain format (no @ symbol)
3. Ensure domain is properly saved in Firestore

#### Validation Errors
1. Check email format
2. Verify domain is lowercase
3. Ensure custom domains are loaded

#### Admin Access Issues
1. Verify user has admin role
2. Check Firestore permissions
3. Ensure proper authentication

### Debug Information
- Enable debug logging in TeacherEmailValidationService
- Check Firestore for domain configuration
- Verify validation service initialization

## API Reference

### TeacherEmailValidationService

#### Static Methods
- `isValidTeacherEmail(String email)`: Returns boolean
- `validateTeacherEmail(String email)`: Returns Future<String?>
- `validateTeacherEmailSync(String email)`: Returns String?
- `getAllowedDomains()`: Returns List<String>
- `getValidationMessage()`: Returns String
- `getShortValidationMessage()`: Returns String
- `loadCustomDomains()`: Returns Future<void>
- `refreshCustomDomains()`: Returns Future<void>
- `addAllowedDomain(String domain)`: Returns void
- `removeAllowedDomain(String domain)`: Returns void
- `isDomainAllowed(String domain)`: Returns boolean
