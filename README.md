# my-claude-plugins

A personal plugin marketplace for Claude Code.

## Plugins

| Plugin | Description |
|---|---|
| [python-harness](./python-harness/) | Enforces Python conventions via hooks — OOP, style, test layout, and test patterns |
| [custom-reviewer](./custom-reviewer/) | Multi-perspective code & plan reviews via parallel specialist agents |

## Installation

Add this repository as a marketplace in Claude Code, then install individual plugins:

```
/plugin marketplace add kimharry99/my-claude-plugins
```

Install only the plugins you need:

```
/plugin install python-harness@my-claude-plugins
/plugin install custom-reviewer@my-claude-plugins
```

## Plugin Structure

Each plugin follows a standard structure:

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json      # Plugin metadata (required)
├── hooks/               # Hook definitions (optional)
├── skills/              # Skill definitions (optional)
├── agents/              # Agent definitions (optional)
└── README.md            # Documentation
```
