.PHONY: help generate build test test-coverage test-scenarios test-citycore-framework-free test-cli-no-audio test-audio-manifest lint format hooks clean sprites-venv sprites-test sprites sprites-offline sprites-reference sprites-verify sprites-content sprites-procedural

WORKSPACE := Citybuilder.xcworkspace
PROJECT := Citybuilder.xcodeproj
SCHEME_IOS := CitybuilderiOS
SCHEME_MAC := CitybuilderMac
SCHEME_CLI := citybuilder-cli
# First available iPhone simulator; override with `make build IOS_SIM="iPhone 17"`.
IOS_SIM ?= $(shell xcrun simctl list devices available 2>/dev/null | grep -m1 'iPhone' | sed -E 's/^ +//; s/ [(][0-9A-F-]+[)].*//')
DESTINATION_IOS := platform=iOS Simulator,name=$(IOS_SIM)
# `xcrun swift` picks the toolchain that matches the active Xcode SDK; a
# bare `swift` on PATH may be a different toolchain that fails to build.
SWIFT ?= xcrun swift
DESTINATION_MAC := platform=macOS
CITYCORE := Packages/CityCore

# AI sprite pipeline targets (see Resources/Sprites.style/world.md and
# openspec/specs/sprite-style-catalog).
SPRITES_VENV := .venv/sprites
SPRITES_PY := $(SPRITES_VENV)/bin/python
SPRITES_PIPELINE_DIR := scripts

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
	$(SWIFT) build --package-path $(CITYCORE)

test:
	$(SWIFT) test --package-path $(CITYCORE) --enable-code-coverage
	$(SWIFT) test --package-path Packages/CityPersistence --enable-code-coverage
	$(SWIFT) test --package-path Packages/CityUI --enable-code-coverage
	$(SWIFT) test --package-path Packages/CityRender2D --enable-code-coverage
	$(SWIFT) test --package-path Packages/CityRender3D --enable-code-coverage
	$(SWIFT) test --package-path Packages/CityAudio --enable-code-coverage

test-coverage:
	./scripts/check-coverage.sh

test-scenarios:
	$(SWIFT) ./scripts/check-scenario-coverage.swift

test-citycore-framework-free:
	./scripts/check-no-apple-ui-imports.sh

test-cli-no-audio:
	./scripts/check-cli-no-audio.sh

test-audio-manifest:
	$(SWIFT) ./scripts/check-audio-manifest.swift

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

sprites-venv:
	python3 -m venv $(SPRITES_VENV)
	$(SPRITES_VENV)/bin/pip install --upgrade pip
	$(SPRITES_VENV)/bin/pip install --no-binary Pillow -r scripts/requirements.txt

sprites-test:
	cd $(SPRITES_PIPELINE_DIR) && ../$(SPRITES_PY) -m pytest tests

sprites:
	cd $(SPRITES_PIPELINE_DIR) && ../$(SPRITES_PY) -m generate_sprites_ai

sprites-offline:
	cd $(SPRITES_PIPELINE_DIR) && ../$(SPRITES_PY) -m generate_sprites_ai --offline

sprites-procedural:
	cd $(SPRITES_PIPELINE_DIR) && ../$(SPRITES_PY) -m generate_sprites_ai --procedural

sprites-reference:
	cd $(SPRITES_PIPELINE_DIR) && ../$(SPRITES_PY) -m generate_sprites_ai --regenerate-reference

sprites-verify:
	cd $(SPRITES_PIPELINE_DIR) && ../$(SPRITES_PY) -m generate_sprites_ai --verify
	$(MAKE) sprites-content

sprites-content:
	$(SWIFT) run -q --package-path Packages/CityRender2D --scratch-path .build/sprite-content-gate sprite-content-gate Resources

clean:
	rm -rf .build DerivedData $(PROJECT) $(WORKSPACE)
	find Packages -name .build -type d -prune -exec rm -rf {} +
