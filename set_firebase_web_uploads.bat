@echo off
REM Deploy Firebase Storage rules and set CORS for web uploads

REM Step 1: Deploy storage.rules to Firebase
firebase deploy --only storage

REM Step 2: Set CORS for Firebase Storage bucket
REM Replace BUCKET_NAME with your actual bucket if different
set BUCKET_NAME=gs://codequest-a5317.firebasestorage.app
gsutil cors set cors.json gs://%BUCKET_NAME%

REM Step 3: Done
@echo Firebase Storage rules deployed and CORS set for bucket: %BUCKET_NAME%
pause 