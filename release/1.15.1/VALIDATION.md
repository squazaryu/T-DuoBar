# T-DuoBar 1.15.1 (43) validation

The release suite ran on Apple Silicon with macOS 27.3. The regression tests cover Bluetooth report parsing, address matching, ambiguous power-source entries, preserving existing readings and stopping accessory polling on pop-up close. The native pop-up previews exercise Standard and Compact layouts in light and dark appearance.

The live accessory reader matched the system Bluetooth menu for Nothing Headphone (1) and Magic Mouse. The Bluetooth report listed both devices without charge levels. The fallback matched the mouse by its Bluetooth address and the headphones by a unique connected-device name. A missing or ambiguous reading stays unavailable. This release shows charge level and colors the battery icon red below 20%; it does not read accessory charging state.

The Universal 2 DMG contains an ad-hoc signed app targeting macOS 13. Packaging checks cover both architectures, signature, bundle metadata and SHA-256. The two accessory models were tested on Apple Silicon. Intel and macOS 13 are build targets.
