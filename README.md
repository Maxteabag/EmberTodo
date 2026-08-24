# Ember Todo

Ember Todo is a small, fully native SwiftUI task manager for iPhone. It keeps tasks on-device, supports priorities and due dates, and is designed for fast one-handed capture.

## Development

Requirements: Swift 6, XcodeGen, and (for the full Linux gate) an authenticated `xtool` with an installed iPhone SDK.

```bash
swift test
./scripts/verify.sh
```

`project.yml` is the maintained Xcode project source. Generate the project with `xcodegen generate`.

## Release

The manual `Build and upload Ember Todo to TestFlight` workflow performs the authoritative Xcode archive, export, IPA metadata check, upload, exact-build processing poll, and internal beta-group verification. The standalone verifier can retry Apple-side processing for an already uploaded build without rebuilding.

