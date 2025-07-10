//
//  AppImageDefinition.swift
//  AssetsConstantPlugin
//
//  Created by 李品毅 on 2025/5/14.
//

// Define the AppImage struct in the generated code, so it's available to users

let appImageDefinition = """
import SwiftUI

/// A type-safe wrapper for images in asset catalogs.
public struct AppImage: Hashable, RawRepresentable, Equatable {
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public let rawValue: String

    public var image: Image {
        return Image(appImage: self)
    }

    #if canImport(UIKit)
    public var uiImage: UIImage {
        UIImage(appImage: self) ?? UIImage()
    }
    #endif

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public var nsImage: NSImage {
        return NSImage(appImage: self) ?? .clear
    }
    #endif
}

public extension Image {
    init(appImage: AppImage) {
        #if canImport(UIKit) 
        if let _ = UIImage(named: appImage.rawValue, in: .main, compatibleWith: nil) {
            self.init(appImage.rawValue)
        } else {
            self.init(appImage.rawValue, bundle: .module)
        }
        #elseif canImport(AppKit)
        if NSImage(named: appImage.rawValue) != nil {
            self.init(appImage.rawValue)
        } else {
            self.init(appImage.rawValue, bundle: .module)
        }
        #else
        self.init(appImage.rawValue)
        #endif
    }
}

#if canImport(UIKit)
public extension UIImage {
    static func from(appImage: AppImage) -> UIImage? {
        return UIImage(named: appImage.rawValue, in: .main, compatibleWith: nil)
            ?? UIImage(named: appImage.rawValue, in: .module, compatibleWith: nil)
            ?? UIImage(named: appImage.rawValue)
    }
}
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
public extension NSImage {
    convenience init?(appImage: AppImage) {
        if NSImage(named: appImage.rawValue) != nil {
            self.init(named: appImage.rawValue)
        } else if let url = Bundle.module.url(forResource: appImage.rawValue, withExtension: ""),
                  NSImage(contentsOf: url) != nil {
            self.init(named: appImage.rawValue)
        } else {
            // Try the standard initialization as a fallback
            self.init(named: appImage.rawValue)
        }
    }
}
#endif
"""
