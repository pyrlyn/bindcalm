# Toolchain

| Program | How to install | Why here | Source |
| --- | --- | --- | --- |
| Xcode 27.0 (Swift 6.4, SwiftPM, XCTest) | Mac App Store / developer.apple.com | Build, test, Apple SDKs | https://developer.apple.com/xcode/ |
| codesign | Ships with Xcode command line tools | Ad-hoc signing in `scripts/bundle.sh` | https://developer.apple.com/documentation/security/code-signing-services |
| gh | Homebrew | Repository creation (one-off) | https://github.com/cli/cli |

## SwiftPM

No package dependencies: Apple frameworks only (AppKit, SwiftUI, Carbon/HIToolbox,
ApplicationServices, CoreGraphics).
