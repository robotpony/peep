# (p)eep 

Display a summary of projects in specified folders (or from the CWD). It answers 
the question, "where are these projects at," more or less.

### Sample Output

**Default output (compact, name column hidden):**
```
➜ ./p ..
Scanning /Users/username/projects...

┌─────────────────────────────┬────────┬─────┬──────────────────────────────┬────────┬────────┐
│ Project                     │ Branch │ Git │ Technologies                 │ TODOs  │ Issues │
├─────────────────────────────┼────────┼─────┼──────────────────────────────┼────────┼────────┤
│ thwarter                    │ main   │ ✓   │ Rust                         │ 15/170 │ 86/86  │
│ oview                       │ main   │ ?   │ Python, Hugo                 │ 0/0    │ 42/42  │
│ peep                        │ main   │ M   │ Python                       │ 11/19  │ 14/14  │
│ spacecommand.ca             │ main   │ M?  │ JS, node.js, npm, react      │ 6/70   │ 3/3    │
│ statsim                     │ main   │ M   │ JS, node.js, npm, typescript │ 0/131  │ 0/0    │
│ robotpony-render            │ main   │ ↑?  │ JS, node.js, npm, typescript │ 2/2    │ 0/0    │
│ w42                         │ main   │ M   │ Hugo                         │ 0/0    │ 0/0    │
└─────────────────────────────┴────────┴─────┴──────────────────────────────┴────────┴────────┘
```


## Features

- **Smart Project Detection**: Automatically identifies projects by README.md, package.json, git repos, and other indicators
- **Technology Detection**: Recognizes 20+ technologies including Python, JavaScript, Rust, Go, Docker, and more
- **Git Integration**: Shows branch names and status indicators (clean ✓, modified M, untracked ?, ahead ↑, behind ↓)
- **Enhanced TODO/Issue Tracking**: Structured parsing of markdown files plus inline code comment scanning with priority scoring
- **Importance Scoring**: Smart sorting that prioritizes projects with issues, git changes, or TODOs
- **Flexible Display**: Compact view by default, optional name column for additional project information
- **Configurable**: Extensive configuration support via TOML files
- **Multiple Output Formats**: Table (default) or JSON for programmatic use
- **Deep Scanning**: Recursively scans subdirectories with configurable depth limits
- **Filtering**: Skip unwanted directories like node_modules, .git, __pycache__

## Usage

```bash
# Basic usage
./p

# Show project names in addition to folder names
./p --show-name

# Scan a specific directory
./p /path/to/projects

# Sort by different criteria
./p -s alpha          # alphabetical
./p -s modified       # last modified (newest first)
./p -s created        # creation time (newest first) 
./p -s importance     # issues, git status, TODOs (default)

# Combine options
./p --show-name -s alpha /path/to/projects

# JSON output for scripts (always includes all data)
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
show_name_column = false      # Set to true to show Name column by default

# Git settings  
default_git_branch = "main"
git_timeout = 10

# Scanning settings
max_scan_depth = 15
exclude_dirs = ["target", "build", "dist"]
exclude_patterns = ["temp", "backup"]
filter_dirs = ["archive", "old"]

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

## TODO and Issue Tracking

The tool provides enhanced tracking of project tasks and issues:

### Display Format
- **TODOs**: Shows `inline/structured` format (e.g., `5/12` = 5 inline TODOs in code, 12 total items)
- **Issues**: Shows `open/total` format (e.g., `3/8` = 3 open issues, 8 total items)

### Sources Detected
- **Structured Files**: TODO.md, TODOS.md, ISSUES.md, BUGS.md in root and subfolders
- **Inline Comments**: TODO, FIXME, BUG, HACK comments in source code
- **Priority Detection**: High/medium/low priority markers in markdown content
- **Completion Tracking**: Markdown checkboxes `[x]` for completed items

### Importance Scoring
Projects are automatically scored based on:
- Issue severity and priority markers
- Open vs. completed item ratios  
- Git repository status (uncommitted changes)
- TODO urgency (FIXME/BUG comments weighted higher)

## Options

- `-s, --sort [alpha|modified|created|importance]`: Sort projects
- `-j, --json`: Output results as JSON
- `-V, --verbose`: Show debug information about sources of TODOs, issues, and technologies
- `--show-name`: Include Name column in table output (off by default for compact display)
- `--no-progress`: Disable progress indicators  
- `--exclude EXCLUDE`: Additional directories to exclude (repeatable)
- `--filter FILTER`: Additional directories to filter/ignore (repeatable, default: archive)
- `-h, --help`: Display help message
- `-v, --version`: Display version

## Requirements

- Python 3.7+
- Git (for repository information)
- Optional: tomli/tomllib for TOML configuration (Python 3.11+ has built-in support)
