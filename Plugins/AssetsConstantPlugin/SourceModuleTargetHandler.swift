//
//  SourceModuleTargetHandler.swift
//  AssetsConstantPlugin
//
//  Created by 李品毅 on 2025/5/13.
//

import Foundation
import PackagePlugin

/// Handler for SourceModuleTarget assets
struct SourceModuleTargetHandler {
    // MARK: Lifecycle

    init(context: PluginContext, target: SourceModuleTarget) {
        self.context = context
        self.target = target
    }

    // MARK: Internal

    let context: PluginContext
    let target: SourceModuleTarget

    func findAssetCatalogs() -> [Path] {
        // Find all asset catalogs
        let assetCatalogs = findAssetCatalogs(in: target)

        // If no asset catalogs were found through normal methods, try direct search
        let allAssetCatalogs = assetCatalogs.isEmpty ?
            searchForAssetCatalogs(in: context, target: target) :
            assetCatalogs

        return allAssetCatalogs
    }

    func createBuildCommands(pluginWorkDirectory: Path) throws -> [Command] {
        let configuration = PluginConfiguration()
        let assetCatalogs = findAssetCatalogs()
        let plugin = AssetsConstantPlugin()

        return try plugin.createBuildCommands(
            pluginWorkDirectory: pluginWorkDirectory,
            configuration: configuration,
            assetCatalogs: assetCatalogs
        )
    }

    // MARK: Private

    /// Find all asset catalogs in the target
    private func findAssetCatalogs(in target: SourceModuleTarget) -> [Path] {
        var assetCatalogs: [Path] = []

        // Get unique directories from source files
        let directories = Set(target.sourceFiles.map { $0.path.removingLastComponent() })
        for directory in directories {
            // No asset catalogs found via sourceFiles. Searching common locations...
            searchForAssetCatalogs(in: directory, results: &assetCatalogs)
        }

        return assetCatalogs
    }

    /// Search for asset catalogs in the specified directory and its subdirectories
    private func searchForAssetCatalogs(in directory: Path, results: inout [Path]) {
        // Check if this is an .xcassets directory
        if directory.string.hasSuffix(".xcassets") {
            results.append(directory)
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
                }
            } else {
                // This is a directory, check for .xcassets folders inside
                searchForAssetCatalogs(in: path, results: &assetCatalogs)
            }
        }

        return assetCatalogs
    }
}
