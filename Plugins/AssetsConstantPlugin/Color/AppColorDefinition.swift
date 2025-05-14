//
//  AppColorDefinition.swift
//  AssetsConstantPlugin
//
//  Created by 李品毅 on 2025/5/14.
//

// Define the AppColor struct in the generated code, so it's available to users

let appColorDefinition = """
import SwiftUI

/// A type-safe wrapper for colors in asset catalogs.
public struct AppColor: Hashable, RawRepresentable, Equatable {
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public let rawValue: String

    public var color: Color {
        return Color(appColor: self)
    }
    
    #if canImport(UIKit)
    public var uiColor: UIColor {
        return UIColor(appColor: self) ?? .clear
    }
    #endif
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public var nsColor: NSColor {
        return NSColor(appColor: self) ?? .clear
    }
    #endif
}

public extension Color {
    init(appColor: AppColor) {
        #if canImport(UIKit)
        if let _ = UIColor(named: appColor.rawValue, in: .main, compatibleWith: nil) {
            self.init(appColor.rawValue)
        } else {
            self.init(appColor.rawValue, bundle: .module)
        }
        #elseif canImport(AppKit)
        if NSColor(named: appColor.rawValue) != nil {
            self.init(appColor.rawValue)
        } else {
            self.init(appColor.rawValue, bundle: .module)
        }
        #else
        self.init(appColor.rawValue)
        #endif
    }
}

#if canImport(UIKit)
public extension UIColor {
    convenience init?(appColor: AppColor) {
        if let color = UIColor(named: appColor.rawValue, in: .main, compatibleWith: nil) {
            self.init(cgColor: color.cgColor)
        } else if let color = UIColor(named: appColor.rawValue, in: .module, compatibleWith: nil) {
            self.init(cgColor: color.cgColor)
        } else {
            // Try the standard initialization as a fallback
            self.init(named: appColor.rawValue)
        }
    }
}
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
public extension NSColor {
    convenience init?(appColor: AppColor) {
        if let color = NSColor(named: appColor.rawValue) {
            self.init(cgColor: color.cgColor)!
        } else if let bundle = Bundle.module.url(forResource: appColor.rawValue, withExtension: ""),
                  let color = NSColor(contentsOf: bundle) {
            self.init(cgColor: color.cgColor)!
        } else {
            // Try the standard initialization as a fallback
            self.init(named: appColor.rawValue) 
        }
    }
}
#endif
""" 
