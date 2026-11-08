#!/usr/bin/env bash
# Generates the platform folders (android, ios, web, windows, macos) and
# applies 1More's settings. Run from the project root before building:
#   bash tool/prepare.sh
set -euo pipefail

flutter create --project-name one_more --org com.onemore.game \
  --platforms=android,ios,web,windows,macos . > /dev/null

# flutter create adds a sample test that doesn't apply to this app.
rm -f test/widget_test.dart

# Android: internet access for online rooms, and the app name.
M=android/app/src/main/AndroidManifest.xml
grep -q 'android.permission.INTERNET' "$M" || \
  perl -0pi -e 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$M"
perl -0pi -e 's#android:label="[^"]*"#android:label="1More"#' "$M"

# macOS: allow outgoing network connections.
for f in macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements; do
  grep -q 'network.client' "$f" || \
    perl -0pi -e 's#<dict>#<dict>\n\t<key>com.apple.security.network.client</key>\n\t<true/>#' "$f"
done

# Display names on the other platforms.
perl -0pi -e 's#(<key>CFBundleDisplayName</key>\s*<string>)[^<]*#${1}1More#' ios/Runner/Info.plist
perl -0pi -e 's#PRODUCT_NAME = .*#PRODUCT_NAME = 1More#' macos/Runner/Configs/AppInfo.xcconfig
perl -0pi -e 's#L"one_more"#L"1More"#' windows/runner/main.cpp
perl -0pi -e 's#<title>[^<]*</title>#<title>1More</title>#' web/index.html
perl -0pi -e 's#"name": "[^"]*"#"name": "1More"#; s#"short_name": "[^"]*"#"short_name": "1More"#' web/manifest.json

flutter pub get
