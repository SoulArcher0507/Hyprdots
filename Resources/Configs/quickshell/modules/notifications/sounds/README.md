Place exactly one active notification sound file in this folder root.

Supported extensions:
- `.wav`
- `.ogg`
- `.oga`
- `.mp3`
- `.flac`
- `.aac`
- `.m4a`

Any files stored in subfolders are ignored by the popup sound picker.
Use `sounds/alternatives/` for optional variants you want to keep around without making them active.

If no valid sound file is present here, Quickshell falls back to the bundled `default-notification.wav` and then to a system notification sound.
