# 🚀 Certificate System Deployment Guide

## **Problem Identified:**
The QR code isn't working because the certificate download page isn't properly hosted. We need to set up Firebase Hosting to serve the certificate download page.

## **Solution:**
I've configured Firebase Hosting and updated the QR codes to point to the correct URLs.

---

## **📋 Step-by-Step Deployment:**

### **Step 1: Install Firebase CLI (if not already installed)**
```bash
npm install -g firebase-tools
```

### **Step 2: Login to Firebase**
```bash
firebase login
```

### **Step 3: Initialize Firebase Hosting (if not already done)**
```bash
firebase init hosting
```
- Select your project: `codequest-a5317`
- Public directory: `web`
- Single-page app: `Yes`
- Overwrite index.html: `No`

### **Step 4: Build Flutter Web App**
```bash
flutter build web
```

### **Step 5: Deploy to Firebase Hosting**
```bash
firebase deploy --only hosting
```

### **Step 6: Test the Certificate System**
1. Open: `https://codequest-a5317.web.app/test-certificate.html`
2. Verify the test page loads correctly
3. Test with a certificate ID: `https://codequest-a5317.web.app/certificate-download.html?cert=test123`

---

## **🔧 What I've Fixed:**

### **1. Firebase Configuration (`firebase.json`)**
```json
{
  "hosting": {
    "public": "web",
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

### **2. Updated QR Code URLs**
- **Before:** `https://codequest-app.web.app/certificate-download.html?cert={certificateId}`
- **After:** `https://codequest-a5317.web.app/certificate-download.html?cert={certificateId}`

### **3. Created Test Page**
- `web/test-certificate.html` - Test page to verify hosting works
- Shows URL parameters and certificate ID extraction

---

## **🎯 Expected Results After Deployment:**

### **QR Code Scanning:**
1. **Scan QR code** → Opens `https://codequest-a5317.web.app/certificate-download.html?cert={certificateId}`
2. **Certificate page loads** → Shows certificate information
3. **Download buttons work** → Direct downloads from Firebase Storage

### **Test URLs:**
- **Main App:** `https://codequest-a5317.web.app/`
- **Test Page:** `https://codequest-a5317.web.app/test-certificate.html`
- **Certificate Download:** `https://codequest-a5317.web.app/certificate-download.html?cert=test123`

---

## **🚨 Troubleshooting:**

### **If QR code still doesn't work:**
1. **Check Firebase Hosting is deployed:** Visit `https://codequest-a5317.web.app/test-certificate.html`
2. **Verify certificate ID format:** Should be `StudentName_CourseName_Timestamp`
3. **Test with manual URL:** Try the certificate URL directly in browser
4. **Check Firebase Storage:** Ensure certificates are uploaded properly

### **If deployment fails:**
1. **Check Firebase login:** `firebase login`
2. **Check project selection:** `firebase use codequest-a5317`
3. **Check web build:** `flutter build web`
4. **Check Firebase CLI:** `firebase --version`

---

## **📱 Quick Test:**

1. **Deploy the system** using the steps above
2. **Generate a certificate** in your app
3. **Scan the QR code** with your phone
4. **Verify it opens** the certificate download page
5. **Test downloads** in all three formats

---

## **🎉 After Deployment:**

Your certificate system will be fully functional with:
- ✅ Working QR codes
- ✅ Firebase-hosted download page
- ✅ Direct file downloads from Firebase Storage
- ✅ Editable certificates in multiple formats
- ✅ Professional certificate generation

**The QR code scanning will work perfectly once Firebase Hosting is deployed!** 🚀
