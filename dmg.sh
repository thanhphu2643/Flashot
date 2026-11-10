#!/bin/bash
# Builds build/Flashot-<version>.dmg with the app and an Applications shortcut.
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
dmg="build/Flashot-$version.dmg"
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT

cp -R build/Flashot.app "$staging/"
ln -s /Applications "$staging/Applications"
hdiutil create -volname Flashot -srcfolder "$staging" -format UDZO -ov "$dmg"
echo "Built $dmg"
