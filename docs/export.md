# Sandspire — Export / build (S16)

Godot **4.7.1** export templates required.

## Install templates (server 110)

```bash
ssh home-mike
bash /home/mike/projects/sandspire/scripts/install_export_templates.sh
# extracts to ~/.local/share/godot/export_templates/4.7.1.stable/
```

Or Editor → Editor Settings → Export → Download templates matching the engine version.

## Export Linux (headless)

```bash
cd /home/mike/projects/sandspire
make export-linux
# → build/linux/Sandspire.x86_64 (+ .pck if not embedded)
./build/linux/Sandspire.x86_64
```

Manual:

```bash
mkdir -p build/linux
~/.local/bin/godot --headless --path . --export-release "Linux" build/linux/Sandspire.x86_64
```

## Export Windows

Requires Windows export templates (same `.tpz`). On a Windows workstation with Godot 4.7.1:

```text
Project → Export → Windows Desktop → Export Project
# or
godot --headless --path . --export-release "Windows Desktop" build/windows/Sandspire.exe
```

On Linux hosts, Windows cross-export works if `windows_release_x86_64.exe` (or equivalent) exists under the templates folder.

## Presets

`export_presets.cfg` — **Linux** and **Windows Desktop**, embed PCK, x86_64.
