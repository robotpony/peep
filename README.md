# Peep at a project

This is a quick script to summarize the projects the specified folders (or from the CWD).

## Usage

```
p [folder] [options]

Projects in /Users/mx/projects

┌─────────────────────────────────────────────┬───────────────────────────┬──────────┬────────────────────────────┬───────────────┐
│ Name                                        │ Folder                    │ Branch   │ Technologies               │ Documentation │
├─────────────────────────────────────────────┼───────────────────────────┼──────────┼────────────────────────────┼───────────────┤
│ Peep at a project                           │ peep                      │ main     │                            │ readme, clau… │
│ w42                                         │ w42                       │ main     │                            │               │
│ oview - ollama visualizer                   │ oview                     │ main     │ Python                     │ readme, clau… │
│ Thwarter Interactive Fiction                │ thwarter                  │ main     │ Rust                       │ readme, clau… │
│ ⌥⌘ SPACE COMMAND, THE FRICKN PLACEHOLDER S… │ spacecommand.ca.placehol… │ main     │                            │ readme, clau… │
│ SpaceCommand                                │ spacecommand.ca           │ main     │ JS, node.js, npm, react    │ readme, clau… │
│ Robotpony Render                            │ robotpony-render          │ main     │ JS, node.js, npm, typescr… │ readme, clau… │
│ statsim                                     │ statsim                   │ main     │ JS, node.js, npm, typescr… │ readme, clau… │
└─────────────────────────────────────────────┴───────────────────────────┴──────────┴────────────────────────────┴───────────────┘
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
