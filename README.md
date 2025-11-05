# CodeQuest

A comprehensive learning platform for coding challenges and courses.

## Features

### Admin Challenge Management

The admin section now includes enhanced challenge organization features:

#### Course-Based Challenge Organization
- **Organized Display**: Challenges are now grouped by course (e.g., Java, Python, C++) in expandable sections
- **Visual Course Identification**: Each course has a unique color and avatar for easy identification
- **Lesson Ordering**: Challenges within each course are automatically sorted by lesson number
- **Course Filtering**: Admins can filter challenges by specific courses using the dropdown in the app bar
- **Quick Course Actions**: When filtering by a course, a special button appears to quickly add challenges to that specific course

#### Enhanced Challenge Creation
- **Course Assignment**: Prominent course selection with visual organization
- **Language Auto-Suggestion**: Programming language is automatically suggested based on course title (e.g., "Java Programming" suggests Java)
- **Improved Form Layout**: Better organized form with sections for:
  - Course Assignment
  - Challenge Details
  - Challenge Configuration
  - Passing Score
- **Visual Indicators**: Language chips and course colors help identify challenge types

#### Challenge Statistics
- **Summary Dashboard**: Overview showing total challenges and breakdown by course
- **Course-Specific Stats**: Number of challenges per course displayed in the summary
- **Filter Information**: Clear indication when viewing filtered results

#### Usage Instructions
1. **View All Challenges**: Navigate to Admin → Challenges to see all challenges organized by course
2. **Filter by Course**: Use the dropdown in the app bar to filter challenges by specific courses
3. **Add Course-Specific Challenge**: When filtered, use the green "Add Challenge to [Course]" button
4. **Create General Challenge**: Use the floating action button to create challenges for any course
5. **Auto-Language Selection**: When selecting a course with a programming language in the title, the language field will be automatically populated

This organization makes it much easier for admins to manage challenges for specific programming courses like Java, Python, or any other programming language course.

## Getting Started

### Prerequisites

- Flutter SDK (>=3.2.3)
- Dart SDK
- Firebase account
- Node.js (for Firebase Functions)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/YOUR_USERNAME/codequest.git
cd codequest
```

2. Install Flutter dependencies:
```bash
flutter pub get
```

3. Install Firebase Functions dependencies:
```bash
cd functions
npm install
cd ..
```

4. Configure Firebase:
   - Ensure Firebase is configured in `lib/config/firebase_options.dart`
   - Update Firebase configuration for your project if needed

5. Run the application:
```bash
flutter run
```

## Deployment

### Quick Setup

1. **GitHub Setup**:
   - Run `setup-github.bat` (Windows) or `setup-github.sh` (Linux/Mac)
   - Or manually initialize git and push to GitHub

2. **Vercel Deployment**:
   - See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed instructions
   - Quick steps:
     1. Sign in to [Vercel](https://vercel.com)
     2. Import your GitHub repository
     3. Configure build settings (already in `vercel.json`)
     4. Deploy!

### Deployment Options

- **Vercel** (Recommended for Web): 
  - See [VERCEL_DEPLOYMENT.md](VERCEL_DEPLOYMENT.md) for detailed Vercel deployment guide
  - See [DEPLOYMENT.md](DEPLOYMENT.md) for general deployment instructions
  - Test your setup: Run `test_vercel_build.sh` (Linux/Mac) or `test_vercel_build.bat` (Windows)
- **Firebase Hosting**: Already configured in `firebase.json`
- **GitHub Actions**: CI/CD workflow available in `.github/workflows/`

## Project Structure

```
codequest/
├── lib/                    # Main application code
│   ├── config/            # Configuration files
│   ├── core/              # Core functionality
│   ├── features/          # Feature modules
│   │   ├── admin/        # Admin features
│   │   ├── auth/         # Authentication
│   │   ├── challenges/   # Challenge management
│   │   ├── courses/      # Course management
│   │   ├── forums/       # Forum features
│   │   ├── student/      # Student features
│   │   └── teacher/      # Teacher features
│   ├── services/         # Service layer
│   └── widgets/          # Shared widgets
├── functions/            # Firebase Cloud Functions
├── web/                  # Web-specific files
├── android/              # Android configuration
└── assets/               # Images, fonts, etc.
```

## Features Overview

- **User Management**: Admin, Teacher, and Student roles
- **Course Management**: Create and manage programming courses
- **Challenges**: Coding challenges with JDoodle integration
- **Forums**: Discussion forums for courses
- **Certificates**: Automated certificate generation
- **Notifications**: Real-time notifications
- **Analytics**: Activity tracking and reporting

## Technology Stack

- **Frontend**: Flutter (Web, Android)
- **Backend**: Firebase (Firestore, Auth, Storage, Functions)
- **Build**: Flutter Build System
- **Deployment**: Vercel (Web), Firebase Hosting

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is private and proprietary.

## Support

For issues and questions:
- Check [DEPLOYMENT.md](DEPLOYMENT.md) for deployment issues
- Review Firebase documentation for backend issues
- Check Flutter documentation for frontend issues

---

For detailed deployment instructions, see [DEPLOYMENT.md](DEPLOYMENT.md).
