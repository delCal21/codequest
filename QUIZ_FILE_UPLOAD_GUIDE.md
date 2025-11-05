# Google Forms-Style Quiz Creation Guide for Teachers

This guide explains how to use the new Google Forms-style quiz creation feature to quickly create quiz challenges for your students.

## Overview

The new quiz creation system works like Google Forms - you can upload a Word or PDF file containing quiz questions, and the system will automatically fill out a form for you. You can then review, edit, and save the quiz. This saves time and makes it easier to create comprehensive quizzes.

## Supported File Formats

### 1. Word Document (.docx) Format
- **File Extension**: `.docx`
- **Format**: Standard Word document with numbered questions and lettered options
- **Structure**: Questions with A), B), C), D) options and correct answer indicators

**Example:**
```
1. What is the capital of France?
A) Paris
B) London
C) Berlin
D) Madrid
Correct: A

2. Which programming language is known as the "language of the web"?
A) Java
B) Python
C) JavaScript
D) C++
Correct: C
```

### 2. PDF Format (.pdf)
- **File Extension**: `.pdf`
- **Format**: Portable Document Format with extractable text
- **Structure**: Same as DOCX format - questions with A), B), C), D) options and correct answer indicators

**Note**: PDF files are automatically converted to text and processed the same way as DOCX files.

## How to Use the New System

### Step 1: Create a Quiz Challenge
1. Go to the Teacher Dashboard
2. Navigate to "Challenges"
3. Click "Create New Challenge"
4. Select "Quiz" or "Summative" as the challenge type

### Step 2: Choose Your Creation Method
The new system offers two ways to create quizzes:

#### Option A: Upload File & Auto-Fill Form
1. Click "Select Word or PDF File" to choose your file
2. Click "Process File & Fill Form" to analyze the file
3. The system will automatically extract questions and fill out the form
4. Review and edit the auto-filled information
5. Click "Save Quiz" to finalize

#### Option B: Create Manually
1. Click "Create Quiz Manually" to switch to manual mode
2. Fill out the quiz form step by step
3. Add questions one by one using the "Add Question" button
4. Click "Save Quiz" when finished

### Step 3: Toggle Between Modes
- Use the toggle button to switch between file upload and manual creation
- You can start with file upload, then switch to manual editing
- Or start manually and switch to file upload later

## File Requirements

### General Requirements
- Each question must have exactly 4 options
- All fields must be filled (no empty questions or options)
- Correct answer must be A, B, C, or D
- File must be properly formatted according to the chosen format

### DOCX Specific
- Use standard Word document formatting
- Number your questions (1., 2., 3., etc.)
- Use A), B), C), D) for options
- Include "Correct: [letter]" after each question
- Ensure proper spacing between questions

### PDF Specific
- Same structure as DOCX
- Ensure text is extractable (not scanned images)
- Use clear formatting for easy parsing

## Form Fields

The new system includes these form fields:

### Basic Quiz Information
- **Quiz Title**: Descriptive name for your quiz
- **Quiz Description**: What the quiz covers
- **Time Limit**: How long students have (in minutes)
- **Passing Score**: Minimum score to pass (percentage)

### Question Management
- **Question Text**: The actual question
- **Options**: Four multiple choice options (A, B, C, D)
- **Correct Answer**: Radio button selection for the right answer
- **Add/Remove Questions**: Dynamic question management

## Benefits of the New System

### ⚡ **Time Savings**
- Upload files and auto-fill forms in seconds
- No need to manually type each question
- Batch process entire quiz sets

### 📝 **Flexibility**
- Switch between file upload and manual creation
- Edit auto-filled content before saving
- Mix uploaded and manual questions

### 🎯 **User Experience**
- Google Forms-like interface
- Intuitive form-based workflow
- Better visual organization
- Real-time validation

### 🔄 **Workflow Options**
- Start with file upload, finish manually
- Start manually, add questions from file
- Full manual creation for simple quizzes
- Full file processing for complex quizzes

## Tips for Creating Quiz Files

### Best Practices
1. **Keep questions clear and concise**
2. **Ensure all options are plausible** (avoid obviously wrong answers)
3. **Use consistent formatting** throughout the file
4. **Test your file** with a small number of questions first
5. **Backup your questions** in case of upload issues

### Common Mistakes to Avoid
1. **Missing options** - Each question must have exactly 4 options
2. **Invalid correct answer** - Must be A, B, C, or D
3. **Poor formatting** - Use consistent spacing and structure
4. **Empty fields** - All questions and options must have content

## Sample Files

Sample template files are available in the `assets/quiz_templates/` folder:
- `sample_quiz.docx.txt` - DOCX format example
- `sample_quiz.pdf.txt` - PDF format example
- `sample_quiz.txt` - TXT format example

## Troubleshooting

### File Upload Issues
- **File too large**: Ensure file is under 5MB
- **Unsupported format**: Only .docx and .pdf files are supported
- **Parsing errors**: Check file format and structure

### Form Issues
- **Questions not loading**: Verify file format and content
- **Validation errors**: Fill in all required fields
- **Save failures**: Check internet connection and try again

## Future Enhancements

The new system is designed to be easily extensible. Future versions may include:
- Excel file support (.xlsx)
- Question bank management
- Import/export functionality
- Advanced question types
- Bulk operations

---

**Note**: This new system replaces the previous file upload functionality with a more intuitive, Google Forms-like experience that supports both Word and PDF files.
