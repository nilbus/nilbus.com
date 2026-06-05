# Brainaural Test Suite

This directory contains an automated test suite for the Brainaural SPA using Playwright.

## Product Notes

- The YouTube playlist area loads with the embedded player visible so users can inspect the source player before playback.
- Once BrainTones playback starts, the page waits 1 second and switches the YouTube area to simple previous/play-pause/next controls.
- Simple mode hides the YouTube embed and controls YouTube only; the toggle restores the full embedded player when desired.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Install Playwright browsers:
```bash
npx playwright install
```

## Running Tests

- **Run all tests**: `npm test` (non-interactive, line reporter)
- **Run tests for CI**: `npm run test:ci` (single worker, line reporter)
- **Run tests with browser UI**: `npm run test:ui`
- **Run tests in headed mode**: `npm run test:headed`
- **Debug tests**: `npm run test:debug`

## Test Structure

The test suite (`test.spec.js`) covers:

1. **Preset Selection and Audio Initialization** - Tests preset button clicks, audio context creation, and UI state changes
2. **Play/Pause Toggle** - Tests mute button functionality and audio context suspend/resume
3. **Preset Parameters Applied Correctly** - Verifies correct parameters are applied from preset_data.js
4. **Output Type Distinction** - Tests headphones vs speakers parameter differences
5. **YouTube Playlist Management** - Tests adding playlists and localStorage persistence
6. **YouTube Playlist Persistence** - Tests state restoration on page refresh
7. **Recent Playlist Deletion** - Tests playlist removal from UI and localStorage
8. **URL Generation** - Tests link button generates correct parameter URLs
9. **Media Keys Integration** - Tests Media Session API integration
10. **Keyboard Shortcuts** - Tests space bar and 'm' key shortcuts
11. **YouTube Display Modes** - Tests full player/simple controls switching and transport button wiring

## Mocking Strategy

- **Web Audio API**: Mocked AudioContext, oscillators, gain nodes to verify creation and method calls
- **YouTube iframe API**: Mocked YT.Player to avoid external dependencies
- **localStorage**: Uses Playwright's context isolation for clean state between tests

## Configuration

- Tests run against `http://localhost:3001` served by npx http-server
- Supports Chromium, Firefox, and WebKit browsers
- Each test runs in isolated browser context with clean localStorage
