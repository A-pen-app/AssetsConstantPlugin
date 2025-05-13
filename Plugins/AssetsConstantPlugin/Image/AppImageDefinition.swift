//
//  AppImageDefinition.swift
//  AssetsConstantPlugin
//
//  Created by 李品毅 on 2025/5/14.
//

// Define the AppImage struct in the generated code, so it's available to users

let appImageDefinition = """
import Foundation
import SwiftUI

#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
public typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
public typealias PlatformImage = NSImage
#endif

/// A type-safe wrapper for images in asset catalogs.
public struct AppImage: Hashable, RawRepresentable, Equatable {
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public let rawValue: String

    public var image: Image {
        return Image(appImage: self)
    }

    public var platformImage: PlatformImage? {
        return PlatformImage(appImage: self)
    }
}

public extension Image {
    init(appImage: AppImage) {
        #if canImport(UIKit) && !os(watchOS)
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

#if os(iOS) || os(tvOS) || os(watchOS)
public extension AppImage {
    var uiImage: UIImage {
        platformImage ?? UIImage()
    }
}

public extension UIImage {
    convenience init?(appImage: AppImage) {
        if let image = UIImage(named: appImage.rawValue, in: .main, compatibleWith: nil) {
            self.init(cgImage: image.cgImage!)
        } else if let image = UIImage(named: appImage.rawValue, in: .module, compatibleWith: nil) {
            self.init(cgImage: image.cgImage!)
        } else {
            // Try the standard initialization as a fallback
            self.init(named: appImage.rawValue)
        }
    }
}
#elseif os(macOS)
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
