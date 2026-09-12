# ZPRT Connection

<p align="center">
  <img src="docs/app-icon.png" alt="ZPRT Connection icon" width="128" height="128">
</p>

**ZPRT Connection** — это **zapret-discord для macOS**: приложение, которое поднимает локальный обход DPI для Discord (и YouTube), как привычный [zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube) на Windows.

На Mac обычный Zapret / zapret-discord почти нереально поставить «из коробки»: нет удобного установщика, куча ручной возни с PF/скриптами, а часть Windows/Linux-сборок на macOS просто не ставится. Этот репозиторий закрывает эту дыру — готовое приложение с движком внутри, установка в один клик **GO**.

> Developer: [@pxdxz](https://t.me/pxdxz)

<p align="center">
  <img src="docs/screenshot.jpg" alt="ZPRT Connection screenshot" width="420">
</p>

## Зачем это нужно

Провайдеры режут Discord и YouTube через DPI. VPN не всегда нужен: достаточно локального обхода, как у Zapret. На Windows для этого обычно ставят **zapret-discord**. На macOS раньше приходилось собирать всё руками — теперь есть ZPRT Connection.

## Что умеет

- Установка и запуск движка Zapret одним нажатием **GO**
- Готовый Discord-профиль (стратегия `general-simple-fake` по умолчанию)
- Стратегии обхода, IP-списки, Discord UDP, блокировка QUIC
- Светлая / тёмная тема, иконка в меню, окно можно закрыть без выхода
- Работает **без Apple Developer Program**

## Скачать

Готовые сборки — в [Releases](https://github.com/pxdxx/ZPRT-Connection-MAC-OS-Zapret-Discord/releases).

1. Скачайте `ZPRT-Connection-macOS.dmg`
2. Откройте DMG и перетащите `ZPRT Connection.app` в **Applications**
3. При предупреждении Gatekeeper: **правый клик → Открыть** (или «Всё равно открыть» в настройках безопасности)
4. Нажмите **GO** — один раз введите пароль администратора
5. После установки повторно ставить движок при перезапуске **не нужно**

### Требования

- macOS **14+** (Sonoma и новее)
- Apple Silicon или Intel
- Пароль администратора для первой установки

## Сборка из исходников

### Xcode

1. Клонируйте репозиторий
2. Откройте `dsffdssd.xcodeproj` в Xcode 15+
3. Схема `dsffdssd` → **My Mac**
4. Signing: **Sign to Run Locally** (уже настроено)
5. Product → Run

### CLI

```bash
xcodebuild \
  -project dsffdssd.xcodeproj \
  -scheme dsffdssd \
  -configuration Release \
  -derivedDataPath /tmp/ZPRTBuild \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  build

open "/tmp/ZPRTBuild/Build/Products/Release/ZPRT Connection.app"
```

Сборка DMG для релиза:

```bash
./scripts/package-release.sh
# → dist/ZPRT-Connection-macOS.dmg
```

> Не собирайте DerivedData на Desktop/iCloud — xattrs ломают codesign. Используйте `/tmp/...`.

## Disclaimer

Используйте в соответствии с законодательством вашей страны. Автор не несёт ответственности за неправомерное применение.

## Tegsss

Zapret Discord Mac запрет дискорд macos zapret-discord для macOS запрет дискорд мак ос
