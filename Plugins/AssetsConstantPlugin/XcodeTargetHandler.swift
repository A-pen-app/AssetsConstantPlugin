//
//  XcodeTargetHandler.swift
//  AssetsConstantPlugin
//
//  Created by 李品毅 on 2025/5/13.
//

#if canImport(XcodeProjectPlugin)
    import Foundation
    import PackagePlugin
    import XcodeProjectPlugin

    /// Handler for XcodeTarget assets
    ///
    /// This struct is responsible for discovering asset catalogs in Xcode targets
    /// and creating build commands for code generation.
    struct XcodeTargetHandler {
        // MARK: Lifecycle

        init(context: XcodePluginContext, target: XcodeTarget) {
            self.context = context
            self.target = target
        }

        // MARK: Internal

        /// The plugin context
        let context: XcodePluginContext

        /// The target to process
        let target: XcodeTarget

        /// Creates build commands for the plugin
        /// - Parameters:
        ///   - plugin: The plugin instance
        ///   - pluginWorkDirectory: Working directory for generated files
        /// - Returns: Array of commands to execute
        func createBuildCommands(plugin: AssetsConstantPlugin, pluginWorkDirectory: Path) throws -> [Command] {
            // Read configuration from file or use defaults
            let configuration = ConfigurationReader.readConfiguration(in: context.xcodeProject.directory)
            let assetCatalogs = findAssetCatalogs()

            return try plugin.createBuildCommands(
                pluginWorkDirectory: pluginWorkDirectory,
                configuration: configuration,
                assetCatalogs: assetCatalogs
            )
        }

        /// Find all asset catalogs in the Xcode target
        /// - Returns: Array of paths to asset catalogs
        func findAssetCatalogs() -> [Path] {
            var assetCatalogs: [Path] = []

            // Process input files to find asset catalogs
            for file in target.inputFiles {
                processFile(file.path, assetCatalogs: &assetCatalogs)
            }

            return assetCatalogs
        }

        // MARK: Private

        /// Process a file to check if it's part of an asset catalog
        /// - Parameters:
        ///   - path: Path to the file
        ///   - assetCatalogs: Collection of asset catalog paths
        private func processFile(_ path: Path, assetCatalogs: inout [Path]) {
            if path.string.hasSuffix(".xcassets"), !assetCatalogs.contains(path) {
                // Direct match for asset catalog
                assetCatalogs.append(path)
            } else if path.string.contains("Assets.xcassets/"), path.string.hasSuffix("Contents.json") {
                // File inside an asset catalog - extract the catalog path
                extractAssetCatalogPath(from: path.string, assetCatalogs: &assetCatalogs)
            }
        }

        /// Extract the asset catalog path from a file path
        /// - Parameters:
        ///   - filePath: Path to a file inside an asset catalog
        ///   - assetCatalogs: Collection of asset catalog paths
        private func extractAssetCatalogPath(from filePath: String, assetCatalogs: inout [Path]) {
            let components = filePath.split(separator: "/")
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
            }
        }
    }
#endif
