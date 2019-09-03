//
//  KBTextFieldDialog.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/14/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

class KBTextFieldDialog: NSViewController {
    @IBOutlet weak var doneButton: NSButton!
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var textField: NSTextField!
    @IBOutlet weak var additionalTextField: NSTextField!
    @IBOutlet weak var additionalTitleLabel: NSTextField!

    private var completionHandler: ((String) -> Void)? = nil
    private var additionalCompletionHandler: ((String, String) -> Void)? = nil

    public var fromViewController: NSViewController? = nil

    private static let smallNibName = "KBTextFieldDialog-small"
    private static let bigNibName = "KBTextFieldDialog-large"

    private var doneButtonText = "Done"
    private var textFieldPlaceholder = "Text"
    private var dialogTitle = "Text"
    private var additionalTextFieldPlaceholder = "Text"
    private var additionalDialogTitle = "Text"

    override func viewDidLoad() {
        self.title = ""
        
        self.doneButton.isEnabled = false
        self.textField.delegate = self
        if let additionalTextField = self.additionalTextField {
            additionalTextField.delegate = self
        }
    }

    @IBAction func cancelButtonClicked(_ sender: NSButton) {
        fromViewController?.dismiss(self)
    }

    @IBAction func doneButtonClicked(_ sender: NSButton) {
        if let completionHandler = self.completionHandler {
            completionHandler(textField.stringValue)
            fromViewController?.dismiss(self)
        } else if let completionHandler = self.additionalCompletionHandler {
            completionHandler(textField.stringValue, additionalTextField.stringValue)
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

        if self.additionalTextField != nil {
            self.additionalTextField.placeholderString = self.additionalTextFieldPlaceholder
            self.additionalTitleLabel.stringValue = self.additionalDialogTitle
        }

        super.viewWillAppear()
    }

    static func show(_ from: NSViewController, doneButtonText: String = "Done", textFieldPlaceholder: String = "Text", dialogTitle: String = "Text", completionHandler handler: ((String) -> Void)? = nil) {
        let instance = KBTextFieldDialog.init(nibName: smallNibName, bundle: nil)

        instance.doneButtonText = doneButtonText
        instance.textFieldPlaceholder = textFieldPlaceholder
        instance.dialogTitle = dialogTitle

        from.presentAsModalWindow(instance)

        instance.fromViewController = from
        if let completionHandler = handler {
            instance.completionHandler = completionHandler
        }
    }

    static func show(_ from: NSViewController, doneButtonText: String = "Done", textFieldPlaceholder: String = "Text", dialogTitle: String = "Text", additionalTextFieldPlaceholder: String = "Text", additionalDialogTitle: String = "Text", completionHandler handler: ((String, String) -> Void)? = nil) {
        let instance = KBTextFieldDialog.init(nibName: bigNibName, bundle: nil)

        instance.doneButtonText = doneButtonText
        instance.textFieldPlaceholder = textFieldPlaceholder
        instance.dialogTitle = dialogTitle
        instance.additionalDialogTitle = additionalDialogTitle
        instance.additionalTextFieldPlaceholder = additionalTextFieldPlaceholder

        from.presentAsModalWindow(instance)

        instance.fromViewController = from
        if let completionHandler = handler {
            instance.additionalCompletionHandler = completionHandler
        }
    }
}
extension KBTextFieldDialog: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        if self.additionalTextField != nil {
            if self.textField.stringValue != "" && self.additionalTextField.stringValue != "" {
                self.doneButton.isEnabled = true
                return
            }
        } else {
            if self.textField.stringValue != "" {
                self.doneButton.isEnabled = true
                return
            }
        }

        self.doneButton.isEnabled = false
    }
}
