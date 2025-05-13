//
//  PluginConfiguration.swift
//  AssetsConstantPlugin
//
//  Created by 李品毅 on 2025/5/13.
//

import Foundation

public struct PluginConfiguration: Codable {
    // MARK: Lifecycle

    public init(enumPrefix: String = "",
                outputFileName: String = "AppImage+Generated.swift",
                includeFolderPaths: Bool = false,
                useNamespacing: Bool = false,
                nameMapping: [String: String] = [:],
                accessLevel: AccessLevel = .public) {
        self.enumPrefix = enumPrefix
        self.outputFileName = outputFileName
        self.includeFolderPaths = includeFolderPaths
        self.useNamespacing = useNamespacing
        self.nameMapping = nameMapping
        self.accessLevel = accessLevel
    }

    // MARK: Public

    public enum AccessLevel: String, Codable {
        case `public` = "public"
        case `internal` = "internal"
        case `fileprivate` = "fileprivate"
        case `private` = "private"

        // MARK: Public

        public var modifier: String {
            return self == .internal ? "" : "\(rawValue) "
        }
    }

    // MARK: Internal

    /// The prefix to add to the generated enum name
    var enumPrefix: String

    /// The name of the output file
    var outputFileName: String

    /// Whether to include folder paths in asset names
    var includeFolderPaths: Bool

    /// Whether to use namespacing for assets in different folders
    var useNamespacing: Bool

    /// Custom name mappings for asset names
    var nameMapping: [String: String]

    /// Access control level for generated code
    var accessLevel: AccessLevel
}
