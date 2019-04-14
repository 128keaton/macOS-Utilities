//
//  KBTextFieldDialog.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/14/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

class KBTextFieldDialog: NSViewController{
    @IBOutlet weak var doneButton: NSButton!
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var textField: NSTextField!
    
    private var completionHandler: ((String) -> Void)? = nil
    
    public var fromViewController: NSViewController? = nil
    
    private static let aNibName = "KBTextFieldDialog"
    
    private var doneButtonText = "Done"
    private var textFieldPlaceholder = "Text"
    private var dialogTitle = "Text"
    
    
    override func viewDidLoad() {
        self.doneButton.isEnabled = false
        self.textField.delegate = self
    }
    
    @IBAction func cancelButtonClicked(_ sender: NSButton) {
        fromViewController?.dismiss(self)
    }
    
    @IBAction func doneButtonClicked(_ sender: NSButton) {
        if let completionHandler = self.completionHandler{
            completionHandler(textField.stringValue)
            fromViewController?.dismiss(self)
        }
    }
    
    override func viewWillAppear() {
        view.window!.styleMask.remove(.resizable)
        view.window!.styleMask.remove(.closable)
        view.window!.styleMask.remove(.miniaturizable)
        
        self.doneButton.title = self.doneButtonText
        self.textField.placeholderString = self.textFieldPlaceholder
        self.titleLabel.stringValue = self.dialogTitle
        
        super.viewWillAppear()
    }
    
    static func show(_ from: NSViewController, doneButtonText: String = "Done", textFieldPlaceholder: String = "Text", dialogTitle: String = "Text", completionHandler handler: ((String) -> Void)? = nil) {
        let instance = KBTextFieldDialog.init(nibName: aNibName, bundle: nil)
        instance.doneButtonText = doneButtonText
        instance.textFieldPlaceholder = textFieldPlaceholder
        instance.dialogTitle = dialogTitle
        
        from.presentAsModalWindow(instance)
        
        instance.fromViewController = from
        if let completionHandler = handler {
            instance.completionHandler = completionHandler
        }
    }
}
extension KBTextFieldDialog: NSTextFieldDelegate{
    func controlTextDidChange(_ obj: Notification) {
        if self.textField.stringValue != ""{
            self.doneButton.isEnabled = true
            return
        }
        self.doneButton.isEnabled = false
    }
}
