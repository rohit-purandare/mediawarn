# Contributing to Content Warning Scanner

Thank you for your interest in contributing to Content Warning Scanner! We welcome contributions from everyone.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Style Guidelines](#style-guidelines)
- [Community](#community)

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## Getting Started

### Types of Contributions

We welcome many different types of contributions:

- **Bug fixes** - Fix issues or unexpected behavior
- **Feature development** - Add new functionality 
- **Documentation** - Improve README, API docs, code comments
- **Testing** - Add or improve test coverage
- **Performance** - Optimize existing code
- **Security** - Address security vulnerabilities
- **Accessibility** - Improve UI/UX accessibility

### Before You Start

1. **Check existing issues** - Search for existing issues or discussions
2. **Create an issue** - For significant changes, create an issue first to discuss
3. **Fork the repository** - Create your own fork to work on
4. **Small PRs** - Prefer smaller, focused pull requests over large ones

## Development Setup

### Prerequisites

- **Docker & Docker Compose** - For running the full stack
- **Go 1.21+** - For backend services
- **Node.js 18+** - For frontend development
- **Python 3.11+** - For NLP service
- **Git** - Version control

### Local Development

1. **Clone your fork:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/content-warning-scanner.git
   cd content-warning-scanner
   ```

2. **Set up environment:**
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

3. **Start dependencies:**
   ```bash
   docker-compose up -d postgres redis
   ```

4. **Install dependencies:**
   ```bash
   # Go services
   cd scanner && go mod download
   cd ../api && go mod download
   
   # Python service
   cd ../nlp && pip install -r requirements.txt
   
   # Frontend
   cd ../frontend && npm install
   ```

5. **Run services individually:**
   ```bash
   # Terminal 1: Scanner
   cd scanner && go run cmd/main.go
   
   # Terminal 2: NLP Service
   cd nlp && python -m app.main
   
   # Terminal 3: API
   cd api && go run main.go
   
   # Terminal 4: Frontend
   cd frontend && npm start
   ```

### Quick Start with Docker

```bash
make build
make up
```

Access the application at http://localhost:7219

## Making Changes

### Branch Strategy

- **main** - Production-ready code
- **develop** - Integration branch for features
- **feature/*** - Feature branches
- **fix/*** - Bug fix branches
- **hotfix/*** - Critical production fixes

### Workflow

1. **Create a branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following our style guidelines

3. **Test your changes:**
   ```bash
   make test
   ```

4. **Commit your changes:**
   ```bash
   git add .
   git commit -m "feat: add new trigger detection algorithm"
   ```

5. **Push to your fork:**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Create a Pull Request** using our template

### Commit Message Format

We follow the [Conventional Commits](https://conventionalcommits.org/) specification:

```
type(scope): description

[optional body]

[optional footer]
```

**Types:**
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation changes
- `style` - Code formatting (no logic changes)
- `refactor` - Code refactoring
- `test` - Adding or updating tests
- `chore` - Maintenance tasks

**Examples:**
```
feat(nlp): add sentiment analysis for context scoring
fix(scanner): handle corrupted subtitle files gracefully
docs(readme): update installation instructions
test(api): add integration tests for results endpoint
```

## Testing

### Test Categories

- **Unit Tests** - Test individual functions/methods
- **Integration Tests** - Test service interactions
- **End-to-End Tests** - Test complete workflows

### Running Tests

```bash
# All tests
make test

# Individual services
cd scanner && go test ./...
cd nlp && pytest
cd frontend && npm test
```

### Test Coverage

- Maintain **80%+ code coverage** for new code
- Include tests for edge cases and error conditions
- Mock external dependencies appropriately

### Writing Tests

**Go (Scanner/API):**
```go
func TestProcessSubtitleFile(t *testing.T) {
    // Arrange
    input := "test input"
    expected := "expected output"
    
    // Act
    result := ProcessSubtitleFile(input)
    
    // Assert
    assert.Equal(t, expected, result)
}
```

**Python (NLP):**
```python
def test_analyze_text():
    # Arrange
    text = "test input"
    expected = {"category": "violence", "score": 7.5}
    
    # Act
    result = analyze_text(text)
    
    # Assert
    assert result == expected
```

**React (Frontend):**
```jsx
test('renders dashboard correctly', () => {
    render(<Dashboard />);
    expect(screen.getByText('Content Warning Scanner')).toBeInTheDocument();
});
```

## Style Guidelines

### Go

- Follow [Go Code Review Comments](https://github.com/golang/go/wiki/CodeReviewComments)
- Use `gofmt` and `goimports`
- Run `golangci-lint` before committing
- Prefer clear, descriptive names
- Document exported functions and types

### Python

- Follow [PEP 8](https://pep8.org/)
- Use `black` for formatting (88 char line length)
- Use `isort` for import sorting
- Type hints for public functions
- Docstrings for classes and functions

### TypeScript/React

- Use TypeScript for all new code
- Follow React best practices
- Use functional components with hooks
- Props interfaces for components
- ESLint and Prettier configuration

### Database

- Use meaningful table and column names
- Include migration scripts for schema changes
- Add indexes for query optimization
- Document schema changes

## Submitting Changes

### Pull Request Process

1. **Update documentation** if needed
2. **Add or update tests** for your changes
3. **Ensure CI passes** - All tests and linting must pass
4. **Request review** from maintainers
5. **Address feedback** promptly
6. **Squash commits** if requested

### Pull Request Template

Use our PR template to provide:
- Clear description of changes
- Link to related issues
- Testing instructions
- Screenshots (for UI changes)
- Breaking change notes

### Review Criteria

**Code Quality:**
- [ ] Follows project style guidelines
- [ ] Has appropriate test coverage
- [ ] Handles errors gracefully
- [ ] Is well-documented

**Functionality:**
- [ ] Solves the intended problem
- [ ] Doesn't break existing features
- [ ] Performs well with large datasets
- [ ] Considers security implications

**Maintainability:**
- [ ] Code is readable and self-documenting
- [ ] Uses existing patterns and conventions
- [ ] Avoids unnecessary complexity
- [ ] Includes migration guides for breaking changes

## Security

### Reporting Security Issues

**DO NOT** create public issues for security vulnerabilities. Instead:

1. Email security details to [maintainer-email]
2. Use GitHub's private security advisory feature
3. Allow time for assessment and fix before public disclosure

### Security Guidelines

- Never commit secrets, keys, or passwords
- Validate all user inputs
- Use secure communication channels
- Follow OWASP security practices
- Regular dependency security updates

## Community

### Getting Help

- **GitHub Discussions** - General questions and ideas
- **Issues** - Bug reports and feature requests  
- **Discord/Slack** - Real-time community chat
- **Email** - Direct maintainer contact

### Recognition

Contributors are recognized through:
- **Contributors file** - All contributors listed
- **Release notes** - Major contributions highlighted
- **Badges** - GitHub profile achievements
- **Maintainer status** - Outstanding contributors invited

## License

By contributing to Content Warning Scanner, you agree that your contributions will be licensed under the same [MIT License](LICENSE) that covers the project.

---

Thank you for contributing to Content Warning Scanner! Your efforts help make media consumption safer and more accessible for everyone. 🙏