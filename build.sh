#!/bin/bash

echo 'Log available at "build.log"'
echo '' > build.log

if ! [ -x "$(command -v /usr/local/bin/pod)" ]; then
  echo 'Cocoapods is not installed. Installing now'
  sudo gem install cocoapods
fi

echo 'Installing Cocoapods dependencies'
/usr/local/bin/pod install >> build.log

echo 'Putting env vars into Secrets.swift'
echo 'let BUGSNAG_KEY = "$BUGSNAG_KEY"' > ./macOS\ Utilities/Secrets.swift

echo 'Building and archiving'
/usr/bin/xcodebuild -workspace macOS\ Utilities.xcworkspace -scheme macOS\ Utilities archive >> build.log

