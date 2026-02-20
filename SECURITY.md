# Security Policy

## Supported Versions

Security fixes are applied to the latest release of each plugin only.
Older plugin versions are not patched — please update to the latest release.

| Plugin | Supported |
|--------|-----------|
| Latest release | ✅ |
| Prior releases | ❌ |

## Reporting a Vulnerability

**Please do not report security vulnerabilities via public GitHub issues.**

To report a vulnerability, use GitHub's private vulnerability reporting:
1. Go to the [Security tab](https://github.com/L3DigitalNet/Claude-Code-Plugins/security)
2. Click **"Report a vulnerability"**
3. Fill in the details

You can expect:
- **Acknowledgement** within 48 hours
- **Status update** within 7 days
- **Fix or mitigation** as soon as reasonably possible, depending on severity

## Scope

This repository distributes Claude Code plugins — scripts and configuration
files that execute within the Claude Code environment. Security concerns
relevant to this project include:

- Hooks or scripts that could execute unexpected commands
- Plugin manifests that could be abused to load malicious content
- MCP server configurations that expose sensitive system access

## Out of Scope

- Vulnerabilities in Claude Code itself (report to [Anthropic](https://www.anthropic.com/security))
- Issues in third-party dependencies (report upstream)
