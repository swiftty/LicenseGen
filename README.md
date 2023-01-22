# LicenseGen

Generate licenses from SwiftPM libraries.

## Installation

### Swift Package Manager

```swift
.binaryTarget(
    name: "LicenseGen",
    url: "https://github.com/swiftty/LicenseGen/releases/download/0.0.10/LicenseGen.artifactbundle.5.7.zip",
    checksum: ""
),

.plugin(
    name: "LicenseGenPlugin",
    capability: .command(
        intent: .custom(
            verb: "licensegen",
            description: "generate licenses to Settings.bundle."
        )
    ),
    dependencies: [
        "LicenseGen"
    ]
),
```

## Usage

```shell
swift package plugin --allow-writing-to-directory . licensegen \
  --settings-bundle \
  --settings-bundle-prefix ${bundle prefix key} \
  --output-path ${path to Settings.bundle} \
  --package-paths ${path to Package.swift directory}
```

## License

LicenseGen is available under the MIT license, and uses source code from open source projects. See the [LICENSE](https://github.com/swiftty/LicenseGen/blob/main/LICENSE) file for more info.
