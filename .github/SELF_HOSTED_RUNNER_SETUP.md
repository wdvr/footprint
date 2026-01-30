# Self-Hosted Runner Setup for iOS Development

This document explains the setup and configuration for the self-hosted macOS runner used for iOS builds and testing.

## Xcode Configuration

### Problem
GitHub Actions self-hosted runners often encounter issues with `sudo xcode-select` commands because:
1. Self-hosted runners may not have passwordless sudo configured
2. Interactive password prompts are not supported in CI environments
3. Xcode selection requires elevated permissions on some systems

### Solution
Our workflows use a multi-tiered approach to configure Xcode:

1. **Attempt non-sudo selection**: Try `xcode-select -s` without sudo first
2. **Fallback to DEVELOPER_DIR**: If sudo fails, set the `DEVELOPER_DIR` environment variable
3. **Graceful error handling**: Provide clear error messages if no Xcode is found

### Xcode Detection Logic
The workflows search for Xcode installations in this order:
1. `/Applications/Xcode_26.2.app` (preferred for iOS 26 development)
2. `/Applications/Xcode_26.1.app`
3. `/Applications/Xcode_26.0.app`
4. `/Applications/Xcode_26.app`
5. `/Applications/Xcode.app` (fallback)

### Runner Setup Recommendations

#### Option 1: Configure passwordless sudo (Recommended)
```bash
# Add to /etc/sudoers.d/github-actions (replace 'runner' with your username)
runner ALL=(ALL) NOPASSWD: /usr/bin/xcode-select
```

#### Option 2: Pre-configure Xcode selection
```bash
# Set the default Xcode version system-wide
sudo xcode-select -s /Applications/Xcode_26.2.app/Contents/Developer
```

#### Option 3: Use DEVELOPER_DIR (Automatic fallback)
The workflows automatically set the `DEVELOPER_DIR` environment variable if sudo fails, which should work for most build commands.

### Verification
After setup, verify the configuration:
```bash
xcodebuild -version
xcrun --show-sdk-version --sdk iphoneos
xcrun simctl list devices available | grep "iPhone"
```

## Required Software on Runner

### Development Tools
- Xcode 26.x (preferably 26.2)
- Homebrew package manager
- XcodeGen (`brew install xcodegen`)

### GitHub Actions Runner
- Latest GitHub Actions Runner software
- Properly configured with repository access
- Labels: `[self-hosted, macOS, ARM64]`

## Troubleshooting

### Common Issues

#### "No Xcode found"
- Verify Xcode is installed in `/Applications/`
- Check naming convention matches expected pattern
- Ensure Xcode license is accepted: `sudo xcodebuild -license accept`

#### "sudo: a password is required"
- Implement passwordless sudo (Option 1 above)
- Or pre-configure Xcode selection (Option 2 above)

#### "No iPhone simulators available"
- Open Xcode and install iOS simulators
- Run: `xcrun simctl list devices available`
- Ensure iOS 26+ simulator runtimes are installed

#### "XcodeGen not found"
- Install via Homebrew: `brew install xcodegen`
- Verify installation: `xcodegen version`

### Debug Commands
```bash
# Check Xcode installations
ls -la /Applications/ | grep -i xcode

# Check current Xcode selection
xcode-select -p

# List available SDKs
xcodebuild -showsdks

# Test xcode-select without sudo
xcode-select -s /Applications/Xcode.app/Contents/Developer

# Check environment variables
echo $DEVELOPER_DIR
```

## Security Considerations

### Secrets and Certificates
The build workflow requires these secrets for code signing:
- `APP_STORE_CONNECT_PRIVATE_KEY`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `DISTRIBUTION_CERTIFICATE_BASE64`
- `DISTRIBUTION_CERTIFICATE_PASSWORD`
- `KEYCHAIN_PASSWORD`

### Runner Security
- Keep the runner updated with latest security patches
- Limit repository access to only required repositories
- Monitor runner logs for suspicious activity
- Use dedicated user account for runner service

## Performance Optimization

### Build Cache
Consider setting up build cache directories:
```bash
# Xcode derived data
export XCODE_DERIVED_DATA_PATH="$HOME/Library/Developer/Xcode/DerivedData"

# Swift package cache
export SWIFT_PACKAGE_CACHE="$HOME/.swiftpm"
```

### Simulator Management
Regularly clean up old simulators to save disk space:
```bash
xcrun simctl delete unavailable
xcrun simctl erase all
```
