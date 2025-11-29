.PHONY: lint format format-check

# Run SwiftLint
lint:
	swiftlint

# Auto-fix formatting issues
format:
	xcrun swift-format format -i --recursive .

# Check formatting (fails on issues)
format-check:
	xcrun swift-format lint --strict --recursive .
