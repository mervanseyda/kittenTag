#!/bin/zsh
set -euo pipefail

PROFILE="${NOTARY_PROFILE:-kittenTag-notary}"

cat <<EOF
This stores kittenTag's Apple notarization credentials in your login Keychain.
Nothing is written to the project or a source file.

You will need:
  • The Apple Account used for the Developer Program
  • The 10-character Team ID from developer.apple.com/account
  • An app-specific password from account.apple.com

Keychain profile: $PROFILE
EOF

xcrun notarytool store-credentials "$PROFILE"
xcrun notarytool history --keychain-profile "$PROFILE"

print
print "Notarization credentials are ready in Keychain profile: $PROFILE"
