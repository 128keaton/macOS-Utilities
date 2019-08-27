//
//  BarcodeGenerator.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/31/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import CocoaLumberjack

class BarcodeGenerator {
    public static var scale: CGFloat = 4
    
    static func fromString(_ string: String) -> NSImage? {
        let barcodeData = string.data(using: String.Encoding.ascii)

        if let filter = CIFilter(name: "CICode128BarcodeGenerator") {
            filter.setValue(barcodeData, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: scale, y: scale)

            if let output = filter.outputImage?.transformed(by: transform) {
                let rep = NSCIImageRep(ciImage: output)
                let barcodeImage = NSImage(size: rep.size)
                barcodeImage.addRepresentation(rep)

                return barcodeImage
            } else {
                DDLogError("Could not generate barcode. A barcode image reference could not be created.")
            }
        } else {
            DDLogError("Could not generate barcode. The image filter was unable to be found.")
        }

        return nil
    }
}
