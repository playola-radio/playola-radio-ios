[![CircleCI](https://dl.circleci.com/status-badge/img/gh/playola-radio/playola-radio-ios/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/playola-radio/playola-radio-ios/tree/main)

# Playola Radio iOS

## Setup

### Git Hooks (One-time setup)

This project uses Git hooks to automatically format Swift code before commits. To enable them:

```bash
./.githooks/install-hooks.sh
```

This installs a pre-commit hook that runs `swift-format` on all staged Swift files.
