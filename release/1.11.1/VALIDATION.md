# T-DuoBar 1.11.1 (30): localization validation

Checked on 2026-10-18, Apple Silicon, macOS 27.2 (26B5112a).

- 16 focused tests passed: LocalizationTests, ConvenienceSettingsTests and PopoverRenderTests/testRenderGermanPopoverAndAppearanceSettings.
- German and English contain the same 232 keys. German values are nonempty, format arguments match English, and no duplicate keys are present. All localization files pass plutil syntax validation.
- German system-language resolution is checked for de-DE, de-AT and de-CH; explicit Deutsch selection is covered.
- Native German pop-up and appearance-settings renders were inspected in light/dark themes. No overlapping controls were found in these fixtures; this does not establish every possible text/device state.
- The attempted full suite was interrupted after it stalled in PopoverAppearanceTests.testGlassSelectionUsesARealGlassSurfaceAndClassicRestoresPopover. A process sample showed the main thread waiting inside IOBluetoothCoreBluetoothCoordinator initialization, reached through BluetoothService.refresh. This is a validation limit, not evidence of a translation defect. System Bluetooth settings were not changed.
- Distribution is a Universal 2 Release build, ad-hoc signed, without Developer ID signing or Apple notarization. Intel runtime, older macOS, exhaustive device coverage and long-duration energy behavior are outside this check.

Reproduction:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project DuoBar.xcodeproj -scheme DuoBar -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$TMPDIR/T-DuoBar-DerivedData" \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
  -only-testing:DuoBarTests/LocalizationTests \
  -only-testing:DuoBarTests/ConvenienceSettingsTests \
  -only-testing:DuoBarTests/PopoverRenderTests/testRenderGermanPopoverAndAppearanceSettings test
```

Local xcresult bundles, renders, process sample and packaging verification are retained under ignored build/ and the task temporary directory. Previous 1.11.0 performance measurements are historical and are not new measurements for 1.11.1.
