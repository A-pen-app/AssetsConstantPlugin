//
//  AssetsConstantPlugin.swift
//  AssetsConstantPlugin
//
//  Created by 李品毅 on 2025/5/13.
//

import Foundation
import PackagePlugin

/// The plugin for generating Swift constants from asset catalogs
///
/// This plugin generates type-safe Swift constants for assets in your asset catalogs.
/// 
/// The plugin can be configured by adding an `assets-constant.json` file to your project's root directory.
/// See the README for full configuration options.
@main
struct AssetsConstantPlugin {
    // MARK: Internal

    func createBuildCommands(pluginWorkDirectory: Path,
                             configuration: PluginConfiguration,
                             assetCatalogs: [Path]) throws -> [Command] {
        guard !assetCatalogs.isEmpty else { return [] }

        var commands = [Command]()

        // Generate Image Assets
        if configuration.generateImages {
            commands.append(contentsOf: generateAssetCommands(
                configuration: configuration,
                pluginWorkDirectory: pluginWorkDirectory,
                assetCatalogs: assetCatalogs,
                outputFileName: configuration.imageOutputFileName,
                definition: appImageDefinition,
                className: "AppImage",
                assetExtension: ".imageset",
                assetTypeName: "image"
            ))
        }

        // Generate Color Assets
        if configuration.generateColors {
            commands.append(contentsOf: generateAssetCommands(
                configuration: configuration,
                pluginWorkDirectory: pluginWorkDirectory,
                assetCatalogs: assetCatalogs,
                outputFileName: configuration.colorOutputFileName,
                definition: appColorDefinition,
                className: "AppColor",
                assetExtension: ".colorset",
                assetTypeName: "color"
            ))
        }

        return commands
    }

    // MARK: Private

    private func generateAssetCommands(configuration: PluginConfiguration,
                                       pluginWorkDirectory: Path,
                                       assetCatalogs: [Path],
                                       outputFileName: String,
                                       definition: String,
                                       className: String,
                                       assetExtension: String,
                                       assetTypeName: String) -> [Command] {
        let outputPath = pluginWorkDirectory.appending(outputFileName)

        let generator = AssetSourceGenerator(
            configuration: configuration,
            assetCatalogs: assetCatalogs,
            assetDefinition: definition,
            assetClassName: className,
            assetExtension: assetExtension,
            assetTypeName: assetTypeName
        )

        let generatedCode = generator.generateSwiftCode()

        do {
            try generatedCode.write(toFile: outputPath.string, atomically: true, encoding: .utf8)
        } catch {
            print("❌ Error generating \(outputFileName): \(error)")
            return []
        }

        return [
            .buildCommand(
                displayName: "Generate \(outputFileName)",
                executable: .init("/bin/echo"),
                arguments: ["Generated \(outputFileName)"],
                inputFiles: collectAssetInputFiles(from: assetCatalogs),
                outputFiles: [outputPath]
            )
        ]
    }

    private func collectAssetInputFiles(from assetCatalogs: [Path]) -> [Path] {
        var allInputFiles: [Path] = []
        for catalog in assetCatalogs {
            allInputFiles.append(catalog)
            collectFilesRecursively(in: catalog, result: &allInputFiles)
        }
        return allInputFiles
    }

    private func collectFilesRecursively(in directory: Path, result: inout [Path]) {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directory.string) else {
            return
        }

        for item in contents {
            let itemPath = directory.appending(item)
            var isDirectory: ObjCBool = false

            if FileManager.default.fileExists(atPath: itemPath.string, isDirectory: &isDirectory) {
                result.append(itemPath)

                if isDirectory.boolValue {
                    collectFilesRecursively(in: itemPath, result: &result)
                }
            }
        }
    }
}

// MARK: - Build Tool Plugin Support
extension AssetsConstantPlugin: BuildToolPlugin {
    /// Create build commands for the specified target during the build process.
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let target = target as? SourceModuleTarget else { return [] }

        let handler = SourceModuleTargetHandler(context: context, target: target)
        return try handler.createBuildCommands(
            plugin: AssetsConstantPlugin(),
            pluginWorkDirectory: context.pluginWorkDirectory
        )
    }
}

// MARK: - Xcode Plugin Support
#if canImport(XcodeProjectPlugin)
    import XcodeProjectPlugin

    extension AssetsConstantPlugin: XcodeBuildToolPlugin {
        func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
            let handler = XcodeTargetHandler(context: context, target: target)
            return try handler.createBuildCommands(
                plugin: AssetsConstantPlugin(),
                pluginWorkDirectory: context.pluginWorkDirectory
            )
        }
    }
#endif
