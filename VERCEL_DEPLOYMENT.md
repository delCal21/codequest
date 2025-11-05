# Vercel Flutter Deployment Guide

This guide explains how to deploy your Flutter web app to Vercel.

## Overview

Vercel doesn't have Flutter installed by default, so we use custom build scripts to install Flutter during the build process.

## How It Works

### Build Process

1. **Install Phase** (`install.sh`):
   - Downloads and installs Flutter SDK in the project root
   - Enables Flutter web support
   - Gets all Flutter dependencies (`flutter pub get`)

2. **Build Phase** (`build.sh`):
   - Verifies Flutter is installed
   - Cleans previous builds
   - Builds the Flutter web app in release mode
   - Output is generated in `build/web/`

### Configuration Files

- **`vercel.json`**: Vercel configuration
  - `installCommand`: Runs `install.sh` to set up Flutter
  - `buildCommand`: Runs `build.sh` to build the app
  - `outputDirectory`: `build/web` (where Flutter outputs the web build)

- **`install.sh`**: Installs Flutter SDK in project root
- **`build.sh`**: Builds the Flutter web app

## Deployment Steps

### 1. Push to GitHub

```bash
git add .
git commit -m "Your commit message"
git push origin main
```

### 2. Connect to Vercel

1. Go to [Vercel Dashboard](https://vercel.com)
2. Click "Add New Project"
3. Import your GitHub repository
4. Vercel will automatically detect `vercel.json` and use those settings

### 3. Verify Build Settings

In Vercel Project Settings, verify:
- **Framework Preset**: Other (or blank)
- **Build Command**: `bash build.sh` (should be auto-detected from vercel.json)
- **Output Directory**: `build/web` (should be auto-detected)
- **Install Command**: `bash install.sh` (should be auto-detected)

## Troubleshooting

### Error: "flutter: command not found"

**Cause**: Flutter isn't installed or PATH isn't set correctly.

**Solution**: 
- Ensure `install.sh` runs before `build.sh`
- Check that Flutter is installed in `./flutter/` directory
- Verify scripts use absolute paths: `./flutter/bin/flutter`

### Build Fails During Install

**Check logs for**:
- Git clone errors (network issues)
- Permission errors
- Disk space issues

**Solutions**:
- Ensure you have internet connection
- Check Vercel build logs for specific error
- Try increasing build timeout in Vercel settings

### Build Succeeds but App Doesn't Load

**Possible causes**:
1. Output directory mismatch
2. Routing issues (SPA)

**Solutions**:
- Verify `outputDirectory` is `build/web` in vercel.json
- Check that `rewrites` in vercel.json routes all paths to `index.html`
- Verify Firebase configuration for web

### Slow Build Times

**Causes**:
- Flutter SDK download on every build
- Large dependency tree

**Solutions**:
- Vercel should cache the `flutter/` directory between builds
- Consider using GitHub Actions for building and deploying artifacts

## Environment Variables

If your app needs environment variables:

1. Go to Vercel Project Settings → Environment Variables
2. Add your variables (e.g., Firebase config)
3. Restart deployment

## Custom Domain

1. Go to Project Settings → Domains
2. Add your custom domain
3. Follow DNS configuration instructions

## Monitoring

- **Build Logs**: Available in Vercel dashboard under "Deployments"
- **Function Logs**: Check Vercel dashboard for serverless function logs
- **Analytics**: Enable in Vercel project settings

## Best Practices

1. **Never commit**:
   - `flutter/` directory (already in .gitignore)
   - `build/` directory (already in .gitignore)
   - Firebase service account keys
   - Environment files with secrets

2. **Test locally first**:
   ```bash
   flutter pub get
   flutter build web --release
   ```

3. **Monitor build times**: First build takes longer (Flutter download), subsequent builds should be faster

4. **Use GitHub Actions** (optional): For more control, use GitHub Actions to build and deploy

## Alternative: GitHub Actions Deployment

If Vercel builds are problematic, you can use GitHub Actions:

1. See `.github/workflows/vercel-deploy.yml`
2. Set up Vercel secrets in GitHub
3. Workflow will build and deploy automatically

## Support

If you encounter issues:
1. Check Vercel build logs
2. Verify `vercel.json` configuration
3. Test `install.sh` and `build.sh` locally
4. Check Flutter version compatibility

