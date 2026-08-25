# kittenTag

kittenTag is a free, open-source audio metadata editor made for macOS. It is focused on manual inspection and batch editing without accounts, online lookups, or a complicated workflow.

## Download

Most users should install the signed and notarized release instead of building the app from source:

**[Download kittenTag 1.0.0 for macOS (.dmg)](https://github.com/mervanseyda/kittenTag/releases/download/v1.0.0/kittenTag-1.0.0.dmg)**

Open the DMG, drag kittenTag into Applications, and launch it from there. kittenTag supports macOS 13 Ventura or later on Apple Silicon and Intel Macs.

## Features

- Edit title, artist, album, album artist, composer, genre, date, comments, track numbers, and disc numbers
- Edit one file or many files at once
- Add, replace, remove, resize, and convert embedded artwork
- Rename files from tag templates with previews and collision checks
- Extract tags from filenames with a preview
- Search, sort, customize columns, and export metadata as CSV
- Preserve metadata fields that kittenTag does not expose
- English and Turkish interfaces, plus light and dark appearance
- Fully offline; no account or metadata service required

## Supported formats

Automated read/write and audio-integrity tests cover:

- MP3
- M4A (AAC in an MPEG-4 container)
- AAC (ADTS)
- FLAC
- Ogg Vorbis
- Opus
- WAV / WAVE
- AIFF / AIF / AIFC

Embedded artwork round-trip tests cover all formats above.

## Safe saving

Text-only changes use the metadata engine's format-aware save path, avoiding a full audio-file copy when possible. Artwork changes use a same-volume staging file because they require multiple write steps. kittenTag verifies the staged metadata, artwork, and readable audio properties before replacing the original.

On APFS, the staging file is normally a copy-on-write clone. On other volumes, kittenTag checks available temporary space first. Batch saves are sequential, so only one staged track is needed at a time.

Back up irreplaceable files regardless of which metadata editor you use.

## Requirements

- macOS 13 Ventura or later
- Apple Silicon or Intel Mac

## Build from source

This section is intended for developers and contributors. Open `Package.swift` in Xcode, choose the **kittenTag** scheme, and run it. The first build downloads the pinned SPFKMetadata dependency.

Or use Terminal:

```sh
swift run kittenTag
```

Run the test suite with:

```sh
swift test
```

The release packaging scripts require Xcode and, for public distribution, an Apple Developer ID certificate and notarization credentials stored in Keychain.

## Contributing

Bug reports and focused pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a change. If a file triggers a metadata bug, share the smallest non-private reproduction you can create; do not publish copyrighted music.

## Privacy

kittenTag edits files locally. It does not require an account, upload music or metadata, or include analytics.

## License

kittenTag is available under the [MIT License](LICENSE). Third-party components remain under their own licenses; release builds include their notices in the application bundle.
