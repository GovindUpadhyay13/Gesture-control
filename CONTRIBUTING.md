# Contributing to GestureCtrl

Thanks for your interest in contributing!

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/GestureCtrl.git`
3. Create a branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test thoroughly
6. Commit: `git commit -m "Add your feature"`
7. Push: `git push origin feature/your-feature-name`
8. Open a Pull Request

## Development Setup

```bash
npm install
cd client && npm install && cd ..
pip install -r ml/requirements.txt
```

## Code Style

- **JavaScript**: Use ES6+ features, functional components
- **Python**: Follow PEP 8
- **Commits**: Use clear, descriptive messages

## Testing

Before submitting:
- Test all gesture training flows
- Verify cursor mode works
- Check camera permissions
- Test on your target OS

## Pull Request Guidelines

- Keep PRs focused on a single feature/fix
- Update README if adding features
- Add comments for complex logic
- Ensure no console errors

## Reporting Issues

Include:
- OS and browser version
- Steps to reproduce
- Expected vs actual behavior
- Screenshots if applicable

## Questions?

Open an issue with the `question` label.
