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
struct AssetsConstantPlugin {
    // MARK: Internal

    func createBuildCommands(pluginWorkDirectory: Path,
                             configuration: PluginConfiguration,
                             assetCatalogs: [Path]) throws -> [Command] {
        // If no asset catalogs, don't generate anything
        guard !assetCatalogs.isEmpty else {
            return []
        }

        var commands = [Command]()
        
        // Generate image constants if enabled
        if configuration.generateImages {
            let imageOutputFilePath = pluginWorkDirectory.appending(configuration.imageOutputFileName)
            
            // Generate Swift code directly in the plugin
            let imageGenerator = AppImageSourceGenerator(
                configuration: configuration,
                assetCatalogs: assetCatalogs
            )
            
            let imageGeneratedCode = imageGenerator.generateSwiftCode()
            
            // Write the generated code to the output file
            do {
                try imageGeneratedCode.write(toFile: imageOutputFilePath.string, atomically: true, encoding: .utf8)
            } catch {
                print("❌ Error generating \(configuration.imageOutputFileName): \(error)")
            }
            
            // Create a command for image generation
            commands.append(
                .buildCommand(
                    displayName: "Generate \(configuration.imageOutputFileName)",
                    executable: .init("/bin/echo"),
                    arguments: ["Generated \(configuration.imageOutputFileName)"],
                    inputFiles: collectAllInputFiles(from: assetCatalogs),
                    outputFiles: [imageOutputFilePath]
                )
            )
        }
        
        // Generate color constants if enabled
        if configuration.generateColors {
            let colorOutputFilePath = pluginWorkDirectory.appending(configuration.colorOutputFileName)
            
            // Generate Swift code directly in the plugin
            let colorGenerator = AppColorSourceGenerator(
                configuration: configuration,
                assetCatalogs: assetCatalogs
            )
            
            let colorGeneratedCode = colorGenerator.generateSwiftCode()
            
            // Write the generated code to the output file
            do {
                try colorGeneratedCode.write(toFile: colorOutputFilePath.string, atomically: true, encoding: .utf8)
            } catch {
                print("❌ Error generating \(configuration.colorOutputFileName): \(error)")
            }
            
            // Create a command for color generation
            commands.append(
                .buildCommand(
                    displayName: "Generate \(configuration.colorOutputFileName)",
                    executable: .init("/bin/echo"),
                    arguments: ["Generated \(configuration.colorOutputFileName)"],
                    inputFiles: collectAllInputFiles(from: assetCatalogs),
                    outputFiles: [colorOutputFilePath]
                )
            )
        }

        return commands
    }

    // MARK: Private

    private func collectAllInputFiles(from assetCatalogs: [Path]) -> [Path] {
        var allInputFiles: [Path] = []
        for catalog in assetCatalogs {
            // Add the catalog itself
            allInputFiles.append(catalog)

            // Add all files within the catalog recursively
            collectAllFilesRecursively(in: catalog, result: &allInputFiles)
        }
        return allInputFiles
    }

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
}

// MARK: - Build Tool Plugin Support
extension AssetsConstantPlugin: BuildToolPlugin {
    /// Create build commands for the specified target during the build process.
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let target = target as? SourceModuleTarget else { return [] }

        let handler = SourceModuleTargetHandler(context: context, target: target)
        return try handler.createBuildCommands(pluginWorkDirectory: context.pluginWorkDirectory)
    }
}

// MARK: - Xcode Plugin Support
#if canImport(XcodeProjectPlugin)
    import XcodeProjectPlugin

    extension AssetsConstantPlugin: XcodeBuildToolPlugin {
        func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
            let handler = XcodeTargetHandler(context: context, target: target)
            return try handler.createBuildCommands(pluginWorkDirectory: context.pluginWorkDirectory)
        }
    }
#endif
