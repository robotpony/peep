# (p)eep 

Display a summary of projects in specified folders (or from the CWD). It answers 
the question, "where are these projects at," more or less.

### Sample Output

```
➜ ./p ..
Scanning /Users/mx/projects...

┌───────────────────────────┬──────────────────────┬────────┬─────┬──────────────────────────────┬───────┬────────┐
│ Name                      │ Folder               │ Branch │ Git │ Technologies                 │ TODOs │ Issues │
├───────────────────────────┼──────────────────────┼────────┼─────┼──────────────────────────────┼───────┼────────┤
│ Thwarter Interactive Fic… │ thwarter             │ main   │ ✓   │ Rust                         │ 297   │ 167    │
│ oview - ollama visualizer │ oview                │ main   │ ?   │ Python                       │ 0     │ 148    │
│ SpaceCommand              │ spacecommand.ca      │ main   │ M?  │ JS, node.js, npm, react      │ 116   │ 45     │
│ statsim                   │ statsim              │ main   │ M   │ JS, node.js, npm, typescript │ 245   │ 0      │
│ (p)eep at a folder of re… │ peep                 │ main   │ M?  │                              │ 5     │ 0      │
│ SPACE COMMAND, THE FRICK… │ spacecommand.ca.pla… │ main   │ ?   │                              │ 0     │ 0      │
│ Robotpony Render          │ robotpony-render     │ main   │ ↑?  │ JS, node.js, npm, typescript │ 0     │ 0      │
│ w42                       │ w42                  │ main   │ M   │                              │ 0     │ 0      │
│ brucealderson.ca.2025     │ brucealderson.ca.20… │ main   │ ✓   │ static website               │ 0     │ 0      │
└───────────────────────────┴──────────────────────┴────────┴─────┴──────────────────────────────┴───────┴────────┘
```

## Features

- **Smart Project Detection**: Automatically identifies projects by README.md, package.json, git repos, and other indicators
- **Technology Detection**: Recognizes 20+ technologies including Python, JavaScript, Rust, Go, Docker, and more
- **Git Integration**: Shows branch names and status indicators (clean ✓, modified M, untracked ?, ahead ↑, behind ↓)
- **Issue & TODO Tracking**: Counts lines in issue and TODO files to highlight projects needing attention
- **Importance Scoring**: Smart sorting that prioritizes projects with issues, git changes, or TODOs
- **Configurable**: Extensive configuration support via TOML files
- **Multiple Output Formats**: Table (default) or JSON for programmatic use
- **Deep Scanning**: Recursively scans subdirectories with configurable depth limits
- **Filtering**: Skip unwanted directories like node_modules, .git, __pycache__

## Usage

```bash
# Basic usage - scan current directory
./p

# Scan a specific directory
./p /path/to/projects

# Sort by different criteria
./p -s alpha          # alphabetical
./p -s modified       # last modified (newest first)
./p -s created        # creation time (newest first) 
./p -s importance     # issues, git status, TODOs (default)

# JSON output for scripts
./p -j /path/to/projects

# Verbose mode with debug information
./p -V /path/to/projects

# Exclude additional directories
./p --exclude temp --exclude backup

# Disable progress indicators
./p --no-progress
```



## Configuration

Create configuration files to customize behavior:
- `~/.config/p/config.toml` (global)
- `p.toml` or `.p.toml` (project-specific)

### Example Configuration

```toml
# Display settings
max_project_name_length = 30
max_folder_name_length = 25
show_progress = true

# Git settings  
default_git_branch = "main"
git_timeout = 10

# Scanning settings
max_scan_depth = 15
exclude_dirs = ["target", "build", "dist"]
exclude_patterns = ["temp", "backup"]

# Custom technology detection
[custom_tech_files]
"deno.json" = ["Deno"]
"poetry.lock" = ["Python", "Poetry"]

[custom_package_deps]
"svelte" = "Svelte"
"@nestjs/core" = "NestJS"
```

## Git Status Indicators

- `✓` Clean repository (no changes, up to date)
- `M` Modified files
- `A` Added files  
- `D` Deleted files
- `?` Untracked files
- `U` Merge conflicts
- `↑` Branch ahead of remote
- `↓` Branch behind remote
- `↕` Branch diverged from remote

## Technology Detection

Automatically detects technologies from:
- **Project Files**: package.json, requirements.txt, Cargo.toml, go.mod, etc.
- **Source Code**: .py, .js, .rs, .go files in project directories
- **Executables**: Python scripts with shebangs (#!/usr/bin/env python3)
- **Dependencies**: React, Vue, Angular, TypeScript from package.json
- **Custom**: Add your own via configuration

### Enhanced Python Detection
Python projects are detected through multiple methods:
- **Traditional files**: requirements.txt, setup.py, pyproject.toml, Pipfile, etc.
- **Source files**: .py files in root, src/, lib/, tests/, scripts/ directories
- **Executables**: Scripts with Python shebangs (even without .py extension)
- **Test files**: Python test files in test/ or tests/ directories

### Early-Stage Project Detection
Projects in planning or initial stages are marked as `n/a`:
- **README-only**: Projects with README.md but no source code yet
- **Git repositories**: Empty git repos waiting for first commit
- **Planning stage**: Projects with TODO.md, PLANNING.md, DESIGN.md but no code
- **Documentation-only**: Projects with specs, notes, or roadmaps but no implementation

Supports: JavaScript, Python, Rust, Go, Java, PHP, Ruby, Docker, and many more.

## Options

- `-s, --sort [alpha|modified|created|importance]`: Sort projects
- `-j, --json`: Output results as JSON
- `-V, --verbose`: Show debug information about sources of TODOs, issues, and technologies
- `--no-progress`: Disable progress indicators  
- `--exclude EXCLUDE`: Additional directories to exclude (repeatable)
- `-h, --help`: Display help message
- `-v, --version`: Display version

## Requirements

- Python 3.7+
- Git (for repository information)
- Optional: tomli/tomllib for TOML configuration (Python 3.11+ has built-in support)
