# JDoodle API Limits Management Guide

## Overview

This guide explains how to manage and optimize JDoodle API usage in your CodeQuest application to avoid hitting rate limits and improve performance.

## Current Implementation

Your CodeQuest app uses JDoodle in two main areas:

1. **Client-side execution** (`lib/services/jdoodle_service.dart`) - For students to run code in real-time
2. **Server-side grading** (`functions/index.js`) - For automatically grading coding challenges

## JDoodle Plan Limits

### Free Tier
- **200 requests per day**
- Basic language support
- Limited execution time

### Paid Plans
- **Starter**: 1,000 requests/day
- **Professional**: 5,000 requests/day  
- **Enterprise**: Custom limits

## Solutions to Remove/Increase Limits

### Option 1: Upgrade JDoodle Plan (Recommended)

1. **Visit JDoodle Pricing**: https://www.jdoodle.com/compiler-api
2. **Choose a plan** that fits your usage needs
3. **Update credentials** in both files:
   - `lib/services/jdoodle_service.dart` (lines 6-7)
   - `functions/index.js` (lines 22-23)

### Option 2: Implement Smart Caching & Rate Limiting

The enhanced implementation I've created includes:

#### Features Added:
- **Intelligent Caching**: Results cached for 24 hours to avoid duplicate API calls
- **Rate Limiting**: Per-user daily and minute limits
- **Usage Tracking**: Monitor API usage across the application
- **Error Handling**: Graceful handling of rate limit errors
- **Admin Dashboard**: Monitor usage statistics

#### Configuration Options:

```dart
// In lib/services/jdoodle_service.dart
static const int _maxRequestsPerDay = 200; // Adjust based on your plan
static const int _maxRequestsPerMinute = 10; // Prevent spam
static const Duration _cacheExpiry = Duration(hours: 24); // Cache duration
```

```javascript
// In functions/index.js
const MAX_REQUESTS_PER_DAY = 200; // Adjust based on your plan
const MAX_REQUESTS_PER_MINUTE = 10;
const CACHE_EXPIRY_HOURS = 24;
```

### Option 3: Alternative Code Execution Services

Consider these alternatives if JDoodle limits are too restrictive:

1. **Judge0 CE** (Self-hosted)
   - Free and unlimited
   - Requires server setup
   - More control over execution environment

2. **CodeX** (API)
   - Higher limits than JDoodle free tier
   - Similar API structure

3. **HackerRank API**
   - Good for competitive programming
   - Higher rate limits

## Usage Optimization Strategies

### 1. Implement Result Caching
- Cache identical code executions
- Reduce redundant API calls
- Store results for 24 hours

### 2. Batch Processing
- Group multiple test cases
- Reduce API calls per challenge
- Use bulk execution when possible

### 3. Smart Rate Limiting
- Per-user limits to prevent abuse
- Graceful degradation when limits reached
- User-friendly error messages

### 4. Usage Monitoring
- Track daily usage per user
- Monitor overall application usage
- Alert when approaching limits

## Implementation Steps

### Step 1: Deploy Enhanced Code
1. The enhanced `JDoodleService` is already implemented
2. Deploy the updated Firebase functions
3. Test the new caching and rate limiting features

### Step 2: Add Usage Widgets
1. Add `JDoodleUsageWidget` to admin dashboard
2. Add `JDoodleUsageDisplay` to student interface
3. Monitor usage patterns

### Step 3: Configure Limits
1. Adjust limits based on your JDoodle plan
2. Set appropriate cache durations
3. Configure rate limiting thresholds

### Step 4: Monitor and Optimize
1. Track usage statistics
2. Identify optimization opportunities
3. Adjust settings based on usage patterns

## Admin Dashboard Integration

Add the usage monitoring widget to your admin dashboard:

```dart
// In your admin dashboard
import 'package:codequest/features/admin/presentation/widgets/jdoodle_usage_widget.dart';

// Add this widget to your dashboard
JDoodleUsageWidget()
```

## Student Interface Integration

Add usage display to student pages:

```dart
// In student challenge pages
import 'package:codequest/features/student/presentation/widgets/jdoodle_usage_display.dart';

// Add this widget to show usage
JDoodleUsageDisplay()
```

## Troubleshooting

### Common Issues:

1. **Rate Limit Exceeded**
   - Check current usage in admin dashboard
   - Consider upgrading JDoodle plan
   - Implement more aggressive caching

2. **Cache Not Working**
   - Verify SharedPreferences is properly configured
   - Check cache expiration settings
   - Monitor cache hit rates

3. **High Usage**
   - Identify heavy users
   - Implement stricter rate limiting
   - Consider usage quotas per user

### Monitoring Commands:

```bash
# Deploy Firebase functions
firebase deploy --only functions

# Check function logs
firebase functions:log

# Monitor usage in real-time
firebase functions:config:get
```

## Best Practices

1. **Always cache results** for identical code executions
2. **Implement user-specific limits** to prevent abuse
3. **Monitor usage patterns** and adjust limits accordingly
4. **Provide clear error messages** when limits are reached
5. **Consider implementing a queue system** for high-traffic periods
6. **Regularly review and optimize** caching strategies

## Cost Optimization

1. **Use caching effectively** to reduce API calls
2. **Implement smart rate limiting** to prevent unnecessary requests
3. **Monitor usage patterns** to optimize limits
4. **Consider self-hosted alternatives** for high-volume usage
5. **Negotiate better rates** with JDoodle for enterprise usage

## Emergency Procedures

If you hit JDoodle limits unexpectedly:

1. **Check current usage** in admin dashboard
2. **Reset usage counters** if needed (admin function available)
3. **Implement temporary restrictions** on heavy users
4. **Consider upgrading plan** immediately
5. **Enable more aggressive caching** settings

## Support

For JDoodle-specific issues:
- Visit: https://www.jdoodle.com/support
- Email: support@jdoodle.com
- Documentation: https://docs.jdoodle.com/

For CodeQuest implementation issues:
- Check the Firebase function logs
- Review the usage monitoring widgets
- Verify configuration settings 