# Peep at a project

This is a quick script to summarize the projects the specified folders (or from the CWD).

## Usage

```
p [folder] [options]

Projects in /Users/mx/projects

┌──────────────────────┬─────────────────┬────────┬──────────────────────────────┬────────────────┬───────┐
│ Name                 │ Folder          │ Branch │ Technologies                 │ Documentation  │ TODOs │
├──────────────────────┼─────────────────┼────────┼──────────────────────────────┼────────────────┼───────┤
│ Peep at a project    │ peep            │ main   │                              │ readme, claude │ 5     │
│ w42                  │ w42             │ main   │                              │                │ 0     │
│ oview - ollama visu… │ oview           │ main   │ Python                       │ readme, claude │ 0     │
│ Thwarter Interactiv… │ thwarter        │ main   │ Rust                         │ readme, claude │ 297   │
│ ⌥⌘ SPACE COMMAND, T… │ spacecommand.c… │ main   │                              │ readme, claude │ 0     │
│ SpaceCommand         │ spacecommand.ca │ main   │ JS, node.js, npm, react      │ readme, claude │ 116   │
│ Robotpony Render     │ robotpony-rend… │ main   │ JS, node.js, npm, typescript │ readme, claude │ 0     │
│ statsim              │ statsim         │ main   │ JS, node.js, npm, typescript │ readme, claude │ 245   │
│ brucealderson.ca.20… │ brucealderson.… │ main   │                              │ readme         │ 0     │
└──────────────────────┴─────────────────┴────────┴──────────────────────────────┴────────────────┴───────┘
```

### Notes

- output is an ASCII table
- listed in order of last modified (unless specified otherwise)
- includes: folder, project name (from the README.md file), current branch (if available), tools used, and available documentation
- folder defaults to CWD

### Options

- `-s, --sort [alpha|modified|created]`: Sort by alpha, modified, or created date
- `-h, --help`: Display this help message
- `-v, --version`: Display the version of the script
