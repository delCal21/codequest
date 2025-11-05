# How to Convert Files for Quiz Upload

## Quick Solution for PDF Files

Since the quiz upload feature currently supports DOCX and TXT files, here's how to convert your existing PDF files:

## Method 1: Copy and Paste (Recommended)

### For PDF Files:
1. **Open your PDF file**
2. **Select all text** (Ctrl+A)
3. **Copy the text** (Ctrl+C)
4. **Open Notepad** (or any text editor)
5. **Paste the content** (Ctrl+V)
6. **Save as** a `.txt` file
7. **Format the content** to match the TXT structure

## Method 2: Manual Conversion

If copy-paste doesn't work (e.g., protected PDFs):

1. **Open your PDF file**
2. **Open Notepad** in another window
3. **Manually type** each question following this format:

```
Q: Your question here?
A: First option
B: Second option
C: Third option
D: Fourth option
Correct: A
```

4. **Save the file** with `.txt` extension

## Required TXT Format

Your text file must follow this exact format (for PDF conversion):

```
Q: What is the capital of France?
A: Paris
B: London
C: Berlin
D: Madrid
Correct: A

Q: Which programming language is known as the "language of the web"?
A: Java
B: Python
C: JavaScript
D: C++
Correct: C
```

## Important Notes:

- **Use exact prefixes**: Q:, A:, B:, C:, D:, Correct:
- **Separate questions** with blank lines
- **Correct answer** must be A, B, C, or D
- **Each question** must have exactly 4 options
- **No empty fields** allowed

## Sample File

You can download the sample file from `assets/quiz_templates/sample_quiz.txt` to see the exact format.

## Need Help?

If you're having trouble converting your files:
1. Try the copy-paste method first
2. Use the sample file as a template
3. Start with just 2-3 questions to test
4. Contact support if you need assistance

## Future Updates

We're working on adding direct support for:
- PDF files
- Excel (.xlsx) files

For now, DOCX and TXT files provide reliable ways to upload your quiz questions!
