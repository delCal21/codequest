# Deployment Guide

This guide will help you deploy CodeQuest to GitHub and Vercel.

## Prerequisites

- Git installed on your system
- GitHub account
- Vercel account (sign up at https://vercel.com)
- Flutter SDK installed (for local builds)
- Firebase project configured

## Step 1: Initialize Git Repository

1. Open your terminal/command prompt in the project root directory.

2. Initialize git repository:
```bash
git init
```

3. Stage all files:
```bash
git add .
```

4. Create your first commit:
```bash
git commit -m "Initial commit: CodeQuest learning platform"
```

## Step 2: Create GitHub Repository

1. Go to GitHub and create a new repository:
   - Visit https://github.com/new
   - Choose a repository name (e.g., `codequest`)
   - Choose visibility (Public or Private)
   - **DO NOT** initialize with README, .gitignore, or license (we already have these)
   - Click "Create repository"

2. Connect your local repository to GitHub:
```bash
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
```

Replace `YOUR_USERNAME` and `YOUR_REPO_NAME` with your actual GitHub username and repository name.

3. Push your code to GitHub:
```bash
git branch -M main
git push -u origin main
```

## Step 3: Deploy to Vercel

### Option A: Deploy via Vercel Dashboard (Recommended)

1. **Sign in to Vercel**
   - Go to https://vercel.com
   - Sign in with your GitHub account (recommended for easier integration)

2. **Import Project**
   - Click "Add New Project"
   - Import your GitHub repository (it should appear in the list)
   - Select your repository

3. **Configure Project Settings**
   - **Framework Preset**: Other (or leave blank)
   - **Root Directory**: `./` (root)
   - **Build Command**: `flutter build web --release`
   - **Output Directory**: `build/web`
   - **Install Command**: `flutter pub get`

4. **Environment Variables** (if needed)
   - Add any environment variables your app needs
   - Firebase configuration is already in the code, but if you use environment variables, add them here

5. **Deploy**
   - Click "Deploy"
   - Wait for the build to complete
   - Your app will be live at a URL like `https://your-project-name.vercel.app`

### Option B: Deploy via Vercel CLI

1. **Install Vercel CLI**:
```bash
npm install -g vercel
```

2. **Login to Vercel**:
```bash
vercel login
```

3. **Deploy**:
```bash
vercel
```

Follow the prompts:
- Set up and deploy? **Yes**
- Which scope? (Select your account)
- Link to existing project? **No** (for first deployment)
- Project name? (Enter your project name or press Enter for default)
- Directory? `./` (or press Enter)
- Override settings? **No** (or Yes if you want to customize)

4. **Production Deployment**:
```bash
vercel --prod
```

## Step 4: Configure Custom Domain (Optional)

1. In Vercel dashboard, go to your project settings
2. Navigate to "Domains"
3. Add your custom domain
4. Follow DNS configuration instructions provided by Vercel

## Step 5: Configure Firebase Functions (if needed)

If you're using Firebase Cloud Functions, they need to be deployed separately:

```bash
cd functions
npm install
firebase deploy --only functions
```

Make sure you have Firebase CLI installed:
```bash
npm install -g firebase-tools
firebase login
```

## Important Notes

### Firebase Configuration
- Your Firebase configuration is currently hardcoded in `lib/config/firebase_options.dart`
- For production, consider using environment variables or Firebase Remote Config
- Never commit Firebase service account keys or sensitive credentials

### Build Configuration
- Vercel will automatically detect the `vercel.json` configuration
- The build command uses `flutter build web --release` for optimized production builds
- Build time depends on your project size and Vercel's resources

### Environment Variables
If you need to use environment variables:
1. Add them in Vercel dashboard → Project Settings → Environment Variables
2. For local development, create a `.env` file (already in .gitignore)
3. Access them in your Flutter code using `dart:io` Platform.environment

### Continuous Deployment
- Vercel automatically deploys when you push to the main branch
- You can configure branch previews in Vercel settings
- Each push creates a new deployment preview

## Troubleshooting

### Build Fails
- Check Vercel build logs for errors
- Ensure Flutter SDK is available in Vercel (may need to specify in vercel.json)
- Verify all dependencies are in `pubspec.yaml`

### Flutter Not Found
If Vercel doesn't have Flutter installed, you may need to:
1. Use a custom build image
2. Or use GitHub Actions to build and deploy
3. Or use Vercel's Build Command to install Flutter first

### Firebase Functions Not Working
- Ensure Firebase Functions are deployed separately
- Check Firebase project configuration
- Verify CORS settings for web app

## Next Steps

1. Set up GitHub Actions for CI/CD (optional)
2. Configure Firebase Hosting as backup/alternative
3. Set up monitoring and analytics
4. Configure custom domain with SSL

## Support

For issues:
- Vercel Docs: https://vercel.com/docs
- Flutter Web: https://docs.flutter.dev/deployment/web
- Firebase: https://firebase.google.com/docs

