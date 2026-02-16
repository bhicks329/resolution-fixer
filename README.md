# resolution-fixer

Automatically sets your Mac's display to **maximum resolution** with **Dynamic Resolution** enabled whenever an incoming Screen Sharing session is detected, then restores the original settings when the session ends.

## The problem

When connecting to a Mac via Screen Sharing, the host defaults to a low resolution. You then have to manually open System Settings → Displays, pick a larger resolution, and toggle "Dynamic resolution" on every time.

This tool fixes that automatically.

## How it works

1. A background script polls for active connections on port 5900 (macOS Screen Sharing / VNC).
2. On connection: waits a few seconds for the display to settle, then:
   - Runs `displayplacer` to switch the host display to the highest available resolution.
   - Calls `SLSDisplaySetDynamicGeometryEnabled` via the SkyLight private framework — the same API that System Settings > Displays uses for the "Dynamic resolution" toggle — so the display automatically resizes to match the viewer's window.
3. On disconnect: restores the previous resolution and dynamic resolution state.
4. A LaunchAgent keeps it running in the background and restarts it at login.

## Requirements

- macOS (Apple Silicon or Intel)
- Xcode Command Line Tools: `xcode-select --install`
- [Homebrew](https://brew.sh) (used to install `displayplacer`)
- Screen Sharing enabled on the host: **System Settings → General → Sharing → Screen Sharing**

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
