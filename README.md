# resolution-fixer

Automatically sets your Mac's display to **maximum resolution** with **Dynamic Resolution** enabled whenever an incoming Screen Sharing session is detected, then restores the original settings when the session ends.

## Why this exists

Every time I connect to my Mac remotely via Screen Sharing, the same annoying ritual plays out: the display is stuck at a low resolution, text is blurry, and I have to dig into **System Settings → Displays**, manually pick a higher resolution, and toggle "Dynamic resolution" on — before I can actually get any work done. Then when I disconnect it's still changed.

This tool eliminates that entirely. It watches for incoming connections and handles everything automatically, so Screen Sharing just works at full resolution the moment you connect.

## What it does

- Detects an incoming Screen Sharing / VNC connection on port 5900
- Waits a few seconds for the display to settle, then switches to the highest available resolution with Dynamic Resolution enabled
- Restores your original display settings when the session ends
- Runs silently in the background as a LaunchAgent, starting automatically at login

## How it works

1. Polls for active connections on port 5900 (macOS Screen Sharing / VNC).
2. On connection: waits a few seconds for the display to settle, then:
   - Uses `displayplacer` to switch the host display to the highest available resolution.
   - Calls `SLSDisplaySetDynamicGeometryEnabled` via the SkyLight private framework — the same API that System Settings > Displays uses for the "Dynamic resolution" toggle.
3. On disconnect: restores the original resolution and dynamic resolution state.
4. A LaunchAgent keeps it running in the background, restarting automatically at login.

## Requirements

- macOS 13 Ventura or later (tested on Ventura, Sonoma, and Sequoia — Apple Silicon and Intel)
- Xcode Command Line Tools: `xcode-select --install`
- [Homebrew](https://brew.sh) (used to install `displayplacer`)
- Screen Sharing enabled on the host: **System Settings → General → Sharing → Screen Sharing**

> **Note:** Dynamic Resolution relies on a private SkyLight framework API — the same one System Settings uses internally. It works on all currently supported macOS versions but could theoretically break on a future release.

## Install

Clone to the host Mac and run:

```bash
bash install.sh
```

The installer will:

- Install `displayplacer` via Homebrew if needed
- Compile the `set-dynamic-resolution` helper binary
- Register and start a LaunchAgent that persists across reboots

## Uninstall

```bash
bash uninstall.sh
```

## Configuration

Edit the variables near the top of `resolution-fixer.sh`:

| Variable | Default | Description |
| --- | --- | --- |
| `CHECK_INTERVAL` | `2` | Seconds between connection polls |
| `CONNECT_DELAY` | `5` | Seconds to wait after detection before applying changes |
| `RESTORE_ON_DISCONNECT` | `true` | Restore original resolution when the session ends |

## Logs

```bash
tail -f ~/Library/Logs/resolution-fixer.log
```

## Troubleshooting

### No resolution change happens

- Confirm Screen Sharing is enabled and a client can connect.
- Check that `displayplacer` works: `displayplacer list`
- Check logs: `tail -f ~/Library/Logs/resolution-fixer.error.log`

### LaunchAgent status

```bash
launchctl list | grep resolution-fixer
```

A `0` in the first column means it is running. A non-zero number is the last exit code.

### Test dynamic resolution support manually

```bash
./set-dynamic-resolution --query   # show current state
./set-dynamic-resolution           # enable
./set-dynamic-resolution --off     # disable
```
