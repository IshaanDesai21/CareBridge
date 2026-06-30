# Contributing to CareBridge

Thank you for your interest in contributing to CareBridge! This document provides guidelines and instructions for contributing.

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in Issues
2. If not, create a new issue with:
   - Clear description of the bug
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (OS, browser, versions)
   - Screenshots if applicable

### Suggesting Features

1. Check if the feature has already been suggested
2. Create a new issue with:
   - Clear description of the feature
   - Use cases and benefits
   - Potential implementation approach
   - Any mockups or examples

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes following our coding standards
4. Write or update tests as needed
5. Ensure all tests pass
6. Commit your changes with clear messages
7. Push to your branch
8. Open a Pull Request

#### PR Guidelines

- Follow the PR template
- Reference related issues
- Provide clear description of changes
- Include screenshots for UI changes
- Ensure CI passes
- Request review from maintainers

## Development Setup

See [README.md](README.md) for development setup instructions.

## Coding Standards

See [docs/coding-standards.md](docs/coding-standards.md) for detailed coding standards.

### Swift (iOS)
- Follow Swift API Design Guidelines
- Use SwiftLint
- Write documentation comments for public APIs
- Prefer Swift Concurrency (async/await)

### TypeScript (Backend/Dashboard)
- Use TypeScript strict mode
- Follow ESLint configuration
- Write JSDoc comments for public APIs
- Prefer async/await over promises

### General
- Write clear, self-documenting code
- Add comments for complex logic
- Keep functions small and focused
- Write tests for new features
- Update documentation

## Commit Messages

Follow conventional commits:

```
feat: add voice recording feature
fix: resolve authentication bug
docs: update API documentation
style: format code with prettier
refactor: simplify patient service
test: add tests for caregiver endpoints
chore: update dependencies
```

## Testing

- Write unit tests for new features
- Ensure existing tests pass
- Aim for high code coverage
- Test edge cases

### Running Tests

```bash
# Backend
cd backend
npm test

# Dashboard
cd dashboard
npm test

# iOS
xcodebuild test -project ios/CareBridge.xcodeproj -scheme CareBridge
```

## Documentation

- Update relevant documentation
- Add JSDoc/DocC comments
- Include examples where helpful
- Update README if needed

## Review Process

1. Maintainers review PRs
2. Address feedback and make changes
3. Once approved, PR will be merged
4. Changes will be included in next release

## Questions?

Feel free to ask questions in:
- GitHub Discussions
- Issue comments
- Pull request comments

Thank you for contributing to CareBridge! 🎉
