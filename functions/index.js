/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onRequest, onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const axios = require('axios');
if (!admin.apps.length) {
  admin.initializeApp();
}

// Read Gmail creds from env config (set with: firebase functions:config:set gmail.user="..." gmail.pass="...")
let gmailEmail = '';
let gmailPassword = '';
try {
  const config = functions.config();
  gmailEmail = (config.gmail && config.gmail.user) || process.env.GMAIL_USER || '';
  gmailPassword = (config.gmail && config.gmail.pass) || process.env.GMAIL_PASS || '';
} catch (error) {
  // Fallback to environment variables if config is not available
  gmailEmail = process.env.GMAIL_USER || '';
  gmailPassword = process.env.GMAIL_PASS || '';
}

// Initialize nodemailer transporter (fix: use createTransport)
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: gmailEmail,
    pass: gmailPassword,
  },
});

// JDoodle credentials
const JDoodleClientId = 'f87072d962e576eb73b5b3fff4b4dcd6';
const JDoodleClientSecret = '3ddd18797f1f5bd9fdcb43d76296660fb1dee99a26cc4737a9a2397834073687';

// Rate limiting configuration
const MAX_REQUESTS_PER_DAY = 200; // Adjust based on your JDoodle plan
const MAX_REQUESTS_PER_MINUTE = 10;
const CACHE_EXPIRY_HOURS = 24;

// In-memory cache for storing execution results
const executionCache = new Map();

// Track daily usage per user
const dailyUsage = new Map();
const recentRequests = new Map();

// Callable function to grade code
exports.gradeCodingChallenge = onCall(async (request) => {
  const { code, language, versionIndex, testCases } = request.data;
  const context = { auth: request.auth };
  
  // Check authentication
  if (!context.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const userId = context.auth.uid;
  
  // Check rate limits
  if (!canMakeRequest(userId)) {
    throw new HttpsError('resource-exhausted', 'Rate limit exceeded. Please try again later.');
  }
  
  // Create cache key
  const cacheKey = generateCacheKey(code, language, versionIndex, testCases);
  
  // Check cache first
  const cachedResult = getCachedResult(cacheKey);
  if (cachedResult) {
    console.log('Returning cached result for code execution');
    return cachedResult;
  }
  
  // Track request
  trackRequest(userId);
  
  let passed = 0;
  let totalExecutions = 0;

  try {
    for (const testCase of testCases) {
      totalExecutions++;
      
      const res = await axios.post('https://api.jdoodle.com/v1/execute', {
        clientId: JDoodleClientId,
        clientSecret: JDoodleClientSecret,
        script: code,
        language: language,
        versionIndex: versionIndex,
        stdin: testCase.input,
      }, {
        timeout: 10000, // 10 second timeout
      });

      const output = (res.data.output || '').trim();
      if (output === (testCase.expectedOutput || '').trim()) {
        passed++;
      }
    }

    const score = (passed / testCases.length) * 100;
    const result = { score, passed, total: testCases.length };
    
    // Cache the result
    cacheResult(cacheKey, result);
    
    return result;
  } catch (error) {
    console.error('Error in gradeCodingChallenge:', error);
    
    if (error.response && error.response.status === 429) {
      throw new HttpsError('resource-exhausted', 'JDoodle rate limit exceeded. Please try again later.');
    }
    
    throw new HttpsError('internal', 'Error executing code: ' + error.message);
  }
});

// Check if user can make a request based on rate limits
function canMakeRequest(userId) {
  const now = new Date();
  
  // Check daily limit
  const userDailyUsage = dailyUsage.get(userId) || { count: 0, date: null };
  
  if (!userDailyUsage.date || 
      (now - userDailyUsage.date) >= 24 * 60 * 60 * 1000) { // 24 hours in milliseconds
    userDailyUsage.count = 0;
    userDailyUsage.date = now;
  }
  
  if (userDailyUsage.count >= MAX_REQUESTS_PER_DAY) {
    console.log(`Daily limit reached for user ${userId}: ${userDailyUsage.count}/${MAX_REQUESTS_PER_DAY}`);
    return false;
  }
  
  // Check minute limit
  const userRecentRequests = recentRequests.get(userId) || [];
  const oneMinuteAgo = new Date(now.getTime() - 60 * 1000);
  
  // Remove requests older than 1 minute
  const filteredRequests = userRecentRequests.filter(time => time > oneMinuteAgo);
  
  if (filteredRequests.length >= MAX_REQUESTS_PER_MINUTE) {
    console.log(`Minute limit reached for user ${userId}: ${filteredRequests.length}/${MAX_REQUESTS_PER_MINUTE}`);
    return false;
  }
  
  return true;
}

// Track a request for a user
function trackRequest(userId) {
  const now = new Date();
  
  // Update daily usage
  const userDailyUsage = dailyUsage.get(userId) || { count: 0, date: now };
  userDailyUsage.count++;
  dailyUsage.set(userId, userDailyUsage);
  
  // Update recent requests
  const userRecentRequests = recentRequests.get(userId) || [];
  userRecentRequests.push(now);
  recentRequests.set(userId, userRecentRequests);
  
  console.log(`Request tracked for user ${userId}. Daily: ${userDailyUsage.count}/${MAX_REQUESTS_PER_DAY}`);
}

// Generate cache key
function generateCacheKey(code, language, versionIndex, testCases) {
  const data = JSON.stringify({ code, language, versionIndex, testCases });
  return Buffer.from(data).toString('base64');
}

// Get cached result
function getCachedResult(cacheKey) {
  const cached = executionCache.get(cacheKey);
  if (cached) {
    const now = new Date();
    const expiryTime = new Date(cached.timestamp.getTime() + CACHE_EXPIRY_HOURS * 60 * 60 * 1000);
    
    if (now < expiryTime) {
      return cached.result;
    } else {
      executionCache.delete(cacheKey);
    }
  }
  return null;
}

// Cache result
function cacheResult(cacheKey, result) {
  executionCache.set(cacheKey, {
    result: result,
    timestamp: new Date()
  });
  
  // Limit cache size to prevent memory issues
  if (executionCache.size > 1000) {
    const firstKey = executionCache.keys().next().value;
    executionCache.delete(firstKey);
  }
  
  console.log('Result cached successfully');
}

// Function to get usage statistics (for admin purposes)
exports.getJDoodleUsageStats = onCall(async (request) => {
  const context = { auth: request.auth };
  // Check if user is admin
  if (!context.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  // You can add admin check here if needed
  
  return {
    dailyUsage: Object.fromEntries(dailyUsage),
    recentRequests: Object.fromEntries(recentRequests),
    cacheSize: executionCache.size,
    limits: {
      daily: MAX_REQUESTS_PER_DAY,
      minute: MAX_REQUESTS_PER_MINUTE
    }
  };
});

// Function to reset usage counters (for admin purposes)
exports.resetJDoodleUsage = onCall(async (request) => {
  const context = { auth: request.auth };
  // Check if user is admin
  if (!context.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  // You can add admin check here if needed
  
  dailyUsage.clear();
  recentRequests.clear();
  executionCache.clear();
  
  console.log('JDoodle usage counters reset');
  return { success: true };
});

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

exports.notifyStudentsOnNewForum = onDocumentCreated('forums/{forumId}', async (event) => {
    if (!event.data) {
      logger.error('Event data is missing for notifyStudentsOnNewForum');
      return null;
    }
    const forum = event.data.data();
    const forumId = event.params.forumId;
    // Get all students (optionally filter by courseId)
    const studentsSnapshot = await admin.firestore().collection('users').where('role', '==', 'student').get();
    const notifications = [];
    studentsSnapshot.forEach(studentDoc => {
      notifications.push(admin.firestore().collection('notifications').add({
        userId: studentDoc.id,
        type: 'forum',
        title: 'New Forum Posted',
        message: `${forum.authorName || 'A teacher'} posted: ${forum.title}`,
        forumId: forumId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
      }));
    });
    return Promise.all(notifications);
  });

// ================================================
// Email notification: send email when a TEACHER is registered by admin
// Triggered when a new document is created in 'users' collection
exports.sendWelcomeEmailOnTeacherCreate = onDocumentCreated('users/{userId}', async (event) => {
    try {
      if (!event.data) {
        logger.error('Event data is missing for sendWelcomeEmailOnTeacherCreate');
        return null;
      }
      const userData = event.data.data() || {};
      const userId = event.params.userId;
      
      logger.info('Processing new user document', { 
        userId, 
        userData: JSON.stringify(userData),
        hasEmail: !!userData.email,
        role: userData.role 
      });

      // Accept both 'role' string and enum-style storage forms
      const role = (userData.role || '').toString().toLowerCase();
      const email = userData.email;
      const name = userData.name || userData.fullName || 'Teacher';

      if (!email) {
        logger.warn('New users document missing email; skipping email send', { 
          userId, 
          userData: JSON.stringify(userData) 
        });
        return null;
      }

      logger.info('Checking role for email send', { 
        userId, 
        email, 
        role, 
        isTeacher: role === 'teacher' 
      });

      if (role !== 'teacher') {
        logger.info('User is not a teacher, skipping email', { 
          userId, 
          email, 
          role 
        });
        return null; // Only email teachers
      }

      // Check if Gmail credentials are configured
      if (!gmailEmail || !gmailPassword) {
        logger.error('Gmail credentials not configured', { 
          hasEmail: !!gmailEmail, 
          hasPassword: !!gmailPassword 
        });
        return null;
      }

      logger.info('Attempting to send welcome email', { userId, email, name });

      // Generate a password reset link so the teacher can set their password
      let resetLink = null;
      try {
        resetLink = await admin.auth().generatePasswordResetLink(email);
        logger.info('Password reset link generated successfully', { userId, email });
      } catch (e) {
        logger.error('Failed generating password reset link', { 
          userId, 
          email, 
          error: e.message 
        });
      }

      const html = `
        <div style="font-family: Arial, sans-serif; color:#222">
          <h2>Welcome to CodeQuest, ${name}!</h2>
          <p>Your teacher account has been created by the administrator.</p>
          ${resetLink ? `<p>To set your password and access your account, click the link below:</p>
          <p><a href="${resetLink}" target="_blank" style="color:#1a73e8">Set your password</a></p>` : '<p>You can set your password using the "Forgot password" option in the login page.</p>'}
          <p>If you did not expect this email, please ignore it.</p>
          <hr/>
          <p style="font-size:12px;color:#666">This is an automated message. Please do not reply.</p>
        </div>`;

      const mailOptions = {
        from: `CodeQuest Admin <${gmailEmail}>`,
        to: email,
        subject: 'Welcome to CodeQuest – Your Teacher Account',
        html,
      };

      logger.info('Sending email with options', { 
        userId, 
        email, 
        from: mailOptions.from,
        subject: mailOptions.subject 
      });

      await transporter.sendMail(mailOptions);
      logger.info('Welcome email sent successfully to teacher', { 
        userId, 
        email, 
        name 
      });
      return null;
    } catch (error) {
      logger.error('Error sending welcome email on teacher create', { 
        userId: event.params.userId,
        error: error.message,
        stack: error.stack 
      });
      return null;
    }
  });

// Test function to check email configuration and send a test email
exports.testEmailConfiguration = onCall(async (request) => {
  const context = { auth: request.auth };
  // Check authentication
  if (!context.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  try {
    logger.info('Testing email configuration', {
      hasGmailEmail: !!gmailEmail,
      hasGmailPassword: !!gmailPassword,
      gmailEmail: gmailEmail ? `${gmailEmail.substring(0, 3)}***` : 'not set'
    });

    if (!gmailEmail || !gmailPassword) {
      return {
        success: false,
        error: 'Gmail credentials not configured',
        details: {
          hasEmail: !!gmailEmail,
          hasPassword: !!gmailPassword
        }
      };
    }

    // Test email to the authenticated user
    const testEmail = context.auth.token.email;
    const testHtml = `
      <div style="font-family: Arial, sans-serif; color:#222">
        <h2>CodeQuest Email Test</h2>
        <p>This is a test email to verify that the email notification system is working correctly.</p>
        <p>If you received this email, the system is configured properly!</p>
        <hr/>
        <p style="font-size:12px;color:#666">Test sent at: ${new Date().toISOString()}</p>
      </div>`;

    const mailOptions = {
      from: `CodeQuest Admin <${gmailEmail}>`,
      to: testEmail,
      subject: 'CodeQuest Email Test',
      html: testHtml,
    };

    await transporter.sendMail(mailOptions);
    
    logger.info('Test email sent successfully', { testEmail });
    
    return {
      success: true,
      message: 'Test email sent successfully',
      testEmail: testEmail
    };
  } catch (error) {
    logger.error('Error testing email configuration', { error: error.message });
    return {
      success: false,
      error: error.message
    };
  }
});
