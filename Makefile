.PHONY: build test run app dry-run

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
