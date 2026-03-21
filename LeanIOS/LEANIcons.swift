//
//  LEANIcons.swift
//  GonativeIO
//
//  Created by Anuj Sevak on 2021-04-21.
//  Copyright © 2021 GoNative.io LLC. All rights reserved.
//

import Foundation
import UIKit

@objc class LEANIcons: NSObject {    
    @objc public static let sharedIcons = LEANIcons()
    
    @objc public class func imageForIconIdentifier(_ name: String, size: CGFloat, color: UIColor) -> UIImage? {
        // Attempt SF Symbols first (available iOS 13+)
        if let sfImage = UIImage(systemName: name) {
            let config = UIImage.SymbolConfiguration(pointSize: size)
            return sfImage.withConfiguration(config).withTintColor(color, renderingMode: .alwaysOriginal)
        }
        // Fall back to named asset in the bundle
        return UIImage(named: name)?.withTintColor(color, renderingMode: .alwaysOriginal)
    }
}
