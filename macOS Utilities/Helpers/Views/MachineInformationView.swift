//
//  MachineInformationView.swift
//  AVTest
//
//  Created by Keaton Burleson on 5/24/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

class MachineInformationView: NSView {
    @IBOutlet private var machineModelField: NSTextField!
    @IBOutlet private var machineMemoryField: NSTextField!
    @IBOutlet private var machineProcessorField: NSTextField!
    
    @IBOutlet private var machineBatteryHealthLabel: NSTextField!
    @IBOutlet private var machineBatteryHealthField: NSTextField!

    @IBOutlet private var printButton: NSButton!
    @IBOutlet private var contentBox: NSBox!

    public var delegate: MachineInformationViewDelegate? = nil

    private (set) public var machineModel: String = ""
    private (set) public var machineMemory: String = ""
    private (set) public var machineProcesser: String = ""

    private (set) public var fieldsPopulated: Bool = false {
        didSet {
            if self.fieldsPopulated {
                self.layoutFields()
            }
        }
    }

    convenience init(frame frameRect: NSRect, hidden: Bool, hardwareItem: HardwareItem) {
        self.init(frame: frameRect, hidden: hidden)
        
        populateFields(withHardwareItem: hardwareItem)
    }

    init(frame frameRect: NSRect, hidden: Bool) {
        super.init(frame: frameRect)

        if hidden {
            self.alphaValue = 0.0
        }

        loadInterface()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        loadInterface()
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)

        loadInterface()
    }

    public func showBatteryHealth(batteryStatus: String){
        machineBatteryHealthField.alphaValue = 1.0
        machineBatteryHealthLabel.alphaValue = 1.0
        
        machineBatteryHealthField.stringValue = batteryStatus
    }
    
    private func populateFields(withHardwareItem hardwareItem: HardwareItem) {
        machineModelField.stringValue = hardwareItem.machineModel ?? "Unknown"
        machineMemoryField.stringValue = hardwareItem.physicalMemory ?? "Unknown"
        machineProcessorField.stringValue = hardwareItem.cpuType ?? "Unknown"
        
        fieldsPopulated = true
    }

    private func layoutFields() {
        machineModelField.sizeToFitText()
        machineProcessorField.sizeToFitText()
        machineMemoryField.sizeToFitText()
        
        machineModelField.delegate = self
        machineProcessorField.delegate = self
        machineMemoryField.delegate = self
        
        machineModel = machineModelField.stringValue
        machineProcesser = machineProcessorField.stringValue
        machineMemory = machineMemoryField.stringValue
    }

    private func loadInterface() {
        Bundle.main.loadNibNamed("MachineInformationView", owner: self, topLevelObjects: nil)
        addSubview(contentBox)
        contentBox.frame = self.bounds
        contentBox.autoresizingMask = [.height, .width]
        
        machineBatteryHealthField.alphaValue = 0.0
        machineBatteryHealthLabel.alphaValue = 0.0
    }

    @IBAction func printButtonClicked(_ sender: NSButton) {
        self.delegate?.printButtonClicked()
    }
}

extension MachineInformationView: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            if textField == machineMemoryField {
                self.machineMemory = textField.stringValue
            } else if textField == machineModelField {
                self.machineModel = textField.stringValue
            } else if textField == machineProcessorField {
                self.machineProcesser = textField.stringValue
            }
        }
    }
}
protocol MachineInformationViewDelegate {
    func printButtonClicked()
}
