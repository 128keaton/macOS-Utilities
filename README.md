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

## [10.13 'Kickoff'](https://github.com/128keaton/macOS-Installer-Kickoff)

Currently, the software installation is kicked off by an AppleScript app that calls a bash script to erase the drive and open the High Sierra installer application. If you do not require the drive to be erased, you can replace the path string in the application yourself. 

