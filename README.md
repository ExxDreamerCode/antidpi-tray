# AntiDPI Tray

[RU](#ru) | [EN](#en)

---

<a id="ru"></a>
## RU

Трей-иконка для управления AntiDPI на Windows: включение/выключение, смена любой из 484 стратегий, перезапуск — **без UAC-запросов и без прав администратора в повседневном использовании**.

Движок и стратегии — проекты [igareck/anti-dpi-for-russia](https://github.com/igareck/anti-dpi-for-russia) и [bol-van/zapret-win-bundle](https://github.com/bol-van/zapret-win-bundle). Этот репозиторий не содержит их кода: инсталлятор скачивает официальные артефакты, **зафиксированные по коммиту и проверяемые по SHA256**, распаковывает и настраивает всё автоматически.

### Как это работает

Единственная проблема управления AntiDPI "без админа": `winws2.exe` требует elevated-токен (загрузка драйвера WinDivert). Решение — **две задачи планировщика** (`AntiDPI Start` / `AntiDPI Stop`), созданные один раз с `RunLevel Highest`. Дальше трей запускает их через `schtasks /run` — UAC не появляется никогда. Номер стратегии передаётся движку через файл состояния (`_state\tray_cmd.json`), поэтому две задачи покрывают все стратегии.

### Установка

1. Windows 10/11 x64, [Python 3.8+](https://www.python.org/downloads/) (инсталлятор сам доставит `pystray` и `pillow`)
2. Скачать репозиторий (Code → Download ZIP) и запустить **`install.bat`**
3. Один UAC-запрос при создании задач — последний в жизни этой установки

Что делает `install.bat`:
- скачивает движок (pin: `zapret-win-bundle@6eb463a`, SHA256 проверяется) и стратегии (pin: релиз `v1.1`, SHA256 проверяется) в `C:\Igareck_AntiDPI`
- копирует файлы трея, регистрирует автозапуск (HKCU, без админа)
- создаёт задачи планировщика (единственный UAC)

> **Антивирус**: `winws2.exe` и `WinDivert64.sys` часто ловятся эвристикой. Инсталлятор это детектит и просит добавить папку `C:\Igareck_AntiDPI` в исключения антивируса перед повторным запуском.

### Использование

| Действие | Как |
|---|---|
| Вкл/выкл | пункт меню или двойной клик по иконке |
| Смена стратегии | меню «Стратегия» → 23 семьи, 484 стратегии с описанием |
| Перезапуск той же стратегии | пункт «Перезапустить» |
| Автостарт при входе в Windows | включён по умолчанию: поднимает последнюю использованную стратегию через ~10 сек после логина |
| Статус | пункт «Статус» |

Если какой-то сервис (игра, мессенджер, IDE) начинает глючить с включённым AntiDPI — добавьте его IP или подсеть в `C:\Igareck_AntiDPI\Igareck\lists\ips-exclude.txt` и в трее нажмите «Перезапустить».

### Удаление

Запустить **`uninstall.bat`** — остановит AntiDPI, удалит задачи и автозапуск. Файлы движка остаются в `C:\Igareck_AntiDPI` — удалить папку вручную, если нужно.

---

<a id="en"></a>
## EN

A tray icon for managing AntiDPI on Windows: on/off, switching between all 484 strategies, restart — **with no UAC prompts and no admin rights in daily use**.

The engine and strategies come from [igareck/anti-dpi-for-russia](https://github.com/igareck/anti-dpi-for-russia) and [bol-van/zapret-win-bundle](https://github.com/bol-van/zapret-win-bundle). This repository ships none of their code: the installer downloads official artifacts **pinned by commit and verified by SHA256**, unpacks and configures everything.

### How it works

`winws2.exe` needs an elevated token (WinDivert driver), so daily "no-admin" control is done via **two scheduled tasks** (`AntiDPI Start` / `AntiDPI Stop`) created once with `RunLevel Highest`. The tray triggers them via `schtasks /run` — UAC never appears. The strategy number is passed through a state file (`_state\tray_cmd.json`), so two tasks cover all 484 strategies.

### Install

1. Windows 10/11 x64, [Python 3.8+](https://www.python.org/downloads/) (the installer adds `pystray` and `pillow` itself)
2. Download this repo (Code → Download ZIP), run **`install.bat`**
3. One UAC prompt while creating tasks — the only one you will ever see

> **Antivirus**: `winws2.exe` / `WinDivert64.sys` are commonly flagged by heuristics. The installer detects quarantine and asks to add `C:\Igareck_AntiDPI` to antivirus exclusions, then re-run.

### Usage

| Action | How |
|---|---|
| Toggle on/off | menu item or double-click the icon |
| Change strategy | "Стратегия" menu → 23 families, 484 entries |
| Restart current strategy | "Перезапустить" item |
| Autostart at logon | on by default: enables the last used strategy ~10 s after logon |
| Status | "Статус" item |

If some service misbehaves with AntiDPI on, add its IP or subnet to `C:\Igareck_AntiDPI\Igareck\lists\ips-exclude.txt` and hit "restart" in the tray.

### Uninstall

Run **`uninstall.bat`** — stops AntiDPI, removes tasks and autostart. Engine files stay in `C:\Igareck_AntiDPI`; delete the folder manually if you want them gone.

---

## Credits & licenses

- Strategies & shell: [igareck/anti-dpi-for-russia](https://github.com/igareck/anti-dpi-for-russia) — © Igor Krauch
- Engine: [bol-van/zapret-win-bundle](https://github.com/bol-van/zapret-win-bundle) — Zapret2 (MIT), WinDivert (GPL-3.0/LGPL-3.0), Cygwin (LGPL-3.0); licenses ship inside the downloaded bundle
- Tray & installer in this repository: MIT, see [LICENSE](LICENSE)
