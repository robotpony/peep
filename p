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
        self.max_folder_name_length = 20
        self.min_column_width = 8
        self.default_git_branch = 'main'
        self.git_timeout = 5
        self.max_scan_depth = 10
        self.show_progress = True
        
        # Issue tracking configuration
        self.issue_subfolders = ['bugs', 'issues', 'tasks', 'docs', 'design']
        self.issue_file_patterns = ['ISSUES', 'BUGS', 'BUG', 'ISSUE']
        self.issue_extensions = ['.md', '.txt', '']
        
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

def detect_technologies(project_path: Union[str, Path]) -> List[str]:
    """Detect technologies used in the project."""
    technologies = []
    
    # Check for common project files
    tech_files = {
        'package.json': ['JS', 'node.js'],
        'requirements.txt': ['Python'],
        'Pipfile': ['Python'],
        'pyproject.toml': ['Python'],
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
        'Makefile': ['Make']
    }
    
    # Merge with custom tech files from config
    tech_files.update(config.custom_tech_files)
    
    for filename, techs in tech_files.items():
        if (Path(project_path) / filename).exists():
            technologies.extend(techs)
    
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
                    
        except (json.JSONDecodeError, KeyError, UnicodeDecodeError):
            # Malformed JSON or encoding issues
            pass
    
    # Check for static website (index.html without other script technologies)
    index_html_path = Path(project_path) / 'index.html'
    if index_html_path.exists() and not technologies:
        # Only add "static website" if no other technologies detected
        technologies.append('static website')
    
    return list(dict.fromkeys(technologies))  # Remove duplicates while preserving order

def count_lines_in_files(project_path: Union[str, Path], file_patterns: List[str], 
                        subfolders: List[str], extensions: List[str]) -> int:
    """Count lines in files matching given patterns."""
    project_path = Path(project_path)
    total_lines = 0
    
    def scan_directory(dir_path):
        """Recursively scan a directory for matching files."""
        lines = 0
        try:
            for item in dir_path.iterdir():
                if item.is_file():
                    name = item.name.upper()
                    # Check if filename contains any of the patterns
                    if any(pattern in name for pattern in file_patterns):
                        # Check if it has an allowed extension
                        if any(name.endswith(ext.upper()) for ext in extensions) or \
                           ('.' not in name and '' in extensions):
                            try:
                                with open(item, 'r', encoding='utf-8', errors='ignore') as f:
                                    lines += sum(1 for _ in f)
                            except (PermissionError, UnicodeDecodeError):
                                pass
        except PermissionError:
            pass
        return lines
    
    # Scan root directory
    total_lines += scan_directory(project_path)
    
    # Scan specific subfolders
    for subfolder in subfolders:
        subfolder_path = project_path / subfolder
        if subfolder_path.exists() and subfolder_path.is_dir():
            total_lines += scan_directory(subfolder_path)
    
    return total_lines

def count_todo_lines(project_path: Union[str, Path]) -> int:
    """Count lines in files with 'TODO' in uppercase in the title."""
    return count_lines_in_files(project_path, config.todo_file_patterns, config.todo_subfolders, config.todo_extensions)

def count_issue_lines(project_path: Union[str, Path]) -> int:
    """Count lines in ISSUES.md, BUGS.md and similar files."""
    return count_lines_in_files(project_path, config.issue_file_patterns, config.issue_subfolders, config.issue_extensions)

def calculate_importance_score(project: Dict[str, Union[str, int, float, Path, List[str], None]]) -> int:
    """Calculate importance score based on issues, git status, and TODOs."""
    score = 0
    
    # Issues are highest priority (×1000)
    score += project['issue_lines'] * 1000
    
    # Git status: non-clean repos need attention (+100)
    if project['git_status'] and project['git_status'] != '✓':
        score += 100
    
    # TODOs are lower priority (×10)
    score += project['todo_lines'] * 10
    
    return score

def get_project_info(project_path: Union[str, Path]) -> Dict[str, Union[str, int, float, Path, List[str], None]]:
    """Get comprehensive information about a project."""
    project_path = Path(project_path)
    folder_name = project_path.name
    
    # Get project name from README
    readme_path = project_path / 'README.md'
    project_name = extract_project_name(readme_path) or folder_name
    
    # Get git branch and status
    git_branch = get_git_branch(project_path)
    git_status = get_git_status(project_path)
    
    # Detect technologies
    technologies = detect_technologies(project_path)
    
    # Count TODO lines
    todo_lines = count_todo_lines(project_path)
    
    # Count issue lines
    issue_lines = count_issue_lines(project_path)
    
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
        'mod_time': mod_time,
        'create_time': create_time,
        'path': project_path
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
        'requirements.txt', 'Pipfile',
        'Cargo.toml',
        'go.mod',
        'pom.xml', 'build.gradle',
        '.git'
    ]
    
    return any((path / indicator).exists() for indicator in indicators)

def scan_projects(root_path: Union[str, Path], depth: int = 0) -> List[Dict[str, Union[str, int, float, Path, List[str], None]]]:
    """Scan for projects in the given directory with depth limiting and filtering."""
    root_path = Path(root_path)
    projects = []
    
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
                
            if item.is_dir():
                if is_project_directory(item):
                    projects.append(get_project_info(item))
                else:
                    # Recursively scan subdirectories if not a project
                    projects.extend(scan_projects(item, depth + 1))
    except PermissionError:
        print(f"Permission denied accessing {root_path}", file=sys.stderr)
    
    return projects

def calculate_column_widths(projects):
    """Calculate optimal column widths for the table."""
    # Get terminal width
    terminal_width = shutil.get_terminal_size().columns
    
    # Minimum widths for headers
    widths = [len("Name"), len("Folder"), len("Branch"), len("Git"), len("Technologies"), len("TODOs"), len("Issues")]
    
    for project in projects:
        # Project name - cap at configured length
        project_name = project['name']
        widths[0] = max(widths[0], min(len(project_name), config.max_project_name_length))
        
        # Folder name - cap at configured length
        folder_name = project['folder']
        widths[1] = max(widths[1], min(len(folder_name), config.max_folder_name_length))
        
        # Branch
        branch_text = project['branch'] or ""
        widths[2] = max(widths[2], len(branch_text))
        
        # Git status - keep it minimal (4 characters should be enough)
        status_text = project['git_status'] or ""
        widths[3] = max(widths[3], min(len(status_text), 4))
        
        # Technologies
        tech_text = ', '.join(project['technologies']) if project['technologies'] else ""
        widths[4] = max(widths[4], len(tech_text))
        
        # TODOs
        todo_text = str(project['todo_lines'])
        widths[5] = max(widths[5], len(todo_text))
        
        # Issues
        issue_text = str(project['issue_lines'])
        widths[6] = max(widths[6], len(issue_text))
    
    # Enforce maximum widths
    widths[0] = min(widths[0], config.max_project_name_length)
    widths[1] = min(widths[1], config.max_folder_name_length)
    
    # Calculate table overhead (borders and padding)
    table_overhead = len(widths) * 3 + 1  # │ col │ col │ etc
    available_width = terminal_width - table_overhead
    
    # If table would be too wide, proportionally reduce column widths
    total_width = sum(widths)
    if total_width > available_width:
        ratio = available_width / total_width
        widths = [max(config.min_column_width, int(w * ratio)) for w in widths]
        # Re-enforce maximums after proportional reduction
        widths[0] = min(widths[0], config.max_project_name_length)
        widths[1] = min(widths[1], config.max_folder_name_length)
    
    return widths

def format_table_row(project, widths):
    """Format a single project as a table row."""
    # Project name
    project_name = project['name']
    
    # Folder name
    folder_name = project['folder']
    
    # Branch
    branch_text = project['branch'] or ""
    
    # Git status
    status_text = project['git_status'] or ""
    
    # Technologies
    tech_text = ', '.join(project['technologies']) if project['technologies'] else ""
    
    # TODOs
    todo_text = str(project['todo_lines'])
    
    # Issues
    issue_text = str(project['issue_lines'])
    
    # Truncate if too long (with ellipsis for visual indication)
    if len(project_name) > widths[0]:
        project_name = project_name[:widths[0]-1] + "…"
    if len(folder_name) > widths[1]:
        folder_name = folder_name[:widths[1]-1] + "…"
    if len(branch_text) > widths[2]:
        branch_text = branch_text[:widths[2]-1] + "…"
    if len(status_text) > widths[3]:
        status_text = status_text[:widths[3]-1] + "…"
    if len(tech_text) > widths[4]:
        tech_text = tech_text[:widths[4]-1] + "…"
    if len(todo_text) > widths[5]:
        todo_text = todo_text[:widths[5]-1] + "…"
    if len(issue_text) > widths[6]:
        issue_text = issue_text[:widths[6]-1] + "…"
    
    return f"│ {project_name:<{widths[0]}} │ {folder_name:<{widths[1]}} │ {branch_text:<{widths[2]}} │ {status_text:<{widths[3]}} │ {tech_text:<{widths[4]}} │ {todo_text:<{widths[5]}} │ {issue_text:<{widths[6]}} │"

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

def format_table_header(widths):
    """Format the table header row."""
    headers = ["Name", "Folder", "Branch", "Git", "Technologies", "TODOs", "Issues"]
    formatted_headers = [f" {header:<{width}} " for header, width in zip(headers, widths)]
    return "│" + "│".join(formatted_headers) + "│"

def main():
    parser = argparse.ArgumentParser(description='Summarize projects in a directory')
    parser.add_argument('folder', nargs='?', default='.', help='Directory to scan (default: current directory)')
    parser.add_argument('-s', '--sort', choices=['alpha', 'modified', 'created', 'importance'], 
                       default='importance', help='Sort projects by alpha, modified, created date, or importance (issues, git status, TODOs)')
    parser.add_argument('-j', '--json', action='store_true', help='Output results as JSON')
    parser.add_argument('--no-progress', action='store_true', help='Disable progress indicators')
    parser.add_argument('--exclude', action='append', help='Additional directories to exclude (can be used multiple times)')
    parser.add_argument('-v', '--version', action='version', version=f'p {VERSION}')
    
    args = parser.parse_args()
    
    # Apply command line exclusions to config
    if args.exclude:
        config.exclude_dirs.extend(args.exclude)
    
    # Override progress setting if specified
    if args.no_progress:
        config.show_progress = False
    
    # Resolve path
    scan_path = Path(args.folder).resolve()
    
    if not scan_path.exists():
        print(f"Error: Directory '{args.folder}' does not exist", file=sys.stderr)
        sys.exit(1)
    
    if not scan_path.is_dir():
        print(f"Error: '{args.folder}' is not a directory", file=sys.stderr)
        sys.exit(1)
    
    # Scan for projects with progress indication
    if config.show_progress and not args.json:
        print(f"Scanning {scan_path}...", file=sys.stderr)
    
    projects = scan_projects(scan_path)
    
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
        # Convert Path objects to strings for JSON serialization
        json_projects = []
        for project in projects:
            json_project = project.copy()
            json_project['path'] = str(json_project['path'])
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
        widths = calculate_column_widths(projects)
        
        # Print table
        print(format_table_separator(widths, top=True))
        print(format_table_header(widths))
        print(format_table_separator(widths))
        
        for project in projects:
            print(format_table_row(project, widths))
        
        print(format_table_separator(widths, bottom=True))

if __name__ == '__main__':
    main()