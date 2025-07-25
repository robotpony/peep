# Peep at a project

This is a quick script to summarize the projects the specified folders (or from the CWD).

## Usage

```
p [folder] [options]

Projects in /Users/mx/projects

┌──────────────────────┬─────────────────┬────────┬──────────────────────────────┬───────┐
│ Name                 │ Folder          │ Branch │ Technologies                 │ TODOs │
├──────────────────────┼─────────────────┼────────┼──────────────────────────────┼───────┤
│ Peep at a project    │ peep            │ main   │                              │ 5     │
│ w42                  │ w42             │ main   │                              │ 0     │
│ oview - ollama visu… │ oview           │ main   │ Python                       │ 0     │
│ Thwarter Interactiv… │ thwarter        │ main   │ Rust                         │ 297   │
│ SpaceCommand         │ spacecommand.ca │ main   │ JS, node.js, npm, react      │ 116   │
│ Robotpony Render     │ robotpony-rend… │ main   │ JS, node.js, npm, typescript │ 0     │
│ statsim              │ statsim         │ main   │ JS, node.js, npm, typescript │ 245   │
│ brucealderson.ca.20… │ brucealderson.… │ main   │                              │ 0     │
└──────────────────────┴─────────────────┴────────┴──────────────────────────────┴───────┘
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
