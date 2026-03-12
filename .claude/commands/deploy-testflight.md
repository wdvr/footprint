# Deploy Footprint to TestFlight

## Via GitHub Actions (preferred)

```bash
# 1. Build (triggered automatically on push to main, or manually)
gh workflow run "iOS Build" --repo wdvr/footprint

# 2. Upload to App Store Connect + distribute to TestFlight
#    Specify the build run_id to use a specific build
gh workflow run "iOS TestFlight Internal" --repo wdvr/footprint -f run_id=<BUILD_RUN_ID>

# Check status
gh run list --repo wdvr/footprint --workflow "iOS Build" --limit 3
gh run list --repo wdvr/footprint --workflow "iOS TestFlight Internal" --limit 3
```

## IMPORTANT: CI Distribution Bug

The CI "Wait for processing & distribute" step frequently times out before distributing
the build to TestFlight internal testers. The build gets uploaded to App Store Connect
but is **NOT distributed to testers**, so it won't appear in the TestFlight app.

**After every TestFlight upload, you MUST manually verify and distribute:**

```bash
# Generate JWT token
TOKEN=$(python3 -c "
import jwt, time
with open('/Users/wouter/.appstoreconnect/private_keys/AuthKey_GA9T4G84AU.p8') as f:
    key = f.read()
payload = {'iss': '39f22957-9a03-421a-ada6-86471b32ee9f', 'iat': int(time.time()), 'exp': int(time.time()) + 1200, 'aud': 'appstoreconnect-v1'}
print(jwt.encode(payload, key, algorithm='ES256', headers={'kid': 'GA9T4G84AU'}))
")

# Check if build is processed
curl -s "https://api.appstoreconnect.apple.com/v1/builds?filter\[app\]=6758334183&sort=-uploadedDate&limit=5&fields\[builds\]=version,processingState,uploadedDate" \
  -H "Authorization: Bearer $TOKEN" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for b in d.get('data',[]):
    a = b['attributes']
    print(f'Build {a[\"version\"]}: {a[\"processingState\"]} uploaded={a.get(\"uploadedDate\",\"?\")} id={b[\"id\"]}')
"

# Check what's distributed to Internal Testers
curl -s "https://api.appstoreconnect.apple.com/v1/betaGroups/58466d75-1e97-4740-86d5-e71182764b62/builds?fields\[builds\]=version,processingState&limit=5" \
  -H "Authorization: Bearer $TOKEN" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for b in d.get('data',[]):
    a = b.get('attributes', {})
    print(f'Build {a.get(\"version\")}: {a.get(\"processingState\")}')
"

# If build is VALID but NOT in the Internal Testers list, distribute it:
BUILD_ID="<build-id-from-above>"
curl -s -X POST "https://api.appstoreconnect.apple.com/v1/betaGroups/58466d75-1e97-4740-86d5-e71182764b62/relationships/builds" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"data\": [{\"type\": \"builds\", \"id\": \"$BUILD_ID\"}]}"
```

## App Store Connect IDs

- **App ID**: `6758334183`
- **Internal Testers Beta Group ID**: `58466d75-1e97-4740-86d5-e71182764b62`
- **API Key**: `AuthKey_GA9T4G84AU.p8` at `/Users/wouter/.appstoreconnect/private_keys/`
- **Key ID**: `GA9T4G84AU`
- **Issuer ID**: `39f22957-9a03-421a-ada6-86471b32ee9f`

## Via xcodebuild (manual)

1. Bump build number in `ios/Footprint/Info.plist` (CFBundleVersion)
2. Regenerate project:
```bash
cd ios && xcodegen generate
```
3. Archive:
```bash
xcodebuild archive -project ios/Footprint.xcodeproj -scheme Footprint \
  -archivePath /tmp/Footprint.xcarchive -destination 'generic/platform=iOS' -quiet
```
4. Export and upload:
```bash
cat > /tmp/ExportOptions.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>teamID</key><string>N324UX8D9M</string>
    <key>destination</key><string>upload</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive -archivePath /tmp/Footprint.xcarchive \
  -exportOptionsPlist /tmp/ExportOptions.plist -exportPath /tmp/Footprint-export \
  -allowProvisioningUpdates \
  -authenticationKeyPath /Users/wouter/.appstoreconnect/private_keys/AuthKey_GA9T4G84AU.p8 \
  -authenticationKeyID GA9T4G84AU \
  -authenticationKeyIssuerID 39f22957-9a03-421a-ada6-86471b32ee9f
```
5. Clean up: `rm -rf /tmp/Footprint.xcarchive /tmp/Footprint-export /tmp/ExportOptions.plist`
6. **Distribute to Internal Testers** using the API commands above

## Notes
- Team ID: `N324UX8D9M`
- Bundle ID: `com.wouterdevriendt.footprint`
- Deployment Target: iOS 17.0
- CI build numbers are calculated from `git rev-list --count HEAD` (e.g. 302), not from Info.plist
- The correct workflow name is `"iOS TestFlight Internal"` (not `"TestFlight Internal"`)
- Self-hosted runner auth key path: `/Users/wouter/.appstoreconnect/private_keys/AuthKey_GA9T4G84AU.p8`
