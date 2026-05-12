.PHONY: help generate build test test-coverage test-scenarios test-citycore-framework-free test-cli-no-audio test-audio-manifest lint format hooks clean

WORKSPACE := Citybuilder.xcworkspace
PROJECT := Citybuilder.xcodeproj
SCHEME_IOS := CitybuilderiOS
SCHEME_MAC := CitybuilderMac
SCHEME_CLI := citybuilder-cli
DESTINATION_IOS := platform=iOS Simulator,name=iPhone 16
DESTINATION_MAC := platform=macOS
CITYCORE := Packages/CityCore

help:
	@echo "Targets:"
	@echo "  generate         Run xcodegen to regenerate the Xcode project"
	@echo "  build            Build all schemes (iOS, macOS, CLI)"
	@echo "  test             Run all swift-testing suites across packages"
	@echo "  test-coverage    Enforce CityCore coverage floors + diff-cover"
	@echo "  test-scenarios   Verify every spec scenario maps to a test"
	@echo "  lint             Run SwiftLint in strict mode"
	@echo "  format           Run SwiftFormat across the repo"
	@echo "  hooks            Install pre-commit / commit-msg / pre-push hooks"
	@echo "  clean            Remove derived data and build artifacts"

generate:
	xcodegen generate

build: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME_IOS) -destination '$(DESTINATION_IOS)' build | xcbeautify || true
	xcodebuild -project $(PROJECT) -scheme $(SCHEME_MAC) -destination '$(DESTINATION_MAC)' build | xcbeautify || true
	swift build --package-path $(CITYCORE)

test:
	swift test --package-path $(CITYCORE) --enable-code-coverage
	swift test --package-path Packages/CityPersistence --enable-code-coverage
	swift test --package-path Packages/CityUI --enable-code-coverage
	swift test --package-path Packages/CityRender2D --enable-code-coverage
	swift test --package-path Packages/CityRender3D --enable-code-coverage
	swift test --package-path Packages/CityAudio --enable-code-coverage

test-coverage: test
	./scripts/check-coverage.sh

test-scenarios:
	swift ./scripts/check-scenario-coverage.swift

test-citycore-framework-free:
	./scripts/check-no-apple-ui-imports.sh

test-cli-no-audio:
	./scripts/check-cli-no-audio.sh

test-audio-manifest:
	swift ./scripts/check-audio-manifest.swift

lint:
	@if find Apps CLI Packages -name '*.swift' -print -quit 2>/dev/null | grep -q .; then \
		swiftlint --strict --quiet; \
	else \
		echo "lint: no Swift sources yet — skipping"; \
	fi

format:
	@if find Apps CLI Packages -name '*.swift' -print -quit 2>/dev/null | grep -q .; then \
		swiftformat .; \
	else \
		echo "format: no Swift sources yet — skipping"; \
	fi

hooks:
	pre-commit install
	pre-commit install --hook-type commit-msg
	pre-commit install --hook-type pre-push

clean:
	rm -rf .build DerivedData $(PROJECT) $(WORKSPACE)
	find Packages -name .build -type d -prune -exec rm -rf {} +
