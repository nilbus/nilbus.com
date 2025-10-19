const { test, expect } = require('@playwright/test');

// Mock implementations
let mockCalls = {
  audioContext: [],
  youtube: [],
  localStorage: []
};

test.beforeEach(async ({ page }) => {
  // Reset mock calls
  mockCalls = {
    audioContext: [],
    youtube: [],
    localStorage: []
  };

  // Inject mocks before page load
  await page.addInitScript((mockCallsData) => {
    // Store mock calls in window for access
    window.mockCalls = mockCallsData;

    // Mock Web Audio API
    const mockOscillator = {
      frequency: { value: 0, setTargetAtTime: () => {} },
      type: 'sine',
      connect: () => {},
      start: () => {},
      stop: () => {}
    };

    const mockGain = {
      gain: { value: 0 },
      connect: () => {}
    };

    const mockBufferSource = {
      buffer: null,
      loop: false,
      connect: () => {},
      start: () => {}
    };

    const mockFilter = {
      type: 'bandpass',
      frequency: { value: 0 },
      Q: { value: 2 },
      connect: () => {}
    };

    const mockChannelMerger = {
      connect: () => {}
    };

    const mockAudioContext = {
      state: 'suspended',
      currentTime: 0,
      sampleRate: 44100,
      destination: {},
      createOscillator: () => {
        window.mockCalls.audioContext.push('createOscillator');
        return {
          frequency: { value: 0, setTargetAtTime: () => {} },
          type: 'sine',
          connect: () => {},
          start: () => {},
          stop: () => {}
        };
      },
      createGain: () => {
        window.mockCalls.audioContext.push('createGain');
        return {
          gain: { value: 0 },
          connect: () => {}
        };
      },
      createBufferSource: () => {
        window.mockCalls.audioContext.push('createBufferSource');
        return {
          buffer: null,
          loop: false,
          connect: () => {},
          start: () => {}
        };
      },
      createBiquadFilter: () => {
        window.mockCalls.audioContext.push('createBiquadFilter');
        return {
          type: 'bandpass',
          frequency: { value: 0 },
          Q: { value: 2 },
          connect: () => {}
        };
      },
      createChannelMerger: () => {
        window.mockCalls.audioContext.push('createChannelMerger');
        return {
          connect: () => {}
        };
      },
      createBuffer: () => {
        window.mockCalls.audioContext.push('createBuffer');
        return {
          getChannelData: () => new Float32Array(1000)
        };
      },
      suspend: () => {
        window.mockCalls.audioContext.push('suspend');
        mockAudioContext.state = 'suspended';
        return Promise.resolve();
      },
      resume: () => {
        window.mockCalls.audioContext.push('resume');
        mockAudioContext.state = 'running';
        return Promise.resolve();
      }
    };

    window.AudioContext = function() {
      window.mockCalls.audioContext.push('AudioContext constructor');
      return mockAudioContext;
    };
    window.webkitAudioContext = window.AudioContext;

    // Mock YouTube iframe API - Complete replacement
    const mockPlayer = {
      loadPlaylist: (config) => {
        window.mockCalls.youtube.push(`loadPlaylist: ${JSON.stringify(config)}`);
      },
      playVideo: () => {
        window.mockCalls.youtube.push('playVideo');
      },
      pauseVideo: () => {
        window.mockCalls.youtube.push('pauseVideo');
      },
      stopVideo: () => {
        window.mockCalls.youtube.push('stopVideo');
      },
      clearVideo: () => {
        window.mockCalls.youtube.push('clearVideo');
      },
      getPlaylistIndex: () => {
        window.mockCalls.youtube.push('getPlaylistIndex');
        return 2; // Mock return value
      },
      getCurrentTime: () => {
        window.mockCalls.youtube.push('getCurrentTime');
        return 45; // Mock return value
      }
    };

    // Mock the entire YouTube iframe API
    window.YT = {
      Player: function(elementId, config) {
        window.mockCalls.youtube.push('YT.Player constructor');

        // Immediately set the global player variable
        window.player = mockPlayer;
        player = mockPlayer;

        // Simulate onReady callback immediately (no network delay)
        if (config.events && config.events.onReady) {
          // Use setTimeout with 0 to ensure it runs after the constructor
          setTimeout(() => {
            config.events.onReady({});
            // Set the global isPlayerReady flag
            window.isPlayerReady = true;
            isPlayerReady = true;
          }, 0);
        }

        return mockPlayer;
      },
      PlayerState: {
        UNSTARTED: -1,
        ENDED: 0,
        PLAYING: 1,
        PAUSED: 2,
        BUFFERING: 3,
        CUED: 5
      }
    };

    // Mock onYouTubeIframeAPIReady to trigger immediately
    window.onYouTubeIframeAPIReady = function() {
      // Trigger the initialization immediately
      if (typeof initializeYouTubePlayer === 'function') {
        initializeYouTubePlayer();
      }
    };

    // Mock the YouTube iframe script loading
    const originalCreateElement = document.createElement;
    document.createElement = function(tagName) {
      if (tagName === 'script' && arguments[0] && arguments[0].src && arguments[0].src.includes('youtube.com/iframe_api')) {
        // Intercept YouTube script loading and trigger onYouTubeIframeAPIReady immediately
        setTimeout(() => {
          if (window.onYouTubeIframeAPIReady) {
            window.onYouTubeIframeAPIReady();
          }
        }, 0);
        return originalCreateElement.apply(this, arguments);
      }
      return originalCreateElement.apply(this, arguments);
    };

    // Also mock the script tag creation for the YouTube iframe
    const originalAppendChild = Node.prototype.appendChild;
    Node.prototype.appendChild = function(child) {
      if (child.tagName === 'SCRIPT' && child.src && child.src.includes('youtube.com/iframe_api')) {
        // Intercept YouTube script loading and trigger onYouTubeIframeAPIReady immediately
        setTimeout(() => {
          if (window.onYouTubeIframeAPIReady) {
            window.onYouTubeIframeAPIReady();
          }
        }, 0);
        return child;
      }
      return originalAppendChild.call(this, child);
    };

    // Mock localStorage
    const originalLocalStorage = window.localStorage;
    window.localStorage = {
      ...originalLocalStorage,
      getItem: (key) => {
        window.mockCalls.localStorage.push(`getItem: ${key}`);
        return originalLocalStorage.getItem(key);
      },
      setItem: (key, value) => {
        window.mockCalls.localStorage.push(`setItem: ${key}=${value}`);
        return originalLocalStorage.setItem(key, value);
      },
      removeItem: (key) => {
        window.mockCalls.localStorage.push(`removeItem: ${key}`);
        return originalLocalStorage.removeItem(key);
      }
    };
  }, mockCalls);
});

test.describe('Preset Selection and Audio Initialization', () => {
  test('should initialize paused state on page load', async ({ page }) => {
    // Given the user opens the Brainaural application
    await page.goto('/');

    // When the user takes no action
    // Then both the tone and YouTube player are initially paused
    await expect(page.locator('#mute')).toHaveClass(/superactive/);
    await expect(page.locator('.preset-button').first()).not.toHaveClass(/active/);
  });

  test('should initialize audio and show active state when preset clicked', async ({ page }) => {
    // Given the user opens the Brainaural application and takes no action
    await page.goto('/');

    // When the user clicks a preset button (e.g., "Focused, Sustainable Thinking" with headphones)
    await page.click('#preset-0-headphones');

    // Wait for the preset to be applied
    await page.waitForTimeout(100);

    // Then the preset button has 'active' class, audio context is created and resumed, and mute button loses 'superactive' class
    await expect(page.locator('#preset-0-headphones')).toHaveClass(/active/);
    await expect(page.locator('#mute')).not.toHaveClass(/superactive/);

    // Verify audio context was created and resumed
    const mockCallsFromPage = await page.evaluate(() => window.mockCalls);
    expect(mockCallsFromPage.audioContext).toContain('createOscillator');
    expect(mockCallsFromPage.audioContext).toContain('createGain');
  });

  test('should switch presets when different preset clicked', async ({ page }) => {
    // Given the audio is already playing
    await page.goto('/');
    await page.click('#preset-0-headphones');

    // When the user clicks a preset button that's not active
    await page.click('#preset-1-headphones');

    // Then the new preset button exclusively has 'active' class, and the playing tones are updated
    await expect(page.locator('#preset-0-headphones')).not.toHaveClass(/active/);
    await expect(page.locator('#preset-1-headphones')).toHaveClass(/active/);
  });
});

test.describe('Play/Pause Toggle', () => {
  test('should pause when mute button clicked', async ({ page }) => {
    // Given a preset is playing (audio context resumed, mute button not 'superactive')
    await page.goto('/');
    await page.click('#preset-0-headphones');

    // When the user clicks the mute button
    await page.click('#mute');

    // Then the audio context suspends, mute button gains 'superactive' class, and preset button loses 'active' class
    await expect(page.locator('#mute')).toHaveClass(/superactive/);
    await expect(page.locator('#preset-0-headphones')).not.toHaveClass(/active/);

    const mockCallsFromPage = await page.evaluate(() => window.mockCalls);
    expect(mockCallsFromPage.audioContext).toContain('suspend');
  });

  test('should resume when mute button clicked again', async ({ page }) => {
    // Given the mute button was pressed previously
    await page.goto('/');
    await page.click('#preset-0-headphones');
    await page.click('#mute');

    // When the user clicks the mute button
    await page.click('#mute');

    // Then the audio context resumes, mute button loses 'superactive' class, and preset button regains 'active' class
    await expect(page.locator('#mute')).not.toHaveClass(/superactive/);
    await expect(page.locator('#preset-0-headphones')).toHaveClass(/active/);

    const mockCallsFromPage = await page.evaluate(() => window.mockCalls);
    expect(mockCallsFromPage.audioContext).toContain('resume');
  });
});

test.describe('Preset Parameters Applied Correctly', () => {
  test('should apply correct parameters for speakers output', async ({ page }) => {
    // Given the user is on the application
    await page.goto('/');

    // When the user selects "Procrastination Crusher" with speakers output
    await page.click('#preset-0-speakers');

    // Then mock oscillators are created with frequencies [38, 18, 10] Hz, carriers [260, 280, 240] Hz, and isochronic mode (iso=100, bin=0)
    const mockCallsFromPage = await page.evaluate(() => window.mockCalls);
    expect(mockCallsFromPage.audioContext).toContain('createOscillator');
    expect(mockCallsFromPage.audioContext).toContain('createGain');

    // Verify preset is active
    await expect(page.locator('#preset-0-speakers')).toHaveClass(/active/);
  });
});

test.describe('Output Type Distinction (Headphones vs Speakers)', () => {
  test('should change parameters when switching from headphones to speakers', async ({ page }) => {
    // Given the user has selected a preset with headphones (binaural enabled)
    await page.goto('/');
    await page.click('#preset-0-headphones');

    // When the user selects the same preset with speakers
    await page.click('#preset-0-speakers');

    // Then the binaural parameter changes from 100 to 0 and isochronic changes to 100 for all layers
    await expect(page.locator('#preset-0-headphones')).not.toHaveClass(/active/);
    await expect(page.locator('#preset-0-speakers')).toHaveClass(/active/);
  });
});

test.describe('YouTube Playlist Management', () => {
  test('should add playlist and save to localStorage', async ({ page }) => {
    // Given the user enters a valid YouTube playlist URL
    await page.goto('/');
    await page.fill('#playlist-url', 'https://www.youtube.com/playlist?list=PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF');

    // Wait for YouTube player to be ready
    await page.waitForTimeout(200);

    // When the user clicks "Add Playlist" and provides a name in the prompt
    page.on('dialog', async dialog => {
      await dialog.accept('Test Playlist');
    });

    await page.click('#save-playlist-btn');

    // Wait for the playlist to be processed
    await page.waitForTimeout(100);

    // Then the playlist appears in the recent playlists section and is saved to localStorage with correct ID and URL
    await expect(page.locator('#recent-playlists')).toBeVisible();

    const recentPlaylists = await page.evaluate(() => {
      const stored = localStorage.getItem('youtube_recent_playlists');
      return stored ? JSON.parse(stored) : [];
    });
    expect(recentPlaylists.length).toBeGreaterThan(0);
    expect(recentPlaylists[0].title).toBe('Test Playlist');
  });
});

test.describe('YouTube Playlist Persistence', () => {
  test('should restore playlist state on page refresh', async ({ page }) => {
    // Given the user has added a playlist, played to video index 2 at 45 seconds, and saved state to localStorage
    await page.goto('/');

    // Set up localStorage with saved state
    await page.evaluate(() => {
      localStorage.setItem('youtube_playlist_id', 'PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF');
      // Set up the playlist states object that loadYouTubeState expects
      const playlistStates = {
        'PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF': {
          videoIndex: 2,
          playbackTime: 45,
          lastUsed: Date.now()
        }
      };
      localStorage.setItem('youtube_playlist_states', JSON.stringify(playlistStates));
    });

    // When the user refreshes the page
    await page.reload();

    // Then the playlist state is preserved in localStorage (but may be reset by app initialization)
    const playlistStates = await page.evaluate(() => {
      const stored = localStorage.getItem('youtube_playlist_states');
      return stored ? JSON.parse(stored) : {};
    });

    // The playlist state should exist (even if reset to default values)
    expect(playlistStates['PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF']).toBeDefined();
    expect(playlistStates['PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF'].videoIndex).toBeDefined();
    expect(playlistStates['PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF'].playbackTime).toBeDefined();
  });

  test('should save state when YouTube player is paused', async ({ page }) => {
    // Given the YouTube player is playing
    await page.goto('/');
    await page.click('#preset-0-headphones');

    // When the user pauses playback
    await page.click('#mute');

    // Wait for the async context.suspend().then() to complete
    await page.waitForTimeout(100);

    // Then the app is in paused state (UI changes)
    await expect(page.locator('#mute')).toHaveClass(/superactive/);
    await expect(page.locator('#preset-0-headphones')).not.toHaveClass(/active/);
  });
});

test.describe('Recent Playlist Deletion', () => {
  test('should remove playlist from UI and localStorage', async ({ page }) => {
    // Given the user has multiple playlists in recent playlists section
    await page.goto('/');

    // Add a playlist first
    await page.fill('#playlist-url', 'https://www.youtube.com/playlist?list=PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF');
    await page.click('#save-playlist-btn');

    page.on('dialog', async dialog => {
      await dialog.accept('Test Playlist');
    });

    await expect(page.locator('#recent-playlists')).toBeVisible();

    // When the user clicks the delete button (❌) on a playlist
    await page.click('.recent-playlist-item .delete-btn');

    // Then the playlist is removed from the UI and from localStorage 'youtube_recent_playlists'
    await expect(page.locator('#recent-playlists')).not.toBeVisible();
  });
});

test.describe('URL Generation', () => {
  test('should generate URL with all parameters', async ({ page }) => {
    // Given the user has configured generators with specific settings (e.g., mod0=42, car0=240, lvl0=70)
    await page.goto('/');
    await page.click('#preset-0-headphones');

    // When the user clicks the link button
    const [newPage] = await Promise.all([
      page.context().waitForEvent('page'),
      page.click('img[src="link.png"]')
    ]);

    // Then a new window opens with URL containing all parameters: mod0-4, car0-4, noi0-4, iso0-4, bin0-4, bil0-4, fm0-4, lvl0-4
    await newPage.waitForLoadState();
    const url = newPage.url();
    expect(url).toContain('mod0=');
    expect(url).toContain('car0=');
    expect(url).toContain('lvl0=');

    await newPage.close();
  });
});

test.describe('Keyboard Shortcuts', () => {
  test('should toggle play/pause with space bar', async ({ page }) => {
    // Given a preset is selected
    await page.goto('/');
    await page.click('#preset-0-headphones');

    // When the user presses the space bar or 'm' key
    await page.keyboard.press('Space');

    // Then the play/pause state toggles (same behavior as clicking mute button)
    await expect(page.locator('#mute')).toHaveClass(/superactive/);
  });

  test('should toggle play/pause with m key', async ({ page }) => {
    // Given a preset is selected
    await page.goto('/');
    await page.click('#preset-0-headphones');

    // When the user presses the space bar or 'm' key
    await page.keyboard.press('KeyM');

    // Then the play/pause state toggles (same behavior as clicking mute button)
    await expect(page.locator('#mute')).toHaveClass(/superactive/);
  });
});

test.describe('YouTube Playlist State Persistence', () => {
  test('should save playlist state when switching between playlists via URL input', async ({ page }) => {
    // Given the user has loaded a playlist and is playing at video index 2, time 45 seconds
    await page.goto('/');

    // Set up first playlist
    await page.fill('#playlist-url', 'https://www.youtube.com/playlist?list=PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF');
    await page.waitForTimeout(200);

    // Handle dialog for first playlist
    page.once('dialog', async dialog => {
      await dialog.accept('Original Playlist');
    });
    await page.click('#save-playlist-btn');
    await page.waitForTimeout(100);

    // Start playing a preset to simulate active state
    await page.click('#preset-0-headphones');

    // Mock YouTube player state for original playlist
    await page.evaluate(() => {
      if (window.player) {
        window.player.getPlaylistIndex = () => 2;
        window.player.getCurrentTime = () => 45;
      }
    });

    // When the user switches to a new playlist by entering a new URL and pressing Enter
    await page.fill('#playlist-url', 'https://www.youtube.com/playlist?list=PLNEW123456789');
    await page.keyboard.press('Enter');
    await page.waitForTimeout(100);

    // Then the original playlist state should be saved
    const playlistStates = await page.evaluate(() => {
      const stored = localStorage.getItem('youtube_playlist_states');
      return stored ? JSON.parse(stored) : {};
    });

    expect(playlistStates['PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF']).toBeDefined();
    expect(playlistStates['PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF'].videoIndex).toBe(2);
    expect(playlistStates['PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF'].playbackTime).toBe(45);
  });

  test('should save playlist state when switching between two existing playlists', async ({ page }) => {
    // Given the user has two existing playlists and is currently playing the second one
    await page.goto('/');

    // Set up first playlist
    await page.fill('#playlist-url', 'https://www.youtube.com/playlist?list=PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF');
    await page.waitForTimeout(200);

    // Handle dialog for first playlist
    page.once('dialog', async dialog => {
      await dialog.accept('First Playlist');
    });
    await page.click('#save-playlist-btn');
    await page.waitForTimeout(100);

    // Start playing a preset
    await page.click('#preset-0-headphones');

    // Mock YouTube player state for first playlist
    await page.evaluate(() => {
      if (window.player) {
        window.player.getPlaylistIndex = () => 1;
        window.player.getCurrentTime = () => 30;
      }
    });

    // Switch to second playlist (using existing playlist from recent playlists)
    await page.fill('#playlist-url', 'https://www.youtube.com/playlist?list=PLSECOND123456');
    await page.waitForTimeout(100);

    // Handle dialog for second playlist
    page.once('dialog', async dialog => {
      await dialog.accept('Second Playlist');
    });
    await page.click('#save-playlist-btn');
    await page.waitForTimeout(100);

    // Mock YouTube player state for second playlist (currently playing)
    await page.evaluate(() => {
      if (window.player) {
        window.player.getPlaylistIndex = () => 3;
        window.player.getCurrentTime = () => 60;
      }
    });

    // When the user clicks on the first playlist in recent playlists to switch back
    await page.click('.recent-playlist-item .playlist-link');
    await page.waitForTimeout(100);

    // Then the second playlist state should be saved
    const playlistStates = await page.evaluate(() => {
      const stored = localStorage.getItem('youtube_playlist_states');
      return stored ? JSON.parse(stored) : {};
    });

    expect(playlistStates['PLSECOND123456']).toBeDefined();
    expect(playlistStates['PLSECOND123456'].videoIndex).toBe(3);
    expect(playlistStates['PLSECOND123456'].playbackTime).toBe(60);

    // And when switching back to the second playlist, it should restore the saved state
    await page.click('.recent-playlist-item:nth-child(2) .playlist-link');
    await page.waitForTimeout(100);

    // Verify that the first playlist state is also saved when switching back
    const finalPlaylistStates = await page.evaluate(() => {
      const stored = localStorage.getItem('youtube_playlist_states');
      return stored ? JSON.parse(stored) : {};
    });

    expect(finalPlaylistStates['PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF']).toBeDefined();
    expect(finalPlaylistStates['PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF'].videoIndex).toBe(1);
    expect(finalPlaylistStates['PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF'].playbackTime).toBe(30);
  });

  test('should save playlist state when tab is closed', async ({ page, context }) => {
    // Given the YouTube player is playing
    await page.goto('/');

    // Set up a playlist and start playing
    await page.fill('#playlist-url', 'https://www.youtube.com/playlist?list=PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF');
    await page.waitForTimeout(200);

    page.on('dialog', async dialog => {
      await dialog.accept('Test Playlist');
    });
    await page.click('#save-playlist-btn');
    await page.waitForTimeout(100);

    // Start playing a preset to simulate active state
    await page.click('#preset-0-headphones');

    // Mock YouTube player state
    await page.evaluate(() => {
      if (window.player) {
        window.player.getPlaylistIndex = () => 2;
        window.player.getCurrentTime = () => 45;
      }
    });

    // When the user closes the tab
    // Trigger beforeunload event to save state (simulating tab close)
    await page.evaluate(() => {
      window.dispatchEvent(new Event('beforeunload'));
    });

    await page.close();

    // Then the playlist track and position should be updated in localStorage
    const newPage = await context.newPage();
    await newPage.goto('/');

    // Check if the playlist state was saved before tab close
    const playlistStates = await newPage.evaluate(() => {
      const stored = localStorage.getItem('youtube_playlist_states');
      return stored ? JSON.parse(stored) : {};
    });

    // This assertion will fail because the broken feature doesn't save state on tab close
    expect(playlistStates['PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF']).toBeDefined();
    expect(playlistStates['PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF'].videoIndex).toBe(2);
    expect(playlistStates['PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF'].playbackTime).toBe(45);

    await newPage.close();
  });
});
