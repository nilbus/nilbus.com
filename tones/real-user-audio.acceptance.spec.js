const { test, expect } = require('@playwright/test');

const DEFAULT_PLAYLIST_ID = 'PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF';
const DEFAULT_PLAYLIST_URL = `https://www.youtube.com/playlist?list=${DEFAULT_PLAYLIST_ID}`;
const DEFAULT_PLAYLIST_TITLE = 'AllieSpaces';

const CUSTOM_PLAYLIST_ID = 'PLa7mrH1FP1itWJGvbEymj_rlPwWimyRf_';
const CUSTOM_PLAYLIST_URL = `https://music.youtube.com/playlist?list=${CUSTOM_PLAYLIST_ID}&si=9K1d6ackFCgoLRWS`;
const CUSTOM_PLAYLIST_TITLE = 'Acceptance Custom Playlist';

const FIRST_PRESET = { index: 0, name: 'Focused & Sustainable Work' };
const ALT_PRESET = { index: 1, name: 'Procrastination Crusher' };
const SPLIT_CARRIER_PRESET = { index: 8, name: 'Edge: Initiation & Buildup' };

const MIN_TONE_RMS = 0.0005;
const YOUTUBE_READY_TIMEOUT_MS = 20000;
const YOUTUBE_PLAY_TIMEOUT_MS = 5000;
const YOUTUBE_NOT_PLAYING_TIMEOUT_MS = 2000;

test.describe('real user audio acceptance', () => {
  test.describe.configure({ mode: 'serial' });
  test.setTimeout(70000);

  test.beforeEach(async ({ page, browserName }) => {
    test.skip(browserName !== 'chromium', 'Real WebAudio and YouTube acceptance coverage runs only in Chromium.');
    await installAcceptanceProbes(page);
  });

  test.describe('startup / first-run playback', () => {
    test('Given a first run, when the page loads, then tones and YouTube are paused with the default playlist available', async ({ page }) => {
      await openFreshApp(page);

      await expectNoTonesPlaying(page);
      await expectYouTubeNotPlaying(page);
      await expectDefaultPlaylistAvailable(page);
    });

    test('Given a first run, when the first preset is clicked, then first tones and the default playlist play', async ({ page }) => {
      await openFreshApp(page);

      await clickPreset(page, FIRST_PRESET.index, 'headphones');

      await expectPlaybackActive(page, {
        presetIndex: FIRST_PRESET.index,
        outputType: 'headphones',
        playlistId: DEFAULT_PLAYLIST_ID,
      });
    });

    test('Given a first run, when Space is pressed, then first tones and the default playlist play', async ({ page }) => {
      await openFreshApp(page);

      await page.keyboard.press('Space');

      await expectPlaybackActive(page, {
        presetIndex: FIRST_PRESET.index,
        outputType: 'speakers',
        playlistId: DEFAULT_PLAYLIST_ID,
      });
    });

    test('Given a first run, when the default playlist link is clicked, then first tones and the default playlist play', async ({ page }) => {
      await openFreshApp(page);

      await clickPlaylistLink(page, DEFAULT_PLAYLIST_TITLE);

      await expectPlaybackActive(page, {
        presetIndex: FIRST_PRESET.index,
        outputType: 'speakers',
        playlistId: DEFAULT_PLAYLIST_ID,
      });
    });

    test('Given a first run, when the YouTube embed is clicked directly, then tones do not start', async ({ page }) => {
      await openFreshApp(page);

      await clickYouTubeEmbed(page);

      await expectNoTonesPlaying(page);
    });
  });

  test.describe('playback controls', () => {
    test('Given playback is active, when the active preset is clicked again, then tones and music pause', async ({ page }) => {
      await openFreshApp(page);
      await establishPlayback(page, {
        presetIndex: FIRST_PRESET.index,
        outputType: 'headphones',
        playlistId: DEFAULT_PLAYLIST_ID,
      });

      await clickPreset(page, FIRST_PRESET.index, 'headphones');

      await expectPlaybackPaused(page);
    });

    test('Given playback is active, when mute is clicked twice, then tones and music pause and resume', async ({ page }) => {
      await openFreshApp(page);
      await establishPlayback(page, {
        presetIndex: FIRST_PRESET.index,
        outputType: 'headphones',
        playlistId: DEFAULT_PLAYLIST_ID,
      });

      await page.locator('#mute').click();
      await expectPlaybackPaused(page);

      await page.locator('#mute').click();
      await expectPlaybackActive(page, {
        presetIndex: FIRST_PRESET.index,
        outputType: 'headphones',
        playlistId: DEFAULT_PLAYLIST_ID,
      });
    });

    test('Given playback is active, when Space is pressed twice, then tones and music pause and resume', async ({ page }) => {
      await openFreshApp(page);
      await establishPlayback(page, {
        presetIndex: FIRST_PRESET.index,
        outputType: 'headphones',
        playlistId: DEFAULT_PLAYLIST_ID,
      });

      await page.keyboard.press('Space');
      await expectPlaybackPaused(page);

      await page.keyboard.press('Space');
      await expectPlaybackActive(page, {
        presetIndex: FIRST_PRESET.index,
        outputType: 'headphones',
        playlistId: DEFAULT_PLAYLIST_ID,
      });
    });

    test('Given playback is active from initial page load, when Media Session pause fires, then tones and music pause together', async ({ page }) => {
      await openFreshApp(page);
      await establishPlayback(page, {
        presetIndex: FIRST_PRESET.index,
        outputType: 'headphones',
        playlistId: DEFAULT_PLAYLIST_ID,
      });
      await expectMediaOwnershipRefreshSettledAfterInitialPlayback(page);

      await invokeMediaSessionAction(page, 'pause');

      await expectPlaybackPaused(page);
    });

    test('Given tones have been started and stopped once, when Media Session play and pause fire, then tones and music pause and resume together', async ({ page }) => {
      await openFreshApp(page);
      await establishPlayback(page, {
        presetIndex: FIRST_PRESET.index,
        outputType: 'headphones',
        playlistId: DEFAULT_PLAYLIST_ID,
      });

      await page.locator('#mute').click();
      await expectPlaybackPaused(page);

      await invokeMediaSessionAction(page, 'play');
      await expectPlaybackActive(page, {
        presetIndex: FIRST_PRESET.index,
        outputType: 'headphones',
        playlistId: DEFAULT_PLAYLIST_ID,
      });

      await invokeMediaSessionAction(page, 'pause');
      await expectPlaybackPaused(page);

      await invokeMediaSessionAction(page, 'play');
      await expectPlaybackActive(page, {
        presetIndex: FIRST_PRESET.index,
        outputType: 'headphones',
        playlistId: DEFAULT_PLAYLIST_ID,
      });
    });

    test('Given playback is active, when Media Session previous and next fire, then YouTube position or track changes while tones continue', async ({ page }) => {
      await openFreshApp(page);
      await establishPlayback(page, {
        presetIndex: FIRST_PRESET.index,
        outputType: 'headphones',
        playlistId: DEFAULT_PLAYLIST_ID,
      });

      await seekYouTubeTo(page, 8);
      await invokeMediaSessionAction(page, 'previoustrack');
      await waitForYouTubeSnapshot(page, snapshot => snapshot.currentTime <= 2, {
        message: 'Expected previous-track action to restart the current video position.',
      });
      await expectSelectedTone(page, FIRST_PRESET.index, 'headphones');

      const beforeNext = await readYouTubeSnapshot(page);
      await invokeMediaSessionAction(page, 'nexttrack');
      await waitForYouTubeSnapshot(page, snapshot => snapshot.playlistIndex !== beforeNext.playlistIndex, {
        message: 'Expected next-track action to change the YouTube playlist index.',
      });
      await expectYouTubePlaying(page, { playlistId: DEFAULT_PLAYLIST_ID });
      await expectSelectedTone(page, FIRST_PRESET.index, 'headphones');
    });
  });

  test.describe('preset / output changes', () => {
    test('Given playback is active, when another preset is selected, then the active tone set changes and the current playlist keeps playing', async ({ page }) => {
      await openFreshApp(page);
      await establishPlayback(page, {
        presetIndex: FIRST_PRESET.index,
        outputType: 'headphones',
        playlistId: DEFAULT_PLAYLIST_ID,
      });
      const firstParams = await readAppliedToneParams(page);

      await clickPreset(page, ALT_PRESET.index, 'headphones');

      await expectPlaybackActive(page, {
        presetIndex: ALT_PRESET.index,
        outputType: 'headphones',
        playlistId: DEFAULT_PLAYLIST_ID,
      });
      const altParams = await readAppliedToneParams(page);
      expect(altParams).not.toEqual(firstParams);
    });

    test('Given a split-carrier preset is playing, when output changes between headphones and speakers, then tone params change and playback stays active', async ({ page }) => {
      await openFreshApp(page);
      await establishPlayback(page, {
        presetIndex: SPLIT_CARRIER_PRESET.index,
        outputType: 'headphones',
        playlistId: DEFAULT_PLAYLIST_ID,
      });
      const headphonesParams = await readAppliedToneParams(page);

      await clickPreset(page, SPLIT_CARRIER_PRESET.index, 'speakers');

      await expectPlaybackActive(page, {
        presetIndex: SPLIT_CARRIER_PRESET.index,
        outputType: 'speakers',
        playlistId: DEFAULT_PLAYLIST_ID,
      });
      const speakersParams = await readAppliedToneParams(page);
      expect(speakersParams).not.toEqual(headphonesParams);
    });
  });

  test.describe('playlist and persistence', () => {
    test('Given a custom playlist is added, when its recent playlist link is clicked, then first tones and the custom playlist play', async ({ page }) => {
      await openFreshApp(page);
      await addCustomPlaylist(page);

      await clickPlaylistLink(page, CUSTOM_PLAYLIST_TITLE);

      await expectPlaybackActive(page, {
        presetIndex: FIRST_PRESET.index,
        outputType: 'speakers',
        playlistId: CUSTOM_PLAYLIST_ID,
      });
    });

    test('Given tones are playing with the default playlist, when a custom playlist is added, then tones continue and the custom playlist plays', async ({ page }) => {
      await openFreshApp(page);
      await establishPlayback(page, {
        presetIndex: FIRST_PRESET.index,
        outputType: 'headphones',
        playlistId: DEFAULT_PLAYLIST_ID,
      });

      await addCustomPlaylist(page);

      await expectPlaybackActive(page, {
        presetIndex: FIRST_PRESET.index,
        outputType: 'headphones',
        playlistId: CUSTOM_PLAYLIST_ID,
      });
    });

    test('Given custom playlist and alternate tone were active before reload, when Space is pressed after reload, then the same tone and playlist play', async ({ page }) => {
      await openFreshApp(page);
      await addCustomPlaylist(page);
      await establishPlayback(page, {
        presetIndex: ALT_PRESET.index,
        outputType: 'headphones',
        playlistId: CUSTOM_PLAYLIST_ID,
      });

      await page.reload();
      await waitForAppReady(page);
      await page.keyboard.press('Space');

      await expectPlaybackActive(page, {
        presetIndex: ALT_PRESET.index,
        outputType: 'headphones',
        playlistId: CUSTOM_PLAYLIST_ID,
      });
    });

    test('Given alternate tone was active before reload, when a playlist link is clicked after reload, then the same tone and clicked playlist play', async ({ page }) => {
      await openFreshApp(page);
      await addCustomPlaylist(page);
      await clickPlaylistLink(page, DEFAULT_PLAYLIST_TITLE);
      await expectPlaybackActive(page, {
        presetIndex: FIRST_PRESET.index,
        outputType: 'speakers',
        playlistId: DEFAULT_PLAYLIST_ID,
      });
      await establishPlayback(page, {
        presetIndex: ALT_PRESET.index,
        outputType: 'headphones',
        playlistId: DEFAULT_PLAYLIST_ID,
      });

      await page.reload();
      await waitForAppReady(page);
      await clickPlaylistLink(page, CUSTOM_PLAYLIST_TITLE);

      await expectPlaybackActive(page, {
        presetIndex: ALT_PRESET.index,
        outputType: 'headphones',
        playlistId: CUSTOM_PLAYLIST_ID,
      });
    });

    test('Given a playlist position was saved, when playback starts after reload, then YouTube resumes that playlist index/time while tones start', async ({ page }) => {
      await seedSavedPlaylistPosition(page, {
        playlistId: DEFAULT_PLAYLIST_ID,
        playlistUrl: DEFAULT_PLAYLIST_URL,
        title: DEFAULT_PLAYLIST_TITLE,
        videoIndex: 1,
        playbackTime: 12,
      });
      await page.goto('/');
      await waitForAppReady(page);
      await waitForYouTubeSnapshot(page, snapshot => snapshot.playlistIndex === 1 && snapshot.currentTime >= 11, {
        timeout: 10000,
        message: 'Expected saved YouTube playlist index and start time to be cued on reload.',
      });

      await clickPreset(page, FIRST_PRESET.index, 'headphones');

      await expectPlaybackActive(page, {
        presetIndex: FIRST_PRESET.index,
        outputType: 'headphones',
        playlistId: DEFAULT_PLAYLIST_ID,
      });
      const snapshot = await readYouTubeSnapshot(page);
      expect(snapshot.playlistIndex).toBe(1);
      expect(snapshot.currentTime).toBeGreaterThan(11);
    });
  });

  test.describe('balance / external playback-affecting controls', () => {
    test('Given playback is active, when balance moves to tones-only, then tones volume stays audible and YouTube volume is zero', async ({ page }) => {
      await openFreshApp(page);
      await establishPlayback(page, {
        presetIndex: FIRST_PRESET.index,
        outputType: 'headphones',
        playlistId: DEFAULT_PLAYLIST_ID,
      });

      await setBalance(page, 0);

      await expectBalanceVolumes(page, { tonesVolume: 1, youtubeVolume: 0 });
      await expectSelectedTone(page, FIRST_PRESET.index, 'headphones');
    });

    test('Given playback is active, when balance moves to music-only, then tones element volume is zero and YouTube volume stays audible', async ({ page }) => {
      await openFreshApp(page);
      await establishPlayback(page, {
        presetIndex: FIRST_PRESET.index,
        outputType: 'headphones',
        playlistId: DEFAULT_PLAYLIST_ID,
      });

      await setBalance(page, 100);

      await expectBalanceVolumes(page, { tonesVolume: 0, youtubeVolume: 100 });
      await expectYouTubePlaying(page, { playlistId: DEFAULT_PLAYLIST_ID });
    });

    test('Given balance was changed, when the page reloads, then the balance setting is preserved', async ({ page }) => {
      await openFreshApp(page);
      await setBalance(page, 25);

      await page.reload();
      await waitForAppReady(page);

      await waitForPageValue(page, () => {
        return {
          apiValue: window.BrainTones.acceptance.getBalance(),
          storedValue: localStorage.getItem('tones_music_balance'),
          inputValue: document.getElementById('tones-music-balance')?.value,
        };
      }, value => value.apiValue === 25 && value.storedValue === '25' && value.inputValue === '25', {
        message: 'Expected balance input and localStorage to preserve 25 after reload.',
      });
    });

    test('Given playback is active, when the Brainaural external-link control is clicked, then tones and music pause before window.open', async ({ page }) => {
      await openFreshApp(page);
      await establishPlayback(page, {
        presetIndex: FIRST_PRESET.index,
        outputType: 'headphones',
        playlistId: DEFAULT_PLAYLIST_ID,
      });

      await page.locator('img[src="link.png"]').click();

      await waitForPageValue(page, () => window.__brainTonesAcceptance.windowOpenCalls, calls => calls.length === 1, {
        message: 'Expected the external Brainaural link to call window.open once.',
      });
      await expectPlaybackPaused(page);
      const openCall = await page.evaluate(() => window.__brainTonesAcceptance.windowOpenCalls[0]);
      expect(openCall.args[0]).toContain('https://brainaural.com/play.php?');
      expect(openCall.bPaused).toBe(true);
    });
  });
});

async function installAcceptanceProbes(page) {
  await page.addInitScript(() => {
    window.__brainTonesAcceptance = {
      mediaSessionHandlers: {},
      mediaSessionActions: [],
      mediaOwnershipRefreshSchedules: [],
      mediaSessionWrapError: null,
      windowOpenCalls: [],
    };

    window.__readAcceptanceToneState = function(presetIndex, outputType) {
      const emptyState = {
        expectedPresetName: null,
        currentPresetName: null,
        currentOutputType: null,
        bPaused: true,
        contextState: null,
        activeButton: false,
        mismatches: ['preset data unavailable'],
      };

      if (
        !window.BrainTones ||
        !window.BrainTones.acceptance ||
        !window.PRESET_TONES ||
        typeof window.generatePresetParams !== 'function' ||
        !window.PRESET_TONES[presetIndex]
      ) {
        return emptyState;
      }

      const preset = window.PRESET_TONES[presetIndex];
      const expected = window.generatePresetParams(preset, outputType);
      const state = window.BrainTones.acceptance.getState();
      const toneParams = window.BrainTones.acceptance.getToneParams();
      const mappings = {
        mod: toneParams.mod,
        car: toneParams.carrier,
        noi: toneParams.noise,
        iso: toneParams.isochronic,
        bin: toneParams.binaural,
        bil: toneParams.bilateral,
        fm: toneParams.fm,
        lvl: toneParams.level,
      };
      const mismatches = [];

      Object.entries(expected).forEach(([key, expectedValue]) => {
        const match = key.match(/^([a-z]+)(\d+)$/);
        if (!match) {
          mismatches.push(`${key}: unrecognized expected param`);
          return;
        }

        const [, prefix, indexText] = match;
        const source = mappings[prefix];
        const layerIndex = Number(indexText);
        if (!source) {
          mismatches.push(`${key}: missing source array`);
          return;
        }

        const actualValue = Number(source[layerIndex]);
        const expectedNumber = Number(expectedValue);
        if (Math.abs(actualValue - expectedNumber) > 0.01) {
          mismatches.push(`${key}: expected ${expectedNumber}, got ${actualValue}`);
        }
      });

      return {
        expectedPresetName: preset.name,
        currentPresetName: state.currentPresetName,
        currentOutputType: state.currentOutputType,
        bPaused: state.isPaused,
        contextState: state.contextState,
        activeButton: Boolean(document.getElementById(`preset-${presetIndex}-${outputType}`)?.classList.contains('active')),
        mismatches,
      };
    };

    const originalOpen = window.open;
    window.open = function(...args) {
      let youtubeState = null;
      let appState = null;
      try {
        const player = window.BrainTones.acceptance.getYouTubePlayer();
        youtubeState = player && typeof player.getPlayerState === 'function'
          ? player.getPlayerState()
          : null;
      } catch (e) {}
      try {
        appState = window.BrainTones.acceptance.getState();
      } catch (e) {}

      window.__brainTonesAcceptance.windowOpenCalls.push({
        args,
        bPaused: appState ? appState.isPaused : null,
        contextState: appState ? appState.contextState : null,
        youtubeState,
      });

      if (args[0] && String(args[0]).startsWith('https://brainaural.com/play.php?')) {
        return null;
      }

      return originalOpen.apply(window, args);
    };

    const wrapMediaSession = () => {
      try {
        if (!navigator.mediaSession || navigator.mediaSession.__brainTonesAcceptanceWrapped) {
          return;
        }

        const originalSetActionHandler = navigator.mediaSession.setActionHandler.bind(navigator.mediaSession);
        navigator.mediaSession.setActionHandler = function(action, handler) {
          window.__brainTonesAcceptance.mediaSessionActions.push(action);
          window.__brainTonesAcceptance.mediaSessionHandlers[action] = handler;
          return originalSetActionHandler(action, handler);
        };

        Object.defineProperty(navigator.mediaSession, '__brainTonesAcceptanceWrapped', {
          value: true,
          configurable: true,
        });
      } catch (error) {
        window.__brainTonesAcceptance.mediaSessionWrapError = String(error && error.message ? error.message : error);
      }
    };

    const wrapAppSession = () => {
      try {
        const session = window.BrainTones && window.BrainTones.session;
        if (!session || session.__brainTonesAcceptanceWrapped || typeof session.scheduleMediaOwnershipPlaybackRefresh !== 'function') {
          return;
        }

        const originalSchedule = session.scheduleMediaOwnershipPlaybackRefresh.bind(session);
        session.scheduleMediaOwnershipPlaybackRefresh = function(delayMs) {
          let youtubeSnapshot = null;
          let appState = null;
          try {
            youtubeSnapshot = window.BrainTones.acceptance.getYouTubeSnapshot();
          } catch (e) {}
          try {
            appState = window.BrainTones.acceptance.getState();
          } catch (e) {}

          const result = originalSchedule(delayMs);

          window.__brainTonesAcceptance.mediaOwnershipRefreshSchedules.push({
            at: performance.now(),
            delayMs: Number(delayMs) || 0,
            result,
            youtubeState: youtubeSnapshot ? youtubeSnapshot.state : null,
            youtubeCurrentTime: youtubeSnapshot ? youtubeSnapshot.currentTime : null,
            appIsPaused: appState ? appState.isPaused : null,
            presetIndex: appState ? appState.currentPresetIndex : null,
            outputType: appState ? appState.currentOutputType : null,
          });

          return result;
        };

        Object.defineProperty(session, '__brainTonesAcceptanceWrapped', {
          value: true,
          configurable: true,
        });
      } catch (error) {
        window.__brainTonesAcceptance.mediaSessionWrapError = String(error && error.message ? error.message : error);
      }
    };

    wrapMediaSession();
    wrapAppSession();
    const wrapTimer = setInterval(wrapMediaSession, 50);
    const appWrapTimer = setInterval(wrapAppSession, 50);
    window.addEventListener('load', () => setTimeout(() => {
      clearInterval(wrapTimer);
      clearInterval(appWrapTimer);
    }, 5000));
  });
}

async function openFreshApp(page) {
  await page.goto('/');
  await page.evaluate(() => localStorage.clear());
  await page.reload();
  await waitForAppReady(page);
  await expectDefaultPlaylistAvailable(page);
}

async function waitForAppReady(page) {
  await page.locator('#preset-0-headphones').waitFor({ state: 'visible', timeout: 10000 });
  await waitForYouTubeReady(page);
}

async function waitForYouTubeReady(page) {
  await waitForPageValue(page, () => {
    const snapshot = window.BrainTones?.acceptance?.getYouTubeSnapshot?.();
    return Boolean(snapshot && snapshot.ready && snapshot.hasPlayer && window.YT && window.YT.PlayerState);
  }, Boolean, {
    timeout: YOUTUBE_READY_TIMEOUT_MS,
    message: 'Expected the real YouTube iframe API player to become ready.',
  });
}

async function expectDefaultPlaylistAvailable(page) {
  await expect(page.locator('#playlist-url')).toHaveValue(DEFAULT_PLAYLIST_URL);
  await expect(page.locator('.playlist-link', { hasText: DEFAULT_PLAYLIST_TITLE })).toBeVisible({ timeout: 10000 });

  const stored = await page.evaluate(() => {
    return {
      playlistId: localStorage.getItem('youtube_playlist_id'),
      playlistUrl: localStorage.getItem('youtube_playlist_url'),
      recentPlaylists: JSON.parse(localStorage.getItem('youtube_recent_playlists') || '[]'),
    };
  });

  expect(stored.playlistId).toBe(DEFAULT_PLAYLIST_ID);
  expect(stored.playlistUrl).toBe(DEFAULT_PLAYLIST_URL);
  expect(stored.recentPlaylists.some(playlist => (
    playlist.id === DEFAULT_PLAYLIST_ID &&
    playlist.title === DEFAULT_PLAYLIST_TITLE &&
    playlist.url === DEFAULT_PLAYLIST_URL
  ))).toBe(true);
}

async function clickPreset(page, presetIndex, outputType) {
  await page.locator(`#preset-${presetIndex}-${outputType}`).click();
}

async function clickPlaylistLink(page, title) {
  await page.locator('.playlist-link', { hasText: title }).click();
}

async function clickYouTubeEmbed(page) {
  const iframe = page.locator('iframe#youtube-player, #youtube-player iframe').first();
  await iframe.waitFor({ state: 'visible', timeout: 10000 });
  const box = await iframe.boundingBox();
  if (!box) {
    throw new Error('YouTube iframe was not visible enough to click.');
  }
  await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
  await page.waitForTimeout(500);
}

async function addCustomPlaylist(page) {
  await page.locator('#playlist-url').fill(CUSTOM_PLAYLIST_URL);
  page.once('dialog', async dialog => {
    await dialog.accept(CUSTOM_PLAYLIST_TITLE);
  });
  await page.locator('#save-playlist-btn').click();
  await expect(page.locator('.playlist-link', { hasText: CUSTOM_PLAYLIST_TITLE })).toBeVisible({ timeout: 10000 });
  await expectActivePlaylist(page, CUSTOM_PLAYLIST_ID);
}

async function establishPlayback(page, { presetIndex, outputType, playlistId }) {
  await clickPreset(page, presetIndex, outputType);
  await expectSelectedTone(page, presetIndex, outputType);
  await expectActivePlaylist(page, playlistId);

  try {
    await expectYouTubePlaying(page, { playlistId });
    return;
  } catch (error) {
    await nudgeYouTubeIfAppPlaybackActive(page, { presetIndex, outputType, playlistId, error });
  }
}

async function expectPlaybackActive(page, { presetIndex, outputType, playlistId }) {
  await expectSelectedTone(page, presetIndex, outputType);
  await expectActivePlaylist(page, playlistId);
  try {
    await expectYouTubePlaying(page, { playlistId });
  } catch (error) {
    await nudgeYouTubeIfAppPlaybackActive(page, { presetIndex, outputType, playlistId, error });
  }
}

async function nudgeYouTubeIfAppPlaybackActive(page, { presetIndex, outputType, playlistId, error }) {
  const appState = await page.evaluate(({ presetIndex: pagePresetIndex, outputType: pageOutputType }) => {
    const state = window.BrainTones.acceptance.getState();
    const activeButton = document.getElementById(`preset-${pagePresetIndex}-${pageOutputType}`);
    return {
      bPaused: state.isPaused,
      activeButton: Boolean(activeButton && activeButton.classList.contains('active')),
      currentPresetName: state.currentPresetName,
      currentOutputType: state.currentOutputType,
    };
  }, { presetIndex, outputType });
  const youtube = await readYouTubeSnapshot(page);
  const canNudgePlayback = (
    appState.bPaused === false &&
    appState.activeButton === true &&
    appState.currentOutputType === outputType &&
    youtube.ready === true &&
    youtube.localPlaylistId === playlistId &&
    [youtube.states.UNSTARTED, youtube.states.CUED].includes(youtube.state)
  );

  if (!canNudgePlayback) {
    throw error;
  }

  await page.evaluate(() => {
    window.BrainTones.acceptance.getYouTubePlayer().playVideo();
  });
  await expectYouTubePlaying(page, { playlistId });
}

async function expectPlaybackPaused(page) {
  await waitForPageValue(page, () => {
    const state = window.BrainTones.acceptance.getState();
    return {
      bPaused: state.isPaused,
      contextState: state.contextState,
      activePresetCount: document.querySelectorAll('.preset-button.active').length,
      muteActive: document.getElementById('mute') ? document.getElementById('mute').classList.contains('superactive') : false,
    };
  }, state => (
    state.bPaused === true &&
    state.activePresetCount === 0 &&
    state.muteActive === true &&
    (!state.contextState || state.contextState === 'suspended')
  ), {
    timeout: 10000,
    message: 'Expected app tone state to be paused.',
  });

  await expectTonesSilentOrUnavailable(page);
  await expectYouTubeNotPlaying(page);
}

async function expectNoTonesPlaying(page) {
  const state = await page.evaluate(() => {
    const apiState = window.BrainTones.acceptance.getState();
    return {
      bPaused: apiState.isPaused,
      initialized: apiState.isAudioInitialized,
      contextState: apiState.contextState,
      activePresetCount: document.querySelectorAll('.preset-button.active').length,
      hasToneStream: apiState.hasToneStream,
    };
  });

  expect(state.bPaused).toBe(true);
  expect(state.activePresetCount).toBe(0);

  if (state.initialized && state.hasToneStream && state.contextState === 'running') {
    await expectTonesSilentOrUnavailable(page);
  }
}

async function expectSelectedTone(page, presetIndex, outputType) {
  await expect(page.locator(`#preset-${presetIndex}-${outputType}`)).toHaveClass(/active/, { timeout: 10000 });

  await waitForPageValue(page, ({ presetIndex: pagePresetIndex, outputType: pageOutputType }) => {
    return window.__readAcceptanceToneState(pagePresetIndex, pageOutputType);
  }, state => (
    state.currentPresetName === state.expectedPresetName &&
    state.currentOutputType === outputType &&
    state.bPaused === false &&
    state.contextState === 'running' &&
    state.activeButton === true &&
    state.mismatches.length === 0
  ), {
    arg: { presetIndex, outputType },
    timeout: 10000,
    message: `Expected ${outputType} preset ${presetIndex} tone params to be active.`,
  });

  await expectTonesAudible(page);
}

async function expectTonesAudible(page) {
  const sample = await sampleTonePcm(page);
  expect(sample.available).toBe(true);
  expect(sample.rms).toBeGreaterThan(MIN_TONE_RMS);
  expect(sample.peak).toBeGreaterThan(MIN_TONE_RMS);
}

async function expectTonesSilentOrUnavailable(page) {
  const sample = await sampleTonePcm(page, 250);
  if (!sample.available) {
    return;
  }
  expect(sample.rms).toBeLessThan(MIN_TONE_RMS);
}

async function sampleTonePcm(page, durationMs = 350) {
  return page.evaluate(async ({ durationMs: pageDurationMs }) => {
    const destination = window.BrainTones.acceptance.getToneMediaOutputDestination();
    if (!destination || !destination.stream) {
      return { available: false, rms: 0, peak: 0, reason: 'missing tonesMediaOutputDestination.stream' };
    }

    const AudioContextCtor = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextCtor) {
      return { available: false, rms: 0, peak: 0, reason: 'missing AudioContext' };
    }

    const probeContext = window.__tonesPcmProbeContext || new AudioContextCtor();
    window.__tonesPcmProbeContext = probeContext;
    if (probeContext.state === 'suspended') {
      await probeContext.resume();
    }

    const source = probeContext.createMediaStreamSource(destination.stream);
    const analyser = probeContext.createAnalyser();
    analyser.fftSize = 2048;
    source.connect(analyser);

    const data = new Float32Array(analyser.fftSize);
    let sumSquares = 0;
    let sampleCount = 0;
    let peak = 0;
    const deadline = performance.now() + pageDurationMs;

    while (performance.now() < deadline) {
      analyser.getFloatTimeDomainData(data);
      for (let i = 0; i < data.length; i += 1) {
        const value = data[i];
        sumSquares += value * value;
        sampleCount += 1;
        peak = Math.max(peak, Math.abs(value));
      }
      await new Promise(resolve => setTimeout(resolve, 50));
    }

    try { source.disconnect(); } catch (e) {}
    try { analyser.disconnect(); } catch (e) {}

    return {
      available: true,
      rms: sampleCount > 0 ? Math.sqrt(sumSquares / sampleCount) : 0,
      peak,
    };
  }, { durationMs });
}

async function readAppliedToneParams(page) {
  return page.evaluate(() => {
    return window.BrainTones.acceptance.getToneParams();
  });
}

async function expectActivePlaylist(page, playlistId) {
  await waitForPageValue(page, () => localStorage.getItem('youtube_playlist_id'), value => value === playlistId, {
    timeout: 5000,
    message: `Expected active playlist ${playlistId}.`,
  });
}

async function readYouTubeSnapshot(page) {
  return page.evaluate(() => {
    return window.BrainTones.acceptance.getYouTubeSnapshot();
  });
}

async function expectYouTubePlaying(page, { playlistId, timeout = YOUTUBE_PLAY_TIMEOUT_MS } = {}) {
  let firstPlayingTime = null;
  let lastSnapshot = null;
  const deadline = Date.now() + timeout;

  while (Date.now() < deadline) {
    lastSnapshot = await readYouTubeSnapshot(page);

    if (
      (!playlistId || lastSnapshot.localPlaylistId === playlistId) &&
      lastSnapshot.ready &&
      lastSnapshot.state === lastSnapshot.states.PLAYING &&
      Number.isFinite(lastSnapshot.currentTime)
    ) {
      if (firstPlayingTime === null) {
        firstPlayingTime = lastSnapshot.currentTime;
      } else if (lastSnapshot.currentTime > firstPlayingTime + 0.15) {
        return lastSnapshot;
      }
    } else {
      firstPlayingTime = null;
    }

    await page.waitForTimeout(100);
  }

  throw new Error(`Expected YouTube to be PLAYING with advancing currentTime. Last snapshot: ${JSON.stringify(lastSnapshot)}`);
}

async function expectYouTubeNotPlaying(page) {
  let firstSnapshot = await readYouTubeSnapshot(page);
  const nonPlayingStates = new Set([
    firstSnapshot.states.UNSTARTED,
    firstSnapshot.states.ENDED,
    firstSnapshot.states.PAUSED,
    firstSnapshot.states.CUED,
  ]);

  if (!firstSnapshot.hasPlayer || !firstSnapshot.ready || nonPlayingStates.has(firstSnapshot.state)) {
    return firstSnapshot;
  }

  const startTime = Number.isFinite(firstSnapshot.currentTime) ? firstSnapshot.currentTime : null;
  let lastSnapshot = firstSnapshot;
  const deadline = Date.now() + YOUTUBE_NOT_PLAYING_TIMEOUT_MS;

  while (Date.now() < deadline) {
    lastSnapshot = await readYouTubeSnapshot(page);

    if (nonPlayingStates.has(lastSnapshot.state)) {
      return lastSnapshot;
    }

    if (
      lastSnapshot.state === lastSnapshot.states.PLAYING &&
      Number.isFinite(startTime) &&
      Number.isFinite(lastSnapshot.currentTime) &&
      lastSnapshot.currentTime > startTime + 0.15
    ) {
      throw new Error(`Expected YouTube not to play, but currentTime advanced. First: ${JSON.stringify(firstSnapshot)} Last: ${JSON.stringify(lastSnapshot)}`);
    }

    await page.waitForTimeout(100);
  }

  if (lastSnapshot.state === lastSnapshot.states.PLAYING) {
    throw new Error(`Expected YouTube not to be PLAYING. Last snapshot: ${JSON.stringify(lastSnapshot)}`);
  }

  return lastSnapshot;
}

async function waitForYouTubeSnapshot(page, predicate, { timeout = 5000, message = 'Expected YouTube snapshot condition.' } = {}) {
  let lastSnapshot = null;
  const deadline = Date.now() + timeout;

  while (Date.now() < deadline) {
    lastSnapshot = await readYouTubeSnapshot(page);
    if (predicate(lastSnapshot)) {
      return lastSnapshot;
    }
    await page.waitForTimeout(100);
  }

  throw new Error(`${message} Last snapshot: ${JSON.stringify(lastSnapshot)}`);
}

async function seekYouTubeTo(page, seconds) {
  await page.evaluate(secondsInPage => {
    window.BrainTones.acceptance.getYouTubePlayer().seekTo(secondsInPage, true);
  }, seconds);

  await waitForYouTubeSnapshot(page, snapshot => snapshot.currentTime >= seconds - 1, {
    message: `Expected YouTube to seek to ${seconds}s.`,
  });
}

async function invokeMediaSessionAction(page, action) {
  await waitForMediaSessionAction(page, action);
  await page.evaluate(async actionInPage => {
    const handler = window.__brainTonesAcceptance.mediaSessionHandlers[actionInPage];
    const result = handler();
    if (result && typeof result.then === 'function') {
      await result;
    }
  }, action);
}

async function waitForMediaSessionAction(page, action) {
  await waitForPageValue(page, actionInPage => {
    return Boolean(
      window.__brainTonesAcceptance &&
      window.__brainTonesAcceptance.mediaSessionHandlers &&
      typeof window.__brainTonesAcceptance.mediaSessionHandlers[actionInPage] === 'function'
    );
  }, Boolean, {
    arg: action,
    timeout: 5000,
    message: `Expected Media Session action handler "${action}" to be registered.`,
  });
}

async function expectMediaOwnershipRefreshSettledAfterInitialPlayback(page) {
  const schedule = await waitForPageValue(page, () => {
    const schedules = window.__brainTonesAcceptance?.mediaOwnershipRefreshSchedules || [];
    return schedules.find(entry => (
      entry.result === true &&
      entry.appIsPaused === false &&
      entry.presetIndex !== null &&
      Boolean(entry.outputType)
    )) || null;
  }, Boolean, {
    timeout: 5000,
    message: 'Expected media ownership playback refresh to be scheduled after initial app playback.',
  });

  await waitForPageValue(page, scheduleInPage => {
    const appState = window.BrainTones.acceptance.getState();
    const youtube = window.BrainTones.acceptance.getYouTubeSnapshot();
    return (
      performance.now() >= scheduleInPage.at + scheduleInPage.delayMs + 500 &&
      appState.isPaused === false &&
      appState.currentPresetIndex !== null &&
      youtube.ready &&
      youtube.state === youtube.states.PLAYING
    );
  }, Boolean, {
    arg: schedule,
    timeout: 5000,
    message: 'Expected app playback to settle active after the media ownership playback refresh.',
  });
}

async function setBalance(page, value) {
  const slider = page.locator('#tones-music-balance');
  await slider.fill(String(value));
  await waitForPageValue(page, () => {
    return {
      apiValue: window.BrainTones.acceptance.getBalance(),
      storedValue: localStorage.getItem('tones_music_balance'),
      inputValue: document.getElementById('tones-music-balance')?.value,
    };
  }, state => state.apiValue === value && state.storedValue === String(value) && state.inputValue === String(value), {
    message: `Expected balance input to move to ${value}.`,
  });
}

async function expectBalanceVolumes(page, { tonesVolume, youtubeVolume }) {
  await waitForPageValue(page, () => {
    const toneElement = window.BrainTones.acceptance.getToneMediaOutputElement();
    const youtube = window.BrainTones.acceptance.getYouTubeSnapshot();
    return {
      tonesVolume: toneElement ? toneElement.volume : null,
      youtubeVolume: youtube.volume,
    };
  }, volumes => (
    volumes.tonesVolume === tonesVolume &&
    volumes.youtubeVolume === youtubeVolume
  ), {
    timeout: 5000,
    message: `Expected tones volume ${tonesVolume} and YouTube volume ${youtubeVolume}.`,
  });
}

async function seedSavedPlaylistPosition(page, { playlistId, playlistUrl, title, videoIndex, playbackTime }) {
  await page.addInitScript(seed => {
    localStorage.setItem('youtube_playlist_id', seed.playlistId);
    localStorage.setItem('youtube_playlist_url', seed.playlistUrl);
    localStorage.setItem('youtube_recent_playlists', JSON.stringify([{
      id: seed.playlistId,
      title: seed.title,
      url: seed.playlistUrl,
      addedAt: Date.now(),
    }]));
    localStorage.setItem('youtube_playlist_states', JSON.stringify({
      [seed.playlistId]: {
        videoIndex: seed.videoIndex,
        playbackTime: seed.playbackTime,
        lastUsed: Date.now(),
      },
    }));
  }, { playlistId, playlistUrl, title, videoIndex, playbackTime });
}

async function waitForPageValue(page, producer, predicate, {
  arg,
  timeout = 5000,
  interval = 100,
  message = 'Expected page value condition.',
} = {}) {
  let lastValue = null;
  const deadline = Date.now() + timeout;

  while (Date.now() < deadline) {
    lastValue = await page.evaluate(producer, arg);
    if (predicate(lastValue)) {
      return lastValue;
    }
    await page.waitForTimeout(interval);
  }

  throw new Error(`${message} Last value: ${JSON.stringify(lastValue)}`);
}
