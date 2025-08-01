#!/usr/bin/env python3

import unittest
import tempfile
import shutil
from pathlib import Path
import sys
import os

# Add the parent directory to sys.path so we can import 'p'
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Import functions from p (the script) using exec
import importlib.util
p_script_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "p")

# Read and execute the p script
with open(p_script_path, 'r') as f:
    p_code = f.read()

# Create a module object to store the functions
import types
p_module = types.ModuleType('p_module')

# Execute the code in the module's namespace
exec(p_code, p_module.__dict__)

class TestProjectScanner(unittest.TestCase):
    
    def setUp(self):
        """Set up test fixtures before each test method."""
        self.test_dir = tempfile.mkdtemp()
        self.test_path = Path(self.test_dir)
        
    def tearDown(self):
        """Clean up after each test method."""
        shutil.rmtree(self.test_dir)
    
    def test_get_git_branch(self):
        """Test git branch detection."""
        # Test non-git directory
        branch = p_module.get_git_branch(self.test_path)
        self.assertIsNone(branch)
    
    def test_extract_project_name_from_readme(self):
        """Test extracting project name from README.md."""
        readme_path = self.test_path / "README.md"
        readme_path.write_text("# Test Project\n\nThis is a test project.")
        
        name = p_module.extract_project_name(readme_path)
        self.assertEqual(name, "Test Project")
    
    def test_extract_project_name_no_readme(self):
        """Test extracting project name when README.md doesn't exist."""
        readme_path = self.test_path / "README.md"
        
        name = p_module.extract_project_name(readme_path)
        self.assertIsNone(name)
    
    def test_detect_technologies_python(self):
        """Test technology detection for Python projects."""
        (self.test_path / "requirements.txt").write_text("flask==2.0.0")
        
        technologies = p_module.detect_technologies(self.test_path)
        self.assertIn("Python", technologies)
    
    def test_detect_python_by_py_files(self):
        """Test Python detection by .py files."""
        (self.test_path / "main.py").write_text("print('hello world')")
        
        technologies = p_module.detect_technologies(self.test_path)
        self.assertIn("Python", technologies)
    
    def test_detect_python_by_test_files(self):
        """Test Python detection by test directory .py files."""
        test_dir = self.test_path / "test"
        test_dir.mkdir()
        (test_dir / "test_main.py").write_text("import unittest")
        
        technologies = p_module.detect_technologies(self.test_path)
        self.assertIn("Python", technologies)
    
    def test_detect_python_by_shebang(self):
        """Test Python detection by shebang in executable."""
        script_path = self.test_path / "script"
        script_path.write_text("#!/usr/bin/env python3\nprint('hello')")
        script_path.chmod(0o755)  # Make executable
        
        technologies = p_module.detect_technologies(self.test_path)
        self.assertIn("Python", technologies)
    
    def test_detect_technologies_javascript(self):
        """Test technology detection for JavaScript projects."""
        (self.test_path / "package.json").write_text('{"name": "test", "dependencies": {"react": "^18.0.0"}}')
        
        technologies = p_module.detect_technologies(self.test_path)
        self.assertIn("JS", technologies)
        self.assertIn("node.js", technologies)
        self.assertIn("react", technologies)
    
    def test_detect_technologies_docker(self):
        """Test technology detection for Docker projects."""
        (self.test_path / "Dockerfile").write_text("FROM node:18")
        
        technologies = p_module.detect_technologies(self.test_path)
        self.assertIn("Docker", technologies)
    
    def test_is_project_directory_with_readme(self):
        """Test project detection with README.md."""
        (self.test_path / "README.md").write_text("# Test Project")
        
        is_project = p_module.is_project_directory(self.test_path)
        self.assertTrue(is_project)
    
    def test_is_project_directory_with_package_json(self):
        """Test project detection with package.json."""
        (self.test_path / "package.json").write_text('{"name": "test"}')
        
        is_project = p_module.is_project_directory(self.test_path)
        self.assertTrue(is_project)
    
    def test_is_project_directory_empty(self):
        """Test project detection with empty directory."""
        is_project = p_module.is_project_directory(self.test_path)
        self.assertFalse(is_project)
    
    def test_count_todo_lines(self):
        """Test counting TODO lines."""
        (self.test_path / "TODO.md").write_text("# TODOs\n\n- Task 1\n- Task 2\n")
        
        todo_count = p_module.count_todo_lines(self.test_path)
        self.assertEqual(todo_count, 5)  # Updated to match actual line count including empty lines
    
    def test_count_structured_items(self):
        """Test counting structured items in markdown with enhanced completion detection."""
        content = """# TODO List
        
- [ ] Task 1
- [x] Task 2 (checkbox completed)
- Task 3 basic
- ~Task 4 strikethrough~
- Task 5 *completed*
- ✓ Task 6 with checkmark
- Task 7 (done)
  - Nested task (should be ignored)
    - Double nested (should be ignored)
1. Numbered task 1 (should be ignored)
2. Numbered task 2 (should be ignored)

Some text and headers should be ignored.

- Final task
"""
        items = p_module.count_structured_items(content)
        self.assertEqual(items['total'], 8)  # Only top-level bullet points, no numbered lists
        self.assertEqual(items['completed'], 5)  # [x], ~strikethrough~, *completed*, ✓, (done)  
        self.assertEqual(items['open'], 3)  # [ ], basic, final task
    
    def test_count_structured_items_completion_patterns(self):
        """Test various completion patterns in structured items."""
        content = """
- [x] Standard checkbox completed
- [X] Uppercase checkbox completed  
- [ ] Empty checkbox (open)
- ~Strikethrough item~
- Task with ~partial strikethrough~ text
- Item *completed*
- Item **done**
- Item *finished*
- ✓ Checkmark at start
- ✅ Green checkmark at start
- ☑️ Ballot box checkmark at start
- Regular item (completed)
- Another item (done)
- Final item (finished)
- Open item without completion markers
- Item with *incomplete* text (should be open)
- Item with (incomplete) status (should be open)
"""
        items = p_module.count_structured_items(content)
        self.assertEqual(items['total'], 17)
        # Completed items: [x], [X], ~strikethrough~, ~partial~, *completed*, **done**, *finished*,
        # ✓, ✅, ☑️, (completed), (done), (finished)
        self.assertEqual(items['completed'], 13)
        self.assertEqual(items['open'], 4)  # [ ], open item, *incomplete*, (incomplete)
    
    def test_count_structured_items_indentation_levels(self):
        """Test that only top-level items are counted, ignoring nested items."""
        content = """
- Top level item 1
  - Nested item 1.1 (should be ignored)
    - Double nested 1.1.1 (should be ignored)
  - Nested item 1.2 (should be ignored)
- Top level item 2
    - Indented item 2.1 (should be ignored)
- Top level item 3
  * Different bullet nested (should be ignored)
  + Plus bullet nested (should be ignored)

  - Item with leading blank (should be ignored)
- Final top level item
"""
        items = p_module.count_structured_items(content)
        self.assertEqual(items['total'], 4)  # Only the 4 top-level items
        self.assertEqual(items['completed'], 0)  # None are marked as completed
        self.assertEqual(items['open'], 4)
    
    def test_count_structured_items_numbered_lists_ignored(self):
        """Test that numbered lists are completely ignored."""
        content = """
- Bullet item 1
- Bullet item 2 [x]
1. Numbered item 1 (should be ignored)
2. Numbered item 2 [x] (should be ignored)
3. Numbered item 3 *completed* (should be ignored)
- Bullet item 3
10. Double digit numbered (should be ignored)
- Final bullet item
"""
        items = p_module.count_structured_items(content)
        self.assertEqual(items['total'], 4)  # Only bullet items
        self.assertEqual(items['completed'], 1)  # Only bullet item 2 [x]
        self.assertEqual(items['open'], 3)
    
    def test_count_structured_items_edge_cases(self):
        """Test edge cases and malformed content."""
        content = """
- Valid item
-Invalid item without space (should be ignored)
- Item with multiple [x] [x] checkboxes (should count as completed)
- Item with mixed ~strikethrough~ and [x] patterns (should count as completed)  
- Item ending with period *completed*.
- 
- Empty item content after bullet
-   Item with spaces but no content after dash (should be ignored)

# Headers should be ignored
## Even with - dashes in them

Regular text with - dashes should be ignored
Text ending with dash -

- Last valid item
"""
        items = p_module.count_structured_items(content)
        self.assertEqual(items['total'], 8)  # All bullet items with spaces after dash
        self.assertEqual(items['completed'], 3)  # Multiple [x], ~strikethrough~ and [x], *completed*.
        self.assertEqual(items['open'], 5)  # Valid item, empty item, empty content, spaces item, last valid item
    
    def test_extract_issue_metadata(self):
        """Test extracting metadata from issue content."""
        content = """# Bug Report
        
This is a high priority issue that needs urgent attention.
        
<!-- labels: bug, ui, frontend -->
        
- [ ] Fix the important bug
- [ ] Test the fix
        
Medium priority task here.
Low priority enhancement.
"""
        metadata = p_module.extract_issue_metadata(content)
        self.assertEqual(metadata['priority_counts']['high'], 1)  # from "high priority" phrase (urgent not matching separately)
        self.assertEqual(metadata['priority_counts']['medium'], 1) 
        self.assertEqual(metadata['priority_counts']['low'], 1)
        self.assertIn('bug', metadata['labels'])
        self.assertIn('ui', metadata['labels'])
        self.assertIn('frontend', metadata['labels'])
        self.assertGreater(metadata['severity_score'], 0)
    
    def test_scan_inline_todos(self):
        """Test scanning inline TODOs in code files."""
        # Create Python file with inline TODOs
        (self.test_path / "code.py").write_text("""
# TODO: Implement this function
def placeholder():
    # FIXME: This is broken
    # BUG: Memory leak here
    pass
""")
        
        # Create JavaScript file with inline TODOs
        (self.test_path / "script.js").write_text("""
// TODO: Add error handling
function test() {
    // FIXME: Optimize this
    return null;
}
""")
        
        counts = p_module.scan_inline_todos(self.test_path)
        self.assertEqual(counts['todo'], 2)  # One in each file
        self.assertEqual(counts['fixme'], 2)  # One in each file
        self.assertEqual(counts['bug'], 1)   # Only in Python file
    
    def test_count_todo_items_enhanced(self):
        """Test enhanced TODO counting with both structured and inline."""
        # Create structured TODO file
        (self.test_path / "TODO.md").write_text("""# Project TODOs
        
- [ ] Task 1 (high priority)
- [x] Task 2 (completed)
- Task 3
""")
        
        # Create code file with inline TODOs
        (self.test_path / "main.py").write_text("""
# TODO: Refactor this
def main():
    # FIXME: Handle errors
    pass
""")
        
        metrics = p_module.count_todo_items(self.test_path)
        self.assertEqual(metrics['structured']['items']['total'], 3)
        self.assertEqual(metrics['structured']['items']['completed'], 1)
        self.assertEqual(metrics['inline']['todo'], 1)
        self.assertEqual(metrics['inline']['fixme'], 1)
        self.assertEqual(metrics['total_items'], 5)  # 3 structured + 2 inline
    
    def test_count_issue_items_enhanced(self):
        """Test enhanced issue counting with priority detection."""
        (self.test_path / "ISSUES.md").write_text("""# Issues
        
<!-- labels: bug, frontend -->
        
- [ ] Critical bug in login system (urgent)
- [ ] Medium priority UI improvement  
- [x] Low priority style fix (completed)
""")
        
        metrics = p_module.count_issue_items(self.test_path)
        self.assertEqual(metrics['items']['total'], 3)
        self.assertEqual(metrics['items']['completed'], 1)
        self.assertEqual(metrics['items']['open'], 2)
        self.assertEqual(metrics['priority_counts']['high'], 1)  # urgent
        self.assertEqual(metrics['priority_counts']['medium'], 1)
        self.assertEqual(metrics['priority_counts']['low'], 1)
        self.assertIn('bug', metrics['labels'])
        self.assertIn('frontend', metrics['labels'])
    
    def test_scan_projects(self):
        """Test scanning projects."""
        # Create a project directory
        project_dir = self.test_path / "test-project"
        project_dir.mkdir()
        (project_dir / "README.md").write_text("# Test Project")
        
        projects = p_module.scan_projects(self.test_path)
        self.assertEqual(len(projects), 1)
        self.assertEqual(projects[0]['folder'], 'test-project')
    
    def test_config_loading(self):
        """Test configuration loading."""
        # Test that config object exists and has expected attributes
        self.assertTrue(hasattr(p_module.config, 'max_project_name_length'))
        self.assertTrue(hasattr(p_module.config, 'git_timeout'))
        self.assertTrue(hasattr(p_module.config, 'exclude_dirs'))
    
    def test_depth_limiting(self):
        """Test depth limiting in directory scanning."""
        # Create nested directories
        deep_dir = self.test_path / "level1" / "level2" / "level3"
        deep_dir.mkdir(parents=True)
        (deep_dir / "README.md").write_text("# Deep Project")
        
        # Scan with default depth (should find it)
        projects = p_module.scan_projects(self.test_path)
        self.assertTrue(any(p['name'] == 'Deep Project' for p in projects))
        
        # Test with limited depth by temporarily changing config
        original_depth = p_module.config.max_scan_depth
        p_module.config.max_scan_depth = 1
        try:
            projects_limited = p_module.scan_projects(self.test_path)
            # Should not find the deep project with limited depth
            self.assertFalse(any(p['name'] == 'Deep Project' for p in projects_limited))
        finally:
            # Restore original depth
            p_module.config.max_scan_depth = original_depth
    
    def test_custom_technology_detection(self):
        """Test custom technology detection."""
        # Add custom tech file to config
        original_custom = p_module.config.custom_tech_files.copy()
        p_module.config.custom_tech_files['test.config'] = ['CustomTech']
        
        try:
            (self.test_path / "test.config").write_text("custom config")
            technologies = p_module.detect_technologies(self.test_path)
            self.assertIn("CustomTech", technologies)
        finally:
            # Restore original config
            p_module.config.custom_tech_files = original_custom
    
    def test_filtering(self):
        """Test directory filtering."""
        # Create directories that should be excluded
        excluded_dir = self.test_path / "__pycache__"
        excluded_dir.mkdir()
        (excluded_dir / "README.md").write_text("# Should be excluded")
        
        # Create a normal project
        normal_dir = self.test_path / "normal-project"
        normal_dir.mkdir()
        (normal_dir / "README.md").write_text("# Normal Project")
        
        projects = p_module.scan_projects(self.test_path)
        project_names = [p['name'] for p in projects]
        
        self.assertIn("Normal Project", project_names)
        self.assertNotIn("Should be excluded", project_names)
    
    def test_na_technology_detection_readme_only(self):
        """Test n/a technology detection for README-only projects."""
        (self.test_path / "README.md").write_text("# New Project\n\nComing soon...")
        
        technologies = p_module.detect_technologies(self.test_path)
        self.assertIn("n/a", technologies)
    
    def test_na_technology_detection_git_only(self):
        """Test n/a technology detection for git repos without code."""
        git_dir = self.test_path / ".git"
        git_dir.mkdir()
        (git_dir / "config").write_text("[core]\n    repositoryformatversion = 0")
        
        technologies = p_module.detect_technologies(self.test_path)
        self.assertIn("n/a", technologies)
    
    def test_na_technology_detection_planning_files(self):
        """Test n/a technology detection for projects with planning files."""
        (self.test_path / "TODO.md").write_text("# TODO\n\n- Plan the project\n- Write code")
        (self.test_path / "DESIGN.md").write_text("# Design\n\nArchitecture notes...")
        
        technologies = p_module.detect_technologies(self.test_path)
        self.assertIn("n/a", technologies)
    
    def test_no_na_when_code_exists(self):
        """Test that n/a is not added when actual code exists."""
        (self.test_path / "README.md").write_text("# Project")
        (self.test_path / "main.py").write_text("print('hello')")
        
        technologies = p_module.detect_technologies(self.test_path)
        self.assertNotIn("n/a", technologies)
        self.assertIn("Python", technologies)
    
    def test_ignore_image_files_in_issue_tracking(self):
        """Test that image files are ignored when scanning for issue files."""
        # Create an image file with "bug" in the name
        bug_image = self.test_path / "bug_screenshot.png"
        bug_image.write_bytes(b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01')  # Minimal PNG header
        
        # Create a legitimate issue file
        issues_file = self.test_path / "ISSUES.md"
        issues_file.write_text("# Issues\n\n- Bug 1\n- Bug 2\n")
        
        # Count issue lines - should only count the markdown file, not the image
        issue_count = p_module.count_issue_lines(self.test_path)
        self.assertEqual(issue_count, 5)  # Only from ISSUES.md, not the image (updated count)
    
    def test_ignore_various_image_extensions(self):
        """Test that various image file extensions are ignored."""
        # Create image files with issue-related names but different extensions
        image_files = [
            "bug_report.jpg", "issue_diagram.png", "problem_screenshot.gif",
            "error_image.bmp", "bug_flow.svg", "issue_chart.webp",
            "bug_screenshot.avif", "issue_photo.jfif", "BUG_chart.eps",
            "issue_video.webm", "bug_clip.mp4", "issue_movie.avi",
            "bug_presentation.pdf", "issue_animation.apng"
        ]
        
        for image_file in image_files:
            image_path = self.test_path / image_file
            image_path.write_bytes(b'\xff\xd8\xff\xe0')  # Minimal binary header
        
        # Create a real issues file
        (self.test_path / "ISSUES.txt").write_text("Real issue content\nLine 2\n")
        
        # Should only count lines from the text file, not any images
        issue_count = p_module.count_issue_lines(self.test_path)
        self.assertEqual(issue_count, 3)  # Only from ISSUES.txt (updated count)
    
    def test_count_issue_lines_with_debug(self):
        """Test counting issue lines with debug information."""
        # Create both text and image files
        (self.test_path / "BUG_REPORT.md").write_text("# Bug Report\n\nDetails here\n")
        (self.test_path / "bug_screenshot.png").write_bytes(b'\x89PNG\r\n\x1a\n')
        
        debug_info = []
        issue_count = p_module.count_issue_lines(self.test_path, debug_info)
        
        # Should count 4 lines from markdown file (including empty line from newline)
        self.assertEqual(issue_count, 4)
        
        # Debug info should only mention the markdown file, not the image
        self.assertEqual(len(debug_info), 1)
        self.assertEqual(debug_info[0]['file'], 'BUG_REPORT.md')
        self.assertEqual(debug_info[0]['lines'], 4)
    
    def test_cwd_folder_name_display(self):
        """Test that CWD folder name shows actual directory name instead of '.'."""
        # Create a project in the test directory
        (self.test_path / "README.md").write_text("# Test Project")
        
        # Get project info with scan_root same as project_path (simulating CWD scan)
        project_info = p_module.get_project_info(self.test_path, scan_root=self.test_path)
        
        # Should show actual directory name, not "."
        self.assertEqual(project_info['folder'], self.test_path.name)
        self.assertNotEqual(project_info['folder'], ".")
    
    def test_cwd_folder_name_nested_projects(self):
        """Test that nested projects still show correct relative paths."""
        # Create nested project structure
        nested_dir = self.test_path / "nested" / "project"
        nested_dir.mkdir(parents=True)
        (nested_dir / "README.md").write_text("# Nested Project")
        
        # Get project info with scan_root as parent (simulating scanning from parent)
        project_info = p_module.get_project_info(nested_dir, scan_root=self.test_path)
        
        # Should show the relative path from scan root
        self.assertEqual(project_info['folder'], "nested/project")
        self.assertNotEqual(project_info['folder'], ".")

if __name__ == '__main__':
    unittest.main()