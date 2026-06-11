# Contributing to Tilepad

Thank you for your interest in contributing to Tilepad! This document provides guidelines and information for contributors.

## 🤝 How to Contribute

### Reporting Issues
- Use the [GitHub Issues](https://github.com/lohanidamodar/tilepad/issues) page
- Search existing issues before creating a new one
- Provide detailed information about the bug or feature request
- Include steps to reproduce for bugs
- Specify platform, Flutter version, and device information

### Suggesting Features
- Check [existing feature requests](https://github.com/lohanidamodar/tilepad/issues?q=is%3Aissue+label%3Aenhancement)
- Explain the use case and expected behavior
- Consider accessibility implications
- Provide mockups or detailed descriptions when possible

### Code Contributions

> ⚖️ All contributions are made under the [BSD 3-Clause License](LICENSE). By submitting a pull request you confirm you have the right to license your work under these terms.

#### Getting Started
1. **Fork the repository**
2. **Clone your fork**
   ```bash
   git clone https://github.com/your-username/tilepad.git
   cd tilepad
   ```
3. **Set up development environment**
   ```bash
   flutter pub get
   ```
4. **Create a feature branch** (use descriptive names such as `feature/auto-discovery-ui`)
   ```bash
   git checkout -b feature/your-feature-name
   ```
5. **Choose the correct entry point when running**
   ```bash
   # Desktop server
   flutter run -d windows -t lib/src/server/main.dart

   # Mobile/web client
   flutter run -d android -t lib/src/client/main.dart
   ```

#### Development Guidelines

##### Code Style
- Follow [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter analyze` to check for issues
- Format code with `dart format`
- Use meaningful variable and function names
- Add documentation comments for public APIs

##### File Organization
```
lib/src/
├── client/          # Client-specific code
├── server/          # Server-specific code  
├── models/          # Shared data models
├── network/         # Communication layer
└── utils/           # Shared utilities
```

##### Naming Conventions
- **Classes**: PascalCase (`ButtonGrid`, `ConnectionManager`)
- **Functions/Variables**: camelCase (`connectToServer`, `isConnected`)
- **Constants**: ALL_CAPS (`MAX_RECONNECT_ATTEMPTS`)
- **Files**: snake_case (`button_grid.dart`, `connection_manager.dart`)

##### Architecture Patterns
- Use **Riverpod** for state management (new features should use providers in `client_providers.dart` or server equivalents)
- Follow modular separation: client, server, shared models, network, utilities
- Keep platform-specific code behind conditional imports
- Keep WebSocket/UDP logic inside `lib/src/network/`
- Prefer asynchronous APIs and cancellation-safe code (streams, disposables)

#### Accessibility Requirements
All UI contributions must meet accessibility standards:

- **Semantic Labels**: Provide meaningful labels for all interactive elements
- **Focus Management**: Ensure proper keyboard navigation
- **Color Contrast**: Meet WCAG 2.1 AA standards
- **Screen Reader Support**: Test with accessibility services
- **Haptic Feedback**: Include appropriate tactile feedback
- **Text Scaling**: Support text scaling from 80% to 200%

#### Testing Requirements

##### Unit Tests
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart
```

##### Integration Tests
```bash
# Run integration tests
flutter test integration_test/
```

##### Accessibility Testing
- Test with screen readers (TalkBack/VoiceOver)
- Verify keyboard navigation
- Check color contrast ratios
- Test with different text scales
- Verify haptic feedback functionality

#### Platform-Specific Considerations

##### Mobile (Android/iOS)
- Test on multiple screen sizes
- Consider mobile-specific interactions (swipe, long press)
- Optimize for touch interfaces
- Test network behavior during app lifecycle changes

##### Desktop (Windows/macOS/Linux)
- Support keyboard shortcuts
- Implement proper window management
- Consider system tray integration
- Test with multiple monitors

##### Web
- Ensure responsive design
- Test across different browsers
- Handle web-specific limitations
- Optimize for both mouse and touch

### Pull Request Process

#### Before Submitting
1. **Sync with main branch**
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run quality checks**
   ```bash
   flutter analyze
   flutter test
   ./build_verification.sh  # If applicable
   ```

3. **Update documentation**
   - Update README.md if needed
   - Add CHANGELOG.md entry
   - Update inline documentation

4. **Test thoroughly**
   - Test on target platforms
   - Verify accessibility features
   - Test edge cases and error conditions

#### Pull Request Template
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update
- [ ] Accessibility improvement

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Accessibility testing completed
- [ ] Cross-platform testing completed

## Accessibility Checklist
- [ ] Semantic labels added
- [ ] Focus management implemented
- [ ] Color contrast verified
- [ ] Screen reader tested
- [ ] Haptic feedback implemented

## Screenshots
If applicable, add screenshots or videos demonstrating the changes.

## Related Issues
Closes #issue-number
```

#### Review Process
1. **Code Review**: Maintainers will review code quality, architecture, and functionality
2. **Accessibility Review**: Verify accessibility standards compliance
3. **Testing**: Automated and manual testing across platforms
4. **Documentation Review**: Ensure documentation is complete and accurate

### Commit Guidelines

#### Commit Message Format
```
type(scope): subject

body (optional)

footer (optional)
```

#### Types
- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, etc.)
- **refactor**: Code refactoring
- **perf**: Performance improvements
- **test**: Adding or updating tests
- **chore**: Maintenance tasks

#### Examples
```bash
feat(client): add haptic feedback to button interactions

fix(network): resolve reconnection timeout issues

docs(readme): update installation instructions

style(server): format code according to style guide

refactor(accessibility): extract common semantic utilities

perf(ui): optimize button grid rendering performance

test(network): add unit tests for connection manager

chore(deps): update Flutter SDK to 3.7.2
```

## 🏗️ Development Environment

### Prerequisites
- **Flutter SDK** (>=3.7.2)
- **Dart SDK** (included with Flutter)
- **IDE**: VS Code or Android Studio with Flutter plugins
- **Git** for version control

### Platform-Specific Setup

#### Android Development
- Android Studio with Android SDK
- Android device or emulator for testing

#### iOS Development
- Xcode (macOS only)
- iOS Simulator or physical device

#### Desktop Development
- Platform-specific build tools
- Windows: Visual Studio Build Tools
- macOS: Xcode command line tools
- Linux: build-essential, pkg-config, libgtk-3-dev

### Useful Commands
```bash
# Get dependencies
flutter pub get

# Run code analysis
flutter analyze

# Format code
dart format lib/

# Run tests
flutter test

# Build for specific platform
flutter build android
flutter build ios
flutter build web
flutter build windows
flutter build macos
flutter build linux

# Run build verification
./build_verification.sh
```

## 📋 Issue Labels

- **bug**: Something isn't working
- **enhancement**: New feature or request
- **documentation**: Improvements or additions to documentation
- **accessibility**: Accessibility-related improvements
- **good first issue**: Good for newcomers
- **help wanted**: Extra attention is needed
- **platform:android**: Android-specific issues
- **platform:ios**: iOS-specific issues
- **platform:web**: Web-specific issues
- **platform:desktop**: Desktop-specific issues

## 🎖️ Recognition

Contributors are recognized in:
- README.md contributors section
- Release notes
- GitHub contributor graphs
- Special mentions for significant contributions

## 📞 Getting Help

- **GitHub Discussions**: For questions and ideas
- **GitHub Issues**: For bugs and feature requests
- **Code Review**: Comments on pull requests
- **Documentation**: Check README.md and wiki

## 📜 Code of Conduct

We follow the [Contributor Covenant](CODE_OF_CONDUCT.md). In short:

1. **Be respectful** to all community members
2. **Be inclusive** of different viewpoints and experiences
3. **Be collaborative** in discussions and reviews
4. **Be constructive** in feedback and criticism
5. **Be patient** with newcomers and learning processes

Report unacceptable behavior to `security@appwriters.dev`.

## 🙏 Thank You

Thank you for contributing to Tilepad! Your efforts help make this project better for everyone in the community.

---

*This document is subject to updates. Please check back periodically for changes.*