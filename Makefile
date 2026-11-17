ORIGINAL_REPO := $(HOME)/playola/playola-radio-ios

.PHONY: lint format format-check changelog-check test-scripts create-release create-new-build release-production release-staging setup-conductor

# Run SwiftLint (strict mode to match CI).
# Warns when the local swiftlint drifts from the pinned version in .swiftlint-version,
# since a newer release adds rules and reports violations CI will not.
lint:
	@expected="$$(cat .swiftlint-version)"; \
	actual="$$(swiftlint version)"; \
	if [ "$$expected" != "$$actual" ]; then \
		echo "warning: swiftlint $$actual installed, but this repo pins $$expected."; \
		echo "warning: results may differ from CI. Install the pinned version to match."; \
	fi
	swiftlint --strict

# Auto-fix formatting issues (vendored third-party code under */Vendor/* excluded)
format:
	find PlayolaRadio PlayolaRadioTests -name '*.swift' -not -path '*/Vendor/*' -print0 | xargs -0 xcrun swift-format format -i

# Check formatting (fails on issues; vendored third-party code under */Vendor/* excluded)
format-check:
	find PlayolaRadio PlayolaRadioTests -name '*.swift' -not -path '*/Vendor/*' -print0 | xargs -0 xcrun swift-format lint --strict

# Validate pending release notes in changelog.d/ and print them
changelog-check:
	python3 scripts/changelog.py check

# Run the release-script tests
test-scripts:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts -p 'test_*.py'

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

.PHONY: ux-evidence ux-evidence-setup ux-evidence-verify ux-evidence-publish ux-evidence-new ux-evidence-ios-login

# The tool lives in the shared skills repo (playola-radio/ai-skills); this repo keeps only its cases in qa/ux/.
UX_EVIDENCE_HOME ?= $(HOME)/playola/playola-skills/ux-evidence/tool
UX_EVIDENCE = npm --prefix "$(UX_EVIDENCE_HOME)" run --silent ux-evidence -- --repo "$(CURDIR)"
UX_EVIDENCE_REQUIRE_TOOL = @test -f "$(UX_EVIDENCE_HOME)/package.json" || { echo "UX evidence tool missing; clone playola-radio/ai-skills to ~/playola/playola-skills or set UX_EVIDENCE_HOME."; exit 1; }

ux-evidence-setup:
	$(UX_EVIDENCE_REQUIRE_TOOL)
	npm --prefix "$(UX_EVIDENCE_HOME)" ci

ux-evidence:
	@test -n "$(CASE)" || { echo "Usage: make ux-evidence CASE=<case-id>"; exit 2; }
	$(UX_EVIDENCE_REQUIRE_TOOL)
	$(UX_EVIDENCE) record --case "$(CASE)" $(if $(filter 1,$(ALLOW_IDENTICAL)),--allow-identical)

ux-evidence-verify:
	$(UX_EVIDENCE_REQUIRE_TOOL)
	$(UX_EVIDENCE) verify

ux-evidence-publish:
	@test -n "$(PR)" || { echo "Usage: make ux-evidence-publish PR=<number>"; exit 2; }
	$(UX_EVIDENCE_REQUIRE_TOOL)
	$(UX_EVIDENCE) publish --pr "$(PR)"

ux-evidence-new:
	@test -n "$(CASE)" || { echo 'Usage: make ux-evidence-new CASE=<id> CLASSIFICATION=<visual|functional> BEFORE=<required|not-applicable> [REASON="..."]'; exit 2; }
	$(UX_EVIDENCE_REQUIRE_TOOL)
	$(UX_EVIDENCE) new --case "$(CASE)" --classification "$(CLASSIFICATION)" --before "$(BEFORE)" $(if $(REASON),--reason "$$REASON")

# Saves a staging session from a simulator where you are signed in to the staging app; DEVICE picks one.
ux-evidence-ios-login:
	$(UX_EVIDENCE_REQUIRE_TOOL)
	$(UX_EVIDENCE) ios-login $(if $(DEVICE),--device "$(DEVICE)")
