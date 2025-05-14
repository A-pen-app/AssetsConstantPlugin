//
//  PluginConfiguration.swift
//  AssetsConstantPlugin
//
//  Created by 李品毅 on 2025/5/13.
//

import Foundation

/// Configuration options for the AssetsConstantPlugin
///
/// This struct defines all available configuration options for the plugin,
/// including output file names, access levels, and generation preferences.
public struct PluginConfiguration: Codable {
    // MARK: Lifecycle

    /// Creates a new plugin configuration with customizable options
    /// - Parameters:
    ///   - generateImages: Whether to generate image constants
    ///   - generateColors: Whether to generate color constants
    ///   - imageOutputFileName: The name of the output file for image constants
    ///   - colorOutputFileName: The name of the output file for color constants
    ///   - includeFolderPaths: Whether to include folder paths in asset names
    ///   - useNamespacing: Whether to use namespacing for assets in different folders
    ///   - nameMapping: Custom name mappings for asset names
    ///   - accessLevel: Access control level for generated code
    public init(generateImages: Bool = true,
                generateColors: Bool = true,
                imageOutputFileName: String = "AppImage+Generated.swift",
                colorOutputFileName: String = "AppColor+Generated.swift",
                includeFolderPaths: Bool = false,
                useNamespacing: Bool = false,
                nameMapping: [String: String] = [:],
                accessLevel: AccessLevel = .public) {
        self.generateImages = generateImages
        self.generateColors = generateColors
        self.imageOutputFileName = imageOutputFileName
        self.colorOutputFileName = colorOutputFileName
        self.includeFolderPaths = includeFolderPaths
        self.useNamespacing = useNamespacing
        self.nameMapping = nameMapping
        self.accessLevel = accessLevel
    }

    // MARK: Public

    /// Access level for generated code
    public enum AccessLevel: String, Codable {
        case `public` = "public"
        case `internal` = "internal"
        case `fileprivate` = "fileprivate"
        case `private` = "private"

        // MARK: Public

        /// Returns the Swift access modifier string
        public var modifier: String {
            return self == .internal ? "" : "\(rawValue) "
        }
    }

    // MARK: Internal

    /// Whether to generate image constants
    let generateImages: Bool

    /// Whether to generate color constants
    let generateColors: Bool

    /// The name of the output file for image constants
    let imageOutputFileName: String

    /// The name of the output file for color constants
    let colorOutputFileName: String

    /// Whether to include folder paths in asset names
    let includeFolderPaths: Bool

    /// Whether to use namespacing for assets in different folders
    let useNamespacing: Bool

    /// Custom name mappings for asset names
    let nameMapping: [String: String]

    /// Access control level for generated code
    let accessLevel: AccessLevel
}
