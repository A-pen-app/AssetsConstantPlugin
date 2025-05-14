//
//  ConfigurationReader.swift
//  AssetsConstantPlugin
//
//  Created by 李品毅 on 2025/5/16.
//

import Foundation
import PackagePlugin

/// Reads and parses plugin configuration from a file
struct ConfigurationReader {
    /// Read configuration from a JSON file or use defaults
    /// - Parameter packageDirectory: The root directory of the package
    /// - Returns: A plugin configuration object
    static func readConfiguration(in packageDirectory: Path) -> PluginConfiguration {
        let configFileName = "assets-constant.json"
        let configFilePath = packageDirectory.appending(configFileName).string
        
        // Check if config file exists
        guard FileManager.default.fileExists(atPath: configFilePath) else {
            return PluginConfiguration()
        }
        
        // Read config file
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configFilePath)) else {
            return PluginConfiguration()
        }
        
        // Parse config file
        do {
            let decoder = JSONDecoder()
            let configuration = try decoder.decode(PluginConfiguration.self, from: data)
            return configuration
        } catch {
            return PluginConfiguration()
        }
    }
} 
