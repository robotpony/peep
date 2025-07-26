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

VERSION = "1.0.0"

# Configuration constants
MAX_PROJECT_NAME_LENGTH = 25
MAX_FOLDER_NAME_LENGTH = 20
MIN_COLUMN_WIDTH = 8
DEFAULT_GIT_BRANCH = 'main'
GIT_TIMEOUT = 5

# Issue tracking constants
ISSUE_SUBFOLDERS = ['bugs', 'issues', 'tasks', 'docs', 'design']
ISSUE_FILE_PATTERNS = ['ISSUES', 'BUGS', 'BUG', 'ISSUE']
ISSUE_EXTENSIONS = ['.md', '.txt', '']

# TODO tracking constants
TODO_SUBFOLDERS = ['tasks', 'docs', 'design']
TODO_FILE_PATTERNS = ['TODO']
TODO_EXTENSIONS = ['.txt', '.md', '']

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
            timeout=GIT_TIMEOUT,
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
                    if '[ahead' in line:
                        status_chars.append('↑')
                    elif '[behind' in line:
                        status_chars.append('↓')
                    elif '[ahead' in line and 'behind' in line:
                        status_chars.append('↕')
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
            timeout=GIT_TIMEOUT,
            shell=False
        )
        if result.returncode == 0:
            branch = result.stdout.strip() or DEFAULT_GIT_BRANCH
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
            
            if 'react' in deps:
                technologies.append('react')
            if 'vue' in deps:
                technologies.append('vue')
            if 'angular' in deps:
                technologies.append('angular')
            if 'typescript' in deps:
                technologies.append('typescript')
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
    return count_lines_in_files(project_path, TODO_FILE_PATTERNS, TODO_SUBFOLDERS, TODO_EXTENSIONS)

def count_issue_lines(project_path: Union[str, Path]) -> int:
    """Count lines in ISSUES.md, BUGS.md and similar files."""
    return count_lines_in_files(project_path, ISSUE_FILE_PATTERNS, ISSUE_SUBFOLDERS, ISSUE_EXTENSIONS)

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
    
    return {
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

def scan_projects(root_path: Union[str, Path]) -> List[Dict[str, Union[str, int, float, Path, List[str], None]]]:
    """Scan for projects in the given directory."""
    root_path = Path(root_path)
    projects = []
    
    try:
        for item in root_path.iterdir():
            if item.is_dir() and not item.name.startswith('.'):
                if is_project_directory(item):
                    projects.append(get_project_info(item))
    except PermissionError:
        print(f"Permission denied accessing {root_path}", file=sys.stderr)
    
    return projects

def calculate_column_widths(projects):
    """Calculate optimal column widths for the table."""
    # Get terminal width
    terminal_width = shutil.get_terminal_size().columns
    
    # Minimum widths for headers
    widths = [len("Project"), len("Path"), len("Branch"), len("Git"), len("Tech"), len("TODOs"), len("Issues")]
    
    for project in projects:
        # Project name - cap at MAX_PROJECT_NAME_LENGTH characters
        project_name = project['name']
        widths[0] = max(widths[0], min(len(project_name), MAX_PROJECT_NAME_LENGTH))
        
        # Folder name - cap at MAX_FOLDER_NAME_LENGTH characters
        folder_name = project['folder']
        widths[1] = max(widths[1], min(len(folder_name), MAX_FOLDER_NAME_LENGTH))
        
        # Branch
        branch_text = project['branch'] or ""
        widths[2] = max(widths[2], len(branch_text))
        
        # Technologies
        tech_text = ', '.join(project['technologies']) if project['technologies'] else ""
        widths[3] = max(widths[3], len(tech_text))
        
        # TODOs
        todo_text = str(project['todo_lines'])
        widths[4] = max(widths[4], len(todo_text))
        
        # Issues
        issue_text = str(project['issue_lines'])
        widths[5] = max(widths[5], len(issue_text))
    
    # Enforce maximum widths
    widths[0] = min(widths[0], MAX_PROJECT_NAME_LENGTH)
    widths[1] = min(widths[1], MAX_FOLDER_NAME_LENGTH)
    
    # Calculate table overhead (borders and padding)
    table_overhead = len(widths) * 3 + 1  # │ col │ col │ etc
    available_width = terminal_width - table_overhead
    
    # If table would be too wide, proportionally reduce column widths
    total_width = sum(widths)
    if total_width > available_width:
        ratio = available_width / total_width
        widths = [max(MIN_COLUMN_WIDTH, int(w * ratio)) for w in widths]
        # Re-enforce maximums after proportional reduction
        widths[0] = min(widths[0], MAX_PROJECT_NAME_LENGTH)
        widths[1] = min(widths[1], MAX_FOLDER_NAME_LENGTH)
    
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
    parser.add_argument('-s', '--sort', choices=['alpha', 'modified', 'created'], 
                       default='modified', help='Sort projects by alpha, modified, or created date')
    parser.add_argument('-v', '--version', action='version', version=f'p {VERSION}')
    
    args = parser.parse_args()
    
    # Resolve path
    scan_path = Path(args.folder).resolve()
    
    if not scan_path.exists():
        print(f"Error: Directory '{args.folder}' does not exist", file=sys.stderr)
        sys.exit(1)
    
    if not scan_path.is_dir():
        print(f"Error: '{args.folder}' is not a directory", file=sys.stderr)
        sys.exit(1)
    
    # Scan for projects
    projects = scan_projects(scan_path)
    
    if not projects:
        print(f"No projects found in {scan_path}")
        return
    
    # Sort projects
    if args.sort == 'alpha':
        projects.sort(key=lambda p: p['folder'].lower())
    elif args.sort == 'created':
        projects.sort(key=lambda p: p['create_time'], reverse=True)
    else:  # modified (default)
        projects.sort(key=lambda p: p['mod_time'], reverse=True)
    
    # Output results
    print(f"Projects in {scan_path}")
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