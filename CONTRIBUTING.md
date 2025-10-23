# Contributing to CMMC Level 2 Implementation Guide

Thank you for your interest in contributing to this project! This guide is released into the public domain under the Unlicense, and we welcome contributions from the community.

## How to Contribute

### Reporting Issues

If you find bugs, errors, or have suggestions:

1. **Search existing issues** to avoid duplicates
2. **Create a new issue** with:
   - Clear, descriptive title
   - Detailed description of the problem or suggestion
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - System information (OS, versions, etc.)
   - Screenshots if applicable

### Submitting Changes

1. **Fork the repository**
   ```bash
   git clone https://github.com/timames/cmmc-level2-implementation-graylog_ollama.git
   cd cmmc-level2-implementation-graylog_ollama
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```
   Use descriptive branch names:
   - `feature/add-ansible-playbooks`
   - `fix/graylog-installation-bug`
   - `docs/update-prerequisites`

3. **Make your changes**
   - Write clear, well-documented code
   - Follow existing code style
   - Add comments where necessary
   - Update documentation as needed

4. **Test your changes**
   - Test in a lab environment
   - Verify compatibility with documented prerequisites
   - Check for unintended side effects
   - Ensure scripts are idempotent where applicable

5. **Commit your changes**
   ```bash
   git add .
   git commit -m "Brief description of changes"
   ```
   
   Write good commit messages:
   - Use present tense ("Add feature" not "Added feature")
   - Be specific but concise
   - Reference issues if applicable (#123)
   - Examples:
     - `Add Graylog input configuration script`
     - `Fix MongoDB authentication issue #42`
     - `Update documentation for Windows hardening`

6. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Create a Pull Request**
   - Go to the original repository
   - Click "New Pull Request"
   - Select your branch
   - Fill out the PR template with:
     - Description of changes
     - Related issues
     - Testing performed
     - Any breaking changes

## Contribution Guidelines

### Code Standards

#### Shell Scripts (Bash)
```bash
#!/bin/bash
# Script description
# Usage: ./script-name.sh [options]

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Use functions
function main() {
    # Code here
}

# Validate inputs
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <arg>"
    exit 1
fi

# Use meaningful variable names
GRAYLOG_VERSION="5.0"

# Comment complex logic
# This loop processes each VLAN...

main "$@"
```

#### Python Scripts
```python
#!/usr/bin/env python3
"""
Script description and purpose.

Usage:
    python script.py --option value
"""

import sys
import argparse

def main():
    """Main function."""
    parser = argparse.ArgumentParser(description="Script description")
    # Add arguments
    args = parser.parse_args()
    
    # Implementation

if __name__ == "__main__":
    main()
```

#### PowerShell Scripts
```powershell
<#
.SYNOPSIS
    Brief description
.DESCRIPTION
    Detailed description
.PARAMETER Name
    Parameter description
.EXAMPLE
    PS> .\script.ps1 -Name "value"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Name
)

# Use approved verbs
function Get-SomethingUseful {
    # Implementation
}

# Error handling
try {
    # Code
} catch {
    Write-Error "Error: $_"
    exit 1
}
```

### Documentation Standards

#### Script Documentation
Every script should include:
- Description of purpose
- Prerequisites/dependencies
- Usage examples
- Parameter descriptions
- Expected output
- Error handling
- Version history (if applicable)

#### README Updates
When adding new scripts or features:
- Update relevant README files
- Add to table of contents if needed
- Include usage examples
- Document new dependencies
- Update architecture diagrams if applicable

#### Inline Comments
- Comment complex logic
- Explain "why" not just "what"
- Keep comments up to date with code changes
- Use clear, professional language

### Security Guidelines

**CRITICAL:** Never commit:
- Passwords or credentials
- Private keys or certificates
- API tokens or secrets
- Real IP addresses or domain names (use placeholders)
- Sensitive company information
- Real CUI data

Instead:
- Use environment variables
- Use placeholder values
- Document required secrets in README
- Add sensitive file patterns to `.gitignore`
- Use configuration templates

Example:
```bash
# ❌ BAD
ADMIN_PASSWORD="SuperSecret123"

# ✅ GOOD
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
if [[ -z "$ADMIN_PASSWORD" ]]; then
    echo "Error: ADMIN_PASSWORD not set"
    exit 1
fi
```

### Testing Requirements

Before submitting:

1. **Functionality Testing**
   - Test in a clean lab environment
   - Verify all features work as expected
   - Test with minimum required dependencies
   - Test error conditions

2. **Compatibility Testing**
   - Test on documented OS versions
   - Test with documented tool versions
   - Document any version-specific issues

3. **Security Testing**
   - No credentials in code
   - Proper input validation
   - Secure default configurations
   - No unnecessary permissions

4. **Documentation Testing**
   - Follow your own documentation
   - Verify all examples work
   - Check for broken links
   - Ensure formatting is correct

### Types of Contributions

We welcome:

#### Scripts and Automation
- New hardening scripts
- Configuration automation
- Deployment tools
- Testing frameworks
- Monitoring solutions

#### Documentation
- Clarifications and corrections
- Additional examples
- Troubleshooting guides
- Architecture improvements
- Tutorial content

#### Tools and Utilities
- Compliance checking tools
- Report generators
- Configuration validators
- Evidence collectors

#### Templates and Examples
- Policy templates
- Configuration examples
- Assessment checklists
- Training materials

## Code Review Process

### What We Look For

Reviewers will check:
- ✅ Code follows style guidelines
- ✅ Documentation is clear and complete
- ✅ Tests pass or testing evidence provided
- ✅ No security issues
- ✅ Changes are backwards compatible (or clearly documented)
- ✅ Commit messages are clear
- ✅ PR description is complete

### Review Timeline

- Most PRs reviewed within 1-2 weeks
- Simple fixes may be merged quickly
- Complex changes may require discussion
- We may request changes or clarifications

### After Review

If changes are requested:
1. Make the requested changes
2. Commit and push to your branch
3. Respond to review comments
4. Request re-review

Once approved:
- PR will be merged
- Your contribution becomes part of the public domain
- You'll be thanked in release notes!

## Getting Help

### Questions?

- **General questions:** Open a GitHub Discussion
- **Bug reports:** Open an issue
- **Security concerns:** Email maintainers directly
- **Feature requests:** Open an issue with "Enhancement" label

### Resources

- [GitHub Flow Guide](https://guides.github.com/introduction/flow/)
- [Markdown Guide](https://www.markdownguide.org/)
- [Shell Script Best Practices](https://google.github.io/styleguide/shellguide.html)
- [Python Style Guide (PEP 8)](https://pep8.org/)

## Recognition

Contributors will be:
- Listed in release notes
- Credited in commit history
- Thanked in the community

Since this is public domain (Unlicense), you retain no copyright, but we appreciate your contributions and will acknowledge your work!

## Code of Conduct

### Our Standards

We are committed to providing a welcoming and professional environment. We expect:

- **Respectful communication** - Be kind and professional
- **Constructive feedback** - Focus on improving the project
- **Collaboration** - Work together toward common goals
- **Inclusivity** - Welcome contributors of all backgrounds and skill levels

### Unacceptable Behavior

- Harassment or discrimination
- Trolling or insulting comments
- Personal or political attacks
- Publishing others' private information
- Other unprofessional conduct

### Enforcement

Maintainers may:
- Remove offensive comments or contributions
- Ban repeat offenders
- Close issues/PRs that violate guidelines

Report violations to repository maintainers.

## License

By contributing, you agree that your contributions will be placed in the public domain under the Unlicense. You waive all copyright and related rights to your contributions.

---

Thank you for contributing to CMMC Level 2 implementation! Your efforts help the entire Defense Industrial Base community. 🎯🔐
