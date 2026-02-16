---
title: Troubleshooting Guide
category: troubleshooting
target_platform: linux
audience: ai_agent
keywords: [debugging, errors, diagnostics, issues]
---

# Troubleshooting

## Diagnostic Commands

```bash
# Check installation
which claude
claude --version

# Check PATH
echo $PATH | tr ':' '\n'

# Check config
ls -la ~/.config/claude/
cat ~/.config/claude/settings.json

# Check plugins
ls -la ~/.cache/claude/plugins/
claude --list-plugins

# Test with debug output
DEBUG=* claude
```

## Installation Issues

### Command Not Found

**Symptom:** `bash: claude: command not found`

**Diagnosis:**

```bash
# Check if binary exists
find /usr -name "claude" 2>/dev/null
find ~/.local -name "claude" 2>/dev/null
find ~/.npm-global -name "claude" 2>/dev/null

# Check npm global bin path
npm config get prefix
npm bin -g
```

**Solutions:**

1. **Add npm global bin to PATH:**

```bash
echo 'export PATH="$(npm bin -g):$PATH"' >> ~/.bashrc
source ~/.bashrc
```

2. **Verify installation location:**

```bash
npm list -g claude-code
```

3. **Reinstall:**

```bash
npm uninstall -g claude-code
npm install -g claude-code
which claude  # Verify
```

### Permission Errors

**Symptom:** `EACCES` or `permission denied` during installation

**Solution - Use nvm (recommended):**

```bash
# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc

# Install node
nvm install node
nvm use node

# Verify npm doesn't need sudo
npm config get prefix
# Should show /home/username/.nvm/...

# Install claude
npm install -g claude-code
```

**Alternative - Configure npm prefix:**

```bash
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
npm install -g claude-code
```

### Missing Dependencies

**Debian/Ubuntu:**

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
```

**Fedora/RHEL:**

```bash
sudo dnf install ca-certificates curl
```

**Arch:**

```bash
sudo pacman -S ca-certificates curl
```

**AppImage execution:**

```bash
chmod +x Claude-Code-*.AppImage
./Claude-Code-*.AppImage
```

## Authentication Issues

### Login Failure

**Diagnosis:**

```bash
# Test connectivity
ping -c 3 anthropic.com
curl -I https://api.anthropic.com

# Check current auth
ls -la ~/.config/claude/auth
cat ~/.config/claude/auth/token.json 2>/dev/null
```

**Solutions:**

```bash
# Clear auth cache
rm -rf ~/.config/claude/auth
claude login

# Check firewall (example with ufw)
sudo ufw status
sudo ufw allow out to api.anthropic.com

# Configure proxy (if needed)
export http_proxy=http://proxy.example.com:8080
export https_proxy=http://proxy.example.com:8080
claude login
```

### Token Expired

**Symptom:** `Authentication token expired`

**Solution:**

```bash
claude logout
claude login
```

### Multiple Accounts

**Switch accounts:**

```bash
claude logout
claude login
# Follow prompts for different account
```

## Performance Issues

### Slow Responses

**Diagnosis:**

```bash
# Check network latency
ping -c 10 api.anthropic.com

# Check system resources
free -h
top -bn1 | head -20

# Check codebase size
du -sh .
find . -type f | wc -l
```

**Solutions:**

1. **Reduce context with .claudeignore:**

```bash
cat > .claudeignore << 'EOF'
node_modules/
__pycache__/
*.pyc
.git/
build/
dist/
coverage/
*.log
EOF
```

2. **Monitor resource usage:**

```bash
# Watch memory
watch -n 1 "ps aux | grep claude | grep -v grep"

# Check I/O
iostat 1 5
```

### High Memory Usage

**Diagnosis:**

```bash
# Check Claude memory usage
ps aux | grep claude | awk '{print $2, $4, $6, $11}'

# Check system memory
free -h
vmstat 1 5
```

**Solutions:**

```bash
# Restart session
pkill claude
claude

# Check for leaks (if persistent)
valgrind --leak-check=full claude
```

## Plugin Issues

### Plugin Not Loading

**Diagnosis:**

```bash
# List installed plugins
/plugin list

# Check plugin directories
ls -la ~/.config/claude/plugins/
ls -la .claude/plugins/
ls -la .claude-local/plugins/

# View errors
/plugin
# Navigate to Errors tab

# Check manifest
cat ~/.config/claude/plugins/*/manifest.json | jq
```

**Solutions:**

```bash
# Verify installation scope
ls -la ~/.config/claude/plugins/      # User scope
ls -la .claude/plugins/                # Project scope
ls -la .claude-local/plugins/          # Local scope

# Reinstall
/plugin uninstall plugin-name@marketplace
/plugin install plugin-name@marketplace

# Check file permissions
find ~/.config/claude/plugins -type f -not -perm -644
```

### Marketplace Addition Failure

**Diagnosis:**

```bash
# Test marketplace accessibility
curl -I https://github.com/owner/repo

# Validate local marketplace.json
cat /path/to/.claude-plugin/marketplace.json | jq .

# Check marketplaces
cat ~/.config/claude/marketplaces.json | jq
```

**Solutions:**

```bash
# Verify URL format
/plugin marketplace add owner/repo            # GitHub
/plugin marketplace add https://gitlab.com/user/repo.git  # GitLab
/plugin marketplace add /path/to/marketplace  # Local

# Check network
ping -c 3 github.com
curl https://raw.githubusercontent.com/owner/repo/main/.claude-plugin/marketplace.json
```

### Command Not Working

**Diagnosis:**

```bash
# List plugin commands
/help | grep plugin-name

# Check plugin status
/plugin list | grep plugin-name

# Verify manifest
cat ~/.config/claude/plugins/plugin-name/manifest.json | jq .commands
```

**Solutions:**

```bash
# Verify namespace format
/plugin-name:command-name  # Correct
/command-name              # Wrong (missing namespace)

# Reload plugin
/plugin disable plugin-name@marketplace
/plugin enable plugin-name@marketplace

# Check command files
ls -la ~/.config/claude/plugins/plugin-name/commands/
```

## MCP Server Issues

### Server Won't Start

**Diagnosis:**

```bash
# Check binary availability
which npx
which <server-command>

# Test server directly
npx -y @modelcontextprotocol/server-github
# Watch for errors

# Check environment
env | grep -i token
env | grep -i api

# Verify manifest config
jq '.mcpServers' ~/.config/claude/plugins/*/manifest.json
```

**Solutions:**

```bash
# Install MCP server package
npm install -g @modelcontextprotocol/server-github

# Set required environment variables
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
echo 'export GITHUB_TOKEN=ghp_xxxx' >> ~/.bashrc

# Test with explicit command
node /path/to/mcp-server/index.js
```

### Authentication Failures

**Diagnosis:**

```bash
# Check token format
echo $GITHUB_TOKEN | wc -c  # Should be 40+ chars
echo $GITHUB_TOKEN | cut -c1-4  # Should start with ghp_

# Test token validity
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user
```

**Solutions:**

```bash
# Generate new token with correct scopes
# GitHub: Settings → Developer settings → Personal access tokens

# Set in environment
export GITHUB_TOKEN=ghp_newtoken
export GITLAB_TOKEN=glpat_newtoken

# Persist in bashrc
echo "export GITHUB_TOKEN=$GITHUB_TOKEN" >> ~/.bashrc
source ~/.bashrc

# Verify
env | grep TOKEN
```

### Server Timeouts

**Diagnosis:**

```bash
# Check connectivity
curl -I https://api.github.com
time curl https://api.github.com/rate_limit

# Check rate limits
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/rate_limit
```

**Solutions:**

```bash
# Increase timeout in manifest.json
# Add timeout field to server config

# Check rate limit status
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/rate_limit | jq

# Wait for rate limit reset
# Or use different token
```

## LSP Server Issues

### Code Intelligence Not Working

**Diagnosis:**

```bash
# Check language server installation
which typescript-language-server
which pylsp
which gopls
which rust-analyzer

# Check plugin installation
/plugin list | grep -i lsp

# Verify file extensions
file your-file.py
file your-file.ts
```

**Solutions:**

```bash
# Install language servers
# Python
pip3 install python-lsp-server

# TypeScript
npm install -g typescript-language-server typescript

# Go
go install golang.org/x/tools/gopls@latest
export PATH="$PATH:$(go env GOPATH)/bin"

# Rust
rustup component add rust-analyzer

# Install LSP plugin
/plugin install python@claude-plugins-official
/plugin install typescript@claude-plugins-official
```

### LSP Server Crashes

**Diagnosis:**

```bash
# Check LSP logs
tail -f ~/.cache/claude/logs/lsp-*.log

# Test server directly
pylsp --help
typescript-language-server --stdio

# Check for syntax errors
python -m py_compile your-file.py
tsc --noEmit your-file.ts
```

**Solutions:**

```bash
# Update language server
pip3 install --upgrade python-lsp-server
npm update -g typescript-language-server

# Clear LSP cache
rm -rf ~/.cache/claude/lsp/

# Restart Claude
pkill claude
claude
```

## File Operations Issues

### Changes Not Saved

**Diagnosis:**

```bash
# Check file permissions
ls -la your-file.py
stat your-file.py

# Check git status
git status
git diff

# Check disk space
df -h .
```

**Solutions:**

```bash
# Fix permissions
chmod 644 your-file.py
chown $USER:$USER your-file.py

# Check for file locks
lsof your-file.py

# Verify write access
touch test-write && rm test-write
```

### Wrong Files Modified

**Prevention:**

```bash
# Use .claudeignore
cat > .claudeignore << 'EOF'
# Exclude generated files
*.generated.*
*_pb2.py
*.min.js

# Exclude sensitive files
*.key
*.pem
.env

# Exclude dependencies
node_modules/
venv/
__pycache__/
EOF

# Be explicit in requests
claude "modify src/utils/helpers.py only"
```

## Debug and Diagnostics

### Enable Debug Logging

```bash
# Full debug output
DEBUG=* claude

# Specific modules
DEBUG=plugin:* claude
DEBUG=mcp:* claude
DEBUG=lsp:* claude

# Save to file
DEBUG=* claude 2>&1 | tee debug.log
```

### Check Version

```bash
claude --version
node --version
npm --version

# Include in bug reports
```

### System Information

```bash
# OS information
uname -a
lsb_release -a

# Node/npm paths
which node
which npm
npm config get prefix

# Environment
env | grep -i claude
env | grep -i node
```

### Log Locations

```bash
# Claude logs
ls -la ~/.cache/claude/logs/
tail -f ~/.cache/claude/logs/claude.log

# Plugin logs
ls -la ~/.cache/claude/logs/plugins/

# LSP logs
ls -la ~/.cache/claude/logs/lsp/
```

## Support Resources

### Diagnostic Report

```bash
# Generate diagnostic bundle
claude diagnose > diagnostic-report.txt

# Include in support requests
```

### Bug Reports

**Include:**

- Claude version: `claude --version`
- OS/distro: `lsb_release -a`
- Node version: `node --version`
- Steps to reproduce
- Error messages
- Diagnostic output

**File at:** GitHub Issues or support@anthropic.com

### Configuration Locations

```bash
# User config
~/.config/claude/settings.json
~/.config/claude/auth/

# Project config
.claude/settings.json
.claude/plugins/

# Cache
~/.cache/claude/logs/
~/.cache/claude/plugins/

# Environment
~/.bashrc
~/.bash_profile
```

## Common Fix Patterns

### Nuclear Reset

```bash
# Backup config
cp -r ~/.config/claude ~/.config/claude.backup

# Clear everything
rm -rf ~/.config/claude/auth
rm -rf ~/.cache/claude/
rm -rf ~/.config/claude/plugins/

# Reinstall
npm uninstall -g claude-code
npm install -g claude-code
claude login
```

### Plugin Reset

```bash
# Uninstall all plugins
/plugin list | grep @ | cut -d' ' -f1 | xargs -I{} /plugin uninstall {}

# Clear cache
rm -rf ~/.cache/claude/plugins/

# Reinstall needed plugins
/plugin install plugin-name@marketplace
```

### LSP Reset

```bash
# Remove LSP cache
rm -rf ~/.cache/claude/lsp/

# Reinstall language servers
npm update -g typescript-language-server
pip3 install --upgrade python-lsp-server

# Restart Claude
pkill claude
claude
```

## Reference

- [Plugins Reference](./plugins-reference.md) - Technical specifications
- [Discover Plugins](./discover-plugins.md) - Installation guide
- [Create Plugins](./plugins.md) - Development guide
- [MCP](./mcp.md) - MCP server configuration
- [Skills](./skills.md) - Skill development
