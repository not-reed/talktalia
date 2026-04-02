# Talktalia

Speech-to-text dictation for [Noctalia](https://github.com/noctalia-dev/noctalia). Toggle to dictate, Whisper-powered, with text injection and visual feedback.

## Requirements

- `wtype` — text injection into the focused window
- Python 3.11+
- [uv](https://docs.astral.sh/uv/) — for daemon installation

## Installation

**1. Add as a source in Noctalia**

In Noctalia settings, add this repo as a plugin source, then install Talktalia from the plugin list.

**2. Install the daemon**

```sh
uv tool install ~/.config/noctalia/plugins/talktalia/daemon
```

This puts `dictation-daemon` on your PATH. The first run will download the selected Whisper model.

## Keybind

**Niri** (`~/.config/niri/config.kdl`):

```kdl
// Dictation - toggle
Alt+V repeat=false { spawn "noctalia-shell" "ipc" "call" "plugin:talktalia" "toggle"; }
// Dictation - cancel (discard without typing)
Alt+Shift+V repeat=false { spawn "noctalia-shell" "ipc" "call" "plugin:talktalia" "cancel"; }
```

**Generic:**

```sh
noctalia-shell ipc call plugin:talktalia toggle
```

## Settings

| Setting | Default | Description |
|---|---|---|
| Whisper Model | `base` | Larger = more accurate, more VRAM |
| Language | `en` | ISO 639-1 code, or `auto` |
| Silence Duration | `1.5s` | Pause after speaking before finalizing |
| Daemon Path | `dictation-daemon` | Override if not on PATH |
| Hide When Inactive | `false` | Hide bar widget when not dictating |
| Auto Start Daemon | `false` | Start daemon on plugin load |
