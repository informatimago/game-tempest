# Rimward -- an original vector tube shooter for iOS.
# Copyright (C) 2026 Pascal J. Bourguignon -- AGPL-3.0-or-later.

PROJECT     = Rimward.xcodeproj
SCHEME      = Rimward
SIMULATOR  ?= generic/platform=iOS Simulator

.PHONY: all help test project build clean

all: test

help:
	@echo "make test     run the game-logic unit tests (swift test; macOS or Linux)"
	@echo "make project  generate $(PROJECT) with XcodeGen (brew install xcodegen)"
	@echo "make build    build the app for the iOS simulator (needs Xcode)"
	@echo "make clean    remove build products and the generated project"

test:
	swift test --package-path RimwardCore

project:
	xcodegen generate

build: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
	  -destination '$(SIMULATOR)' CODE_SIGNING_ALLOWED=NO build

clean:
	rm -rf RimwardCore/.build build DerivedData $(PROJECT) App/Info.plist
