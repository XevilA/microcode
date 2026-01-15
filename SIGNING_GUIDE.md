# CodeTunner - Code Signing & Distribution Guide

## Overview

This guide explains how to properly sign and notarize CodeTunner for distribution to other macOS users.

## Requirements

1. **Apple Developer Account** - Paid ($99/year) at [developer.apple.com](https://developer.apple.com)
2. **Developer ID Certificate** - Application & Installer certificates
3. **Xcode Command Line Tools** - `xcode-select --install`

## Setup Steps

### Step 1: Create Developer ID Certificates

1. Go to [developer.apple.com/account/resources/certificates](https://developer.apple.com/account/resources/certificates)
2. Click "+" to create new certificates:
   - **Developer ID Application** - for signing the app
   - **Developer ID Installer** - for signing PKG installers
3. Download and double-click to install in Keychain

### Step 2: Create App-Specific Password

1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign in → Security → App-Specific Passwords
3. Click "Generate Password"
4. Name it "Notarization" and save the password

### Step 3: Find Your Credentials

```bash
# List your signing certificates
security find-identity -v -p codesigning

# Output example:
# 1) ABC123... "Developer ID Application: Your Name (TEAM_ID)"
# 2) DEF456... "Developer ID Installer: Your Name (TEAM_ID)"
```

Your **Team ID** is the 10-character code in parentheses (e.g., `ABC1234567`).

### Step 4: Set Environment Variables

Add to your `~/.zshrc` or `~/.bash_profile`:

```bash
# Apple Developer Credentials
export DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)"
export APPLE_ID="your@email.com"
export APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"  # App-specific password
export TEAM_ID="YOUR_TEAM_ID"
```

Then reload: `source ~/.zshrc`

## Building & Signing

### Quick Method (All-in-One)

```bash
# Build first
./build_distribution.sh

# Then sign and notarize
./sign_and_notarize.sh all
```

### Step-by-Step Method

```bash
# 1. Check credentials are set
./sign_and_notarize.sh check

# 2. Sign the app
./sign_and_notarize.sh sign

# 3. Create DMG
./sign_and_notarize.sh dmg

# 4. Create PKG
./sign_and_notarize.sh pkg

# 5. Notarize (submit to Apple)
./sign_and_notarize.sh notarize

# 6. Verify everything
./sign_and_notarize.sh verify
```

## Output Files

After successful signing and notarization:

```
Dist/
├── CodeTunner.app          # Signed app bundle
├── CodeTunner-1.0.0.dmg    # Signed & notarized DMG
└── CodeTunner-1.0.0.pkg    # Signed installer package
```

## Distribution

These files can now be safely distributed:

- **DMG** - Best for direct downloads
- **PKG** - Best for enterprise/MDM deployment
- **App** - Can be zipped for distribution

Users will see "Apple checked it for malicious software and none was detected" when opening.

## Troubleshooting

### "Developer ID not found"

```bash
# Check available certificates
security find-identity -v -p codesigning
```

### "Notarization failed"

```bash
# Check the log
xcrun notarytool log <submission-id> \
  --apple-id "$APPLE_ID" \
  --password "$APP_PASSWORD" \
  --team-id "$TEAM_ID"
```

Common issues:
- Missing entitlements
- Unsigned nested binaries
- Invalid Info.plist

### "App is damaged" message

The app wasn't properly signed. Re-run:
```bash
./sign_and_notarize.sh sign
./sign_and_notarize.sh notarize
```

## Security Notes

- Never commit your `APP_PASSWORD` to git
- Use environment variables or macOS Keychain
- Keep certificates secure and backed up
