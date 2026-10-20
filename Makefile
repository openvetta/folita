PROJECT := Folita.xcodeproj
SCHEME := Folita
DERIVED := .build/DerivedData
APP := $(DERIVED)/Build/Products/Debug/Folita.app

.PHONY: project build test run clean check-release-notes app-icons

project:
	xcodegen generate

build: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -derivedDataPath $(DERIVED) build

test: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED) test

run: build
	open $(APP)

clean:
	rm -rf .build $(PROJECT)

app-icons:
	scripts/icons/export-app-icons.sh

check-release-notes:
	scripts/release/test-check-release-notes.sh
	scripts/release/check-release-notes.sh
