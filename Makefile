# CommandLineTools-only environment: Testing.framework requires -F flag.
# Use `make test` instead of bare `swift test`.
TESTING_FRAMEWORK_PATH = /Library/Developer/CommandLineTools/Library/Developer/Frameworks
SWIFT_TEST_FLAGS = \
	-Xswiftc -F -Xswiftc $(TESTING_FRAMEWORK_PATH) \
	-Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
	-Xlinker -F -Xlinker $(TESTING_FRAMEWORK_PATH) \
	-Xlinker -rpath -Xlinker $(TESTING_FRAMEWORK_PATH)

.PHONY: test build clean app

test:
	swift test $(SWIFT_TEST_FLAGS)

build:
	swift build

clean:
	swift package clean

# VERSION is injected by CI from the git tag (e.g. make app VERSION=1.2.0).
# Falls back to 0.0.0-dev for local builds.
VERSION  ?= 0.0.0-dev
APP_NAME  = ClaudeUsageBar
BUNDLE    = .build/$(APP_NAME).app
PLIST     = $(BUNDLE)/Contents/Info.plist
DMG       = $(APP_NAME)-$(VERSION).dmg

# Locate the Sparkle artifact unpacked by SPM (set by swift package resolve / build).
SPARKLE_ROOT := $(shell find .build/artifacts -name "Sparkle.xcframework" -type d 2>/dev/null | head -1 | xargs -I{} dirname {})
SPARKLE_FW   := $(SPARKLE_ROOT)/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework
SPARKLE_BIN  := $(SPARKLE_ROOT)/bin

app: test
	# Build universal binary
	swift build -c release --arch arm64
	swift build -c release --arch x86_64
	lipo -create \
	  .build/arm64-apple-macosx/release/$(APP_NAME) \
	  .build/x86_64-apple-macosx/release/$(APP_NAME) \
	  -output .build/$(APP_NAME)
	# Fix RPATH so dyld finds Sparkle.framework in Contents/Frameworks/ at runtime
	install_name_tool -add_rpath @executable_path/../Frameworks .build/$(APP_NAME)
	# Assemble .app bundle
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Frameworks
	cp .build/$(APP_NAME)                    $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Resources/Info.plist                  $(BUNDLE)/Contents/
	mkdir -p $(BUNDLE)/Contents/Resources
	cp Resources/ClaudeUsageBar.icns         $(BUNDLE)/Contents/Resources/
	# Embed Sparkle (ditto preserves symlinks)
	ditto "$(SPARKLE_FW)" "$(BUNDLE)/Contents/Frameworks/Sparkle.framework"
	# Inject version from tag
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" $(PLIST)
	# Ad-hoc sign the app — Sparkle.framework is already signed by the Sparkle project
	codesign --force --sign - $(BUNDLE)
	codesign --verify $(BUNDLE)
	# Package as DMG with drag-to-install UI (requires: brew install create-dmg)
	rm -rf .build/dmg-staging
	mkdir .build/dmg-staging
	cp -r $(BUNDLE) .build/dmg-staging/
	rm -f $(DMG) $(DMG).sha256
	create-dmg \
	  --volname "$(APP_NAME)" \
	  --window-size 540 420 \
	  --background "Resources/dmg-background@2x.png" \
	  --icon-size 100 \
	  --icon "$(APP_NAME).app" 135 148 \
	  --hide-extension "$(APP_NAME).app" \
	  --app-drop-link 405 148 \
	  $(DMG) \
	  .build/dmg-staging/
	shasum -a 256 $(DMG) > $(DMG).sha256
	@echo "Built $(DMG) ($(VERSION))"
	@cat $(DMG).sha256
