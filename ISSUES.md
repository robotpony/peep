# ISSUES.md

## Issue: Bug/Issue tracking logic scans image files

### Problem Description
The bug/issue tracking logic in the `p` script incorrectly scans image files when looking for issue-related content. The `count_lines_in_files` function (specifically the `scan_directory` function at lines 482-508) checks if filenames contain patterns like 'ISSUES', 'BUGS', 'BUG', 'ISSUE' but doesn't filter out binary image files.

### Impact
- Image files with names containing issue keywords (e.g., "bug_screenshot.png", "issue_diagram.jpg") are incorrectly processed
- The code attempts to read binary image files as text, which can cause errors or produce meaningless line counts
- This can lead to inaccurate issue tracking metrics

### Root Cause
In the `scan_directory` function at p:486-505, the code:
1. Iterates through all files in directories
2. Checks if filenames contain issue patterns ('ISSUES', 'BUGS', 'BUG', 'ISSUE')
3. Checks if files have allowed extensions (`.md`, `.txt`, or no extension)
4. Attempts to read and count lines in matching files

The problem is that image files with issue-related names can match the pattern check, and binary files are attempted to be read as text.

### Solution
✅ **RESOLVED**: Enhanced image file extension filtering to exclude common image and media formats before attempting to read files for line counting.

### Files Affected
- `p` (main script) - lines 490-494 in the `scan_directory` function within `count_lines_in_files`
- `test/test_p.py` - Enhanced test coverage for additional image formats

### Fix Details
Enhanced the `image_extensions` set to include:
- Modern formats: `.AVIF`, `.JFIF`, `.APNG`, `.FLIF`
- Vector/print formats: `.EPS`, `.XBM`, `.XPM`
- Media formats: `.WEBM`, `.MP4`, `.AVI`, `.MOV`
- Document formats: `.PDF`
- Game/texture formats: `.DDS`, `.TGA`

The fix ensures that any file with these extensions is skipped during issue tracking, preventing binary files from being processed as text.