# Quick Start Guide: GitHub + Vercel Setup

## 🚀 Quick Setup (5 minutes)

### Step 1: Run Setup Script

**Windows:**
```bash
setup-github.bat
```

**Linux/Mac:**
```bash
chmod +x setup-github.sh
./setup-github.sh
```

This will:
- Initialize git repository (if not already done)
- Stage all files
- Create initial commit

### Step 2: Create GitHub Repository

1. Go to https://github.com/new
2. Repository name: `codequest` (or your preferred name)
3. **Important**: Choose **Public** or **Private**
4. **DO NOT** check "Initialize with README" (we already have one)
5. Click "Create repository"

### Step 3: Connect to GitHub

Replace `YOUR_USERNAME` and `YOUR_REPO_NAME` with your actual values:

```bash
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
git branch -M main
git push -u origin main
```

If you get authentication errors:
- Use GitHub CLI: `gh auth login`
- Or use SSH: `git remote set-url origin git@github.com:YOUR_USERNAME/YOUR_REPO_NAME.git`
- Or use Personal Access Token instead of password

### Step 4: Deploy to Vercel

#### Option A: Via Dashboard (Easiest)

1. Go to https://vercel.com
2. Sign in with GitHub (recommended)
3. Click "Add New Project"
4. Import your `codequest` repository
5. **Project Settings:**
   - Framework Preset: **Other**
   - Root Directory: `./`
   - Build Command: `flutter build web --release`
   - Output Directory: `build/web`
   - Install Command: `flutter pub get`
6. Click "Deploy"

**Note**: Vercel may need Flutter installed. If build fails:
- Go to Project Settings → Environment Variables
- Or use the Vercel CLI method below

#### Option B: Via Vercel CLI

```bash
# Install Vercel CLI
npm install -g vercel

# Login
vercel login

# Deploy (first time)
vercel

# Deploy to production
vercel --prod
```

### Step 5: Configure Vercel Build (if needed)

If Flutter is not available in Vercel, you can:

1. **Use GitHub Actions** (recommended):
   - The workflow is already in `.github/workflows/vercel-deploy.yml`
   - Add secrets to GitHub:
     - `VERCEL_TOKEN`: Get from Vercel → Settings → Tokens
     - `VERCEL_ORG_ID`: Found in Vercel project settings
     - `VERCEL_PROJECT_ID`: Found in Vercel project settings
   - Push to main branch to trigger deployment

2. **Or use custom build image**:
   - Configure in Vercel dashboard → Project Settings → Build & Development Settings

## ✅ Verification

After deployment:
1. Check your Vercel dashboard for deployment status
2. Visit your app URL (e.g., `https://codequest.vercel.app`)
3. Test authentication and main features

## 🔧 Troubleshooting

### Build fails with "Flutter not found"
- Vercel doesn't have Flutter by default
- Solution: Use GitHub Actions workflow or custom Docker image

### Firebase errors
- Check `lib/config/firebase_options.dart` has correct config
- Ensure Firebase project is set up correctly
- Check Firebase console for any issues

### Environment variables
- Add in Vercel Dashboard → Settings → Environment Variables
- Use for sensitive data (API keys, etc.)

## 📚 Next Steps

- Set up custom domain (Vercel → Settings → Domains)
- Configure Firebase Functions: `cd functions && firebase deploy --only functions`
- Set up GitHub Actions for CI/CD
- Configure monitoring and analytics

## 🆘 Need Help?

- Full guide: See [DEPLOYMENT.md](DEPLOYMENT.md)
- Vercel Docs: https://vercel.com/docs
- Flutter Web: https://docs.flutter.dev/deployment/web

