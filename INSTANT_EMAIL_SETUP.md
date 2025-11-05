# Instant Email Setup Guide

This guide will help you set up **automatic email sending** so teachers receive emails directly in their inbox when registered.

## 🚀 Quick Setup (5 minutes)

### **Option 1: EmailJS (Recommended - Free)**

1. **Go to EmailJS**: https://www.emailjs.com/
2. **Sign up for free** (200 emails/month free)
3. **Create a new service**:
   - Service Type: Gmail
   - Connect your Gmail account
4. **Create an email template**:
   - Template ID: `template_welcome`
   - Subject: `Welcome to CodeQuest - Your Teacher Account`
   - Content: Use the template below
5. **Get your Public Key** from the integration page
6. **Update the code** with your keys

### **Option 2: Brevo (Formerly Sendinblue) - Free**

1. **Go to Brevo**: https://www.brevo.com/
2. **Sign up for free** (300 emails/day free)
3. **Get your API key** from the settings
4. **Update the service** to use Brevo API

## 📧 Email Template

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

## 🔧 Code Configuration

### **Step 1: Update EmailJS Keys**

In `lib/services/real_email_service.dart`, replace:

```dart
static const String _serviceId = 'YOUR_EMAILJS_PUBLIC_KEY';
static const String _templateId = 'template_welcome';
static const String _publicKey = 'YOUR_EMAILJS_PUBLIC_KEY';
```

With your actual EmailJS keys.

### **Step 2: Switch to Real Email Service**

In `lib/features/admin/presentation/pages/users_page.dart`, change:

```dart
import 'package:codequest/services/simple_direct_email.dart';
```

To:

```dart
import 'package:codequest/services/real_email_service.dart';
```

And update the service call:

```dart
final emailSent = await RealEmailService.sendWelcomeEmail(
  teacherName: _nameController.text.trim(),
  teacherEmail: _emailController.text.trim(),
  teacherPassword: _passwordController.text.trim(),
);
```

## 🧪 Testing

1. **Test the service**:
   ```dart
   await RealEmailService.testEmailService();
   ```

2. **Register a teacher** with a real email address
3. **Check the teacher's inbox** for the welcome email

## ✅ What Happens Now

1. **Admin registers teacher** → Teacher account created
2. **Email sent automatically** → Real email to teacher's inbox
3. **Teacher receives email** → Professional welcome message with credentials
4. **No manual steps** → Completely automated

## 🆘 Troubleshooting

### **If emails don't arrive:**

1. **Check spam folder**
2. **Verify EmailJS configuration**
3. **Check console logs** for error messages
4. **Test with a different email address**

### **Common Issues:**

- **"Service not found"** → Check service ID
- **"Template not found"** → Check template ID
- **"Invalid public key"** → Check public key

## 🎉 Success!

Once configured, teachers will receive **real emails** in their inbox automatically when registered!

The system is now **fully automated** - no manual email sending required! 📧✨
