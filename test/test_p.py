#!/usr/bin/env python3

import unittest
import tempfile
import shutil
from pathlib import Path
import sys
import os

# Add the parent directory to sys.path so we can import 'p'
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Import functions from p (the script) - rename to .py for import
import importlib.util
import shutil as shell_util
p_script_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "p")

# Create a temporary .py copy for importing
temp_py_path = p_script_path + ".py"
shell_util.copy2(p_script_path, temp_py_path)

try:
    spec = importlib.util.spec_from_file_location("p_module", temp_py_path)
    if spec is None:
        raise ImportError(f"Could not load spec from {temp_py_path}")
    p_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(p_module)
finally:
    # Clean up temp file
    if os.path.exists(temp_py_path):
        os.remove(temp_py_path)

class TestProjectScanner(unittest.TestCase):
    
    def setUp(self):
        """Set up test fixtures before each test method."""
        self.test_dir = tempfile.mkdtemp()
        self.test_path = Path(self.test_dir)
        
    def tearDown(self):
        """Clean up after each test method."""
        shutil.rmtree(self.test_dir)
        # Clear git cache between tests
        p_module._git_cache.clear()
    
    def test_validate_directory_path_valid(self):
        """Test that validate_directory_path works with valid directory."""
        path, error = p_module.validate_directory_path(self.test_dir)
        self.assertIsNotNone(path)
        self.assertIsNone(error)
        self.assertEqual(path, Path(self.test_dir).resolve())
    
    def test_validate_directory_path_nonexistent(self):
        """Test that validate_directory_path handles nonexistent directory."""
        fake_path = "/nonexistent/directory"
        path, error = p_module.validate_directory_path(fake_path)
        self.assertIsNone(path)
        self.assertIn("does not exist", error)
    
    def test_validate_directory_path_file(self):
        """Test that validate_directory_path handles file instead of directory."""
        test_file = self.test_path / "test.txt"
        test_file.write_text("test")
        
        path, error = p_module.validate_directory_path(str(test_file))
        self.assertIsNone(path)
        self.assertIn("is not a directory", error)
    
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
    
    def test_scan_projects_non_recursive(self):
        """Test scanning projects non-recursively."""
        # Create a project directory
        project_dir = self.test_path / "test-project"
        project_dir.mkdir()
        (project_dir / "README.md").write_text("# Test Project")
        
        projects = p_module.scan_projects(self.test_path, recursive=False)
        self.assertEqual(len(projects), 1)
        self.assertEqual(projects[0]['folder'], 'test-project')
    
    def test_scan_projects_recursive(self):
        """Test scanning projects recursively."""
        # Create nested project directories
        project_dir1 = self.test_path / "project1"
        project_dir1.mkdir()
        (project_dir1 / "README.md").write_text("# Project 1")
        
        nested_dir = self.test_path / "nested"
        nested_dir.mkdir()
        project_dir2 = nested_dir / "project2"
        project_dir2.mkdir()
        (project_dir2 / "package.json").write_text('{"name": "project2"}')
        
        projects = p_module.scan_projects(self.test_path, recursive=True)
        self.assertEqual(len(projects), 2)
        project_names = [p['folder'] for p in projects]
        self.assertIn('project1', project_names)
        self.assertIn('project2', project_names)

if __name__ == '__main__':
    unittest.main()