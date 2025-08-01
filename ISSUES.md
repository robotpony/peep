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

## Issue: Current Directory Display Shows "." Instead of Directory Name ✅ **RESOLVED**

### Problem Description
When scanning the current working directory (CWD), the folder name is displayed as "." which is not very descriptive or user-friendly in the Project column.

**Current behavior:**
```
┌────────┬─────────┬────────┬─────┬────────┬───────┬────────┬───────┐
│ Name   │ Project │ Branch │ Git │ Stack  │ TODOs │ Issues │ Ideas │
├────────┼─────────┼────────┼─────┼────────┼───────┼────────┼───────┤
│ (p)eep │ .       │ main   │ M   │ Python │ 11/19 │ 14/14  │ 3/3   │
└────────┴─────────┴────────┴─────┴────────┴───────┴────────┴───────┘
```

The "Project" column shows "." instead of a meaningful folder name like "peep".

### Impact
- Poor user experience when using the most common scenario (scanning current directory)
- "." provides no meaningful information about the project location
- Inconsistent with how other directories are displayed

### Root Cause
In `p:789-798`, the `get_project_info` function calculates the folder name using:
```python
if scan_root is not None:
    scan_root = Path(scan_root)
    try:
        folder_name = str(project_path.relative_to(scan_root))
    except ValueError:
        # Fallback if project_path is not relative to scan_root
        folder_name = project_path.name
else:
    folder_name = project_path.name
```

When the scan root is the CWD and the project is also the CWD, `relative_to` returns "." which is not descriptive.

### Proposed Solution
Replace "." with the actual directory name (`project_path.name`) to provide meaningful context.

**Expected behavior after fix:**
```
┌────────┬─────────┬────────┬─────┬────────┬───────┬────────┬───────┐
│ Name   │ Project │ Branch │ Git │ Stack  │ TODOs │ Issues │ Ideas │
├────────┼─────────┼────────┼─────┼────────┼───────┼────────┼───────┤
│ (p)eep │ peep    │ main   │ M   │ Python │ 11/19 │ 14/14  │ 3/3   │
└────────┴─────────┴────────┴─────┴────────┴───────┴────────┴───────┘
```

### Implementation Plan
- Modify the folder name calculation in `get_project_info()` at line ~796
- Add a check: if `folder_name == "."`, replace with `project_path.name`
- Ensure the fix works for both root CWD scanning and nested project scanning

### Test Cases
- Scanning CWD directly: `./p .`
- Scanning CWD with show-name: `./p . --show-name`
- Scanning parent directory that includes CWD (should not be affected)
- Scanning nested projects (should not be affected)

### Priority
**High** - This affects the user experience when using the tool in the most common scenario (scanning current directory).

### Resolution
✅ **FIXED**: Modified `get_project_info()` at line 795 to replace "." with the actual directory name (`project_path.name`) when the folder name would be "." due to scanning the current working directory.

**Fix details:**
- Added check: `if folder_name == ".": folder_name = project_path.name`
- Maintains backward compatibility for nested project scanning
- Added comprehensive test coverage for both CWD and nested scenarios
- All existing tests pass