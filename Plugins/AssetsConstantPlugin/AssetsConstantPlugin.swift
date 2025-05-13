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

        // Set up output file paths
        let outputFilePath = pluginWorkDirectory.appending(configuration.outputFileName)

        // Generate Swift code directly in the plugin
        let generator = AppImageSourceGenerator(
            configuration: configuration,
            assetCatalogs: assetCatalogs
        )

        let generatedCode = generator.generateSwiftCode()

        // Write the generated code to the output file
        do {
            try generatedCode.write(toFile: outputFilePath.string, atomically: true, encoding: .utf8)
        } catch {
            print("❌ Error generating \(configuration.outputFileName): \(error)")
        }

        // Collect all input files from asset catalogs
        let allInputFiles = collectAllInputFiles(from: assetCatalogs)

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
