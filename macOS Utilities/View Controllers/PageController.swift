//
//  PageController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/9/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import CocoaLumberjack

class PageController: NSObject {
    public static let shared = PageController()

    private var pageController: NSPageController? = nil
    private var currentPageIndex = 0
    private var initialPageIndex = 0
    private var loadingViewController: WizardViewController? = nil
    private var finishViewController: WizardViewController? = nil
    private var viewControllersAndIdentifiers = [String: NSViewController]()

    private override init() {
        super.init()
        self.setArrangedObjects()
    }

    public func setPageController(pageController: NSPageController) {
        pageController.delegate = self

        self.pageController = pageController
        self.setArrangedObjects()
    }

    private func setArrangedObjects() {
        guard let pageController = self.pageController
            else {
                return
        }

        pageController.arrangedObjects = ["installSelectorController", "diskSelectorController", "loadingViewController", "finishViewController"]
    }

    public func isInitialPage(_ viewController: NSViewController) -> Bool {
        if let viewControllerMapped = (viewControllersAndIdentifiers.first(where: {$1 == viewController})){
            if let identifiers =  (pageController?.arrangedObjects.map { String(describing: $0)}){
                if let indexOfIdentifier = identifiers.firstIndex(of: viewControllerMapped.key){
                    return initialPageIndex == indexOfIdentifier
                }
            }
        }
        
        return false
    }

    public func showPageController(initialPage: Int = 0) {
        if(initialPage > 0) {
            initialPageIndex = initialPage
            goToPage(initialPage) {
                self.presentPageController()
            }
        } else {
            initialPageIndex = 0
            presentPageController()
        }

    }

    private func presentPageController() {
        guard let pageController = self.pageController
            else {
                return
        }

        if let mainWindow = NSApplication.shared.mainWindow {
            if let mainViewController = mainWindow.contentViewController {
                mainViewController.presentAsSheet(pageController)
            }
        }
    }

    public func goToPage(_ page: Int, completion: @escaping () -> ()) {
        guard let pageController = self.pageController
            else {
                return
        }

        if pageController.arrangedObjects.indices.contains(page) {
            currentPageIndex = page
            NSAnimationContext.runAnimationGroup({ (_) in
                pageController.animator().selectedIndex = page
            }) {
                pageController.completeTransition()
                completion()
            }
        } else {
            DDLogInfo("Cannot change")
            completion()
        }
    }


    public func goToPage(_ page: Int) {
        guard let pageController = self.pageController
            else {
                return
        }

        if pageController.arrangedObjects.indices.contains(page) {
            currentPageIndex = page
            NSAnimationContext.runAnimationGroup({ (_) in
                pageController.animator().selectedIndex = page
            }) {
                pageController.completeTransition()
            }
        } else {
            DDLogInfo("Cannot change")
        }
    }

    public func goToNextPage() {
        guard let pageController = self.pageController
            else {
                return
        }

        if pageController.arrangedObjects.indices.contains(currentPageIndex + 1) {
            currentPageIndex += 1
            self.goToPage(currentPageIndex)
        } else {
            dismissPageController()
        }
    }

    public func goToPreviousPage() {
        guard let pageController = self.pageController
            else {
                return
        }

        if pageController.arrangedObjects.indices.contains(currentPageIndex - 1) {
            currentPageIndex -= 1
            self.goToPage(currentPageIndex)
        } else {
            dismissPageController()
        }
    }

    public func dismissPageController(savePosition: Bool = false) {
        guard let pageController = self.pageController
            else {
                return
        }

        if !savePosition {
            resetPosition()
        }

        DDLogInfo("Dismissing NSPageController: \(String(describing: pageController))")
        pageController.dismiss(self)
    }

    public func resetPosition(){
        if(currentPageIndex > 0){
            goToPage(0)
        }
        currentPageIndex = 0
        initialPageIndex = 0
    }
    
    public func goToLoadingPage(loadingText: String = "Loading") {
        guard let pageController = self.pageController
            else {
                return
        }

        let objectIdentifiers = (pageController.arrangedObjects.map { ($0 as? String) }.compactMap { $0 })

        if let loadingPageIndex = objectIdentifiers.firstIndex(of: "loadingViewController") {
            if let _loadingViewController = loadingViewController {
                _loadingViewController.titleText = loadingText
            } else {
                let _loadingViewController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "loadingViewController") as? WizardViewController
                _loadingViewController?.viewMode = .loading
                _loadingViewController?.titleText = loadingText
                self.loadingViewController = _loadingViewController
            }

            goToPage(loadingPageIndex)
        } else {
            DDLogInfo("loadingViewController identifier not present in arrangedObjects \(pageController.arrangedObjects)")
        }
    }

    public func goToFinishPage(finishedText: String = "Finished", descriptionText: String = "Finished task") {
        guard let pageController = self.pageController
            else {
                return
        }

        let objectIdentifiers = (pageController.arrangedObjects.map { ($0 as? String) }.compactMap { $0 })

        if let loadingPageIndex = objectIdentifiers.firstIndex(of: "finishViewController") {
            if let _finishViewController = finishViewController {
                _finishViewController.titleText = finishedText
                _finishViewController.descriptionText = descriptionText
            } else {
                let _finishViewController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "finishViewController") as? WizardViewController
                _finishViewController?.viewMode = .finish
                _finishViewController?.titleText = finishedText
                _finishViewController?.descriptionText = descriptionText
                self.finishViewController = _finishViewController
            }

            goToPage(loadingPageIndex)
        } else {
            DDLogInfo("finishViewController identifier not present in arrangedObjects \(pageController.arrangedObjects)")
        }
    }
}
extension PageController: NSPageControllerDelegate {
    func pageController(_ pageController: NSPageController, identifierFor object: Any) -> String {
        if let identifier = object as? String {
            return identifier
        }
        DDLogError("Object \(object) not string")
        return String()
    }

    func pageController(_ pageController: NSPageController, viewControllerForIdentifier identifier: String) -> NSViewController {
        let viewController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: identifier) as! NSViewController

        if(identifier == "loadingViewController" && self.loadingViewController == nil) {
            self.loadingViewController = viewController as? WizardViewController
        } else if(identifier == "loadingViewController" && self.loadingViewController != nil) {
            return self.loadingViewController! as NSViewController
        }


        if(identifier == "finishViewController" && self.finishViewController == nil) {
            self.finishViewController = viewController as? WizardViewController
        } else if(identifier == "finishViewController" && self.finishViewController != nil) {
            return self.finishViewController! as NSViewController
        }

        viewControllersAndIdentifiers[identifier] = viewController
        
        return viewController
    }

    func pageControllerDidEndLiveTransition(_ pageController: NSPageController) {
        guard let pageController = self.pageController
            else {
                return
        }

        DDLogInfo("Page Controller changed pages to \(pageController.arrangedObjects[currentPageIndex])")
        pageController.completeTransition()
    }
}
