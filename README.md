# macOS-Utilities
A custom macOS Utilities app.

![](https://raw.githubusercontent.com/128keaton/macOS-Utilities/master/macOS%20Utilities/screenshot.png)

## Usage
Bundle this with your NBI. Use something like [outset](https://github.com/chilcote/outset) to run it on launch.

## macOS Installation
This app expects to have 'Install macOS High Sierra' mounted. Due to the laziness of the author, this is hardcoded.
If you wish to change the installer version, and kick off app, please make your own changes in your own repository. Sorry.

## Customizing
The `com.er2.applications.plist` file is full of options like:
* Applications
* Remote NFS server containing install images
* Papertrail Remote Logging
* Email address to email logs to
* [DeviceIdentifier](https://docs.reincubate.com/deviceidentifier/) API key
