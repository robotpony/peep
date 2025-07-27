# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is "p" (peep) - a sophisticated command-line tool for analyzing and summarizing software projects in directories. The tool recursively scans folders to identify projects, extracts comprehensive metadata, and presents organized summaries in table or JSON format with intelligent project importance scoring.

## Architecture

### Documentation and project settings:
- A single README.md file documenting the tool's usage
- Claude Code settings in `.claude/settings.local.json` with bash permissions for `find` and `ls` commands

### Design

`p` is a comprehensive Python script (version 1.0.0) for analyzing software projects with the following capabilities:

- **Recursive Directory Scanning**: Configurable depth limits and smart exclusion of common build/cache directories
- **Project Detection**: Identifies projects via README files, package manifests, git repositories, and code patterns
- **Technology Recognition**: Auto-detects 20+ technologies including Python, JavaScript, Rust, Go, Docker, and frameworks
- **Git Integration**: Shows branch names, commit status, and sync state with remote repositories
- **Enhanced TODO/Issue Tracking**: Structured parsing of markdown files plus inline code comment scanning
- **Importance Scoring**: Intelligent prioritization based on open issues, git changes, and pending TODOs
- **Multiple Output Formats**: Rich terminal tables or JSON for programmatic use
- **Configuration Support**: TOML-based configuration with user and project-specific overrides

## Development Commands

### Testing
```bash
python -m pytest test/test_p.py -v
```

### Running the Tool
```bash
# Direct execution
./p [directory] [options]

# With Python interpreter
python p [directory] [options]
```

### Development Testing
```bash
# Test basic functionality
./p --help
./p --version

# Test scanning current directory
./p . -V

# Test JSON output
./p . -j
```

## Key Features

- **Smart Project Detection**: Automatically identifies projects via README files, package manifests, git repos, and code patterns
- **Technology Auto-Detection**: Recognizes 20+ technologies and frameworks from project files and dependencies
- **Advanced Git Integration**: Shows branch names, status indicators (✓ M A D ? U ↑ ↓ ↕), and sync state
- **Enhanced TODO/Issue Tracking**: Structured markdown parsing plus inline comment scanning with priority scoring
- **Importance-Based Sorting**: Intelligent ranking by issues, git changes, TODOs, and project activity
- **Rich Terminal Output**: Unicode table formatting with responsive column sizing
- **JSON Export**: Machine-readable output for integration with other tools
- **TOML Configuration**: User and project-specific configuration files for customization
- **Verbose Debug Mode**: Detailed source information for technology detection and metrics
- **Extensible Architecture**: Plugin-like technology detection with custom file pattern support

## Usage Pattern

The tool is invoked as:
```
p [folder] [options]
```

### Core Options
- `-s, --sort [alpha|modified|created|importance]`: Sort projects (default: importance)
- `-j, --json`: Output results as JSON
- `-V, --verbose`: Show debug information about sources of TODOs, issues, and technologies
- `--no-progress`: Disable progress indicators
- `--exclude EXCLUDE`: Additional directories to exclude (repeatable)
- `-h, --help`: Display help message
- `-v, --version`: Display version (currently 1.0.0)

### Configuration
Supports TOML configuration files:
- `~/.config/p/config.toml` (global)
- `p.toml` or `.p.toml` (project-specific)

### Output Formats
- **Table**: Rich Unicode terminal tables with responsive sizing
- **JSON**: Structured data with full metadata for programmatic use
- **Verbose**: Additional debug information showing technology detection sources
