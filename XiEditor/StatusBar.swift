// Copyright 2018 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Cocoa

enum StatusItemAlignment: String {
    case left = "left"
    case right = "right"
}

class StatusItem: NSTextField {
    let key: String
    var value: String = ""
    let barAlignment: StatusItemAlignment
    var sideConstraints = [NSLayoutConstraint]()

    init(_ key: String, _ value: String, _ barAlignment: String) {
        self.key = key
        self.value = value
        self.barAlignment = StatusItemAlignment(rawValue: barAlignment)!
        super.init(frame: .zero)

        // Similar to what NSTextField's label convenience init creates
        self.isEditable = false
        self.isSelectable = false
        self.textColor = NSColor.labelColor
        self.backgroundColor = NSColor.clear
        self.lineBreakMode = .byClipping
        self.isBezeled = false
        self.stringValue = value
        self.preferredMaxLayoutWidth = self.frame.width
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class StatusBar: NSView {

    var currentItems = [String : StatusItem]()
    var hiddenItems: [StatusItem] {
        return currentItems.values
            .filter { $0.isHidden == true }
            .sorted { $0.key > $1.key }
    }
    var leftItems: [StatusItem] {
        return currentItems.values
            .filter { $0.barAlignment == .left && $0.isHidden == false }
            .sorted { $0.key < $1.key }
    }
    var rightItems: [StatusItem] {
        return currentItems.values
            .filter { $0.barAlignment == .right && $0.isHidden == false }
            .sorted { $0.key < $1.key }
    }

    var lastLeftItem: StatusItem?
    var lastRightItem: StatusItem?

    var backgroundColor: NSColor = NSColor.windowFrameColor
    var itemTextColor: NSColor = NSColor.windowFrameTextColor
    let statusBarPadding: CGFloat = 10
    let statusBarHeight: CGFloat = 24
    let firstItemMargin: CGFloat = 3

    // Returns the minimum width required to display all items.
    var minWidth: CGFloat {
        return currentItems.values.filter { $0.isHidden == false }
            .map({$0.frame.width})
            .reduce(CGFloat(currentItems.count - 1) * statusBarPadding, +)
    }

    // Difference (in points) to compensate for when status bar is resized
    let minWidthDifference: CGFloat = 3

    override var isFlipped: Bool {
        return true;
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: .zero)
        self.translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Adds a status bar item.
    func addStatusItem(_ item: StatusItem) {
        if let existingItem = currentItems[item.key] {
            print("tried to add existing item with key \(existingItem.key), ignoring")
            return
        }
        item.translatesAutoresizingMaskIntoConstraints = false
        item.textColor = itemTextColor
        self.addSubview(item)
        currentItems[item.key] = item
        checkItemsFitFor(windowWidth: self.superview!.frame.width)
        self.needsUpdateConstraints = true
    }

    // Update a status bar item with a new value.
    func updateStatusItem(_ key: String, _ value: String) {
        if let item = currentItems[key] {
            item.stringValue = value
            currentItems.updateValue(item, forKey: key)
        } else {
            print("tried to update item with key \(key) that doesn't exist")
        }
        checkItemsFitFor(windowWidth: self.superview!.frame.width)
    }

    // Removes status bar item with a specified key.
    func removeStatusItem(_ key: String) {
        if let item = currentItems[key] {
            item.removeFromSuperview()
            currentItems.removeValue(forKey: key)
        } else {
            print("tried to remove item with \(key) that doesn't exist")
            return
        }
        checkItemsFitFor(windowWidth: self.superview!.frame.width)
        self.needsUpdateConstraints = true
    }

    // Also handles ordering of status bar items.
    // Called when the status bar item state is modified.
    override func updateConstraints() {
        lastLeftItem = leftItems.first
        lastRightItem = rightItems.first

        for item in currentItems.values.sorted(by: {$0.key < $1.key}) {
            NSLayoutConstraint.deactivate(item.sideConstraints)
            item.sideConstraints.removeAll()
            switch item.barAlignment {
            case .left:
                if item == leftItems.first {
                    let leftConstraint = item.leadingAnchor.constraint(equalTo:
                        self.leadingAnchor, constant: firstItemMargin)
                    item.sideConstraints.append(leftConstraint)
                } else {
                    guard lastLeftItem != nil else { return }
                    let leftConstraint = item.leadingAnchor.constraint(equalTo:
                        lastLeftItem!.trailingAnchor, constant: statusBarPadding)
                    item.sideConstraints.append(leftConstraint)
                }
                lastLeftItem = item
            case .right:
                if item == rightItems.first {
                    let rightConstraint = item.trailingAnchor.constraint(equalTo:
                        self.trailingAnchor, constant: -firstItemMargin)
                    item.sideConstraints.append(rightConstraint)
                } else {
                    guard lastRightItem != nil else { return }
                    let rightConstraint = item.trailingAnchor.constraint(equalTo:
                        lastRightItem!.leadingAnchor, constant: -statusBarPadding)
                    item.sideConstraints.append(rightConstraint)
                }
                lastRightItem = item
            }
            item.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
            NSLayoutConstraint.activate(item.sideConstraints)
        }
        super.updateConstraints()
    }

    func updateStatusBarColor(newBackgroundColor: NSColor, newTextColor: NSColor) {
        self.backgroundColor = newBackgroundColor
        self.itemTextColor = newTextColor
        self.needsDisplay = true
    }

    // When items are added, expanded or removed, the status bar checks if
    // any items need to be hidden or unhidden to make use of available space.
    func checkItemsFitFor(windowWidth: CGFloat) {
        if windowWidth <= minWidth {
            hideItemsToFit(windowWidth)
        } else {
            unhideItemsToFit(windowWidth)
            self.needsUpdateConstraints = true
        }
    }

    func hideItemsToFit(_ widthToFit: CGFloat) {
        repeat {
            if leftItems.count > 1 {
                guard lastLeftItem != nil else { return }
                lastLeftItem!.isHidden = true
                lastLeftItem = leftItems.last
            } else {
                guard lastRightItem != nil else { return }
                lastRightItem!.isHidden = true
                lastRightItem = rightItems.last
            }
        } while (minWidth - widthToFit > minWidthDifference)
    }

    func unhideItemsToFit(_ widthToFit: CGFloat) {
        if let lastHiddenItem = hiddenItems.last {
            let newMinWidth = minWidth + statusBarPadding + lastHiddenItem.frame.width
            if (newMinWidth - widthToFit) < minWidthDifference {
                lastHiddenItem.isHidden = false
                switch lastHiddenItem.barAlignment {
                case .left:
                    lastLeftItem = lastHiddenItem
                case .right:
                    lastRightItem = lastHiddenItem
                }
                currentItems.updateValue(lastHiddenItem, forKey: lastHiddenItem.key)
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
//        backgroundColor.setFill()
        dirtyRect.fill()

        // test to replicate native NSWindow title gradient
        let native1 = NSColor(calibratedWhite: 246/255, alpha: 1)
        let native2 = NSColor(calibratedWhite: 202/255, alpha: 1)
        let nativeColor = NSGradient(colors: [native1, native2])

        nativeColor?.draw(in: dirtyRect, angle: 90)

        let borderColor = NSColor(calibratedRed: 194 / 255, green: 194 / 255, blue: 194 / 255, alpha: 1)
        borderColor.setStroke()

        let path = NSBezierPath()
        path.lineWidth = 1
        path.move(to: CGPoint(x: dirtyRect.minX, y: dirtyRect.minY))
        path.line(to: CGPoint(x: dirtyRect.maxX, y: dirtyRect.minY))
        path.stroke()
    }
}
