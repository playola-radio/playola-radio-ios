#!/bin/bash

# Script to install Git hooks for the project

echo "Setting up Git hooks..."

# Get the Git directory
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)

if [ -z "$GIT_DIR" ]; then
    echo "Error: Not in a Git repository"
    exit 1
fi

# Install pre-commit hook
if [ -f .githooks/pre-commit ]; then
    echo "Installing pre-commit hook..."
    cp .githooks/pre-commit "$GIT_DIR/hooks/pre-commit"
    chmod +x "$GIT_DIR/hooks/pre-commit"
    echo "✓ Pre-commit hook installed"
else
    echo "Warning: .githooks/pre-commit not found"
fi

echo ""
echo "Git hooks setup complete!"
echo "The pre-commit hook will automatically format Swift files before each commit."