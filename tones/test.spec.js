const { test, expect } = require('@playwright/test');

const DEFAULT_PLAYLIST_ID = 'PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF';
const DEFAULT_PLAYLIST_URL = `https://www.youtube.com/playlist?list=${DEFAULT_PLAYLIST_ID}`;

test.beforeEach(async ({ page }) => {
  await page.route('https://www.youtube.com/iframe_api', route => {
    route.fulfill({
      status: 200,
      contentType: 'application/javascript',
      body: 'setTimeout(function(){ if (window.onYouTubeIframeAPIReady) window.onYouTubeIframeAPIReady(); }, 0);',
    });
  });

  await page.addInitScript(() => {
    window.mockCalls = {
      audioContext: [],
      youtube: [],
      wakeLock: [],
      mediaSession: [],
      windowOpen: [],
    };

    const connectable = () => ({ connect: () => {}, disconnect: () => {} });
    const audioParam = value => ({
      value,
      setTargetAtTime(nextValue) {
        this.value = nextValue;
      },
    });

    const mockAudioContext = {
      state: 'suspended',
      currentTime: 0,
      sampleRate: 44100,
      destination: connectable(),
      createOscillator: () => {
        window.mockCalls.audioContext.push('createOscillator');
        return {
          ...connectable(),
          frequency: audioParam(0),
          type: 'sine',
          start: () => {},
          stop: () => {},
        };
      },
      createGain: () => {
        window.mockCalls.audioContext.push('createGain');
        return {
          ...connectable(),
          gain: audioParam(0),
        };
      },
      createBufferSource: () => {
        window.mockCalls.audioContext.push('createBufferSource');
        return {
          ...connectable(),
          buffer: null,
          loop: false,
          start: () => {},
        };
      },
      createBiquadFilter: () => {
        window.mockCalls.audioContext.push('createBiquadFilter');
        return {
          ...connectable(),
          type: 'bandpass',
          frequency: audioParam(0),
          Q: audioParam(2),
        };
      },
      createChannelMerger: () => {
        window.mockCalls.audioContext.push('createChannelMerger');
        return connectable();
      },
      createBuffer: (_channels, length) => {
        window.mockCalls.audioContext.push('createBuffer');
        return {
          getChannelData: () => new Float32Array(length),
        };
      },
      createMediaStreamDestination: () => {
        window.mockCalls.audioContext.push('createMediaStreamDestination');
        return {
          ...connectable(),
          stream: new MediaStream(),
        };
      },
      resume: () => {
        window.mockCalls.audioContext.push('resume');
        mockAudioContext.state = 'running';
        return Promise.resolve();
      },
      suspend: () => {
        window.mockCalls.audioContext.push('suspend');
        mockAudioContext.state = 'suspended';
        return Promise.resolve();
      },
    };

    window.AudioContext = function AudioContext() {
      window.mockCalls.audioContext.push('AudioContext constructor');
      return mockAudioContext;
    };
    window.webkitAudioContext = window.AudioContext;

    HTMLMediaElement.prototype.play = function play() {
      return Promise.resolve();
    };
    HTMLMediaElement.prototype.pause = function pause() {};

    let playerState = -1;
    let currentIndex = 0;
    let currentTime = 0;
    let duration = 208;
    let videoData = {
      video_id: 'video1',
      title: 'LORN - ANVIL [Official Music Video]',
      author: 'GERIKO',
    };
    let volume = 100;
    const mockPlayer = {
      cuePlaylist: config => {
        window.mockCalls.youtube.push(`cuePlaylist:${JSON.stringify(config)}`);
        playerState = 5;
        if (Number.isFinite(config.index)) currentIndex = config.index;
        if (Number.isFinite(config.startSeconds)) currentTime = config.startSeconds;
      },
      loadPlaylist: config => {
        window.mockCalls.youtube.push(`loadPlaylist:${JSON.stringify(config)}`);
        playerState = 1;
        if (Number.isFinite(config.index)) currentIndex = config.index;
        if (Number.isFinite(config.startSeconds)) currentTime = config.startSeconds;
      },
      playVideo: () => {
        window.mockCalls.youtube.push('playVideo');
        playerState = 1;
        currentTime += 1;
      },
      pauseVideo: () => {
        window.mockCalls.youtube.push('pauseVideo');
        playerState = 2;
      },
      stopVideo: () => {
        window.mockCalls.youtube.push('stopVideo');
        playerState = 2;
      },
      clearVideo: () => {
        window.mockCalls.youtube.push('clearVideo');
      },
      getPlayerState: () => playerState,
      getPlaylistIndex: () => currentIndex,
      getCurrentTime: () => currentTime,
      getDuration: () => duration,
      getPlaylist: () => ['video1', 'video2', 'video3'],
      getVideoData: () => videoData,
      getVolume: () => volume,
      setVolume: nextVolume => {
        window.mockCalls.youtube.push(`setVolume:${nextVolume}`);
        volume = nextVolume;
      },
      seekTo: (seconds, allowSeekAhead) => {
        window.mockCalls.youtube.push(`seekTo:${seconds}:${allowSeekAhead}`);
        currentTime = seconds;
      },
      previousVideo: () => {
        window.mockCalls.youtube.push('previousVideo');
        currentIndex = Math.max(0, currentIndex - 1);
      },
      nextVideo: () => {
        window.mockCalls.youtube.push('nextVideo');
        currentIndex = Math.min(2, currentIndex + 1);
      },
    };

    window.mockPlayerState = {
      get currentIndex() { return currentIndex; },
      set currentIndex(value) { currentIndex = value; },
      get currentTime() { return currentTime; },
      set currentTime(value) { currentTime = value; },
      get duration() { return duration; },
      set duration(value) { duration = value; },
      get videoData() { return videoData; },
      set videoData(value) { videoData = value; },
      get playerState() { return playerState; },
      set playerState(value) { playerState = value; },
      get volume() { return volume; },
    };

    window.YT = {
      Player: function Player(_elementId, config) {
        window.mockCalls.youtube.push('YT.Player constructor');
        requestAnimationFrame(() => {
          config.events.onReady({});
        });
        return mockPlayer;
      },
      PlayerState: {
        UNSTARTED: -1,
        ENDED: 0,
        PLAYING: 1,
        PAUSED: 2,
        BUFFERING: 3,
        CUED: 5,
      },
    };

    const mockWakeLock = {
      addEventListener: (event, callback) => {
        window.mockCalls.wakeLock.push(`addEventListener:${event}`);
        if (event === 'release') mockWakeLock.releaseCallback = callback;
      },
      release: () => {
        window.mockCalls.wakeLock.push('release');
        if (mockWakeLock.releaseCallback) mockWakeLock.releaseCallback();
        return Promise.resolve();
      },
    };

    Object.defineProperty(navigator, 'wakeLock', {
      value: {
        request: type => {
          window.mockCalls.wakeLock.push(`request:${type}`);
          return Promise.resolve(mockWakeLock);
        },
      },
      configurable: true,
    });

    const mediaSessionHandlers = {};
    Object.defineProperty(navigator, 'mediaSession', {
      value: {
        playbackState: 'none',
        metadata: null,
        setActionHandler(action, handler) {
          mediaSessionHandlers[action] = handler;
          window.mockCalls.mediaSession.push(`setActionHandler:${action}`);
        },
        setPositionState(state) {
          window.mockCalls.mediaSession.push(`setPositionState:${JSON.stringify(state)}`);
        },
      },
      configurable: true,
    });
    window.mediaSessionHandlers = mediaSessionHandlers;
    window.MediaMetadata = function MediaMetadata(data) {
      return data;
    };

    const originalOpen = window.open;
    window.open = (...args) => {
      window.mockCalls.windowOpen.push(args);
      if (String(args[0]).startsWith('https://brainaural.com/play.php?')) {
        return null;
      }
      return originalOpen(...args);
    };
  });
});

async function openApp(page) {
  await page.goto('/');
  await page.locator('#preset-0-headphones').waitFor({ state: 'visible' });
  await page.waitForFunction(() => window.BrainTones.acceptance.getYouTubeSnapshot().ready);
}

async function appState(page) {
  return page.evaluate(() => window.BrainTones.acceptance.getState());
}

test.describe('mocked non-playback coverage', () => {
  test('seeds the default playlist keys and recent playlist on first load', async ({ page }) => {
    await openApp(page);

    const state = await appState(page);
    expect(state.isPaused).toBe(true);
    expect(state.isAudioInitialized).toBe(false);
    expect(state.activePlaylistId).toBe(DEFAULT_PLAYLIST_ID);

    const stored = await page.evaluate(() => ({
      playlistId: localStorage.getItem('youtube_playlist_id'),
      playlistUrl: localStorage.getItem('youtube_playlist_url'),
      recentPlaylists: JSON.parse(localStorage.getItem('youtube_recent_playlists') || '[]'),
    }));
    expect(stored.playlistId).toBe(DEFAULT_PLAYLIST_ID);
    expect(stored.playlistUrl).toBe(DEFAULT_PLAYLIST_URL);
    expect(stored.recentPlaylists[0]).toEqual(expect.objectContaining({
      id: DEFAULT_PLAYLIST_ID,
      title: 'AllieSpaces',
      url: DEFAULT_PLAYLIST_URL,
    }));
  });

  test('marks invalid playlist URLs without changing the active playlist', async ({ page }) => {
    await openApp(page);

    await page.locator('#playlist-url').fill('not a playlist');
    await page.keyboard.press('Enter');

    await expect(page.locator('#playlist-url')).toHaveClass(/invalid/);
    expect((await appState(page)).activePlaylistId).toBe(DEFAULT_PLAYLIST_ID);
  });

  test('adds and deletes a recent playlist from UI and localStorage', async ({ page }) => {
    await openApp(page);

    await page.locator('#playlist-url').fill('https://www.youtube.com/playlist?list=PLTEST123456789');
    page.once('dialog', dialog => dialog.accept('Test Playlist'));
    await page.locator('#save-playlist-btn').click();
    await expect(page.locator('.playlist-link', { hasText: 'Test Playlist' })).toBeVisible();

    await page.locator('.recent-playlist-item', { hasText: 'Test Playlist' }).locator('.delete-btn').click();
    await expect(page.locator('.playlist-link', { hasText: 'Test Playlist' })).toHaveCount(0);

    const recentIds = await page.evaluate(() => JSON.parse(localStorage.getItem('youtube_recent_playlists') || '[]').map(playlist => playlist.id));
    expect(recentIds).not.toContain('PLTEST123456789');
  });

  test('places playlist tools beside presets on wide screens', async ({ page }) => {
    await page.setViewportSize({ width: 950, height: 900 });
    await openApp(page);

    const positions = await page.evaluate(() => {
      const presets = document.querySelector('.preset-grid').getBoundingClientRect();
      const youtube = document.querySelector('.youtube-section').getBoundingClientRect();
      const player = document.querySelector('#youtube-player').getBoundingClientRect();

      return {
        presets: {
          top: presets.top,
          right: presets.right,
        },
        youtube: {
          top: youtube.top,
          left: youtube.left,
        },
        player: {
          left: player.left,
        },
      };
    });

    expect(positions.youtube.left).toBeGreaterThan(positions.presets.right);
    expect(Math.abs(positions.youtube.top - positions.presets.top)).toBeLessThan(2);
    expect(positions.player.left).toBeGreaterThan(positions.presets.right);
  });

  test('shows the embedded YouTube player first and toggles display modes', async ({ page }) => {
    await openApp(page);

    await expect(page.locator('.youtube-section')).toHaveClass(/youtube-mode-player/);
    await expect(page.locator('#youtube-simple-controls')).not.toBeVisible();
    await expect(page.locator('#youtube-display-toggle')).toHaveText('Show controls');
    expect((await appState(page)).youtubeDisplayMode).toBe('player');

    await page.locator('#youtube-display-toggle').click();

    await expect(page.locator('.youtube-section')).toHaveClass(/youtube-mode-simple/);
    await expect(page.locator('#youtube-simple-controls')).toBeVisible();
    await expect(page.locator('#youtube-display-toggle')).toHaveText('Show video');
    expect((await appState(page)).youtubeDisplayMode).toBe('simple');
    await expect(page.locator('.youtube-player-container')).not.toBeVisible();

    await page.locator('#youtube-display-toggle').click();

    await expect(page.locator('.youtube-section')).toHaveClass(/youtube-mode-player/);
    await expect(page.locator('#youtube-simple-controls')).not.toBeVisible();
    await expect(page.locator('#youtube-display-toggle')).toHaveText('Show controls');
    await expect(page.locator('.youtube-player-container')).toBeVisible();
  });

  test('switches to simple YouTube controls after app playback starts', async ({ page }) => {
    await openApp(page);

    await page.locator('#preset-0-headphones').click();

    await expect(page.locator('.youtube-section')).toHaveClass(/youtube-mode-simple/, { timeout: 2500 });
    await expect(page.locator('#youtube-simple-controls')).toBeVisible();
    await expect(page.locator('.youtube-player-container')).not.toBeVisible();
    expect((await appState(page)).youtubeDisplayMode).toBe('simple');
  });

  test('simple YouTube controls only toggle YouTube playback and navigate tracks', async ({ page }) => {
    await openApp(page);

    await page.locator('#preset-0-headphones').click();
    await expect(page.locator('.youtube-section')).toHaveClass(/youtube-mode-simple/, { timeout: 2500 });

    await page.locator('#youtube-playpause-btn').click();
    await page.waitForFunction(() => window.BrainTones.acceptance.getYouTubeSnapshot().state === window.BrainTones.acceptance.getYouTubeSnapshot().states.PAUSED);
    expect((await appState(page)).isPaused).toBe(false);
    await expect(page.locator('#preset-0-headphones')).toHaveClass(/active/);
    await expect(page.locator('#youtube-previous-btn')).toBeEnabled();
    await expect(page.locator('#youtube-next-btn')).toBeEnabled();

    await page.locator('#youtube-playpause-btn').click();
    await page.waitForFunction(() => window.BrainTones.acceptance.getYouTubeSnapshot().state === window.BrainTones.acceptance.getYouTubeSnapshot().states.PLAYING);
    expect((await appState(page)).isPaused).toBe(false);

    await page.evaluate(() => {
      window.mockPlayerState.currentTime = 8;
    });
    await page.locator('#youtube-previous-btn').click();
    await page.locator('#youtube-next-btn').click();

    const youtubeCalls = await page.evaluate(() => window.mockCalls.youtube);
    expect(youtubeCalls).toContain('seekTo:0:true');
    expect(youtubeCalls).toContain('nextVideo');
  });

  test('shows current YouTube track details and live time in simple controls', async ({ page }) => {
    await openApp(page);

    await page.locator('#youtube-display-toggle').click();
    await page.evaluate(() => {
      window.mockPlayerState.currentIndex = 1;
      window.mockPlayerState.currentTime = 75;
      window.BrainTones.ui.updateYouTubeNowPlaying();
    });

    await expect(page.locator('#youtube-track-title')).toHaveText('LORN - ANVIL [Official Music Video]');
    await expect(page.locator('#youtube-track-author')).toHaveText('GERIKO');
    await expect(page.locator('#youtube-track-index')).toHaveText('Track 2 of 3');
    await expect(page.locator('#youtube-track-time')).toHaveText('1:15 / 3:28');

    await page.evaluate(() => {
      window.mockPlayerState.currentTime = 76;
    });
    await expect(page.locator('#youtube-track-time')).toHaveText('1:16 / 3:28', { timeout: 1500 });
  });

  test('saves the outgoing playlist state when switching playlist URLs', async ({ page }) => {
    await openApp(page);

    await page.evaluate(() => {
      window.mockPlayerState.currentIndex = 2;
      window.mockPlayerState.currentTime = 45;
    });
    await page.locator('#playlist-url').fill('https://www.youtube.com/playlist?list=PLNEW123456789');
    await page.keyboard.press('Enter');

    const stored = await page.evaluate(() => ({
      playlistId: localStorage.getItem('youtube_playlist_id'),
      states: JSON.parse(localStorage.getItem('youtube_playlist_states') || '{}'),
    }));
    expect(stored.playlistId).toBe('PLNEW123456789');
    expect(stored.states[DEFAULT_PLAYLIST_ID]).toEqual(expect.objectContaining({
      videoIndex: 2,
      playbackTime: 45,
    }));
  });

  test('does not overwrite a saved nonzero playlist time with zero', async ({ page }) => {
    await openApp(page);

    const savedAt = Date.now() - 1000;
    await page.evaluate(({ savedAt }) => {
      localStorage.setItem('youtube_playlist_states', JSON.stringify({
        [localStorage.getItem('youtube_playlist_id')]: {
          videoIndex: 2,
          playbackTime: 45,
          lastUsed: savedAt,
        },
      }));
      window.mockPlayerState.currentIndex = 0;
      window.mockPlayerState.currentTime = 0;
      window.BrainTones.youtube.saveCurrentPosition();
    }, { savedAt });

    const states = await page.evaluate(() => JSON.parse(localStorage.getItem('youtube_playlist_states') || '{}'));
    expect(states[DEFAULT_PLAYLIST_ID]).toEqual({
      videoIndex: 2,
      playbackTime: 45,
      lastUsed: savedAt,
    });
  });

  test('persists native balance input values', async ({ page }) => {
    await openApp(page);

    await page.locator('#tones-music-balance').fill('25');
    await page.reload();
    await page.locator('#preset-0-headphones').waitFor({ state: 'visible' });

    await expect(page.locator('#tones-music-balance')).toHaveValue('25');
    expect(await page.evaluate(() => localStorage.getItem('tones_music_balance'))).toBe('25');
  });

  test('m keyboard alias toggles the unified playback state', async ({ page }) => {
    await openApp(page);

    await page.locator('#preset-0-headphones').click();
    await expect(page.locator('#preset-0-headphones')).toHaveClass(/active/);
    expect((await appState(page)).isPaused).toBe(false);

    await page.keyboard.press('KeyM');
    await expect(page.locator('#mute')).toHaveClass(/superactive/);
    expect((await appState(page)).isPaused).toBe(true);

    await page.keyboard.press('KeyM');
    await expect(page.locator('#preset-0-headphones')).toHaveClass(/active/);
    expect((await appState(page)).isPaused).toBe(false);
  });

  test('requests and releases screen wake lock with app playback', async ({ page }) => {
    await openApp(page);

    await page.locator('#preset-0-headphones').click();
    await expect(page.locator('#wake-lock-status')).toBeVisible();
    expect(await page.evaluate(() => window.mockCalls.wakeLock)).toContain('request:screen');

    await page.locator('#mute').click();
    await expect(page.locator('#wake-lock-status')).not.toBeVisible();
    expect(await page.evaluate(() => window.mockCalls.wakeLock)).toContain('release');
  });

  test('registers Media Session handlers and updates metadata for the selected preset', async ({ page }) => {
    await openApp(page);

    const actions = await page.evaluate(() => window.mockCalls.mediaSession);
    expect(actions).toEqual(expect.arrayContaining([
      'setActionHandler:play',
      'setActionHandler:pause',
      'setActionHandler:stop',
      'setActionHandler:previoustrack',
      'setActionHandler:nexttrack',
    ]));

    await page.locator('#preset-1-speakers').click();
    const expectedTitle = await page.evaluate(() => window.PRESET_TONES[1].name);
    const metadata = await page.evaluate(() => navigator.mediaSession.metadata);
    expect(metadata.title).toBe(expectedTitle);
  });

  test('generates Brainaural URLs from current tone params and pauses first', async ({ page }) => {
    await openApp(page);

    await page.locator('#preset-0-headphones').click();
    await page.locator('#brainaural-link').click();

    const result = await page.evaluate(() => ({
      calls: window.mockCalls.windowOpen,
      state: window.BrainTones.acceptance.getState(),
    }));
    expect(result.state.isPaused).toBe(true);
    expect(result.calls).toHaveLength(1);
    const url = result.calls[0][0];
    for (let index = 0; index < 5; index += 1) {
      expect(url).toContain(`mod${index}=`);
      expect(url).toContain(`car${index}=`);
      expect(url).toContain(`lvl${index}=`);
    }
  });

  test('generates expected preset params for all presets and output types', async ({ page }) => {
    await openApp(page);

    const result = await page.evaluate(() => {
      const failures = [];
      window.PRESET_TONES.forEach((preset, presetIndex) => {
        ['headphones', 'speakers'].forEach(outputType => {
          const params = window.generatePresetParams(preset, outputType);
          preset.layers.forEach((layer, layerIndex) => {
            if (layerIndex >= window.BrainTones.config.MAX_TONE_LAYERS) return;
            if (params[`mod${layerIndex}`] !== layer.freq) {
              failures.push(`${presetIndex}:${outputType}:mod${layerIndex}`);
            }
            if (outputType === 'speakers' && params[`bin${layerIndex}`] !== 0) {
              failures.push(`${presetIndex}:${outputType}:bin${layerIndex}`);
            }
            if (outputType === 'speakers' && params[`iso${layerIndex}`] !== 100) {
              failures.push(`${presetIndex}:${outputType}:iso${layerIndex}`);
            }
            if (outputType === 'headphones' && layer.type === 'binaural' && params[`bin${layerIndex}`] !== 100) {
              failures.push(`${presetIndex}:${outputType}:headphone-bin${layerIndex}`);
            }
          });
        });
      });

      return {
        failures,
        splitHeadphones: window.generatePresetParams(window.PRESET_TONES[8], 'headphones'),
        splitSpeakers: window.generatePresetParams(window.PRESET_TONES[8], 'speakers'),
      };
    });

    expect(result.failures).toEqual([]);
    expect(result.splitHeadphones.car0).toBe(285);
    expect(result.splitSpeakers.car0).toBe(174);
  });
});
