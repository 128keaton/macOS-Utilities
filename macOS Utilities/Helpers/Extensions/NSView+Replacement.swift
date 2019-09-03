//
// Copyright Noel Cower 2014.
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt
//

import Cocoa

extension NSView {
    /// Replaces the receiver with `view` in its superview. If
    /// `preservingConstraints` is true, any constraints referencing the
    /// receiver in its superview will be rewritten to reference `view`.
    func replaceInSuperviewWithView(view: NSView, preservingConstraints: Bool = true) {
        assert(superview != nil, "Cannot replace self without a superview")
        if preservingConstraints {
            superview!.replaceSubviewsPreservingConstraints(replacements: [self: view])
        } else {
            superview!.replaceSubview(self, with: view)
        }
    }
    
    /// Copies constraints from one view to the other
    func copyConstraintsTo(_ otherView: NSView) {
        let currentConstraints = constraints as [NSLayoutConstraint]
        var removedConstraints = [NSLayoutConstraint]()
        var newConstraints = [NSLayoutConstraint]()
        
        for current in currentConstraints {
            otherView.frame = self.frame
            
            if self === current.firstItem && otherView === current.secondItem {
                continue
            }
            
            let updated = NSLayoutConstraint(
                item: self,
                attribute: current.firstAttribute,
                relatedBy: current.relation,
                toItem: otherView,
                attribute: current.secondAttribute,
                multiplier: current.multiplier,
                constant: current.constant
            )
            
            updated.shouldBeArchived = current.shouldBeArchived
            updated.identifier = current.identifier
            updated.priority = current.priority
            
            removedConstraints.append(current)
            newConstraints.append(updated)
        }
        
        if !removedConstraints.isEmpty {
            removeConstraints(removedConstraints)
        }
        
        if !newConstraints.isEmpty {
            addConstraints(newConstraints)
        }
    }
    
    /// Replaces subviews in the receiver while preserving their constraints.
    /// Accepts a dictionary of [NSView: NSView] objects, where the key is the
    /// view to be replaced and its value the replacement.
    func replaceSubviewsPreservingConstraints(replacements: [NSView: NSView]) {
        if replacements.isEmpty {
            return
        }
        
        let currentConstraints = constraints as [NSLayoutConstraint]
        var removedConstraints = [NSLayoutConstraint]()
        var newConstraints = [NSLayoutConstraint]()
        
        for current in currentConstraints {
            var firstItem: AnyObject? = current.firstItem
            var secondItem: AnyObject? = current.secondItem
            
            if let firstView = firstItem as? NSView {
                if let replacement = replacements[firstView] {
                    firstItem = replacement
                    replacement.frame = firstView.frame
                }
            }
            
            if let secondView = secondItem as? NSView {
                if let replacement = replacements[secondView] {
                    secondItem = replacement
                    replacement.frame = secondView.frame
                }
            }
            
            if firstItem === current.firstItem && secondItem === current.secondItem {
                continue
            }
            
            let updated = NSLayoutConstraint(
                item: firstItem as Any,
                attribute: current.firstAttribute,
                relatedBy: current.relation,
                toItem: secondItem,
                attribute: current.secondAttribute,
                multiplier: current.multiplier,
                constant: current.constant
            )
            
            updated.shouldBeArchived = current.shouldBeArchived
            updated.identifier = current.identifier
            updated.priority = current.priority
            
            removedConstraints.append(current)
            newConstraints.append(updated)
        }
        
        if !removedConstraints.isEmpty {
            removeConstraints(removedConstraints)
        }
        
        for (subview, replacement) in replacements {
            replaceSubview(subview, with: replacement)
        }
        
        if !newConstraints.isEmpty {
            addConstraints(newConstraints)
        }
    }
    
    /// Wrapper for replaceSuviewsPreservingConstraints([subview: replacement])
    func replaceSubviewPreservingConstraints(subview: NSView, replacement: NSView) {
        replaceSubviewsPreservingConstraints(replacements: [subview: replacement])
    }
}
