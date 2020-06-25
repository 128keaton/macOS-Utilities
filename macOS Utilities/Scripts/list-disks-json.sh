#!/bin/sh

#  list-disks-json.sh
#  macOS Utilities
#
#  Created by Keaton Burleson on 6/24/20.
#  Copyright © 2020 Keaton Burleson. All rights reserved.

/usr/sbin/diskutil list -plist | /usr/bin/plutil -convert json - -o -
