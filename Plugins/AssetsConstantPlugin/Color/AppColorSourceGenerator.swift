//
//  AppColorSourceGenerator.swift
//  AssetsConstantPlugin
//
//  Created by 李品毅 on 2025/5/14.
//

import Foundation
import PackagePlugin

/// Generator for AppColor source code
struct AppColorSourceGenerator {
    // MARK: Internal

    let configuration: PluginConfiguration
    let assetCatalogs: [Path]

    /// Generate Swift code for the discovered color assets
    func generateSwiftCode() -> String {
        var allColorItems = scanAssetCatalogs()

        // Sort and deduplicate assets
        allColorItems.sort { $0.name < $1.name }

        // Group assets by namespace if using namespacing
        let generatedExtension: String

        if configuration.useNamespacing {
            generatedExtension = generateNamespacedCode(from: allColorItems)
        } else {
            generatedExtension = generateFlatCode(from: allColorItems)
        }

        // Create the complete file with proper imports
        return appColorDefinition + "\n" + generatedExtension
    }

    // MARK: Private

    /// Scan all asset catalogs for colors
    private func scanAssetCatalogs() -> [AssetItem] {
        var allColorItems = [AssetItem]()

        for catalog in assetCatalogs {
            let colorItems = scanAssetCatalog(path: catalog)
            allColorItems.append(contentsOf: colorItems)
        }

        return allColorItems
    }

    /// Scan a single asset catalog for colors
    private func scanAssetCatalog(path: Path) -> [AssetItem] {
        var results = [AssetItem]()
        scanFolderRecursively(path: path, folderPath: nil, results: &results)
        return results
    }

    /// Recursively scan a folder for color assets
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

        // Scan for color sets in the current folder
        for item in contents {
            if item.hasSuffix(".colorset") {
                // Found a colorset directory
                let colorName = item.replacingOccurrences(of: ".colorset", with: "")

                let assetItem = AssetItem(
                    name: colorName,
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
        var uniqueColorNames = Set<String>()
        var codeLines: [String] = []

        // Process all colors without considering folders
        for item in items {
            let colorName = item.name
            let assetName = getSwiftIdentifier(for: colorName)

            // If we've already processed this name, skip it
            if uniqueColorNames.contains(assetName) {
                continue
            }

            uniqueColorNames.insert(assetName)

            // Apply custom name mapping if exists
            let swiftName = configuration.nameMapping[colorName] ?? assetName

            // Use the raw name for the string value
            let rawName = configuration.includeFolderPaths && item.folder != nil
                ? "\(item.folder!)/\(colorName)"
                : colorName

            codeLines.append("    static let \(swiftName) = AppColor(rawValue: \"\(rawName)\")")
        }

        // Only add the extension if we found at least one color
        if codeLines.isEmpty {
            return "// No color assets found in the asset catalog"
        }

        return """
        // Auto-generated from Assets.xcassets - DO NOT EDIT

        \(configuration.accessLevel.modifier)extension AppColor {
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
                    rootLines.append("    static let \(swiftName) = AppColor(rawValue: \"\(item.name)\")")
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
            return "// No color assets found in the asset catalog"
        }

        return """
        // Auto-generated from Assets.xcassets - DO NOT EDIT

        \(configuration.accessLevel.modifier)extension AppColor {
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
                lines.append("\(indent)static let \(swiftName) = AppColor(rawValue: \"\(rawName)\")")
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
