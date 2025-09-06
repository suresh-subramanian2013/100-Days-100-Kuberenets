# Day 6: Terminal-Based Kubernetes Management with K9s

Welcome to Day 6 of the 100 Days of Kubernetes journey! This day introduces K9s, a powerful terminal-based UI that provides an efficient way to manage your Kubernetes clusters directly from the command line.

## Overview

K9s is a terminal-based UI to interact with your Kubernetes clusters. It aims to make it easier to navigate, observe, and manage your applications in the wild. K9s continually watches Kubernetes for changes and offers subsequent commands to interact with your observed resources.

## What is K9s?

K9s is a command-line tool that provides:
- **Interactive terminal UI** for Kubernetes
- **Real-time cluster monitoring**
- **Resource management capabilities**
- **Built-in shortcuts and commands**
- **Multi-cluster support**

## Key Benefits

### 1. Switch Easily Between EKS Clusters & Namespaces
- **Context Switching**: Quick switching between different Kubernetes contexts
- **Namespace Navigation**: Seamless namespace switching with keyboard shortcuts
- **Cluster Overview**: Real-time view of cluster resources and health
- **Multi-Context Support**: Manage multiple clusters simultaneously

**Shortcuts:**
- `:ctx` - Switch contexts
- `:ns` - Switch namespaces
- `Ctrl+A` - Show all namespaces

### 2. Check Deployment & Pod Describe & Logs
- **Resource Details**: View detailed information about any Kubernetes resource
- **Live Logs**: Stream logs from pods and containers in real-time
- **Describe Resources**: Get comprehensive resource descriptions
- **Event Monitoring**: Track cluster events and changes

**Shortcuts:**
- `d` - Describe selected resource
- `l` - View logs
- `Enter` - Drill down into resource
- `Esc` - Go back

### 3. Edit Running Resource Files
- **Live Editing**: Edit running resources directly from the terminal
- **YAML Editing**: Built-in YAML editor with syntax highlighting
- **Configuration Updates**: Apply changes to running resources
- **Validation**: Built-in validation before applying changes

**Shortcuts:**
- `e` - Edit selected resource
- `Ctrl+S` - Save changes
- `Ctrl+Q` - Quit editor

### 4. Delete Resources via CLI
- **Resource Deletion**: Delete resources with confirmation prompts
- **Bulk Operations**: Perform operations on multiple resources
- **Safe Deletion**: Built-in safeguards to prevent accidental deletions
- **Force Delete**: Options for force deletion when needed

**Shortcuts:**
- `Ctrl+D` - Delete selected resource
- `Ctrl+K` - Kill selected resource (force delete)

### 5. Additional Features
- **Resource Filtering**: Filter resources by name, namespace, or labels
- **Sorting**: Sort resources by various criteria
- **Search**: Quick search functionality across resources
- **Bookmarks**: Save frequently accessed resources
- **Plugins**: Extend functionality with custom plugins

## Installation

### Installation Methods

#### 1. Using Package Managers
```bash
# macOS (Homebrew)
brew install k9s

# Linux (Snap)
sudo snap install k9s

# Windows (Chocolatey)
choco install k9s

# Windows (Scoop)
scoop install k9s
```

#### 2. Direct Download
```bash
# Download latest release
curl -L https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_x86_64.tar.gz | tar xz
sudo mv k9s /usr/local/bin/
```

#### 3. Using Go
```bash
go install github.com/derailed/k9s@latest
```

### Verify Installation
```bash
k9s version
```

## Getting Started

### 1. Launch K9s
```bash
# Start K9s with default context
k9s

# Start with specific context
k9s --context my-context

# Start in specific namespace
k9s -n my-namespace

# Read-only mode
k9s --readonly
```

### 2. Basic Navigation
- **Arrow Keys**: Navigate through resources
- **Tab**: Switch between different views
- **Enter**: Drill down into selected resource
- **Esc**: Go back to previous view
- **q**: Quit current view or K9s

## Essential Commands and Shortcuts

### Resource Navigation
```bash
:pods          # View pods
:deployments   # View deployments
:services      # View services
:nodes         # View nodes
:ns            # View namespaces
:pv            # View persistent volumes
:events        # View cluster events
```

### Common Operations
| Shortcut | Action |
|----------|--------|
| `?` | Show help |
| `/` | Filter resources |
| `d` | Describe resource |
| `l` | View logs |
| `e` | Edit resource |
| `y` | View YAML |
| `Ctrl+D` | Delete resource |
| `s` | Shell into pod |
| `f` | Port forward |

### Advanced Features
```bash
# Aliases (create shortcuts)
:alias

# Benchmarks (performance testing)
:bench

# XRay (resource relationships)
:xray

# Popeye (cluster sanitizer)
:popeye
```

## Configuration

### K9s Configuration File
K9s stores configuration in `~/.k9s/config.yml`:

```yaml
k9s:
  refreshRate: 2
  maxConnRetry: 5
  readOnly: false
  noExitOnCtrlC: false
  ui:
    enableMouse: false
    headless: false
    logoless: false
    crumbsless: false
    reactive: false
    noIcons: false
  skipLatestRevCheck: false
  disablePodCounting: false
  shellPod:
    image: busybox:1.35.0
    namespace: default
    limits:
      cpu: 100m
      memory: 100Mi
```

### Skin Customization
```bash
# List available skins
k9s --help | grep skin

# Use specific skin
k9s --skin dracula
```

## Practical Use Cases

### 1. Daily Operations
```bash
# Check cluster health
k9s -> :nodes

# Monitor application pods
k9s -> :pods -> filter by app name

# Check service endpoints
k9s -> :services -> describe service
```

### 2. Troubleshooting
```bash
# Find failing pods
k9s -> :pods -> sort by status

# Check pod logs
k9s -> :pods -> select pod -> 'l'

# Describe problematic resources
k9s -> select resource -> 'd'
```

### 3. Development Workflow
```bash
# Edit deployment
k9s -> :deployments -> select -> 'e'

# Port forward for testing
k9s -> :pods -> select -> 'f'

# Shell into pod for debugging
k9s -> :pods -> select -> 's'
```

## Best Practices

### 1. Safety Measures
- Use `--readonly` flag in production environments
- Set up proper RBAC permissions
- Be cautious with delete operations
- Use describe before making changes

### 2. Efficiency Tips
- Learn keyboard shortcuts for common operations
- Use filters to narrow down resource lists
- Set up aliases for frequently used commands
- Customize configuration for your workflow

### 3. Team Collaboration
- Share common K9s configurations
- Document custom aliases and shortcuts
- Use consistent naming conventions
- Train team members on essential shortcuts

## Comparison with Other Tools

| Feature | K9s | kubectl | Octant |
|---------|-----|---------|--------|
| Interface | Terminal UI | Command-line | Web UI |
| Real-time updates | Yes | No | Yes |
| Resource editing | Yes | Yes | Yes |
| Learning curve | Medium | High | Low |
| Performance | Fast | Fast | Medium |
| Offline capability | Yes | Yes | No |

## Troubleshooting

### Common Issues
```bash
# K9s won't start
k9s --help  # Check available options

# Context issues
kubectl config current-context  # Verify kubectl context

# Permission errors
kubectl auth can-i get pods  # Check permissions

# Performance issues
k9s --refresh-rate 5  # Reduce refresh rate
```

## Key Takeaways

- K9s provides a powerful terminal-based interface for Kubernetes management
- It combines the efficiency of command-line tools with visual feedback
- Essential for daily Kubernetes operations and troubleshooting
- Highly customizable and extensible
- Perfect complement to kubectl and web-based tools

## Next Steps

With K9s providing efficient terminal-based cluster management, you're ready to move on to Day 7, which covers PodDisruptionBudgets for ensuring application availability during cluster maintenance.