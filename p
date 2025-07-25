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

VERSION = "1.0.0"

def get_git_branch(project_path):
    """Get the current git branch for a project."""
    try:
        result = subprocess.run(
            ['git', 'branch', '--show-current'],
            cwd=project_path,
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            return result.stdout.strip() or 'main'
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return None

def extract_project_name(readme_path):
    """Extract project name from README.md file."""
    try:
        with open(readme_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Look for first h1 heading
        match = re.search(r'^#\s+(.+)$', content, re.MULTILINE)
        if match:
            return match.group(1).strip()
    except (FileNotFoundError, UnicodeDecodeError):
        pass
    return None

def detect_technologies(project_path):
    """Detect technologies used in the project."""
    technologies = []
    
    # Check for common project files
    tech_files = {
        'package.json': ['JS', 'node.js'],
        'requirements.txt': ['Python'],
        'Pipfile': ['Python'],
        'Cargo.toml': ['Rust'],
        'go.mod': ['Go'],
        'pom.xml': ['Java', 'Maven'],
        'build.gradle': ['Java', 'Gradle'],
        'composer.json': ['PHP'],
        'Gemfile': ['Ruby'],
        'yarn.lock': ['JS', 'yarn'],
        'package-lock.json': ['JS', 'npm']
    }
    
    for filename, techs in tech_files.items():
        if (Path(project_path) / filename).exists():
            technologies.extend(techs)
    
    # Check package.json for React/Vue/etc
    package_json_path = Path(project_path) / 'package.json'
    if package_json_path.exists():
        try:
            with open(package_json_path, 'r') as f:
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
        except (json.JSONDecodeError, KeyError):
            pass
    
    return list(dict.fromkeys(technologies))  # Remove duplicates while preserving order

def count_todo_lines(project_path):
    """Count lines in files with 'TODO' in uppercase in the title."""
    project_path = Path(project_path)
    total_lines = 0
    
    # Define subfolders to check for TODO files
    subfolders_to_check = ['tasks', 'docs', 'design']
    
    def scan_directory(dir_path):
        """Recursively scan a directory for TODO files."""
        lines = 0
        try:
            for item in dir_path.iterdir():
                if item.is_file():
                    name = item.name.upper()
                    # Check if filename contains TODO and has .txt, .md extension or no extension
                    if 'TODO' in name:
                        if (name.endswith('.TXT') or name.endswith('.MD') or 
                            '.' not in name or name.split('.')[-1].upper() in ['TXT', 'MD']):
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
    for subfolder in subfolders_to_check:
        subfolder_path = project_path / subfolder
        if subfolder_path.exists() and subfolder_path.is_dir():
            total_lines += scan_directory(subfolder_path)
    
    return total_lines

def get_project_info(project_path):
    """Get comprehensive information about a project."""
    project_path = Path(project_path)
    folder_name = project_path.name
    
    # Get project name from README
    readme_path = project_path / 'README.md'
    project_name = extract_project_name(readme_path) or folder_name
    
    # Get git branch
    git_branch = get_git_branch(project_path)
    
    # Detect technologies
    technologies = detect_technologies(project_path)
    
    # Count TODO lines
    todo_lines = count_todo_lines(project_path)
    
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
        'technologies': technologies,
        'todo_lines': todo_lines,
        'mod_time': mod_time,
        'create_time': create_time,
        'path': project_path
    }

def is_project_directory(path):
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

def scan_projects(root_path):
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
    widths = [len("Project"), len("Path"), len("Branch"), len("Tech"), len("TODOs")]
    
    for project in projects:
        # Project name - cap at 20 characters
        project_name = project['name']
        widths[0] = max(widths[0], min(len(project_name), 20))
        
        # Folder name - cap at 15 characters
        folder_name = project['folder']
        widths[1] = max(widths[1], min(len(folder_name), 15))
        
        # Branch
        branch_text = project['branch'] or ""
        widths[2] = max(widths[2], len(branch_text))
        
        # Technologies
        tech_text = ', '.join(project['technologies']) if project['technologies'] else ""
        widths[3] = max(widths[3], len(tech_text))
        
        # TODOs
        todo_text = str(project['todo_lines'])
        widths[4] = max(widths[4], len(todo_text))
    
    # Enforce maximum widths
    widths[0] = min(widths[0], 20)  # Name column max 20
    widths[1] = min(widths[1], 15)  # Folder column max 15
    
    # Calculate table overhead (borders and padding)
    table_overhead = len(widths) * 3 + 1  # │ col │ col │ etc
    available_width = terminal_width - table_overhead
    
    # If table would be too wide, proportionally reduce column widths
    total_width = sum(widths)
    if total_width > available_width:
        ratio = available_width / total_width
        widths = [max(8, int(w * ratio)) for w in widths]  # Minimum 8 chars per column
        # Re-enforce maximums after proportional reduction
        widths[0] = min(widths[0], 20)  # Name column max 20
        widths[1] = min(widths[1], 15)  # Folder column max 15
    
    return widths

def format_table_row(project, widths):
    """Format a single project as a table row."""
    # Project name
    project_name = project['name']
    
    # Folder name
    folder_name = project['folder']
    
    # Branch
    branch_text = project['branch'] or ""
    
    # Technologies
    tech_text = ', '.join(project['technologies']) if project['technologies'] else ""
    
    # TODOs
    todo_text = str(project['todo_lines'])
    
    # Truncate if too long (with ellipsis for visual indication)
    if len(project_name) > widths[0]:
        project_name = project_name[:widths[0]-1] + "…"
    if len(folder_name) > widths[1]:
        folder_name = folder_name[:widths[1]-1] + "…"
    if len(branch_text) > widths[2]:
        branch_text = branch_text[:widths[2]-1] + "…"
    if len(tech_text) > widths[3]:
        tech_text = tech_text[:widths[3]-1] + "…"
    if len(todo_text) > widths[4]:
        todo_text = todo_text[:widths[4]-1] + "…"
    
    return f"│ {project_name:<{widths[0]}} │ {folder_name:<{widths[1]}} │ {branch_text:<{widths[2]}} │ {tech_text:<{widths[3]}} │ {todo_text:<{widths[4]}} │"

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
    headers = ["Name", "Folder", "Branch", "Technologies", "TODOs"]
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