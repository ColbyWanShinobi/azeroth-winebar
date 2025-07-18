# Contributing to Azeroth Winebar

Thank you for your interest in contributing to Azeroth Winebar! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Contributing Guidelines](#contributing-guidelines)
- [Testing](#testing)
- [Documentation](#documentation)
- [Submitting Changes](#submitting-changes)
- [Release Process](#release-process)

## Code of Conduct

This project adheres to a code of conduct that we expect all contributors to follow:

- **Be respectful**: Treat all community members with respect and kindness
- **Be inclusive**: Welcome newcomers and help them get started
- **Be constructive**: Provide helpful feedback and suggestions
- **Be patient**: Remember that everyone has different skill levels and backgrounds
- **Focus on the project**: Keep discussions relevant to Azeroth Winebar

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- A Linux development environment
- Basic knowledge of bash scripting
- Git installed and configured
- Understanding of wine and gaming on Linux

### Areas for Contribution

We welcome contributions in these areas:

- **Bug fixes**: Resolve issues and improve stability
- **Feature development**: Add new functionality
- **Testing**: Improve test coverage and reliability
- **Documentation**: Enhance guides and documentation
- **Distribution support**: Add support for new Linux distributions
- **Performance optimization**: Improve speed and resource usage

## Development Setup

### 1. Fork and Clone

```bash
# Fork the repository on GitHub, then clone your fork
git clone https://github.com/YOUR-USERNAME/azeroth-winebar.git
cd azeroth-winebar

# Add upstream remote
git remote add upstream https://github.com/original-repo/azeroth-winebar.git
```

### 2. Development Environment

```bash
# Make the main script executable
chmod +x azeroth-winebar.sh

# Make test scripts executable
chmod +x tests/*.sh

# Install development dependencies (Ubuntu/Debian example)
sudo apt install shellcheck bash-completion
```

### 3. Verify Setup

```bash
# Run system compatibility tests
./tests/system-compatibility-tests.sh

# Run all tests to ensure everything works
./tests/run-all-tests.sh
```

## Contributing Guidelines

### Code Style

#### Bash Scripting Standards

- **Indentation**: Use 4 spaces (no tabs)
- **Line length**: Maximum 120 characters
- **Quoting**: Always quote variables: `"$variable"`
- **Functions**: Use descriptive names with underscores
- **Comments**: Add comments for complex logic

#### Example Code Style

```bash
# Good example
function install_battle_net() {
    local wine_prefix="$1"
    local download_url="$2"
    
    if [[ -z "$wine_prefix" ]]; then
        debug_print exit "Wine prefix not specified"
        return 1
    fi
    
    debug_print continue "Installing Battle.net to: $wine_prefix"
    
    # Download Battle.net installer
    if ! download_file "$download_url" "$temp_file"; then
        debug_print exit "Failed to download Battle.net installer"
        return 1
    fi
    
    return 0
}
```

#### Variable Naming

- **Global variables**: Use lowercase with underscores: `wine_prefix`
- **Local variables**: Use lowercase with underscores: `local temp_file`
- **Constants**: Use uppercase with underscores: `SCRIPT_VERSION`
- **Arrays**: Use descriptive names: `wine_runner_sources`

#### Error Handling

- Always check return codes for critical operations
- Use `debug_print` for consistent error messaging
- Provide meaningful error messages to users
- Clean up temporary files and resources

```bash
# Good error handling
if ! mkdir -p "$config_dir"; then
    debug_print exit "Failed to create config directory: $config_dir"
    return 1
fi
```

### Git Workflow

#### Branch Naming

- **Feature branches**: `feature/description-of-feature`
- **Bug fixes**: `fix/description-of-bug`
- **Documentation**: `docs/description-of-change`
- **Testing**: `test/description-of-test`

#### Commit Messages

Use clear, descriptive commit messages:

```
type(scope): brief description

Longer description if needed, explaining what and why.

Fixes #123
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Adding or updating tests
- `refactor`: Code refactoring
- `style`: Code style changes
- `chore`: Maintenance tasks

**Examples:**
```
feat(wine): add support for Wine 8.0
fix(battlenet): resolve installation timeout issue
docs(readme): update installation instructions
test(unit): add tests for configuration management
```

### Development Process

#### 1. Create Feature Branch

```bash
git checkout -b feature/my-new-feature
```

#### 2. Make Changes

- Write code following the style guidelines
- Add tests for new functionality
- Update documentation as needed
- Test your changes thoroughly

#### 3. Test Changes

```bash
# Run all tests
./tests/run-all-tests.sh

# Run specific test suites
./tests/run-all-tests.sh --suite=unit
./tests/run-all-tests.sh --suite=integration

# Test on your system
./azeroth-winebar.sh
```

#### 4. Commit Changes

```bash
git add .
git commit -m "feat(scope): description of changes"
```

#### 5. Push and Create PR

```bash
git push origin feature/my-new-feature
```

Then create a pull request on GitHub.

## Testing

### Test Requirements

All contributions should include appropriate tests:

- **New features**: Add unit and integration tests
- **Bug fixes**: Add regression tests
- **Refactoring**: Ensure existing tests still pass

### Running Tests

```bash
# Run all tests with verbose output
./tests/run-all-tests.sh --verbose

# Run specific test types
./tests/unit-tests.sh
./tests/integration-tests.sh
./tests/system-compatibility-tests.sh
```

### Writing Tests

#### Unit Tests

Add unit tests to `tests/unit-tests.sh`:

```bash
test_my_new_function() {
    echo -e "${YELLOW}Testing my new function...${NC}"
    
    # Test normal operation
    local result
    result=$(my_new_function "test-input")
    assert_equals "expected-output" "$result" "Normal operation"
    
    # Test error handling
    assert_failure "my_new_function ''" "Empty input rejection"
}
```

#### Integration Tests

Add integration tests to `tests/integration-tests.sh`:

```bash
test_my_workflow() {
    echo -e "${BLUE}Testing my workflow...${NC}"
    
    # Setup test environment
    setup_test_environment
    
    # Test complete workflow
    my_workflow_function
    assert_file_exists "$expected_file" "Workflow creates expected file"
    
    # Cleanup
    cleanup_test_environment
}
```

### Test Coverage

Aim for good test coverage:

- **Critical functions**: 100% coverage
- **User-facing features**: Comprehensive testing
- **Error paths**: Test failure scenarios
- **Edge cases**: Test boundary conditions

## Documentation

### Documentation Standards

- **Clear and concise**: Write for users of all skill levels
- **Examples**: Include practical examples
- **Up-to-date**: Keep documentation current with code changes
- **Structured**: Use consistent formatting and organization

### Types of Documentation

#### Code Documentation

- Add comments for complex logic
- Document function parameters and return values
- Explain non-obvious behavior

```bash
# Download and install wine runner from GitHub releases
# Parameters:
#   $1 - runner_type: Type of wine runner (lutris-ge, proton-ge, etc.)
#   $2 - release_tag: Specific release version to install
# Returns:
#   0 - Success
#   1 - Download or installation failed
install_wine_runner() {
    local runner_type="$1"
    local release_tag="$2"
    # ... implementation
}
```

#### User Documentation

- Update README.md for user-facing changes
- Add troubleshooting information
- Include configuration examples

#### Developer Documentation

- Document development setup
- Explain architecture decisions
- Provide contribution guidelines

## Submitting Changes

### Pull Request Process

1. **Create descriptive PR title**: Summarize the changes clearly
2. **Fill out PR template**: Provide detailed description
3. **Link related issues**: Reference issue numbers
4. **Request review**: Tag relevant maintainers
5. **Address feedback**: Respond to review comments
6. **Ensure tests pass**: All CI checks must pass

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Refactoring
- [ ] Other (specify)

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] New tests added (if applicable)

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No breaking changes (or documented)

## Related Issues
Fixes #123
```

### Review Process

All pull requests go through code review:

1. **Automated checks**: Tests and linting must pass
2. **Maintainer review**: Code quality and design review
3. **Community feedback**: Input from other contributors
4. **Approval**: At least one maintainer approval required
5. **Merge**: Maintainer merges approved PRs

## Release Process

### Version Numbering

We use semantic versioning (SemVer):

- **Major** (X.0.0): Breaking changes
- **Minor** (0.X.0): New features, backward compatible
- **Patch** (0.0.X): Bug fixes, backward compatible

### Release Workflow

1. **Feature freeze**: Stop adding new features
2. **Testing**: Comprehensive testing on multiple systems
3. **Documentation**: Update changelog and documentation
4. **Tagging**: Create release tag
5. **Distribution**: Package and distribute release

### Changelog

We maintain a changelog following [Keep a Changelog](https://keepachangelog.com/):

```markdown
## [1.2.0] - 2024-01-15

### Added
- Support for Wine 8.0
- New system optimization checks

### Changed
- Improved Battle.net installation process

### Fixed
- Fixed memory leak in wine runner management

### Deprecated
- Old configuration format (will be removed in 2.0.0)
```

## Getting Help

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and community support
- **Pull Request Comments**: Code-specific discussions

### Maintainer Contact

For urgent issues or questions about contributing:

- Create a GitHub issue with the `question` label
- Tag maintainers in discussions
- Be patient - we're volunteers with day jobs

### Resources

- [Bash Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Wine Documentation](https://wiki.winehq.org/)
- [DXVK Documentation](https://github.com/doitsujin/dxvk)
- [Git Best Practices](https://git-scm.com/book)

## Recognition

Contributors are recognized in:

- **README.md**: Major contributors listed
- **Changelog**: Contributors credited for each release
- **GitHub**: Contributor statistics and graphs

Thank you for contributing to Azeroth Winebar! Your efforts help make gaming on Linux better for everyone.