#!/usr/bin/env python3

import os
import sys
import argparse
import subprocess
import json
import re
import shutil
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple, Union
try:
    import tomllib
except ImportError:
    try:
        import tomli as tomllib
    except ImportError:
        tomllib = None

VERSION = "1.0.0"

class Config:
    """Configuration management for the p tool."""
    
    def __init__(self):
        # Default configuration
        self.max_project_name_length = 25
        self.max_folder_name_length = 30
        self.min_column_width = 8
        self.default_git_branch = 'main'
        self.git_timeout = 5
        self.max_scan_depth = 10
        self.show_progress = True
        
        # Issue tracking configuration
        self.issue_subfolders = ['bugs', 'issues', 'tasks', 'docs', 'design']
        self.issue_file_patterns = ['ISSUES', 'BUGS', 'BUG', 'ISSUE']
        self.issue_extensions = ['.md', '.txt', '']
        
        # Ideas tracking configuration
        self.ideas_subfolders = ['ideas', 'docs', 'design']
        self.ideas_file_patterns = ['IDEAS', 'IDEA']
        self.ideas_extensions = ['.md', '.txt', '']
        
        # TODO tracking configuration
        self.todo_subfolders = ['tasks', 'docs', 'design']
        self.todo_file_patterns = ['TODO']
        self.todo_extensions = ['.txt', '.md', '']
        
        # Technology detection configuration
        self.custom_tech_files = {}
        self.custom_package_deps = {}
        
        # Filtering configuration
        self.exclude_dirs = ['.git', '__pycache__', 'node_modules', '.venv', 'venv']
        self.exclude_patterns = []
        self.filter_dirs = ['archive']
        
        # Display configuration
        self.show_name_column = False
        
        # Load configuration files
        self._load_config()
    
    def _load_config(self):
        """Load configuration from files in order of precedence."""
        config_files = [
            Path.home() / '.config' / 'p' / 'config.toml',
            Path.cwd() / '.p.toml',
            Path.cwd() / 'p.toml'
        ]
        
        for config_file in config_files:
            if config_file.exists():
                self._load_config_file(config_file)
    
    def _load_config_file(self, config_path: Path):
        """Load configuration from a TOML file."""
        if not tomllib:
            return  # Skip if TOML support not available
            
        try:
            with open(config_path, 'rb') as f:
                config_data = tomllib.load(f)
            
            # Update configuration with loaded data
            for key, value in config_data.items():
                if hasattr(self, key):
                    setattr(self, key, value)
                    
        except Exception:
            # Ignore config file errors to maintain robustness
            pass

# Global configuration instance
config = Config()

# Git branch cache to avoid repeated calls
_git_cache = {}

def get_git_status(project_path: Union[str, Path]) -> str:
    """Get git status indicators (M=modified, ?=untracked, etc)."""
    project_path_str = str(project_path)
    
    # Check cache first
    cache_key = f"{project_path_str}_status"
    if cache_key in _git_cache:
        return _git_cache[cache_key]
    
    status_chars = []
    try:
        # Check if repo is clean and pushed
        result = subprocess.run(
            ['git', 'status', '--porcelain', '--branch'],
            cwd=project_path,
            capture_output=True,
            text=True,
            timeout=config.git_timeout,
            shell=False
        )
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            has_changes = False
            
            for line in lines:
                if not line:
                    continue
                    
                # Branch info line starts with ##
                if line.startswith('##'):
                    # Check if branch is ahead/behind
                    if '[ahead' in line and 'behind' in line:
                        status_chars.append('↕')
                    elif '[ahead' in line:
                        status_chars.append('↑')
                    elif '[behind' in line:
                        status_chars.append('↓')
                    continue
                
                # File status lines
                if len(line) >= 2:
                    has_changes = True
                    index_status = line[0]
                    work_status = line[1]
                    
                    # Add status characters based on git status format
                    if index_status == 'M' or work_status == 'M':
                        if 'M' not in status_chars:
                            status_chars.append('M')
                    if index_status == 'A' or work_status == 'A':
                        if 'A' not in status_chars:
                            status_chars.append('A')
                    if index_status == 'D' or work_status == 'D':
                        if 'D' not in status_chars:
                            status_chars.append('D')
                    if index_status == '?' or work_status == '?':
                        if '?' not in status_chars:
                            status_chars.append('?')
                    if index_status == 'U' or work_status == 'U':
                        if 'U' not in status_chars:
                            status_chars.append('U')
            
            # If no changes and no ahead/behind, repo is clean
            if not has_changes and not status_chars:
                status_chars = ['✓']
                
    except (subprocess.TimeoutExpired, FileNotFoundError, subprocess.SubprocessError):
        status_chars = []
    
    status_str = ''.join(status_chars) if status_chars else ''
    _git_cache[cache_key] = status_str
    return status_str

def get_git_branch(project_path: Union[str, Path]) -> Optional[str]:
    """Get the current git branch for a project."""
    project_path_str = str(project_path)
    
    # Check cache first
    if project_path_str in _git_cache:
        return _git_cache[project_path_str]
    
    branch = None
    try:
        result = subprocess.run(
            ['git', 'branch', '--show-current'],
            cwd=project_path,
            capture_output=True,
            text=True,
            timeout=config.git_timeout,
            shell=False
        )
        if result.returncode == 0:
            branch = result.stdout.strip() or config.default_git_branch
    except subprocess.TimeoutExpired:
        # Git command timed out, likely a large repo
        pass
    except FileNotFoundError:
        # Git not installed or not a git repo
        pass
    except subprocess.SubprocessError:
        # Other git-related errors
        pass
    
    # Cache the result (including None)
    _git_cache[project_path_str] = branch
    return branch

def _has_python_files(project_path: Path) -> bool:
    """Check if the project contains Python files."""
    try:
        # Check for .py files in common directories
        python_dirs = ['.', 'src', 'lib', 'tests', 'test', 'scripts', 'bin']
        
        for dir_name in python_dirs:
            dir_path = project_path / dir_name
            if dir_path.exists() and dir_path.is_dir():
                # Look for .py files in this directory
                for item in dir_path.iterdir():
                    if item.is_file() and item.suffix == '.py':
                        return True
                        
        # Also check root directory for .py files
        for item in project_path.iterdir():
            if item.is_file() and item.suffix == '.py':
                return True
                
    except (PermissionError, OSError):
        pass
    return False

def _has_python_executables(project_path: Path) -> bool:
    """Check if the project contains executable files with Python shebangs."""
    try:
        # Check common executable locations
        exec_dirs = ['.', 'bin', 'scripts']
        
        for dir_name in exec_dirs:
            dir_path = project_path / dir_name
            if dir_path.exists() and dir_path.is_dir():
                for item in dir_path.iterdir():
                    if item.is_file() and _is_python_executable(item):
                        return True
                        
        # Check root directory for executables
        for item in project_path.iterdir():
            if item.is_file() and _is_python_executable(item):
                return True
                
    except (PermissionError, OSError):
        pass
    return False

def _is_python_executable(file_path: Path) -> bool:
    """Check if a file is a Python executable by examining its shebang."""
    try:
        # Check if file is executable
        if not file_path.stat().st_mode & 0o111:
            return False
            
        # Read first line to check for Python shebang
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            first_line = f.readline().strip()
            
        python_shebangs = [
            '#!/usr/bin/env python',
            '#!/usr/bin/python',
            '#!/usr/local/bin/python',
            '#!python'
        ]
        
        return any(first_line.startswith(shebang) for shebang in python_shebangs)
        
    except (PermissionError, UnicodeDecodeError, OSError):
        pass
    return False

def extract_project_name(readme_path: Union[str, Path]) -> Optional[str]:
    """Extract project name from README.md file."""
    try:
        with open(readme_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Look for first h1 heading
        match = re.search(r'^#\s+(.+)$', content, re.MULTILINE)
        if match:
            project_name = match.group(1).strip()
            # Remove unicode characters and keep only ASCII printable characters
            project_name = ''.join(char for char in project_name if ord(char) < 128 and char.isprintable())
            # Clean up multiple spaces
            project_name = re.sub(r'\s+', ' ', project_name).strip()
            return project_name if project_name else None
    except (FileNotFoundError, UnicodeDecodeError):
        pass
    return None

def detect_technologies(project_path: Union[str, Path], debug_info: List[Dict] = None) -> List[str]:
    """Detect technologies used in the project."""
    technologies = []
    project_path = Path(project_path)
    
    # Check for common project files
    tech_files = {
        'package.json': ['JS', 'node.js'],
        'requirements.txt': ['Python'],
        'Pipfile': ['Python'],
        'pyproject.toml': ['Python'],
        'setup.py': ['Python'],
        'setup.cfg': ['Python'],
        'tox.ini': ['Python'],
        'pytest.ini': ['Python'],
        '.python-version': ['Python'],
        'Cargo.toml': ['Rust'],
        'go.mod': ['Go'],
        'pom.xml': ['Java', 'Maven'],
        'build.gradle': ['Java', 'Gradle'],
        'composer.json': ['PHP'],
        'Gemfile': ['Ruby'],
        'yarn.lock': ['JS', 'yarn'],
        'package-lock.json': ['JS', 'npm'],
        'Dockerfile': ['Docker'],
        'docker-compose.yml': ['Docker'],
        'docker-compose.yaml': ['Docker'],
        'Makefile': ['Make'],
        'config.toml': ['Hugo'],
        'config.yaml': ['Hugo'],
        'config.yml': ['Hugo'],
        'hugo.toml': ['Hugo'],
        'hugo.yaml': ['Hugo'],
        'hugo.yml': ['Hugo']
    }
    
    # Merge with custom tech files from config
    tech_files.update(config.custom_tech_files)
    
    for filename, techs in tech_files.items():
        if (project_path / filename).exists():
            technologies.extend(techs)
            if debug_info is not None:
                debug_info.append({
                    'source': filename,
                    'type': 'file',
                    'technologies': techs
                })
    
    # Enhanced Python detection
    if not any('Python' in tech for tech in technologies):
        # Check for .py files
        if _has_python_files(project_path):
            technologies.append('Python')
            if debug_info is not None:
                debug_info.append({
                    'source': '*.py files',
                    'type': 'pattern',
                    'technologies': ['Python']
                })
        # Check for executable files with Python shebang
        elif _has_python_executables(project_path):
            technologies.append('Python')
            if debug_info is not None:
                debug_info.append({
                    'source': 'Python executables',
                    'type': 'pattern',
                    'technologies': ['Python']
                })
    
    # Check package.json for React/Vue/etc
    package_json_path = Path(project_path) / 'package.json'
    if package_json_path.exists():
        try:
            with open(package_json_path, 'r', encoding='utf-8') as f:
                package_data = json.load(f)
            
            deps = {**package_data.get('dependencies', {}), **package_data.get('devDependencies', {})}
            
            # Default package dependencies
            package_deps = {
                'react': 'react',
                'vue': 'vue', 
                'angular': 'angular',
                'typescript': 'typescript'
            }
            
            # Merge with custom package dependencies from config
            package_deps.update(config.custom_package_deps)
            
            for dep_name, tech_name in package_deps.items():
                if dep_name in deps:
                    technologies.append(tech_name)
                    if debug_info is not None:
                        debug_info.append({
                            'source': f'package.json dependency: {dep_name}',
                            'type': 'dependency',
                            'technologies': [tech_name]
                        })
                    
        except (json.JSONDecodeError, KeyError, UnicodeDecodeError):
            # Malformed JSON or encoding issues
            pass
    
    # Check for static website (index.html without other script technologies)
    index_html_path = Path(project_path) / 'index.html'
    if index_html_path.exists() and not technologies:
        # Only add "static website" if no other technologies detected
        technologies.append('static website')
        if debug_info is not None:
            debug_info.append({
                'source': 'index.html',
                'type': 'file',
                'technologies': ['static website']
            })
    
    # If no technologies detected but this is a valid project directory, mark as n/a
    if not technologies and _is_empty_or_planning_project(project_path):
        technologies.append('n/a')
        if debug_info is not None:
            debug_info.append({
                'source': 'empty/planning project',
                'type': 'inference',
                'technologies': ['n/a']
            })
    
    return list(dict.fromkeys(technologies))  # Remove duplicates while preserving order

def _is_empty_or_planning_project(project_path: Path) -> bool:
    """Check if this appears to be a new/empty project or planning stage project."""
    try:
        # Check if it has basic project structure but no code yet
        has_readme = (project_path / 'README.md').exists() or (project_path / 'readme.md').exists()
        has_git = (project_path / '.git').exists()
        
        # If it has README or git but no detectable technology, it's likely a new project
        if has_readme or has_git:
            # Make sure it doesn't have any actual code files
            if not _has_any_code_files(project_path):
                return True
                
        # Check for common planning/documentation-only indicators
        planning_files = [
            'TODO.md', 'todo.md', 'TODOS.md',
            'PLANNING.md', 'planning.md',
            'DESIGN.md', 'design.md',
            'NOTES.md', 'notes.md',
            'IDEAS.md', 'ideas.md',
            'ROADMAP.md', 'roadmap.md',
            'SPEC.md', 'spec.md'
        ]
        
        has_planning_files = any((project_path / filename).exists() for filename in planning_files)
        
        # If it has planning files but no code, it's in planning stage
        if has_planning_files and not _has_any_code_files(project_path):
            return True
            
    except (PermissionError, OSError):
        pass
        
    return False

def _has_any_code_files(project_path: Path) -> bool:
    """Check if directory contains any code files."""
    try:
        # Common code file extensions
        code_extensions = {
            '.py', '.js', '.ts', '.jsx', '.tsx', '.rs', '.go', '.java', '.cpp', '.c', 
            '.php', '.rb', '.swift', '.kt', '.scala', '.clj', '.cs', '.fs', '.vb',
            '.sh', '.bash', '.zsh', '.fish', '.ps1', '.bat', '.cmd'
        }
        
        # Common directories to check
        dirs_to_check = ['.', 'src', 'lib', 'app', 'scripts', 'bin', 'test', 'tests']
        
        for dir_name in dirs_to_check:
            dir_path = project_path / dir_name
            if dir_path.exists() and dir_path.is_dir():
                for item in dir_path.iterdir():
                    if item.is_file() and item.suffix.lower() in code_extensions:
                        return True
                        
    except (PermissionError, OSError):
        pass
        
    return False

def count_structured_items(content: str) -> Dict[str, int]:
    """Count actual items instead of just lines in markdown content."""
    items = {'open': 0, 'completed': 0, 'total': 0}
    
    for line in content.split('\n'):
        line = line.strip()
        # Count markdown list items (bullet points)
        if re.match(r'^[-*+]\s+', line):
            items['total'] += 1
            if re.match(r'^[-*+]\s+\[x\]', line, re.IGNORECASE):
                items['completed'] += 1
            else:
                items['open'] += 1
        # Count numbered lists
        elif re.match(r'^\d+\.\s+', line):
            items['total'] += 1
            items['open'] += 1  # Assume numbered items are open
    
    return items

def extract_issue_metadata(content: str) -> Dict[str, any]:
    """Extract priority, labels, and severity from issue content."""
    metadata = {
        'priority_counts': {'high': 0, 'medium': 0, 'low': 0},
        'labels': set(),
        'severity_score': 0
    }
    
    priority_patterns = {
        'high': re.compile(r'\b(urgent|critical|high priority|p0|p1)\b', re.IGNORECASE),
        'medium': re.compile(r'\b(medium priority|normal priority|p2)\b', re.IGNORECASE),
        'low': re.compile(r'\b(low priority|minor|p3|p4)\b', re.IGNORECASE)
    }
    
    # Extract labels from markdown: <!-- labels: bug, ui, frontend -->
    label_pattern = re.compile(r'<!--\s*labels?:\s*([^-->]+)\s*-->', re.IGNORECASE)
    
    for line in content.split('\n'):
        # Check for priority keywords
        for priority, pattern in priority_patterns.items():
            if pattern.search(line):
                metadata['priority_counts'][priority] += 1
        
        # Extract labels
        label_match = label_pattern.search(line)
        if label_match:
            labels = [l.strip() for l in label_match.group(1).split(',')]
            metadata['labels'].update(labels)
    
    # Calculate weighted severity score
    metadata['severity_score'] = (
        metadata['priority_counts']['high'] * 100 +
        metadata['priority_counts']['medium'] * 10 +
        metadata['priority_counts']['low'] * 1
    )
    
    return metadata

def scan_inline_todos(project_path: Path, debug_info: List[Dict] = None) -> Dict[str, int]:
    """Find TODO/FIXME comments in code files."""
    patterns = {
        'todo': re.compile(r'(//|#|<!--|\*|/\*)\s*TODO\b', re.IGNORECASE),
        'fixme': re.compile(r'(//|#|<!--|\*|/\*)\s*FIXME\b', re.IGNORECASE),
        'bug': re.compile(r'(//|#|<!--|\*|/\*)\s*BUG\b', re.IGNORECASE),
        'hack': re.compile(r'(//|#|<!--|\*|/\*)\s*HACK\b', re.IGNORECASE)
    }
    
    counts = {'todo': 0, 'fixme': 0, 'bug': 0, 'hack': 0}
    code_extensions = {'.py', '.js', '.ts', '.jsx', '.tsx', '.java', '.cpp', '.c', '.go', '.rs', 
                      '.php', '.rb', '.swift', '.kt', '.scala', '.clj', '.cs', '.fs', '.vb',
                      '.sh', '.bash', '.zsh', '.fish', '.html', '.css', '.scss', '.sass'}
    
    try:
        for file_path in project_path.rglob('*'):
            if (file_path.is_file() and 
                file_path.suffix.lower() in code_extensions and
                not any(excluded in str(file_path) for excluded in config.exclude_dirs)):
                
                try:
                    content = file_path.read_text(encoding='utf-8', errors='ignore')
                    file_counts = {}
                    
                    for pattern_type, pattern in patterns.items():
                        matches = pattern.findall(content)
                        count = len(matches)
                        counts[pattern_type] += count
                        if count > 0:
                            file_counts[pattern_type] = count
                    
                    if debug_info is not None and file_counts:
                        relative_path = file_path.relative_to(project_path)
                        debug_info.append({
                            'file': str(relative_path),
                            'inline_counts': file_counts,
                            'type': 'inline'
                        })
                        
                except (PermissionError, UnicodeDecodeError, OSError):
                    pass
    except (PermissionError, OSError):
        pass
    
    return counts

def count_items_in_files(project_path: Union[str, Path], file_patterns: List[str], 
                        subfolders: List[str], extensions: List[str], debug_info: List[Dict] = None) -> Dict[str, any]:
    """Count structured items in files matching given patterns with enhanced metrics."""
    project_path = Path(project_path)
    total_metrics = {
        'items': {'open': 0, 'completed': 0, 'total': 0},
        'lines': 0,
        'priority_counts': {'high': 0, 'medium': 0, 'low': 0},
        'severity_score': 0,
        'labels': set()
    }
    
    def scan_directory(dir_path):
        """Recursively scan a directory for matching files."""
        metrics = {
            'items': {'open': 0, 'completed': 0, 'total': 0},
            'lines': 0,
            'priority_counts': {'high': 0, 'medium': 0, 'low': 0},
            'severity_score': 0,
            'labels': set()
        }
        
        try:
            for item in dir_path.iterdir():
                if item.is_file():
                    name = item.name.upper()
                    
                    # Skip image files - common image extensions
                    image_extensions = {'.PNG', '.JPG', '.JPEG', '.GIF', '.BMP', '.TIFF', '.TIF', 
                                       '.WEBP', '.SVG', '.ICO', '.HEIC', '.HEIF', '.RAW',
                                       '.AVIF', '.JFIF', '.EPS', '.WEBM', '.MP4', '.AVI', '.MOV',
                                       '.PDF', '.APNG', '.FLIF', '.XBM', '.XPM', '.DDS', '.TGA'}
                    if any(name.endswith(ext) for ext in image_extensions):
                        continue
                    
                    # Check if filename contains any of the patterns
                    if any(pattern in name for pattern in file_patterns):
                        # Check if it has an allowed extension
                        if any(name.endswith(ext.upper()) for ext in extensions) or \
                           ('.' not in name and '' in extensions):
                            try:
                                content = item.read_text(encoding='utf-8', errors='ignore')
                                file_lines = sum(1 for _ in content.split('\n'))
                                
                                # Count structured items
                                item_counts = count_structured_items(content)
                                
                                # Extract metadata
                                metadata = extract_issue_metadata(content)
                                
                                # Update metrics
                                metrics['lines'] += file_lines
                                for key in item_counts:
                                    metrics['items'][key] += item_counts[key]
                                for priority in metadata['priority_counts']:
                                    metrics['priority_counts'][priority] += metadata['priority_counts'][priority]
                                metrics['severity_score'] += metadata['severity_score']
                                metrics['labels'].update(metadata['labels'])
                                
                                if debug_info is not None:
                                    relative_path = item.relative_to(project_path)
                                    debug_info.append({
                                        'file': str(relative_path),
                                        'lines': file_lines,
                                        'items': item_counts,
                                        'metadata': {
                                            'priority_counts': metadata['priority_counts'],
                                            'severity_score': metadata['severity_score'],
                                            'labels': list(metadata['labels'])
                                        },
                                        'type': 'structured'
                                    })
                            except (PermissionError, UnicodeDecodeError):
                                pass
        except PermissionError:
            pass
        return metrics
    
    # Scan root directory
    root_metrics = scan_directory(project_path)
    for key in total_metrics:
        if key == 'items':
            for subkey in total_metrics[key]:
                total_metrics[key][subkey] += root_metrics[key][subkey]
        elif key == 'priority_counts':
            for priority in total_metrics[key]:
                total_metrics[key][priority] += root_metrics[key][priority]
        elif key == 'labels':
            total_metrics[key].update(root_metrics[key])
        else:
            total_metrics[key] += root_metrics[key]
    
    # Scan specific subfolders
    for subfolder in subfolders:
        subfolder_path = project_path / subfolder
        if subfolder_path.exists() and subfolder_path.is_dir():
            subfolder_metrics = scan_directory(subfolder_path)
            for key in total_metrics:
                if key == 'items':
                    for subkey in total_metrics[key]:
                        total_metrics[key][subkey] += subfolder_metrics[key][subkey]
                elif key == 'priority_counts':
                    for priority in total_metrics[key]:
                        total_metrics[key][priority] += subfolder_metrics[key][priority]
                elif key == 'labels':
                    total_metrics[key].update(subfolder_metrics[key])
                else:
                    total_metrics[key] += subfolder_metrics[key]
    
    return total_metrics

def count_todo_items(project_path: Union[str, Path], debug_info: List[Dict] = None) -> Dict[str, any]:
    """Count TODO items using enhanced structured parsing and inline scanning."""
    # Get structured TODO items from dedicated files
    structured_metrics = count_items_in_files(project_path, config.todo_file_patterns, 
                                            config.todo_subfolders, config.todo_extensions, debug_info)
    
    # Get inline TODOs from code files
    inline_counts = scan_inline_todos(project_path, debug_info)
    
    # Combine metrics
    combined_metrics = {
        'structured': structured_metrics,
        'inline': inline_counts,
        'total_items': structured_metrics['items']['total'] + sum(inline_counts.values()),
        'total_lines': structured_metrics['lines'],
        'severity_score': structured_metrics['severity_score'] + (inline_counts['fixme'] * 50) + (inline_counts['bug'] * 75),
        'priority_counts': structured_metrics['priority_counts'].copy(),
        'labels': structured_metrics['labels'].copy()
    }
    
    return combined_metrics

def count_issue_items(project_path: Union[str, Path], debug_info: List[Dict] = None) -> Dict[str, any]:
    """Count issue items using enhanced structured parsing."""
    return count_items_in_files(project_path, config.issue_file_patterns, 
                               config.issue_subfolders, config.issue_extensions, debug_info)

def count_ideas_items(project_path: Union[str, Path], debug_info: List[Dict] = None) -> Dict[str, any]:
    """Count ideas items using enhanced structured parsing."""
    return count_items_in_files(project_path, config.ideas_file_patterns, 
                               config.ideas_subfolders, config.ideas_extensions, debug_info)

def count_todo_lines(project_path: Union[str, Path], debug_info: List[Dict] = None) -> int:
    """Legacy function for backward compatibility - count lines in TODO files."""
    metrics = count_todo_items(project_path, debug_info)
    return metrics['total_lines']

def count_issue_lines(project_path: Union[str, Path], debug_info: List[Dict] = None) -> int:
    """Legacy function for backward compatibility - count lines in issue files."""
    metrics = count_issue_items(project_path, debug_info)
    return metrics['lines']

def count_ideas_lines(project_path: Union[str, Path], debug_info: List[Dict] = None) -> int:
    """Legacy function for backward compatibility - count lines in ideas files."""
    metrics = count_ideas_items(project_path, debug_info)
    return metrics['lines']

def calculate_importance_score(project: Dict[str, Union[str, int, float, Path, List[str], None]]) -> int:
    """Calculate importance score based on enhanced issue and TODO metrics."""
    score = 0
    
    # Enhanced issue scoring using severity and priority
    if 'issue_metrics' in project and project['issue_metrics']:
        issue_metrics = project['issue_metrics']
        # Base score from issue severity
        score += issue_metrics['severity_score'] * 10
        # Additional score for open items
        score += issue_metrics['items']['open'] * 500
        # High priority items get extra weight
        score += issue_metrics['priority_counts']['high'] * 200
        score += issue_metrics['priority_counts']['medium'] * 50
    else:
        # Fallback to legacy line count
        score += project.get('issue_lines', 0) * 1000
    
    # Git status: non-clean repos need attention
    if project['git_status'] and project['git_status'] != '✓':
        score += 100
    
    # Enhanced TODO scoring
    if 'todo_metrics' in project and project['todo_metrics']:
        todo_metrics = project['todo_metrics']
        # Score based on TODO severity
        score += todo_metrics['severity_score']
        # Additional score for total items
        score += todo_metrics['total_items'] * 5
        # Inline FIXMEs and BUGs are more urgent
        score += todo_metrics['inline'].get('fixme', 0) * 25
        score += todo_metrics['inline'].get('bug', 0) * 40
    else:
        # Fallback to legacy line count
        score += project.get('todo_lines', 0) * 10
    
    return score

def get_project_info(project_path: Union[str, Path], collect_debug: bool = False, scan_root: Union[str, Path, None] = None) -> Dict[str, Union[str, int, float, Path, List[str], None]]:
    """Get comprehensive information about a project."""
    project_path = Path(project_path)
    
    # Calculate folder name relative to scan root if provided
    if scan_root is not None:
        scan_root = Path(scan_root)
        try:
            folder_name = str(project_path.relative_to(scan_root))
            # Replace "." with actual directory name for better UX
            if folder_name == ".":
                folder_name = project_path.name
        except ValueError:
            # Fallback if project_path is not relative to scan_root
            folder_name = project_path.name
    else:
        folder_name = project_path.name
    
    # Get project name from README
    readme_path = project_path / 'README.md'
    project_name = extract_project_name(readme_path) or folder_name
    
    # Get git branch and status
    git_branch = get_git_branch(project_path)
    git_status = get_git_status(project_path)
    
    # Initialize debug info collections
    tech_debug = [] if collect_debug else None
    todo_debug = [] if collect_debug else None
    issue_debug = [] if collect_debug else None
    ideas_debug = [] if collect_debug else None
    
    # Detect technologies
    technologies = detect_technologies(project_path, tech_debug)
    
    # Enhanced TODO, issue, and ideas metrics
    todo_metrics = count_todo_items(project_path, todo_debug)
    issue_metrics = count_issue_items(project_path, issue_debug)
    ideas_metrics = count_ideas_items(project_path, ideas_debug)
    
    # Legacy line counts for backward compatibility
    todo_lines = todo_metrics['total_lines']
    issue_lines = issue_metrics['lines']
    ideas_lines = ideas_metrics['lines']
    
    # Get modification times
    try:
        mod_time = project_path.stat().st_mtime
        create_time = project_path.stat().st_ctime
    except OSError:
        mod_time = create_time = 0
    
    project_data = {
        'folder': folder_name,
        'name': project_name,
        'branch': git_branch,
        'git_status': git_status,
        'technologies': technologies,
        'todo_lines': todo_lines,
        'issue_lines': issue_lines,
        'ideas_lines': ideas_lines,
        'todo_metrics': todo_metrics,
        'issue_metrics': issue_metrics,
        'ideas_metrics': ideas_metrics,
        'mod_time': mod_time,
        'create_time': create_time,
        'path': project_path
    }
    
    # Add debug information if requested
    if collect_debug:
        project_data['debug'] = {
            'technologies': tech_debug,
            'todos': todo_debug,
            'issues': issue_debug,
            'ideas': ideas_debug
        }
    
    # Calculate importance score
    project_data['importance_score'] = calculate_importance_score(project_data)
    
    return project_data

def is_project_directory(path: Union[str, Path]) -> bool:
    """Determine if a directory contains a project."""
    path = Path(path)
    
    # Check for common project indicators
    indicators = [
        'README.md', 'readme.md',
        'package.json',
        'requirements.txt', 'Pipfile', 'pyproject.toml', 'setup.py', 'setup.cfg',
        'Cargo.toml',
        'go.mod',
        'pom.xml', 'build.gradle',
        '.git',
        # Planning/documentation indicators
        'TODO.md', 'TODOS.md', 'PLANNING.md', 'DESIGN.md'
    ]
    
    # First check for explicit project indicators
    if any((path / indicator).exists() for indicator in indicators):
        return True
    
    # Fallback: check if directory contains significant code files
    return _has_significant_code_files(path)

def _has_significant_code_files(path: Path) -> bool:
    """Check if directory contains significant code files that indicate a project."""
    try:
        # Check for Python files
        if _has_python_files(path):
            return True
            
        # Check for Python executables with shebangs
        if _has_python_executables(path):
            return True
            
        # Check for other common code file extensions
        code_extensions = {'.js', '.ts', '.jsx', '.tsx', '.rs', '.go', '.java', '.cpp', '.c', '.php', '.rb'}
        
        for item in path.iterdir():
            if item.is_file() and item.suffix in code_extensions:
                return True
                
        # Check in common code directories
        for subdir_name in ['src', 'lib', 'app']:
            subdir = path / subdir_name
            if subdir.exists() and subdir.is_dir():
                for item in subdir.iterdir():
                    if item.is_file() and item.suffix in code_extensions:
                        return True
                        
    except (PermissionError, OSError):
        pass
        
    return False

def scan_projects(root_path: Union[str, Path], depth: int = 0, collect_debug: bool = False, scan_root: Union[str, Path, None] = None) -> List[Dict[str, Union[str, int, float, Path, List[str], None]]]:
    """Scan for projects in the given directory with depth limiting and filtering."""
    root_path = Path(root_path)
    projects = []
    
    # Set scan_root to root_path if not provided (first call)
    if scan_root is None:
        scan_root = root_path
        # Check if the root directory itself is a project
        if is_project_directory(root_path):
            projects.append(get_project_info(root_path, collect_debug, scan_root))
    
    # Check depth limit
    if depth > config.max_scan_depth:
        return projects
    
    try:
        for item in root_path.iterdir():
            # Skip hidden directories and excluded directories
            if item.name.startswith('.') or item.name in config.exclude_dirs:
                continue
                
            # Skip if matches exclude patterns
            if any(pattern in item.name for pattern in config.exclude_patterns):
                continue
                
            # Skip if matches filter directories
            if item.name in config.filter_dirs:
                continue
                
            if item.is_dir():
                if is_project_directory(item):
                    projects.append(get_project_info(item, collect_debug, scan_root))
                else:
                    # Recursively scan subdirectories if not a project
                    projects.extend(scan_projects(item, depth + 1, collect_debug, scan_root))
    except PermissionError:
        print(f"Permission denied accessing {root_path}", file=sys.stderr)
    
    return projects

def calculate_column_widths(projects, show_name=False):
    """Calculate optimal column widths for the table."""
    # Get terminal width
    terminal_width = shutil.get_terminal_size().columns
    
    # Minimum widths for headers (conditionally include Name column)
    if show_name:
        widths = [len("Name"), len("Project"), len("Branch"), len("Git"), len("Stack"), len("TODOs"), len("Issues"), len("Ideas")]
    else:
        widths = [len("Project"), len("Branch"), len("Git"), len("Stack"), len("TODOs"), len("Issues"), len("Ideas")]
    
    for project in projects:
        col_idx = 0
        
        if show_name:
            # Project name - cap at configured length
            project_name = project['name']
            widths[col_idx] = max(widths[col_idx], min(len(project_name), config.max_project_name_length))
            col_idx += 1
        
        # Folder name - cap at configured length
        folder_name = project['folder']
        widths[col_idx] = max(widths[col_idx], min(len(folder_name), config.max_folder_name_length))
        col_idx += 1
        
        # Branch
        branch_text = project['branch'] or ""
        widths[col_idx] = max(widths[col_idx], len(branch_text))
        col_idx += 1
        
        # Git status - keep it minimal (4 characters should be enough)
        status_text = project['git_status'] or ""
        widths[col_idx] = max(widths[col_idx], min(len(status_text), 4))
        col_idx += 1
        
        # Technologies
        tech_text = ', '.join(project['technologies']) if project['technologies'] else ""
        widths[col_idx] = max(widths[col_idx], len(tech_text))
        col_idx += 1
        
        # TODOs - show enhanced format if available
        if 'todo_metrics' in project and project['todo_metrics']:
            todo_metrics = project['todo_metrics']
            todo_text = f"{todo_metrics['total_items']}"
            if todo_metrics['inline'] and sum(todo_metrics['inline'].values()) > 0:
                inline_total = sum(todo_metrics['inline'].values())
                todo_text += f"+{inline_total}"
        else:
            todo_text = str(project['todo_lines'])
        widths[col_idx] = max(widths[col_idx], len(todo_text))
        col_idx += 1
        
        # Issues - show enhanced format if available
        if 'issue_metrics' in project and project['issue_metrics']:
            issue_metrics = project['issue_metrics']
            issue_text = f"{issue_metrics['items']['total']}"
            if issue_metrics['items']['open'] > 0:
                issue_text += f"({issue_metrics['items']['open']})"
        else:
            issue_text = str(project['issue_lines'])
        widths[col_idx] = max(widths[col_idx], len(issue_text))
        col_idx += 1
        
        # Ideas - show enhanced format if available
        if 'ideas_metrics' in project and project['ideas_metrics']:
            ideas_metrics = project['ideas_metrics']
            ideas_text = f"{ideas_metrics['items']['total']}"
            if ideas_metrics['items']['open'] > 0:
                ideas_text += f"({ideas_metrics['items']['open']})"
        else:
            ideas_text = str(project['ideas_lines'])
        widths[col_idx] = max(widths[col_idx], len(ideas_text))
    
    # Enforce maximum widths
    if show_name:
        widths[0] = min(widths[0], config.max_project_name_length)
        widths[1] = min(widths[1], config.max_folder_name_length)
    else:
        widths[0] = min(widths[0], config.max_folder_name_length)
    
    # Calculate table overhead (borders and padding)
    table_overhead = len(widths) * 3 + 1  # │ col │ col │ etc
    available_width = terminal_width - table_overhead
    
    # If table would be too wide, proportionally reduce column widths
    total_width = sum(widths)
    if total_width > available_width:
        ratio = available_width / total_width
        widths = [max(config.min_column_width, int(w * ratio)) for w in widths]
        # Re-enforce maximums after proportional reduction
        if show_name:
            widths[0] = min(widths[0], config.max_project_name_length)
            widths[1] = min(widths[1], config.max_folder_name_length)
        else:
            widths[0] = min(widths[0], config.max_folder_name_length)
    
    return widths

def format_table_row(project, widths, show_name=False):
    """Format a single project as a table row."""
    col_idx = 0
    columns = []
    
    if show_name:
        # Project name
        project_name = project['name']
        if len(project_name) > widths[col_idx]:
            project_name = project_name[:widths[col_idx]-1] + "…"
        columns.append(f" {project_name:<{widths[col_idx]}} ")
        col_idx += 1
    
    # Folder name
    folder_name = project['folder']
    if len(folder_name) > widths[col_idx]:
        folder_name = folder_name[:widths[col_idx]-1] + "…"
    columns.append(f" {folder_name:<{widths[col_idx]}} ")
    col_idx += 1
    
    # Branch
    branch_text = project['branch'] or ""
    if len(branch_text) > widths[col_idx]:
        branch_text = branch_text[:widths[col_idx]-1] + "…"
    columns.append(f" {branch_text:<{widths[col_idx]}} ")
    col_idx += 1
    
    # Git status
    status_text = project['git_status'] or ""
    if len(status_text) > widths[col_idx]:
        status_text = status_text[:widths[col_idx]-1] + "…"
    columns.append(f" {status_text:<{widths[col_idx]}} ")
    col_idx += 1
    
    # Technologies
    tech_text = ', '.join(project['technologies']) if project['technologies'] else ""
    if len(tech_text) > widths[col_idx]:
        tech_text = tech_text[:widths[col_idx]-1] + "…"
    columns.append(f" {tech_text:<{widths[col_idx]}} ")
    col_idx += 1
    
    # TODOs - show enhanced format if available
    if 'todo_metrics' in project and project['todo_metrics']:
        todo_metrics = project['todo_metrics']
        todo_text = f""
        if todo_metrics['inline'] and sum(todo_metrics['inline'].values()) > 0:
            inline_total = sum(todo_metrics['inline'].values())
            todo_text += f"{inline_total}"
        else:
            todo_text += f"0"
        todo_text += f"/{todo_metrics['total_items']}"
    else:
        todo_text = str(project['todo_lines'])
    if len(todo_text) > widths[col_idx]:
        todo_text = todo_text[:widths[col_idx]-1] + "…"
    columns.append(f" {todo_text:<{widths[col_idx]}} ")
    col_idx += 1
    
    # Issues - show enhanced format if available
    if 'issue_metrics' in project and project['issue_metrics']:
        issue_metrics = project['issue_metrics']
        issue_text = f""
        if issue_metrics['items']['open'] > 0:
            issue_text += f"{issue_metrics['items']['open']}"
        else:
            issue_text += f"0"
        issue_text += f"/{issue_metrics['items']['total']}"
    else:
        issue_text = str(project['issue_lines'])
    if len(issue_text) > widths[col_idx]:
        issue_text = issue_text[:widths[col_idx]-1] + "…"
    columns.append(f" {issue_text:<{widths[col_idx]}} ")
    col_idx += 1
    
    # Ideas - show enhanced format if available
    if 'ideas_metrics' in project and project['ideas_metrics']:
        ideas_metrics = project['ideas_metrics']
        ideas_text = f""
        if ideas_metrics['items']['open'] > 0:
            ideas_text += f"{ideas_metrics['items']['open']}"
        else:
            ideas_text += f"0"
        ideas_text += f"/{ideas_metrics['items']['total']}"
    else:
        ideas_text = str(project['ideas_lines'])
    if len(ideas_text) > widths[col_idx]:
        ideas_text = ideas_text[:widths[col_idx]-1] + "…"
    columns.append(f" {ideas_text:<{widths[col_idx]}} ")
    
    return "│" + "│".join(columns) + "│"

def format_table_separator(widths, top=False, bottom=False):
    """Format table separator line."""
    if top:
        left, mid, right, cross = "┌", "─", "┐", "┬"
    elif bottom:
        left, mid, right, cross = "└", "─", "┘", "┴"
    else:
        left, mid, right, cross = "├", "─", "┤", "┼"
    
    parts = []
    for i, width in enumerate(widths):
        parts.append(mid * (width + 2))
    
    return left + cross.join(parts) + right

def format_table_header(widths, show_name=False):
    """Format the table header row."""
    if show_name:
        headers = ["Name", "Project", "Branch", "Git", "Stack", "TODOs", "Issues", "Ideas"]
    else:
        headers = ["Project", "Branch", "Git", "Stack", "TODOs", "Issues", "Ideas"]
    formatted_headers = [f" {header:<{width}} " for header, width in zip(headers, widths)]
    return "│" + "│".join(formatted_headers) + "│"

def format_debug_info(projects):
    """Format debug information for verbose output."""
    output = []
    
    for project in projects:
        debug_data = project.get('debug')
        if not debug_data:
            continue
            
        has_debug_info = (
            debug_data.get('technologies') or 
            debug_data.get('todos') or 
            debug_data.get('issues')
        )
        
        if not has_debug_info:
            continue
            
        output.append(f"\n## Debug Information for {project['name']} ({project['folder']})")
        
        # Technology sources
        if debug_data.get('technologies'):
            output.append("### Technology Detection Sources:")
            for tech_info in debug_data['technologies']:
                technologies_str = ', '.join(tech_info['technologies'])
                if tech_info['type'] == 'file':
                    output.append(f"  • {tech_info['source']} → {technologies_str}")
                elif tech_info['type'] == 'dependency':
                    output.append(f"  • {tech_info['source']} → {technologies_str}")
                elif tech_info['type'] == 'pattern':
                    output.append(f"  • {tech_info['source']} → {technologies_str}")
                elif tech_info['type'] == 'inference':
                    output.append(f"  • {tech_info['source']} → {technologies_str}")
        
        # TODO sources
        if debug_data.get('todos'):
            output.append("### TODO Sources:")
            for todo_info in debug_data['todos']:
                if todo_info.get('type') == 'structured':
                    items = todo_info.get('items', {})
                    metadata = todo_info.get('metadata', {})
                    output.append(f"  • {todo_info['file']} ({todo_info['lines']} lines, {items.get('total', 0)} items)")
                    if items.get('completed', 0) > 0:
                        output.append(f"    - {items['completed']} completed, {items['open']} open")
                    if metadata.get('severity_score', 0) > 0:
                        output.append(f"    - Priority score: {metadata['severity_score']}")
                elif todo_info.get('type') == 'inline':
                    inline_counts = todo_info.get('inline_counts', {})
                    counts_str = ', '.join([f"{k}: {v}" for k, v in inline_counts.items() if v > 0])
                    output.append(f"  • {todo_info['file']} (inline: {counts_str})")
                else:
                    # Legacy format
                    output.append(f"  • {todo_info['file']} ({todo_info['lines']} lines)")
        
        # Issue sources
        if debug_data.get('issues'):
            output.append("### Issue Sources:")
            for issue_info in debug_data['issues']:
                if issue_info.get('type') == 'structured':
                    items = issue_info.get('items', {})
                    metadata = issue_info.get('metadata', {})
                    output.append(f"  • {issue_info['file']} ({issue_info['lines']} lines, {items.get('total', 0)} items)")
                    if items.get('completed', 0) > 0:
                        output.append(f"    - {items['completed']} completed, {items['open']} open")
                    if metadata.get('severity_score', 0) > 0:
                        output.append(f"    - Priority score: {metadata['severity_score']}")
                    if metadata.get('labels'):
                        labels_str = ', '.join(metadata['labels'])
                        output.append(f"    - Labels: {labels_str}")
                else:
                    # Legacy format
                    output.append(f"  • {issue_info['file']} ({issue_info['lines']} lines)")
        
        # Ideas sources
        if debug_data.get('ideas'):
            output.append("### Ideas Sources:")
            for ideas_info in debug_data['ideas']:
                if ideas_info.get('type') == 'structured':
                    items = ideas_info.get('items', {})
                    metadata = ideas_info.get('metadata', {})
                    output.append(f"  • {ideas_info['file']} ({ideas_info['lines']} lines, {items.get('total', 0)} items)")
                    if items.get('completed', 0) > 0:
                        output.append(f"    - {items['completed']} completed, {items['open']} open")
                    if metadata.get('severity_score', 0) > 0:
                        output.append(f"    - Priority score: {metadata['severity_score']}")
                    if metadata.get('labels'):
                        labels_str = ', '.join(metadata['labels'])
                        output.append(f"    - Labels: {labels_str}")
                else:
                    # Legacy format
                    output.append(f"  • {ideas_info['file']} ({ideas_info['lines']} lines)")
        
        output.append("")  # Add blank line between projects
    
    return '\n'.join(output)

def main():
    parser = argparse.ArgumentParser(description='Summarize projects in a directory')
    parser.add_argument('folder', nargs='?', default='.', help='Directory to scan (default: current directory)')
    parser.add_argument('-s', '--sort', choices=['alpha', 'modified', 'created', 'importance'], 
                       default='importance', help='Sort projects by alpha, modified, created date, or importance (issues, git status, TODOs)')
    parser.add_argument('-j', '--json', action='store_true', help='Output results as JSON')
    parser.add_argument('-V', '--verbose', action='store_true', help='Show debug information about sources of TODOs, issues, and technologies')
    parser.add_argument('--no-progress', action='store_true', help='Disable progress indicators')
    parser.add_argument('--exclude', action='append', help='Additional directories to exclude (can be used multiple times)')
    parser.add_argument('--filter', action='append', help='Additional directories to filter/ignore (can be used multiple times)')
    parser.add_argument('--show-name', action='store_true', help='Include Name column in table output')
    parser.add_argument('-v', '--version', action='version', version=f'p {VERSION}')
    
    args = parser.parse_args()
    
    # Apply command line exclusions to config
    if args.exclude:
        config.exclude_dirs.extend(args.exclude)
    
    # Apply command line filters to config
    if args.filter:
        config.filter_dirs.extend(args.filter)
    
    # Override progress setting if specified
    if args.no_progress:
        config.show_progress = False
    
    # Determine whether to show name column (command line overrides config)
    show_name = args.show_name or config.show_name_column
    
    # Resolve path
    scan_path = Path(args.folder).resolve()
    
    if not scan_path.exists():
        print(f"Error: Directory '{args.folder}' does not exist", file=sys.stderr)
        sys.exit(1)
    
    if not scan_path.is_dir():
        print(f"Error: '{args.folder}' is not a directory", file=sys.stderr)
        sys.exit(1)
    
    projects = scan_projects(scan_path, collect_debug=args.verbose)
    
    if not projects:
        if args.json:
            print(json.dumps({"projects": [], "scan_path": str(scan_path)}))
        else:
            print(f"No projects found in {scan_path}")
        return
    
    # Sort projects
    if args.sort == 'alpha':
        projects.sort(key=lambda p: p['folder'].lower())
    elif args.sort == 'created':
        projects.sort(key=lambda p: p['create_time'], reverse=True)
    elif args.sort == 'modified':
        projects.sort(key=lambda p: p['mod_time'], reverse=True)
    else:  # importance (default)
        projects.sort(key=lambda p: p['importance_score'], reverse=True)
    
    # Output results
    if args.json:
        # Convert Path objects and sets to strings for JSON serialization
        def convert_sets_to_lists(obj):
            """Recursively convert sets to lists for JSON serialization."""
            if isinstance(obj, dict):
                return {k: convert_sets_to_lists(v) for k, v in obj.items()}
            elif isinstance(obj, list):
                return [convert_sets_to_lists(item) for item in obj]
            elif isinstance(obj, set):
                return list(obj)
            elif isinstance(obj, Path):
                return str(obj)
            else:
                return obj
        
        json_projects = []
        for project in projects:
            json_project = convert_sets_to_lists(project)
            json_projects.append(json_project)
        
        output = {
            "projects": json_projects,
            "scan_path": str(scan_path),
            "sort_method": args.sort,
            "total_projects": len(projects)
        }
        print(json.dumps(output, indent=2))
    else:
        print()
        
        # Calculate column widths
        widths = calculate_column_widths(projects, show_name)
        
        # Print table
        print(format_table_separator(widths, top=True))
        print(format_table_header(widths, show_name))
        print(format_table_separator(widths))
        
        for project in projects:
            print(format_table_row(project, widths, show_name))
        
        print(format_table_separator(widths, bottom=True))
        
        # Show debug information if verbose mode is enabled
        if args.verbose:
            debug_output = format_debug_info(projects)
            if debug_output.strip():
                print(debug_output)

if __name__ == '__main__':
    main()