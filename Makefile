.PHONY: build test run app dry-run dmg

build:
	swift build

test:
	swift test

run:
	swift run r-metronome

app:
	swift run r-metronome-app

dry-run:
	swift run r-metronome --dry-run --duration 4

dmg:
	./scripts/package-dmg.sh
