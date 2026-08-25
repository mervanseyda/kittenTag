# Third-party notices

kittenTag depends directly on [SPFKMetadata](https://github.com/ryanfrancesconi/spfk-metadata), which is distributed under the MIT License and uses TagLib and format-specific audio libraries.

Each dependency remains governed by its own license. The release build script collects available `LICENSE`, `COPYING`, and `NOTICE` files from resolved Swift package dependencies into `kittenTag.app/Contents/Resources/ThirdPartyNotices`.

The bundled Haskoy font is licensed under the SIL Open Font License 1.1. Its full license text is stored at `Packaging/Fonts/OFL.txt` and is copied into release notices.
