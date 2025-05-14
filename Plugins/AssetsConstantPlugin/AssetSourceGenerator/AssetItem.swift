//
//  AssetItem.swift
//  AssetsConstantPlugin
//
//  Created by 李品毅 on 2025/5/14.
//

import Foundation

/// Represents an asset item found in an asset catalog
struct AssetItem {
    /// The name of the asset (without .imageset)
    let name: String

    /// The folder path of the asset (optional)
    let folder: String?

    /// The full path to the asset
    let fullPath: String
}
