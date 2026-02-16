# Changelog

All notable changes to this project will be documented here.

## [v1.1.0] - 2026-02-16

### Security fixes
- **Command injection:** `original_config` was passed unquoted to `displayplacer`, allowing word-splitting and potential shell injection from malformed tool output. Now stored as a proper bash array and expanded with `"${original_config[@]}"`.
- **Predictable temp file:** The state file was written to a fixed path (`/tmp/resolution-fixer.state`), enabling symlink attacks by other local users. Now created with `mktemp` and cleaned up on exit. The path is logged at startup.
- **Unsafe sed substitution:** Install paths were interpolated directly into `sed` patterns; characters like `|`, `\`, and `&` would corrupt the plist substitution. Values are now escaped before use.
- **Input validation:** `origin` and `degree` values extracted from `displayplacer` output are now validated against strict patterns before being used to construct display commands.
- **C buffer overflow:** Display count is now clamped to `MAX_DISPLAYS` after `CGGetOnlineDisplayList` to prevent reading past the end of the array.
- **Null pointer:** `isEnabled` function pointer is now included in the early null-check guard alongside `supports` and `setEnabled`.

### Upgrade notes
- The state file is no longer at the fixed path `/tmp/resolution-fixer.state`. If you were checking that path externally, look for the path in the startup log line instead:
  ```
  tail -1 ~/Library/Logs/resolution-fixer.log | grep "State file"
  ```

---

## [v1.0.0] - 2026-02-14

Initial release.

- Detects incoming Screen Sharing / VNC connections on port 5900
- Switches host display to maximum resolution with Dynamic Resolution enabled
- Restores original display settings on disconnect
- LaunchAgent for automatic startup at login
- `set-dynamic-resolution` helper binary using the SkyLight private framework

[v1.1.0]: https://github.com/bhicks329/resolution-fixer/compare/v1.0.0...v1.1.0
[v1.0.0]: https://github.com/bhicks329/resolution-fixer/releases/tag/v1.0.0
