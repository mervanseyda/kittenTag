# kittenTag icon sources

- `AppIcon.icon` is the editable Icon Composer document and the source of truth.
- `kittenTag-light.png` is used to generate the legacy macOS `.icns` icon.
- `kittenTag-light.png` is the current compatibility icon used by the macOS
  asset catalog.
- `kittenTag-dark.png`, `clear`, and `tinted` exports are retained for native
  Icon Composer appearance support once the release toolchain can compile the
  `.icon` document.

The generated `.icns` is the bundle icon used by Dock, Finder, and Spotlight.
kittenTag never replaces `NSApplication.applicationIconImage` at runtime, so
macOS remains responsible for standard icon sizing and masking.
