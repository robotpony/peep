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
        self.assertEqual(todo_count, 4)
    
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

if __name__ == '__main__':
    unittest.main()