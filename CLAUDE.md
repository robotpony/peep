# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is "p" - a command-line script for summarizing projects in specified folders. The tool scans directories and provides markdown-formatted summaries including project names, git branches, technologies used, and links to documentation.

## Architecture

### Documentation and project settings:
- A single README.md file documenting the tool's usage
- Claude Code settings in `.claude/settings.local.json` with bash permissions for `find` and `ls` commands

### Design

`p` is a python script for displaying details of projects in the current (or provided) folder.

- Takes a folder path as input (defaults to current working directory)
- Scans for projects in subdirectories
- Extracts metadata from README.md files and git repositories
- Outputs markdown-formatted project summaries
- Supports sorting by alpha, modified, or created date

## Development Commands

This project does not appear to have traditional build/test commands. The main functionality is likely executed directly as a script named `p`.

## Key Features

- Markdown output format
- Git branch detection
- Technology stack identification
- Automatic linking to README.md and claude.md files
- Configurable sorting options
- Directory scanning with last-modified ordering by default

## Usage Pattern

Based on the README, the tool is invoked as:
```
p [folder] [options]
```

With options:
- `-s, --sort [alpha|modified|created]`: Sort projects
- `-h, --help`: Display help
- `-v, --version`: Display version
