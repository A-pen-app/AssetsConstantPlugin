# AssetsConstantPlugin

A Swift Package Manager plugin that generates type-safe Swift code for assets in your asset catalogs.

## Features

- Generate type-safe constants for images and colors in asset catalogs
- Support for namespacing assets by folder structure
- Customizable output file names and access control levels
- Works with both Swift Packages and Xcode projects

## Usage

### Adding the plugin to your package

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YourPackage",
    products: [
        .library(name: "YourLibrary", targets: ["YourTarget"])
    ],
    dependencies: [
        .package(url: "https://github.com/A-pen-app/AssetsConstantPlugin", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "YourTarget",
            dependencies: [],
            plugins: [
                .plugin(name: "AssetsConstantPlugin", package: "AssetsConstantPlugin")
            ]
        )
    ]
)
```

### Configuration

The plugin behavior can be customized by creating an `assets-constant.json` file in your project's root directory. If no file is found, default settings will be used.

Example configuration file:

```json
{
  "generateImages": true,
  "generateColors": true,
  "imageOutputFileName": "AppImage+Generated.swift",
  "colorOutputFileName": "AppColor+Generated.swift",
  "includeFolderPaths": false,
  "useNamespacing": true,
  "nameMapping": {
    "some-image-name": "customImageName"
  },
  "accessLevel": "public"
}
```

### Configuration options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `generateImages` | Boolean | `true` | Whether to generate image constants |
| `generateColors` | Boolean | `true` | Whether to generate color constants |
| `imageOutputFileName` | String | `"AppImage+Generated.swift"` | The name of the output file for image constants |
| `colorOutputFileName` | String | `"AppColor+Generated.swift"` | The name of the output file for color constants |
| `includeFolderPaths` | Boolean | `false` | Whether to include folder paths in asset names |
| `useNamespacing` | Boolean | `false` | Whether to use namespacing for assets in different folders |
| `nameMapping` | Object | `{}` | Custom name mappings for asset names |
| `accessLevel` | String | `"public"` | Access control level for generated code. Options: `"public"`, `"internal"`, `"fileprivate"`, `"private"` |

## Usage examples

### Basic usage

After adding the plugin, your assets will be available as static constants:

```swift
// Using image assets
let image = AppImage.menuIcon.image  // SwiftUI Image
let uiImage = AppImage.menuIcon.uiImage  // UIKit UIImage

// Using color assets
let color = AppColor.brandPrimary.color  // SwiftUI Color
let uiColor = AppColor.brandPrimary.uiColor  // UIKit UIColor
```

### With namespacing

If you enable namespacing with `"useNamespacing": true`, assets will be grouped by folders:

```swift
// Using image assets in folders
let image = AppImage.TabBar.home.image
let buttonImage = AppImage.Buttons.primary.image

// Using color assets in folders
let color = AppColor.Brand.primary.color
let accentColor = AppColor.Text.accent.uiColor
```

### Asset Resolution Mechanism

The generated code for `AppImage` and `AppColor` uses a smart asset resolution system:

1. First, it looks for the asset in the main application bundle (`.main`)
2. If not found in the main bundle, it falls back to the module bundle (`.module`)
3. If still not found, it uses standard initialization as a last resort

This prioritization system provides several benefits:
- You can override assets from your package by adding same-named assets to your app's main bundle
- Package assets work seamlessly when used directly
- Graceful fallback ensures the best available asset is used

Example from the generated code:

```swift
public extension Image {
    init(appImage: AppImage) {
        #if canImport(UIKit) 
        if let _ = UIImage(named: appImage.rawValue, in: .main, compatibleWith: nil) {
            self.init(appImage.rawValue)  // Uses asset from main bundle
        } else {
            self.init(appImage.rawValue, bundle: .module)  // Falls back to module bundle
        }
        #elseif canImport(AppKit)
        // Similar logic for AppKit...
        #else
        self.init(appImage.rawValue)
        #endif
    }
}
```

## Generated code

The plugin generates Swift files at build time with type-safe constants for your assets. These files will be created in your build directory and automatically included in your target.

## Requirements

- Swift 5.9 or later
- Xcode 15.0 or later

## License

This package is available under the MIT license. 
