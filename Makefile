ORIGINAL_REPO := $(HOME)/playola/playola-radio-ios

.PHONY: lint format format-check create-release create-new-build release-production release-staging setup-conductor

# Run SwiftLint (strict mode to match CI)
lint:
	swiftlint --strict

# Auto-fix formatting issues (vendored third-party code under */Vendor/* excluded)
format:
	find PlayolaRadio PlayolaRadioTests -name '*.swift' -not -path '*/Vendor/*' -print0 | xargs -0 xcrun swift-format format -i

# Check formatting (fails on issues; vendored third-party code under */Vendor/* excluded)
format-check:
	find PlayolaRadio PlayolaRadioTests -name '*.swift' -not -path '*/Vendor/*' -print0 | xargs -0 xcrun swift-format lint --strict

# Create a release PR (develop -> main) with a version bump
create-release:
	./scripts/release.sh

# Create a hotfix PR that bumps only the build number (version unchanged)
create-new-build:
	./scripts/bump-build.sh

# Build and upload production to TestFlight
release-production:
	git checkout main
	git pull origin main
	bundle exec fastlane release_production

# Upload debug symbols to Sentry
upload-symbols:
	bundle exec fastlane upload_symbols

# Build and upload staging to TestFlight
release-staging:
	bundle exec fastlane release_staging

# Set up workspace for Conductor agents
setup-conductor:
	@test -d $(ORIGINAL_REPO) || (echo "ERROR: Original repo not found at $(ORIGINAL_REPO). Set ORIGINAL_REPO to the correct path." && exit 1)
	@for f in Secrets Secrets-Development Secrets-Local Secrets-Staging; do \
		test -f PlayolaRadio/Config/$$f.xcconfig \
			|| cp $(ORIGINAL_REPO)/PlayolaRadio/Config/$$f.xcconfig PlayolaRadio/Config/$$f.xcconfig; \
	done
