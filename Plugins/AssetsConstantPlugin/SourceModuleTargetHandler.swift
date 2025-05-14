//
//  SourceModuleTargetHandler.swift
//  AssetsConstantPlugin
//
//  Created by 李品毅 on 2025/5/13.
//

import Foundation
import PackagePlugin

/// Handler for SourceModuleTarget assets
///
/// This struct is responsible for discovering asset catalogs in Swift Package Manager
/// targets and creating build commands for code generation.
struct SourceModuleTargetHandler {
    // MARK: Lifecycle

    init(context: PluginContext, target: SourceModuleTarget) {
        self.context = context
        self.target = target
    }

    // MARK: Internal

    /// The plugin context
    let context: PluginContext

    /// The target to process
    let target: SourceModuleTarget

    /// Creates build commands for the plugin
    /// - Parameters:
    ///   - plugin: The plugin instance
    ///   - pluginWorkDirectory: Working directory for generated files
    /// - Returns: Array of commands to execute
    func createBuildCommands(plugin: AssetsConstantPlugin, pluginWorkDirectory: Path) throws -> [Command] {
        // Read configuration from file or use defaults
        let configuration = ConfigurationReader.readConfiguration(in: context.package.directory)
        let assetCatalogs = findAssetCatalogs()

        return try plugin.createBuildCommands(
            pluginWorkDirectory: pluginWorkDirectory,
            configuration: configuration,
            assetCatalogs: assetCatalogs
        )
    }

    /// Finds all asset catalogs in the target
    /// - Returns: Array of paths to asset catalogs
    func findAssetCatalogs() -> [Path] {
        // Find all asset catalogs in the target
        var assetCatalogs: [Path] = []

        // Get unique directories from source files
        let directories = Set(target.sourceFiles.map { $0.path.removingLastComponent() })
        for directory in directories {
            searchForAssetCatalogs(in: directory, results: &assetCatalogs)
        }

        // If no asset catalogs were found through normal methods, try direct search
        if assetCatalogs.isEmpty {
            return searchCommonLocations()
        }

        return assetCatalogs
    }

    // MARK: Private

    /// Search for asset catalogs in the specified directory and its subdirectories
    /// - Parameters:
    ///   - directory: Directory to search in
    ///   - results: Array to collect results
    private func searchForAssetCatalogs(in directory: Path, results: inout [Path]) {
        // Check if this is an .xcassets directory
        if directory.string.hasSuffix(".xcassets") {
            results.append(directory)
            return
        }

        // Check subdirectories
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directory.string) else {
            return
        }

        for item in contents where !item.hasPrefix(".") {
            let fullPath = directory.appending(item)

            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: fullPath.string, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            searchForAssetCatalogs(in: fullPath, results: &results)
        }
    }

    /// Search for asset catalogs in common locations
    /// - Returns: Array of paths to found asset catalogs
    private func searchCommonLocations() -> [Path] {
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
                }
            } else {
                // This is a directory, check for .xcassets folders inside
                searchForAssetCatalogs(in: path, results: &assetCatalogs)
            }
        }

        return assetCatalogs
    }
}
