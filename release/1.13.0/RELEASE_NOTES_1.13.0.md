# T-DuoBar 1.13.0 · build 40

- Choose **Standard** cards or a **Compact** menu in Settings → General → Appearance → Menu layout. Order, visibility and favorites are shared; Standard remains the default.
- Disclosures expand/collapse over 180 ms, including their window height. Motion respects the app preference and macOS Reduce Motion.
- A lighter footer provides Settings and an accessible power button for Quit.
- Network details include nearby Wi-Fi discovery, refresh and explicit joining. Passwords stay in memory; enterprise/unsupported networks open macOS settings.
- Login-item access is isolated from temporary/test copies. Approved registration is renewed after an installed update; disabled or approval-pending entries are not enabled automatically.
- Bluetooth state reads no longer block the main thread during launch or menu interaction.
- Internal-battery readings no longer fall back to UPS data or treat a rounded 100% as authoritative full charge.
- Requested glyph size extends to 120% while preserving a circular ring and fitting macOS menu-bar height.

No breaking changes or preference migration. Existing preferences are retained. The app still installs as DuoBar.app and must not run beside the original DuoBar.

**After updating:** launch from Applications. Verify launch at login during your next normal login; no reboot was performed for this release. Nearby Wi-Fi requires macOS location access. Real network association remains unverified.

Universal 2 (Apple Silicon + Intel), macOS 13+. Experimental ad-hoc signed community build, without Developer ID signing or Apple notarization. See VALIDATION.md for checks and limits.

---

Обычный и компактный виды меню, плавное раскрытие разделов и облегчённая нижняя панель. Добавлены поиск ближайших Wi-Fi-сетей и подключение по явному действию. Исправлены привязка автозапуска к тестовой копии, блокировка запуска Bluetooth и определение внутренней батареи. Размер значка — до 120% с сохранением круга и учётом высоты строки меню.

Настройки сохраняются, миграций нет. Запускайте приложение из «Программ». Автозапуск после реальной перезагрузки и подключение к другой сети требуют отдельной проверки. Сборка экспериментальная, с ad-hoc подписью и без нотариализации Apple.
