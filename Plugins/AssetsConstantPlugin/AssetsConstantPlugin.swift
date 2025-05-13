//
//  AssetsConstantPlugin.swift
//  AssetsConstantPlugin
//
//  Created by 李品毅 on 2025/5/13.
//

import Foundation
import PackagePlugin

/// The plugin for generating Swift constants from asset catalogs
@main
struct AssetsConstantPlugin: BuildToolPlugin {
    // MARK: Internal

    /// Create build commands for the specified target during the build process.
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let target = target as? SourceModuleTarget else { return [] }

        // Load configuration for this plugin
        let configuration = loadConfiguration(for: target, in: context)

        // Find all .xcassets directories
        let assetCatalogs = findAssetCatalogs(in: target)

        // If no asset catalogs were found through normal methods, try direct search
        let allAssetCatalogs = assetCatalogs.isEmpty ?
            searchForAssetCatalogs(in: context, target: target) :
            assetCatalogs

        // If still no asset catalogs, don't generate anything
        guard !allAssetCatalogs.isEmpty else {
            print("⚠️ No .xcassets directories found")
            return []
        }

        // Set up output file paths
        let outputFilePath = context.pluginWorkDirectory.appending(configuration.outputFileName)

        // Generate Swift code directly in the plugin
        let generator = AppImageSourceGenerator(
            configuration: configuration,
            assetCatalogs: allAssetCatalogs
        )

        let generatedCode = generator.generateSwiftCode()

        // Write the generated code to the output file
        do {
            try generatedCode.write(toFile: outputFilePath.string, atomically: true, encoding: .utf8)
            print("✅ Successfully generated \(configuration.outputFileName)")
        } catch {
            print("❌ Error generating \(configuration.outputFileName): \(error)")
        }

        // Collect all input files from asset catalogs
        var allInputFiles: [Path] = []
        for catalog in allAssetCatalogs {
            // Add the catalog itself
            allInputFiles.append(catalog)

            // Add all files within the catalog recursively
            collectAllFilesRecursively(in: catalog, result: &allInputFiles)
        }

        // If force regeneration is enabled, add a timestamp file as input
        if configuration.forceRegeneration {
            let timestampPath = context.pluginWorkDirectory.appending(".timestamp")
            let timestamp = "Last generated: \(Date())"
            try? timestamp.write(toFile: timestampPath.string, atomically: true, encoding: .utf8)
            allInputFiles.append(timestampPath)
            print("🔄 Force regeneration enabled - added timestamp file")
        }

        print("🔍 Tracking \(allInputFiles.count) input files for change detection")

        // Create a command to run a simple echo command so SPM knows we've processed this target
        return [
            .buildCommand(
                displayName: "Generate \(configuration.outputFileName)",
                executable: .init("/bin/echo"),
                arguments: ["Generated \(configuration.outputFileName)"],
                inputFiles: allInputFiles,
                outputFiles: [outputFilePath]
            )
        ]
    }

    // MARK: Private

    /// Collect all files recursively in a directory
    private func collectAllFilesRecursively(in directory: Path, result: inout [Path]) {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directory.string) else {
            return
        }

        for item in contents {
            let itemPath = directory.appending(item)
            var isDirectory: ObjCBool = false

            if FileManager.default.fileExists(atPath: itemPath.string, isDirectory: &isDirectory) {
                // Add file to input files
                result.append(itemPath)

                // Recursively check subdirectories
                if isDirectory.boolValue {
                    collectAllFilesRecursively(in: itemPath, result: &result)
                }
            }
        }
    }

    // MARK: - Configuration

    /// Load configuration for the plugin
    private func loadConfiguration(for _: SourceModuleTarget, in context: PluginContext) -> PluginConfiguration {
        // Check for configuration file
        let configFilePath = context.package.directory.appending("generate-appimage.json")

        if FileManager.default.fileExists(atPath: configFilePath.string),
           let configData = try? Data(contentsOf: URL(fileURLWithPath: configFilePath.string)),
           let decodedConfig = try? JSONDecoder().decode(PluginConfiguration.self, from: configData) {
            print("📝 Loaded custom configuration")
            return decodedConfig
        }

        // Return default configuration
        return PluginConfiguration()
    }

    // MARK: - Asset Catalog Finding

    /// Find all asset catalogs in the target
    private func findAssetCatalogs(in target: SourceModuleTarget) -> [Path] {
        var assetCatalogs: [Path] = []

        // Get unique directories from source files
        let directories = Set(target.sourceFiles.map { $0.path.removingLastComponent() })
        for directory in directories {
            // Search for .xcassets directories
            searchForAssetCatalogs(in: directory, results: &assetCatalogs)
        }

        return assetCatalogs
    }

    /// Search for asset catalogs in the specified directory and its subdirectories
    private func searchForAssetCatalogs(in directory: Path, results: inout [Path]) {
        // Check if this is an .xcassets directory
        if directory.string.hasSuffix(".xcassets") {
            results.append(directory)
            print("✅ Found asset catalog: \(directory.string)")
            return
        }

        // Check subdirectories
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: directory.string) {
            for item in contents where !item.hasPrefix(".") {
                let fullPath = directory.appending(item)

                // Check if this is a directory
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: fullPath.string, isDirectory: &isDirectory), isDirectory.boolValue {
                    searchForAssetCatalogs(in: fullPath, results: &results)
                }
            }
        }
    }

    /// Search for asset catalogs in known locations
    private func searchForAssetCatalogs(in context: PluginContext, target: SourceModuleTarget) -> [Path] {
        var assetCatalogs: [Path] = []

        // Common paths for asset catalogs
        let commonPaths = [
            context.package.directory.appending("Sources/\(target.name)/Resources/Assets.xcassets"),
            context.package.directory.appending("Sources/\(target.name)/Assets.xcassets"),
            context.package.directory.appending("Sources/\(target.name)/Resources"),
            context.package.directory.appending("Sources/Resources/Assets.xcassets"),
            context.package.directory.appending("Resources/Assets.xcassets")
        ]

        for path in commonPaths {
            if path.string.hasSuffix(".xcassets") {
                if FileManager.default.fileExists(atPath: path.string) {
                    assetCatalogs.append(path)
                    print("✅ Found asset catalog in common location: \(path.string)")
                }
            } else {
                // This is a directory, check for .xcassets folders inside
                searchForAssetCatalogs(in: path, results: &assetCatalogs)
            }
        }

        return assetCatalogs
    }
}

// MARK: - Xcode Plugin Support

#if canImport(XcodeProjectPlugin)
    import XcodeProjectPlugin

    extension AssetsConstantPlugin: XcodeBuildToolPlugin {
        func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
            // Load configuration for this plugin
            let configuration = loadConfiguration(for: context)

            // Find all .xcassets directories
            let assetCatalogs = findAssetCatalogs(in: context, target: target)

            // If no asset catalogs found, don't generate anything
            guard !assetCatalogs.isEmpty else {
                print("⚠️ No .xcassets directories found in Xcode target")
                return []
            }

            // Set up output file paths
            let outputFilePath = context.pluginWorkDirectory.appending(configuration.outputFileName)

            // Generate Swift code directly in the plugin
            let generator = AppImageSourceGenerator(
                configuration: configuration,
                assetCatalogs: assetCatalogs
            )

            let generatedCode = generator.generateSwiftCode()

            // Write the generated code to the output file
            do {
                try generatedCode.write(toFile: outputFilePath.string, atomically: true, encoding: .utf8)
                print("✅ Successfully generated \(configuration.outputFileName)")
            } catch {
                print("❌ Error generating \(configuration.outputFileName): \(error)")
            }

            // Collect all input files from asset catalogs
            var allInputFiles: [Path] = []
            for catalog in assetCatalogs {
                // Add the catalog itself
                allInputFiles.append(catalog)

                // Add all files within the catalog recursively
                collectAllFilesRecursively(in: catalog, result: &allInputFiles)
            }

            // If force regeneration is enabled, add a timestamp file as input
            if configuration.forceRegeneration {
                let timestampPath = context.pluginWorkDirectory.appending(".timestamp")
                let timestamp = "Last generated: \(Date())"
                try? timestamp.write(toFile: timestampPath.string, atomically: true, encoding: .utf8)
                allInputFiles.append(timestampPath)
                print("🔄 Force regeneration enabled - added timestamp file (Xcode)")
            }

            print("🔍 Tracking \(allInputFiles.count) input files for change detection (Xcode)")

            // Create a command to run a simple echo command so Xcode knows we've processed this target
            return [
                .buildCommand(
                    displayName: "Generate \(configuration.outputFileName)",
                    executable: .init("/bin/echo"),
                    arguments: ["Generated \(configuration.outputFileName)"],
                    inputFiles: allInputFiles,
                    outputFiles: [outputFilePath]
                )
            ]
        }

        /// Load configuration for the plugin in Xcode context
        private func loadConfiguration(for context: XcodePluginContext) -> PluginConfiguration {
            // Check for configuration file
            let configFilePath = context.xcodeProject.directory.appending("generate-appimage.json")

            if FileManager.default.fileExists(atPath: configFilePath.string),
               let configData = try? Data(contentsOf: URL(fileURLWithPath: configFilePath.string)),
               let decodedConfig = try? JSONDecoder().decode(PluginConfiguration.self, from: configData) {
                print("📝 Loaded custom configuration")
                return decodedConfig
            }

            // Return default configuration
            return PluginConfiguration()
        }

        /// Find all asset catalogs in the Xcode target
        private func findAssetCatalogs(in _: XcodePluginContext, target: XcodeTarget) -> [Path] {
            var assetCatalogs: [Path] = []

            // First approach: Look directly for .xcassets folders in input files
            for file in target.inputFiles {
                let path = file.path
                if path.string.hasSuffix(".xcassets"), !assetCatalogs.contains(path) {
                    assetCatalogs.append(path)
                    print("✅ Found asset catalog in Xcode target: \(path.string)")
                } else if path.string.contains("Assets.xcassets/"), path.string.hasSuffix("Contents.json") {
                    // This is a file inside an asset catalog, extract the asset catalog path
                    let components = path.string.split(separator: "/")
                    var assetCatalogPath = ""

                    for component in components {
                        assetCatalogPath += "/\(component)"
                        if component == "Assets.xcassets" {
                            break
                        }
                    }

                    let assetCatalog = Path(assetCatalogPath)
                    if !assetCatalogs.contains(assetCatalog), FileManager.default.fileExists(atPath: assetCatalogPath) {
                        assetCatalogs.append(assetCatalog)
                        print("✅ Found asset catalog in Xcode target: \(assetCatalogPath)")
                    }
                }
            }

            return assetCatalogs
        }
    }
#endif

// MARK: - Configuration

/// Configuration for the plugin
struct PluginConfiguration: Codable {
    /// Access levels for Swift code
    enum AccessLevel: String, Codable {
        case `public` = "public"
        case `internal` = "internal"
        case `fileprivate` = "fileprivate"
        case `private` = "private"

        // MARK: Internal

        var modifier: String {
            return self == .internal ? "" : "\(rawValue) "
        }
    }

    /// The prefix to add to the generated enum name
    var enumPrefix: String = ""

    /// The name of the output file
    var outputFileName: String = "AppImage+Generated.swift"

    /// Whether to include folder paths in asset names
    var includeFolderPaths: Bool = false

    /// Whether to use namespacing for assets in different folders
    var useNamespacing: Bool = false

    /// Custom name mappings for asset names
    var nameMapping: [String: String] = [:]

    /// Access control level for generated code
    var accessLevel: AccessLevel = .public

    /// Whether to force regeneration on every build
    var forceRegeneration: Bool = false

    /// Whether to add a timestamp to the generated code
    var addTimestamp: Bool = true
}

// MARK: - Source Generator

/// Generator for AppImage source code
struct AppImageSourceGenerator {
    // MARK: Internal

    let configuration: PluginConfiguration
    let assetCatalogs: [Path]

    /// Generate Swift code for the discovered assets
    func generateSwiftCode() -> String {
        var allImageItems = scanAssetCatalogs()

        print("🔍 Found \(allImageItems.count) total images across all catalogs")

        // Sort and deduplicate assets
        allImageItems.sort { $0.name < $1.name }

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

        // Group assets by namespace if using namespacing
        let generatedExtension: String

        if configuration.useNamespacing {
            generatedExtension = generateNamespacedCode(from: allImageItems)
        } else {
            generatedExtension = generateFlatCode(from: allImageItems)
        }

        // Create the complete file with proper imports
        return appImageDefinition + "\n" + generatedExtension
    }

    // MARK: Private

    /// Scan all asset catalogs for images
    private func scanAssetCatalogs() -> [AssetItem] {
        var allImageItems = [AssetItem]()

        for catalog in assetCatalogs {
            print("📁 Scanning asset catalog: \(catalog)")
            let imageItems = scanAssetCatalog(path: catalog)
            print("   Found \(imageItems.count) images")

            for item in imageItems {
                print("   - \(item.name) \(item.folder != nil ? "in folder '\(item.folder!)'" : "")")
            }

            allImageItems.append(contentsOf: imageItems)
        }

        return allImageItems
    }

    /// Scan a single asset catalog for images
    private func scanAssetCatalog(path: Path) -> [AssetItem] {
        var results = [AssetItem]()
        scanFolderRecursively(path: path, folderPath: nil, results: &results)
        return results
    }

    /// Recursively scan a folder for image assets
    private func scanFolderRecursively(path: Path, folderPath: String?, results: inout [AssetItem]) {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path.string) else {
            print("⚠️ Could not read contents of \(path)")
            return
        }

        // Determine current folder name
        var currentFolder = folderPath
        if currentFolder == nil, configuration.includeFolderPaths || configuration.useNamespacing {
            let pathComponents = path.string.split(separator: "/")
            if let lastComponent = pathComponents.last, lastComponent.hasSuffix(".xcassets") {
                currentFolder = String(lastComponent.replacingOccurrences(of: ".xcassets", with: ""))
            }
        }

        // Scan for image sets in the current folder
        for item in contents {
            if item.hasSuffix(".imageset") {
                // Found an imageset directory
                let imageName = item.replacingOccurrences(of: ".imageset", with: "")
                print("   Found image: \(imageName)")

                let assetItem = AssetItem(
                    name: imageName,
                    folder: currentFolder,
                    fullPath: path.appending(item).string
                )
                results.append(assetItem)
            } else {
                // Check if it's a directory
                let fullPath = path.appending(item)
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: fullPath.string, isDirectory: &isDirectory), isDirectory.boolValue {
                    // Get subfolder name
                    var subfolderPath = currentFolder
                    if configuration.includeFolderPaths || configuration.useNamespacing {
                        if let current = currentFolder {
                            subfolderPath = "\(current)/\(item)"
                        } else {
                            subfolderPath = item
                        }
                    }

                    // Recursively scan subfolders
                    scanFolderRecursively(path: fullPath, folderPath: subfolderPath, results: &results)
                }
            }
        }
    }

    /// Generate flat code structure (all assets at the same level)
    private func generateFlatCode(from items: [AssetItem]) -> String {
        var uniqueImageNames = Set<String>()
        var codeLines: [String] = []

        print("📝 Generating flat code structure for \(items.count) images")

        // Process all images without considering folders
        for item in items {
            let imageName = item.name
            let assetName = getSwiftIdentifier(for: imageName)

            print("   Processing image: \(imageName) -> \(assetName)")

            // If we've already processed this name, skip it
            if uniqueImageNames.contains(assetName) {
                print("   - Skipping duplicate: \(assetName)")
                continue
            }

            uniqueImageNames.insert(assetName)

            // Apply custom name mapping if exists
            let swiftName = configuration.nameMapping[imageName] ?? assetName

            // Use the raw name for the string value
            let rawName = configuration.includeFolderPaths && item.folder != nil
                ? "\(item.folder!)/\(imageName)"
                : imageName

            codeLines.append("    static let \(swiftName) = AppImage(rawValue: \"\(rawName)\")")
        }

        // Only add the extension if we found at least one image
        if codeLines.isEmpty {
            print("⚠️ No code lines generated from \(items.count) images")
            return "// No image assets found in the asset catalog"
        }

        print("✅ Generated \(codeLines.count) image constants")

        // Add timestamp if configured
        let timestampComment = configuration.addTimestamp
            ? "\n// Generated on: \(Date())\n"
            : ""

        return """
        // Auto-generated from Assets.xcassets - DO NOT EDIT\(timestampComment)

        \(configuration.accessLevel.modifier)extension AppImage {
        \(codeLines.joined(separator: "\n"))
        }
        """
    }

    /// Generate namespaced code structure (assets grouped by folder)
    private func generateNamespacedCode(from items: [AssetItem]) -> String {
        // Group items by folder
        var itemsByFolder: [String?: [AssetItem]] = [:]

        for item in items {
            let folderKey = item.folder ?? ""
            if itemsByFolder[folderKey] == nil {
                itemsByFolder[folderKey] = []
            }
            itemsByFolder[folderKey]?.append(item)
        }

        // Sort folders for consistent output
        let sortedFolders = itemsByFolder.keys.sorted { ($0 ?? "") < ($1 ?? "") }

        var codeBlocks: [String] = []

        // Add root-level assets
        if let rootItems = itemsByFolder[""] {
            var rootLines: [String] = []
            var uniqueNames = Set<String>()

            for item in rootItems {
                let assetName = getSwiftIdentifier(for: item.name)

                if !uniqueNames.contains(assetName) {
                    uniqueNames.insert(assetName)
                    let swiftName = configuration.nameMapping[item.name] ?? assetName
                    rootLines.append("    static let \(swiftName) = AppImage(rawValue: \"\(item.name)\")")
                }
            }

            if !rootLines.isEmpty {
                codeBlocks.append(rootLines.joined(separator: "\n"))
            }
        }

        // Add namespaced assets
        for folder in sortedFolders where folder != "" && folder != nil {
            guard let folderItems = itemsByFolder[folder] else { continue }

            let namespaceLines = generateNamespaceBlock(for: folder!, items: folderItems)
            if !namespaceLines.isEmpty {
                codeBlocks.append(namespaceLines)
            }
        }

        // If no assets were found, return a comment
        if codeBlocks.isEmpty {
            return "// No image assets found in the asset catalog"
        }

        // Add timestamp if configured
        let timestampComment = configuration.addTimestamp
            ? "\n// Generated on: \(Date())\n"
            : ""

        return """
        // Auto-generated from Assets.xcassets - DO NOT EDIT\(timestampComment)

        \(configuration.accessLevel.modifier)extension AppImage {
        \(codeBlocks.joined(separator: "\n\n"))
        }
        """
    }

    /// Generate a namespace block for the given folder
    private func generateNamespaceBlock(for folder: String, items: [AssetItem]) -> String {
        let namespaceName = folder
            .split(separator: "/")
            .map { getSwiftIdentifier(for: String($0)) }
            .joined(separator: ".")

        let namespaceParts = namespaceName.split(separator: ".")
        let indent = String(repeating: "    ", count: namespaceParts.count)

        var lines: [String] = []

        // Begin namespace blocks
        var currentIndent = "    "
        for (index, part) in namespaceParts.enumerated() {
            let enumName = index == namespaceParts.count - 1 ? part : part
            lines.append("\(currentIndent)enum \(enumName) {")
            currentIndent += "    "
        }

        // Add assets
        var uniqueNames = Set<String>()
        for item in items {
            let assetName = getSwiftIdentifier(for: item.name)

            if !uniqueNames.contains(assetName) {
                uniqueNames.insert(assetName)
                let swiftName = configuration.nameMapping[item.name] ?? assetName
                let rawName = configuration.includeFolderPaths ? "\(folder)/\(item.name)" : item.name
                lines.append("\(indent)static let \(swiftName) = AppImage(rawValue: \"\(rawName)\")")
            }
        }

        // Close namespace blocks
        for _ in 0 ..< namespaceParts.count {
            currentIndent = String(currentIndent.dropLast(4))
            lines.append("\(currentIndent)}")
        }

        return lines.joined(separator: "\n")
    }

    /// Convert a string to a valid Swift identifier
    private func getSwiftIdentifier(for input: String) -> String {
        // Replace invalid characters and apply camel case conversion
        let components = input
            .replacingOccurrences(of: "-", with: "_")
            .components(separatedBy: "_")

        guard let first = components.first else { return input }

        return ([first] + components.dropFirst().map { $0.capitalized }).joined()
    }
}

/// Represents an asset item found in an asset catalog
struct AssetItem {
    /// The name of the asset (without .imageset)
    let name: String

    /// The folder path of the asset (optional)
    let folder: String?

    /// The full path to the asset
    let fullPath: String
}
