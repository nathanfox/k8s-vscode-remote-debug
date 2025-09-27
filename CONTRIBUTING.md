# Contributing to K8s Remote Debugging Examples

Thank you for your interest in this project!

## Repository Purpose

This is a **reference repository** designed to demonstrate best practices for remote debugging applications in Kubernetes. It serves as a learning resource and starting point for teams implementing similar workflows.

## Recommended Approach: Fork First

We recommend **forking this repository** for your own use rather than contributing directly. This allows you to:

- Customize examples for your specific tech stack
- Adapt management scripts to your team's workflow
- Add company-specific tooling and configurations
- Maintain your own debugging patterns

**When to fork instead of contribute:**
- Adding company-specific configurations
- Customizing for internal workflows
- Experimenting with different approaches
- Adding frameworks/languages specific to your needs

## When to Contribute

We welcome contributions for:

### 🐛 Bug Fixes
- Errors in existing code
- Issues with debugging workflows
- Problems with management scripts
- Documentation errors

### 📖 Documentation Improvements
- Clarifying existing documentation
- Adding troubleshooting tips
- Improving setup instructions
- Fixing typos or broken links

### ✨ New Language/Framework Examples
We consider new examples on a **case-by-case basis** for:
- Widely-used languages/frameworks
- Significantly different debugging approaches
- Clear demand from the community

**Before proposing a new example**, please:
1. Open an issue to discuss the addition
2. Explain why it would benefit the broader community
3. Confirm you can provide complete documentation
4. Ensure it fits the repository's scope

## How to Contribute

### Reporting Bugs

1. **Check existing issues** to avoid duplicates
2. **Open a new issue** with:
   - Clear description of the problem
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (K8s version, VS Code version, etc.)
   - Relevant logs or screenshots

### Submitting Changes

1. **Fork the repository**
2. **Create a feature branch** from `develop`:
   ```bash
   git checkout develop
   git checkout -b fix/your-bug-fix
   # or
   git checkout -b docs/your-doc-improvement
   ```
3. **Make your changes**
   - Follow existing code style
   - Maintain consistency with other examples
   - Update documentation as needed
   - Test thoroughly
4. **Commit with clear messages**:
   ```bash
   git commit -m "Fix: Correct port-forward command in C# example"
   ```
5. **Push to your fork**:
   ```bash
   git push origin fix/your-bug-fix
   ```
6. **Open a Pull Request** to the `develop` branch
   - Describe what you changed and why
   - Reference any related issues
   - Include testing notes

## Contribution Guidelines

### Code Style

- **Bash scripts**: Follow existing style in `shared/scripts/`
- **Consistency**: Match patterns used in existing examples
- **Comments**: Explain complex logic
- **No spaces**: Use hyphens in file/directory names (e.g., `k8s-templates`, not `k8s templates`)

### Documentation

- **Clear and concise**: Write for developers new to remote debugging
- **Complete examples**: Include all necessary commands
- **Troubleshooting**: Add common issues and solutions
- **Keep it current**: Update docs when code changes

### Testing

Before submitting:
- [ ] Test on local K8s cluster (kind or minikube)
- [ ] Verify debugging workflow works end-to-end
- [ ] Check all commands in documentation
- [ ] Validate scripts with `shellcheck` if possible
- [ ] Test with NAMESPACE env var and `-n` flag

### Git Workflow

- **Base branch**: `develop` (not `main`)
- **Branch naming**:
  - `fix/` - Bug fixes
  - `docs/` - Documentation changes
  - `feature/` - New features (after discussion)
- **Commit messages**: Clear, descriptive, present tense
- **Keep PRs focused**: One bug fix or feature per PR

## What We Won't Accept

- ❌ Company-specific configurations
- ❌ Proprietary tooling
- ❌ Incomplete examples without documentation
- ❌ Changes that break existing examples
- ❌ Overly complex solutions when simple ones exist
- ❌ Language/framework examples without prior discussion

## Questions?

- **General questions**: Open a GitHub issue
- **Bug reports**: Use the issue tracker
- **Feature proposals**: Open an issue for discussion first

## License

By contributing, you agree that your contributions will be licensed under the same [MIT License](LICENSE) that covers this project.

---

**Thank you for helping improve K8s remote debugging for everyone!**