# Gmail Email Setup Guide for Teacher Notifications

This guide will help you configure Gmail to send actual email notifications to teachers when they are registered by an admin.

## 📧 What This Does

When an admin registers a new teacher:
1. **Real Gmail email** is sent to the teacher's email address
2. **Email contains** welcome message and password reset link
3. **Teacher receives** the email in their Gmail inbox (not just app notifications)

## 🔧 Step-by-Step Setup

### Step 1: Enable 2-Factor Authentication on Gmail

1. Go to [Google Account Security](https://myaccount.google.com/security)
2. Sign in with your Gmail account
3. Under "Signing in to Google", click **2-Step Verification**
4. Follow the setup process to enable 2FA

### Step 2: Generate App Password

1. In the same Google Account Security page
2. Under "Signing in to Google", click **App passwords**
3. Select **Mail** as the app
4. Select **Other (Custom name)** as the device
5. Enter "CodeQuest Firebase Functions" as the name
6. Click **Generate**
7. **Copy the 16-character password** (it looks like: `abcd efgh ijkl mnop`)

### Step 3: Configure Firebase Functions

Open your terminal/command prompt in the project directory and run:

```bash
firebase functions:config:set gmail.user="your-email@gmail.com" gmail.pass="your-16-char-app-password"
```

**Replace:**
- `your-email@gmail.com` with your actual Gmail address
- `your-16-char-app-password` with the password from Step 2

### Step 4: Deploy Firebase Functions

```bash
firebase deploy --only functions
```

### Step 5: Test the Email System

1. Go to your **Admin Dashboard**
2. Scroll down to **"Email Configuration Test"** section
3. Click **"Send Gmail Test Email"**
4. Check your **Gmail inbox** for the test email
5. If you receive it, the system is working! ✅

## 🧪 Testing Teacher Registration

1. Go to **Teachers** page in admin dashboard
2. Click **"Register Teacher"**
3. Fill in teacher details:
   - Name: Test Teacher
   - Email: teacher@gmail.com (use a real email you can check)
   - Password: (any secure password)
4. Click **"Register Teacher"**
5. **Check the teacher's Gmail inbox** for the welcome email

## 🔍 Troubleshooting

### If you don't receive emails:

1. **Check Firebase Functions Logs:**
   ```bash
   firebase functions:log
   ```
   Look for error messages about Gmail credentials

2. **Verify Gmail Credentials:**
   - Make sure you're using an **App Password**, not your regular password
   - Ensure 2FA is enabled on your Gmail account
   - Check that the email address is correct

3. **Test with Email Test Widget:**
   - Use the test widget in the admin dashboard
   - It will show exactly what's wrong

4. **Check Gmail Spam Folder:**
   - Sometimes emails go to spam initially

### Common Error Messages:

- **"Gmail credentials not configured"** → Run the config command again
- **"Authentication failed"** → Check your App Password
- **"User not found"** → Check the email address

## 📱 What Teachers Receive

When a teacher is registered, they get a **real Gmail email** with:

- **Subject:** "Welcome to CodeQuest – Your Teacher Account"
- **Content:** Professional welcome message
- **Password Reset Link:** To set their initial password
- **Instructions:** How to access their account

## ✅ Success Indicators

You'll know it's working when:
- ✅ Test email arrives in your Gmail inbox
- ✅ Teacher registration shows "welcome email sent" message
- ✅ Teachers receive actual Gmail emails (not just app notifications)
- ✅ Firebase logs show "Welcome email sent successfully"

## 🆘 Need Help?

If you're still having issues:
1. Check the Firebase Functions logs for detailed error messages
2. Verify your Gmail App Password is correct
3. Make sure 2FA is enabled on your Gmail account
4. Try the test email function first before registering teachers

The system sends **real Gmail emails** to teachers' inboxes, not just in-app notifications!
