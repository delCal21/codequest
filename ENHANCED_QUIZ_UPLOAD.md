# Enhanced Quiz Upload Functionality

## Overview
The quiz upload system has been enhanced to allow teachers to upload multiple quiz files and accumulate questions more efficiently. Teachers can now choose between replacing all questions or appending new questions to existing ones.

## New Features

### 1. Upload Modes
- **Replace All Questions**: Removes existing questions and loads new ones from the file
- **Append Questions**: Keeps existing questions and adds new ones from the file

### 2. Multiple File Upload
- **Single File Upload**: Upload one quiz file at a time (existing functionality)
- **Multiple Files Upload**: Upload multiple quiz files simultaneously for batch processing

### 3. Enhanced UI
- Clear upload mode selection with radio buttons
- File summary dialog showing selected files before processing
- Progress indicator during multiple file processing
- Enhanced current questions preview with detailed view
- Better error handling and user feedback

## How to Use

### Single File Upload
1. Select your upload mode (Replace or Append)
2. Click "Select Quiz File" to choose a DOCX or TXT file
3. Click the play button to process the file
4. Confirm the action in the dialog
5. Questions will be loaded according to your selected mode

### Multiple Files Upload
1. Select your upload mode (Replace or Append)
2. Click "Upload Multiple Files at Once"
3. Select multiple DOCX or TXT files
4. Review the file summary in the dialog
5. Click "Process Files" to continue
6. Wait for processing to complete
7. Confirm the action in the final dialog

## Supported File Formats

### DOCX Files
- Microsoft Word documents (.docx)
- Automatically extracts text content from XML structure
- Supports complex formatting and tables
- Handles both file path and inline bytes for web compatibility
- Intelligent parsing of Word document structure

### PDF Files
- Portable Document Format (.pdf)
- Enhanced text extraction with intelligent parsing
- Supports various PDF formats and layouts
- Automatic question and option detection
- Fallback text extraction for complex PDFs

### TXT Files
- Plain text files (.txt)
- UTF-8 encoding recommended
- Simple and reliable
- Direct text parsing

## Question Format Requirements

The system is designed to be flexible and will automatically detect questions from various formats. Here are the supported formats:

### Format 1 - Standard Format:
```
Q: [Question text]
A: [Option A]
B: [Option B]
C: [Option C]
D: [Option D]
Correct: [A/B/C/D]
```

### Format 2 - Numbered Questions:
```
1. [Question text]
A) [Option A]
B) [Option B]
C) [Option C]
D) [Option D]
Correct: B
```

### Format 3 - Mixed Numbering:
```
Question 1: [Question text]
1) [Option 1]
2) [Option 2]
3) [Option 3]
4) [Option 4]
Answer: 3
```

### Format 4 - Bullet Points:
```
[Question text]
- [Option A]
- [Option B]
- [Option C]
- [Option D]
Correct: [A/B/C/D]
```

### Examples:
```
Q: What is the capital of France?
A: Paris
B: London
C: Berlin
D: Madrid
Correct: A

1. Which planet is closest to the sun?
A) Venus
B) Earth
C) Mercury
D) Mars
Correct: C

What is 2 + 2?
- 3
- 4
- 5
- 6
Correct: 4
```

**Note**: The system automatically detects questions, options, and correct answers regardless of the specific format used. You can mix formats within the same document.

## Benefits for Teachers

1. **Google Forms-like Experience**: Upload Word/PDF files and get instant quiz conversion
2. **Efficiency**: Upload multiple files at once instead of one by one
3. **Flexibility**: Choose to replace or append questions based on needs
4. **Time Saving**: Batch process multiple quiz files simultaneously
5. **Better Organization**: Keep existing questions while adding new ones
6. **Visual Feedback**: Clear previews and progress indicators
7. **Format Flexibility**: Support for various question formats and numbering styles
8. **Automatic Parsing**: No need to manually format questions - the system does it for you

## Error Handling

The system provides comprehensive error handling:
- File format validation
- Question structure validation
- Option count validation
- Correct answer validation
- Detailed error messages for troubleshooting

## Best Practices

1. **File Organization**: Use consistent naming conventions for your quiz files
2. **Question Format**: Ensure all questions follow the required format
3. **Batch Upload**: Group related questions in separate files for better organization
4. **Validation**: Review the preview before confirming uploads
5. **Backup**: Keep original files as backup

## Technical Details

- Supports files up to 50MB
- Processes multiple file formats simultaneously
- Maintains question order from files
- Automatic question numbering
- Progress tracking for large uploads

## Troubleshooting

### Common Issues
1. **File not loading**: Check file format and size
2. **Questions not parsing**: Verify question format follows requirements
3. **Upload errors**: Ensure files are not corrupted
4. **Slow processing**: Large files may take longer to process

### Solutions
1. Convert files to supported formats
2. Check question formatting
3. Split large files into smaller ones
4. Use TXT format for better compatibility

## Future Enhancements

Planned improvements include:
- Support for more file formats (PDF, RTF)
- Question import from Excel/CSV files
- Question bank management
- Template-based question creation
- Bulk question editing
