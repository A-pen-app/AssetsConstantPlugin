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
    struct XcodeTargetHandler {
        // MARK: Lifecycle

        init(context: XcodePluginContext, target: XcodeTarget) {
            self.context = context
            self.target = target
        }

        // MARK: Internal

        let context: XcodePluginContext
        let target: XcodeTarget

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

        /// Find all asset catalogs in the Xcode target
        func findAssetCatalogs() -> [Path] {
            var assetCatalogs: [Path] = []

            // First approach: Look directly for .xcassets folders in input files
            for file in target.inputFiles {
                let path = file.path
                if path.string.hasSuffix(".xcassets"), !assetCatalogs.contains(path) {
                    assetCatalogs.append(path)
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
                    }
                }
            }

            return assetCatalogs
        }
    }
#endif
