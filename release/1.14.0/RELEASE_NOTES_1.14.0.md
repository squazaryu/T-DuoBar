# T-DuoBar 1.14.0 · build 41

- Five independent opt-ins in Settings → General → Menu options: wide popup, row highlighting, larger/higher-contrast text, one expanded main section and manual network diagnostics. All are off by default; existing settings are retained.
- Local battery history is always available in expanded Battery: a six-hour chart and consumption over a continuous unplugged hour. Data is capped at 24 hours/1500 samples, without an additional polling timer. History starts with installation; charging/sleep gaps are not bridged.
- Diagnostics check a single Apple HTTPS test page only after Check connection is pressed. DNS failures are distinguished, redirects/cookies/credential storage are disabled and closing the popup cancels the request. This is not a VPN leak test or a guarantee of every app's connectivity.
- Visual polish: locale-aware chart hours, percentage axis labels, no duplicate power-source sentence and a percentage fallback instead of truncated numeric estimates in narrow Compact rows.

No breaking changes or preference migration. No new options are enabled automatically. After updating, choose any desired options; hourly usage appears only after enough continuous battery readings have accumulated.

Universal 2, macOS 13+. Experimental ad-hoc signed community build, without Developer ID signing or Apple notarization. See VALIDATION.md for checks and limits.

---

Пять независимых дополнительных опций меню — все по умолчанию выключены. В раскрытом разделе батареи доступна локальная история без отдельного переключателя: график за 6 часов и расход за непрерывный час работы от батареи. Данные до установки не восстанавливаются, фоновый таймер не добавлен.

Необязательная диагностика выполняется только по кнопке и проверяет тестовую HTTPS-страницу Apple. Исправлены подписи времени/процентов графика, повтор питания и обрезание числовой оценки в узком меню. Настройки сохраняются; миграций и breaking changes нет. Сборка экспериментальная, с ad-hoc подписью и без нотариализации Apple.
