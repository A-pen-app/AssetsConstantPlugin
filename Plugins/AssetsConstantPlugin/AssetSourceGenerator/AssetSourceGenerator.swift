//
//  AssetSourceGenerator.swift
//  AssetsConstantPlugin
//
//  Created by 李品毅 on 2025/5/15.
//

import Foundation
import PackagePlugin

/// Generator for asset source code
///
/// This struct provides functionality for generating Swift code from asset catalogs.
/// It implements methods for discovering and processing asset files,
/// and generating Swift code with proper namespacing or flat structure.
struct AssetSourceGenerator {
    // MARK: - Properties
    
    /// Configuration for code generation
    let configuration: PluginConfiguration
    
    /// Asset catalogs to process
    let assetCatalogs: [Path]

    /// Configuration properties
    let assetDefinition: String
    let assetClassName: String
    let assetExtension: String
    let assetTypeName: String
    
    // MARK: - Initialization

    init(configuration: PluginConfiguration,
         assetCatalogs: [Path],
         assetDefinition: String,
         assetClassName: String,
         assetExtension: String,
         assetTypeName: String) {
        self.configuration = configuration
        self.assetCatalogs = assetCatalogs
        self.assetDefinition = assetDefinition
        self.assetClassName = assetClassName
        self.assetExtension = assetExtension
        self.assetTypeName = assetTypeName
    }

    // MARK: - Public Methods

    /// Generate Swift code for the discovered assets
    func generateSwiftCode() -> String {
        let allAssetItems = scanAssetCatalogs().sorted { $0.name < $1.name }

        // Generate the code based on configured style (namespaced or flat)
        let generatedExtension = configuration.useNamespacing 
            ? generateNamespacedCode(from: allAssetItems)
            : generateFlatCode(from: allAssetItems)

        // Return the complete file with proper imports
        return assetDefinition + "\n" + generatedExtension
    }

    // MARK: - Helper Methods

    /// Convert a string to a valid Swift identifier
    func getSwiftIdentifier(for input: String) -> String {
        let components = input
            .replacingOccurrences(of: "-", with: "_")
            .components(separatedBy: "_")

        guard let first = components.first else { return input }

        return ([first] + components.dropFirst().map { $0.capitalized }).joined()
    }

    // MARK: - Asset Scanning

    /// Scan all asset catalogs for assets
    private func scanAssetCatalogs() -> [AssetItem] {
        var allAssetItems = [AssetItem]()

        for catalog in assetCatalogs {
            let assetItems = scanAssetCatalog(path: catalog)
            allAssetItems.append(contentsOf: assetItems)
        }

        return allAssetItems
    }

    /// Scan a single asset catalog for assets
    private func scanAssetCatalog(path: Path) -> [AssetItem] {
        var results = [AssetItem]()
        scanFolderRecursively(path: path, folderPath: nil, results: &results)
        return results
    }

    /// Recursively scan a folder for assets
    private func scanFolderRecursively(path: Path, folderPath: String?, results: inout [AssetItem]) {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path.string) else {
            print("⚠️ Could not read contents of \(path)")
            return
        }

        // Determine current folder name
        let currentFolder = determineFolderName(path: path, folderPath: folderPath)

        // Scan for asset sets in the current folder
        for item in contents {
            if item.hasSuffix(assetExtension) {
                // Found an asset
                addAssetToResults(assetName: item, path: path, folderName: currentFolder, results: &results)
            } else {
                // Might be a directory to explore
                exploreSubdirectoryIfNeeded(path: path, item: item, currentFolder: currentFolder, results: &results)
            }
        }
    }
    
    /// Determine the folder name based on path and context
    private func determineFolderName(path: Path, folderPath: String?) -> String? {
        guard folderPath == nil, configuration.includeFolderPaths || configuration.useNamespacing else {
            return folderPath
        }
        
        let pathComponents = path.string.split(separator: "/")
        guard let lastComponent = pathComponents.last, lastComponent.hasSuffix(".xcassets") else {
            return folderPath
        }
        
        return String(lastComponent.replacingOccurrences(of: ".xcassets", with: ""))
    }
    
    /// Add a discovered asset to the results
    private func addAssetToResults(assetName: String, path: Path, folderName: String?, results: inout [AssetItem]) {
        let assetName = assetName.replacingOccurrences(of: assetExtension, with: "")
        
        let assetItem = AssetItem(
            name: assetName,
            folder: folderName,
            fullPath: path.appending(assetName).string
        )
        results.append(assetItem)
    }
    
    /// Explore subdirectories if needed
    private func exploreSubdirectoryIfNeeded(path: Path, item: String, currentFolder: String?, results: inout [AssetItem]) {
        let fullPath = path.appending(item)
        var isDirectory: ObjCBool = false
        
        guard FileManager.default.fileExists(atPath: fullPath.string, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return
        }
        
        let subfolderPath = determineSubfolderPath(currentFolder: currentFolder, item: item)
        scanFolderRecursively(path: fullPath, folderPath: subfolderPath, results: &results)
    }
    
    /// Determine the subfolder path
    private func determineSubfolderPath(currentFolder: String?, item: String) -> String? {
        guard configuration.includeFolderPaths || configuration.useNamespacing else {
            return currentFolder
        }
        
        if let current = currentFolder {
            return "\(current)/\(item)"
        } else {
            return item
        }
    }

    // MARK: - Code Generation

    /// Generate flat code structure (all assets at the same level)
    private func generateFlatCode(from items: [AssetItem]) -> String {
        var uniqueAssetNames = Set<String>()
        var codeLines: [String] = []

        // Process all assets without considering folders
        for item in items {
            let assetName = item.name
            let swiftIdentifier = getSwiftIdentifier(for: assetName)

            // Skip if we've already processed this name
            guard !uniqueAssetNames.contains(swiftIdentifier) else {
                continue
            }

            uniqueAssetNames.insert(swiftIdentifier)
            
            // Apply custom name mapping if exists
            let swiftName = configuration.nameMapping[assetName] ?? swiftIdentifier

            // Use the raw name for the string value
            let rawName = buildRawName(for: item)
            
            codeLines.append("    static let \(swiftName) = \(assetClassName)(rawValue: \"\(rawName)\")")
        }

        // Return appropriate result based on whether assets were found
        return buildFinalCode(from: codeLines)
    }

    /// Generate namespaced code structure (assets grouped by folder)
    private func generateNamespacedCode(from items: [AssetItem]) -> String {
        // Group items by folder
        let itemsByFolder = groupItemsByFolder(items)
        let sortedFolders = itemsByFolder.keys.sorted { ($0 ?? "") < ($1 ?? "") }
        var codeBlocks: [String] = []

        // Add root-level assets
        if let rootItems = itemsByFolder[""] {
            let rootLines = generateRootLevelAssets(from: rootItems)
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

        return buildFinalCode(from: codeBlocks, separator: "\n\n")
    }
    
    /// Build the raw name for an asset
    private func buildRawName(for item: AssetItem) -> String {
        if configuration.includeFolderPaths && item.folder != nil {
            return "\(item.folder!)/\(item.name)"
        }
        return item.name
    }
    
    /// Build final code with appropriate wrapping
    private func buildFinalCode(from lines: [String], separator: String = "\n") -> String {
        // Handle empty results
        if lines.isEmpty {
            return "// No \(assetTypeName) assets found in the asset catalog"
        }
        
        // Build the final extension block
        return """
        // Auto-generated from Assets.xcassets - DO NOT EDIT
        
        \(configuration.accessLevel.modifier)extension \(assetClassName) {
        \(lines.joined(separator: separator))
        }
        """
    }
    
    /// Group assets by their folders
    private func groupItemsByFolder(_ items: [AssetItem]) -> [String?: [AssetItem]] {
        var itemsByFolder: [String?: [AssetItem]] = [:]
        
        for item in items {
            let folderKey = item.folder ?? ""
            if itemsByFolder[folderKey] == nil {
                itemsByFolder[folderKey] = []
            }
            itemsByFolder[folderKey]?.append(item)
        }
        
        return itemsByFolder
    }
    
    /// Generate root level assets
    private func generateRootLevelAssets(from items: [AssetItem]) -> [String] {
        var rootLines: [String] = []
        var uniqueNames = Set<String>()

        for item in items {
            let swiftIdentifier = getSwiftIdentifier(for: item.name)

            if !uniqueNames.contains(swiftIdentifier) {
                uniqueNames.insert(swiftIdentifier)
                let swiftName = configuration.nameMapping[item.name] ?? swiftIdentifier
                rootLines.append("    static let \(swiftName) = \(assetClassName)(rawValue: \"\(item.name)\")")
            }
        }
        
        return rootLines
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
        for part in namespaceParts {
            lines.append("\(currentIndent)enum \(part) {")
            currentIndent += "    "
        }

        // Add assets
        var uniqueNames = Set<String>()
        for item in items {
            let swiftIdentifier = getSwiftIdentifier(for: item.name)

            if !uniqueNames.contains(swiftIdentifier) {
                uniqueNames.insert(swiftIdentifier)
                let swiftName = configuration.nameMapping[item.name] ?? swiftIdentifier
                let rawName = configuration.includeFolderPaths ? "\(folder)/\(item.name)" : item.name
                lines.append("\(indent)static let \(swiftName) = \(assetClassName)(rawValue: \"\(rawName)\")")
            }
        }

        // Close namespace blocks
        for _ in 0 ..< namespaceParts.count {
            currentIndent = String(currentIndent.dropLast(4))
            lines.append("\(currentIndent)}")
        }

        return lines.joined(separator: "\n")
    }
}
