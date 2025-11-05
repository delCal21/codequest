# Email Service Setup Guide

## 🚨 Current Issue
The email service is failing because the EmailJS service ID is not configured. You need to set up EmailJS or use an alternative email service.

## 🚀 Quick Fix Options

### Option 1: Set Up EmailJS (Recommended - Free)

1. **Go to EmailJS**: https://www.emailjs.com/
2. **Sign up for free** (200 emails/month free)
3. **Create a new service**:
   - Click "Add New Service"
   - Choose "Gmail" as service type
   - Connect your Gmail account
   - Note down the **Service ID** (e.g., `service_abc123`)
4. **Create an email template**:
   - Click "Create New Template"
   - Template ID: `template_welcome` (or any name you prefer)
   - Subject: `Welcome to CodeQuest - Your Teacher Account`
   - Content: Use the template below
5. **Get your Public Key**:
   - Go to Account → API Keys
   - Copy your **Public Key**
6. **Update the code** in `lib/services/real_email_service.dart`:
   ```dart
   static const String _serviceId = 'service_abc123'; // Your actual service ID
   static const String _templateId = 'template_welcome'; // Your template ID
   static const String _publicKey = 'your_actual_public_key'; // Your public key
   ```

### Option 2: Use Alternative Email Service (No Setup Required)

I've created a working email service that doesn't require EmailJS setup. This service will work immediately but emails will be logged to console instead of actually sent.

## 📧 Email Template for EmailJS

Use this template in EmailJS:

```
Subject: Welcome to CodeQuest - Your Teacher Account

Dear {{teacher_name}},

Welcome to CodeQuest! Your teacher account has been created by the administrator.

Your login credentials:
Email: {{to_email}}
Password: {{password}}

Please log in to the CodeQuest system and change your password for security.

Best regards,
CodeQuest Administration Team

---
This is an automated message. Please do not reply.
```

## 🔧 Alternative: Working Email Service (No Setup)

If you want to test the system immediately without setting up EmailJS, I can switch you to a working email service that logs emails to console. This will allow you to test the teacher registration flow while you set up EmailJS later.

## 🧪 Testing

After configuration, test with:
```dart
await RealEmailService.testEmailService();
```

## ✅ What Happens After Setup

1. **Admin registers teacher** → Teacher account created
2. **Email sent automatically** → Real email to teacher's inbox
3. **Teacher receives email** → Professional welcome message with credentials
4. **No manual steps** → Completely automated

## 🆘 Troubleshooting

### Common Issues:
- **"Service not found"** → Check service ID matches exactly
- **"Template not found"** → Check template ID matches exactly
- **"Invalid public key"** → Check public key is correct
- **"400 error"** → Usually means service ID is wrong

### Quick Test:
1. Go to https://dashboard.emailjs.com/admin
2. Verify your service ID, template ID, and public key
3. Make sure they match exactly in the code (case-sensitive)

## 🎉 Success!

Once configured, teachers will receive **real emails** in their inbox automatically when registered!

The system will be **fully automated** - no manual email sending required! 📧✨
