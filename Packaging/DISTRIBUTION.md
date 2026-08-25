# kittenTag direct distribution

kittenTag is distributed outside the Mac App Store as a signed and notarized
disk image. Release secrets are kept in the macOS Keychain, never in this
repository.

## One-time Apple setup

1. In Xcode, open **Settings > Accounts**, select the Developer Program team,
   then open **Manage Certificates**.
2. Add a **Developer ID Application** certificate. This is different from
   Apple Development, Mac Distribution, and Developer ID Installer.
3. Create an app-specific password at `account.apple.com`.
4. Run `Scripts/configure-notarization.sh` and enter the Apple Account, Team ID,
   and app-specific password when `notarytool` asks for them.

## Create a distributable release

```sh
Scripts/release-distribution.sh
```

The command builds a universal app, signs every nested framework and the app
with Hardened Runtime and a secure timestamp, notarizes and staples the app,
creates and signs a DMG, notarizes and staples the DMG, runs Gatekeeper checks,
and writes a SHA-256 checksum in `.build/releases`.

To test DMG layout without Apple credentials:

```sh
Scripts/release-distribution.sh --unsigned
```

The resulting filename contains `UNSIGNED-DO-NOT-DISTRIBUTE` and is never a
customer build.
