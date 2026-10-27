# T-DuoBar repository artwork

- `app-icon.png`: the app's existing icon, copied from its asset catalog.
- `t-duobar-hero.png`: a presentation of the real production glyphs and pop-up content.
- `popup-light.png`, `popup-dark.png`: native SwiftUI pop-up content in both appearances.
- `settings-general.png`: the native General settings content, including appearance and battery-digit options.

Screenshots use explicit demo battery, network, audio and VPN values. They are native view renders, not captures of a user's desktop. The hero backdrop is a documentation layout; it is not a claim that the pop-up has that exact background. Liquid Glass is shown as a settings option, not simulated in the classic menu screenshots. No live SSIDs, device names or VPN credentials are included.

Reproduce with `RepositoryArtworkTests/testRenderRepositoryArtwork` in the DuoBar test scheme. Images are written to `$TMPDIR/T-DuoBar-RepositoryArtwork/`; inspect them and copy the approved PNGs into `assets/`. Normal test runs do not modify repository assets. The renderer restores the previous language preference and uses isolated settings for the screenshots. Historical upstream marketing images remain in `marketing/`; the main README uses these fork-specific images.


## Next-version UI preview (24 October 2026)

`preview/standard-light.png`, `preview/standard-dark.png`, `preview/compact-light.png` and `preview/compact-dark.png` show the selectable layouts from the local development build. `preview/settings-light.png` and `preview/settings-dark.png` show the independent layout picker and background choice. The preview is not included in the published 1.12.2 download.

These six images were rendered from the current production views by `PopoverLayoutTests/testRenderBothLayoutsAndExpandedControlsInLightAndDark` in the development checkout. Output: `$TMPDIR/T-DuoBar-CompactLayout/`. They include the compact footer grid and one-point Audio Output optical adjustment. Demo network/VPN/audio/battery values are shared between layouts; no live connection data is used. The corresponding application changes are still local; this documentation-only commit does not publish their source or a new application build.

The root-level artwork remains the published-interface gallery. Keep release and preview images separate until the application release is published.
