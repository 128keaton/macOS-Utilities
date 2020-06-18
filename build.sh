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

/bin/mkdir -p ./Output/
/bin/rm -rf ./Output/*

echo 'Building and archiving'
/usr/bin/xcodebuild archive \
                    -allowProvisioningUpdates \
                    -workspace macOS\ Utilities.xcworkspace \
                    -scheme macOS\ Utilities \
                    -configuration Release \
                    -archivePath Output/macOS\ Utilities.xcarchive >> build.log

if [ ! $? -eq 0 ]; then
  echo 'Unable to build and archive. Please check build.log for more info'
  exit 1
fi

echo 'Exporting archive'
/usr/bin/xcodebuild -exportArchive \
                    -archivePath ./Output/macOS\ Utilities.xcarchive \
                    -exportOptionsPlist exportOptions.plist \
                    -exportPath Output/ >> build.log

if [ ! $? -eq 0 ]; then
  echo 'Unable to export the archive. Please check build.log for more info'
  exit 1
fi

/bin/rm -rf Output/*.xcarchive

echo 'Done! Available at ./Output/macOS\ Utilities.app'
/bin/rm -rf build.log
