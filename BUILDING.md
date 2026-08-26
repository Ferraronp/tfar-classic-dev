# Сборка TFAR Classic

Инструкция предназначена для сборки TeamSpeak-плагина TFAR Classic на Windows 10/11.

Игровые PBO этой командой не собираются. Результат — две DLL:

- task_force_radio_win32.dll;
- task_force_radio_win64.dll.

## 1. Требования

Установить:

1. Git и Git LFS.
2. Visual Studio 2022 Community или Build Tools 2022.
3. Workload «Разработка классических приложений на C++».
4. MSVC v143 для x86/x64.
5. Windows 10 SDK или Windows 11 SDK.
6. 7-Zip — только для упаковки .ts3_plugin.

В проекте исторически указаны toolset v142 и Windows SDK 8.1. Команды ниже переопределяют их на v143 и установленный Windows SDK 10/11, поэтому редактировать .vcxproj локально не требуется.

## 2. Получение рабочей ветки

~~~powershell
Set-Location C:\Artur\Projects\tfar-classic

git fetch origin
git switch classic
git pull --ff-only
git status
~~~

Перед сборкой рабочее дерево должно быть чистым.

## 3. Проверка среды C++

Наличия одного MSBuild недостаточно: отдельно должны быть установлены VC targets, компиляторы x86/x64 и Windows SDK.

~~~powershell
$programFilesX86 = [Environment]::GetFolderPath("ProgramFilesX86")
$vswhere = "$programFilesX86\Microsoft Visual Studio\Installer\vswhere.exe"

$installPath = & $vswhere `
  -latest `
  -products * `
  -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
  -property installationPath

if (-not $installPath) {
    throw "Не установлены MSVC C++ Build Tools x86/x64"
}

$msbuild = "$installPath\MSBuild\Current\Bin\MSBuild.exe"
$cppProps = "$installPath\MSBuild\Microsoft\VC\v170\Microsoft.Cpp.Default.props"

Test-Path $msbuild
Test-Path $cppProps
~~~

Обе проверки должны вернуть True. Если Microsoft.Cpp.Default.props отсутствует, установлен только MSBuild без C++ toolchain. Сборка в таком состоянии завершается ошибкой MSB4019 ещё до компиляции кода.

### Установка через интерфейс

1. Открыть **Visual Studio Installer**.
2. У Build Tools 2022 нажать **Изменить**.
3. Выбрать workload **Разработка классических приложений на C++**.
4. Убедиться, что выбраны:
   - MSVC v143 — VS 2022 C++ x64/x86 build tools;
   - Windows 10 SDK или Windows 11 SDK.
5. Применить изменения и заново открыть PowerShell.

### Установка через командную строку

Альтернативно существующую установку Build Tools можно дополнить официальным workload VCTools:

~~~powershell
$existingInstall = & $vswhere `
  -latest `
  -products * `
  -property installationPath

$setup = "$programFilesX86\Microsoft Visual Studio\Installer\setup.exe"

$setupArguments = @(
    "modify"
    "--installPath"
    "`"$existingInstall`""
    "--add"
    "Microsoft.VisualStudio.Workload.VCTools"
    "--includeRecommended"
    "--passive"
    "--norestart"
)

Start-Process `
  -FilePath $setup `
  -ArgumentList $setupArguments `
  -Verb RunAs `
  -Wait
~~~

Параметр --includeRecommended добавляет MSVC v143 x86/x64 и актуальный Windows SDK. После завершения установки нужно открыть новое окно PowerShell и повторить две проверки Test-Path.

## 4. Сборка и упаковка

### Автоматический способ

Рекомендуемый вариант собирает обе архитектуры, проверяет обязательные экспорты и создаёт установщик одной командой:

~~~powershell
.\scripts\build-teamspeak-plugin.ps1
~~~

Готовые распространяемые файлы появятся в:

~~~text
dist\teamspeak-plugin\task_force_radio_win32.dll
dist\teamspeak-plugin\task_force_radio_win64.dll
dist\teamspeak-plugin\tfar-classic-api26.ts3_plugin
~~~

Скрипт:

- сам находит Visual Studio, MSBuild, dumpbin и 7-Zip;
- собирает Win32 и x64 с разными `IntDir`;
- проверяет ненулевой размер DLL и обязательные экспорты;
- загружает официальный установщик TFAR 0.9.12, если его ещё нет;
- заменяет в нём только две DLL;
- проверяет структуру готового `.ts3_plugin`;
- выводит SHA-256 всех результатов.

Чтобы собрать и проверить только DLL без установщика:

~~~powershell
.\scripts\build-teamspeak-plugin.ps1 -SkipPackage
~~~

### GitHub Actions

Workflow `.github/workflows/teamspeak-plugin.yml` запускается:

- для каждого pull request;
- после релевантных изменений в ветке `classic`;
- вручную через вкладку Actions.

Runner получает только папки `ts` и `scripts` через sparse checkout. Игровые модели и Git LFS-объекты не загружаются. После успешного запуска artifact содержит обе DLL и `tfar-classic-api26.ts3_plugin`.

### Ручная сборка Release x64 и Win32

Старый проект использует общую папку промежуточных файлов для обеих платформ. Поэтому задаём отдельный `IntDir` для x64 и Win32: иначе второй `Rebuild` может удалить DLL, собранную первой командой.

~~~powershell
$repo = (git rev-parse --show-toplevel).Trim()
$solution = "$repo\ts\src\task_force_radio_plugin.sln"
$x64IntDir = "$repo\ts\src\obj\x64\Release\"
$win32IntDir = "$repo\ts\src\obj\Win32\Release\"

& $msbuild $solution `
  /t:Rebuild `
  /m `
  /p:Configuration=Release `
  /p:Platform=x64 `
  /p:PlatformToolset=v143 `
  /p:WindowsTargetPlatformVersion=10.0 `
  "/p:IntDir=$x64IntDir"

if ($LASTEXITCODE -ne 0) {
    throw "Сборка x64 завершилась с ошибкой"
}

& $msbuild $solution `
  /t:Rebuild `
  /m `
  /p:Configuration=Release `
  /p:Platform=Win32 `
  /p:PlatformToolset=v143 `
  /p:WindowsTargetPlatformVersion=10.0 `
  "/p:IntDir=$win32IntDir"

if ($LASTEXITCODE -ne 0) {
    throw "Сборка Win32 завершилась с ошибкой"
}
~~~

Готовые файлы:

~~~text
ts\src\build\task_force_radio_win64.dll
ts\src\build\task_force_radio_win32.dll
~~~

Старый код может вывести много предупреждений. Если `Ошибок: 0` и `$LASTEXITCODE` равен `0`, сборка считается успешной.

## 5. Проверка экспортов

`dumpbin.exe` устанавливается вместе с MSVC C++ Build Tools, но в обычном PowerShell обычно отсутствует в `PATH`. Найдём его автоматически через каталог установленной Visual Studio:

~~~powershell
$dumpbin = (Get-Command dumpbin.exe -ErrorAction SilentlyContinue).Source

if (-not $dumpbin) {
    $programFilesX86 = [Environment]::GetFolderPath("ProgramFilesX86")
    $vswhere = "$programFilesX86\Microsoft Visual Studio\Installer\vswhere.exe"

    $installPath = & $vswhere `
      -latest `
      -products * `
      -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
      -property installationPath

    $dumpbin = Get-ChildItem `
      "$installPath\VC\Tools\MSVC\*\bin\Hostx64\x64\dumpbin.exe" `
      -File `
      -ErrorAction SilentlyContinue |
      Sort-Object FullName -Descending |
      Select-Object -First 1 -ExpandProperty FullName
}

if (-not $dumpbin -or -not (Test-Path $dumpbin)) {
    throw "dumpbin.exe не найден — проверьте установку MSVC C++ Build Tools"
}

& $dumpbin /exports "$repo\ts\src\build\task_force_radio_win64.dll" |
  findstr "ts3plugin_apiVersion ts3plugin_onPluginCommandEvent"

& $dumpbin /exports "$repo\ts\src\build\task_force_radio_win32.dll" |
  findstr "ts3plugin_apiVersion ts3plugin_onPluginCommandEvent"
~~~

В обеих DLL должны присутствовать как минимум:

~~~text
ts3plugin_apiVersion
ts3plugin_onPluginCommandEvent
ts3plugin_onPluginCommandEventNew
ts3plugin_onPluginCommandEventOld
~~~

## 6. Быстрая ручная установка

Для первого локального теста упаковка необязательна.

Полностью закрыть TeamSpeak, включая процесс в трее:

~~~powershell
Get-Process |
  Where-Object ProcessName -Like "ts3client*"
~~~

Вывода быть не должно. Затем сохранить старую DLL и скопировать новую:

~~~powershell
$plugins = "$env:APPDATA\TS3Client\plugins"
$backup = "$repo\dist\backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

New-Item -ItemType Directory -Force $backup | Out-Null

Copy-Item "$plugins\task_force_radio_win64.dll" `
  $backup `
  -ErrorAction SilentlyContinue

Copy-Item "$repo\ts\src\build\task_force_radio_win64.dll" `
  "$plugins\task_force_radio_win64.dll" `
  -Force
~~~

Проверка размеров:

~~~powershell
Get-Item `
  "$repo\ts\src\build\task_force_radio_win64.dll", `
  "$plugins\task_force_radio_win64.dll" |
  Select-Object FullName, Length, LastWriteTime
~~~

## 7. Ручная упаковка .ts3_plugin

За основу используется официальный установщик TFAR 0.9.12. Его структура и звуки сохраняются, заменяются только DLL.

~~~powershell
$repo = (git rev-parse --show-toplevel).Trim()
$dist = "$repo\dist"
$stage = "$dist\api26-package"
$original = "$dist\upstream\task_force_radio.ts3_plugin"
$zip = "$dist\tfar-classic-api26.zip"
$installer = "$dist\tfar-classic-api26.ts3_plugin"

New-Item -ItemType Directory -Force "$dist\upstream" | Out-Null
New-Item -ItemType Directory -Force "$stage\plugins" | Out-Null

if (-not (Test-Path $original)) {
    Invoke-WebRequest `
      "https://github.com/michail-nikolaev/task-force-arma-3-radio/releases/download/0.9.12/task_force_radio.ts3_plugin" `
      -OutFile $original
}
~~~

Найти 7-Zip:

~~~powershell
$sevenZip = (Get-Command 7z.exe -ErrorAction SilentlyContinue).Source

if (-not $sevenZip) {
    $sevenZip = "C:\Programs\7-Zip\7z.exe"
}

if (-not (Test-Path $sevenZip)) {
    throw "7z.exe не найден — укажите его путь вручную в переменной sevenZip"
}
~~~

Подготовить DLL и обновить официальный архив:

~~~powershell
Copy-Item "$repo\ts\src\build\task_force_radio_win32.dll" `
  "$stage\plugins\task_force_radio_win32.dll" `
  -Force

Copy-Item "$repo\ts\src\build\task_force_radio_win64.dll" `
  "$stage\plugins\task_force_radio_win64.dll" `
  -Force

Copy-Item $original $zip -Force

Push-Location $stage

& $sevenZip u `
  -tzip `
  $zip `
  ".\plugins" `
  -r `
  -mm=Deflate `
  -mx=9

$packExitCode = $LASTEXITCODE
Pop-Location

if ($packExitCode -ne 0) {
    throw "7-Zip завершил упаковку с ошибкой"
}

Copy-Item $zip $installer -Force
~~~

Важно обновлять папку plugins целиком. При добавлении отдельных DLL из неверной рабочей директории 7-Zip может положить новые файлы в корень архива.

Проверка структуры:

~~~powershell
& $sevenZip l $installer |
  Select-String "task_force_radio_win"

Get-Item $installer |
  Select-Object FullName, Length, LastWriteTime
~~~

В списке должны быть ровно две DLL:

~~~text
plugins\task_force_radio_win32.dll
plugins\task_force_radio_win64.dll
~~~

Корневых копий без префикса plugins\ быть не должно.

## 8. Проверка установщика

Полностью закрыть TeamSpeak и запустить:

~~~powershell
Start-Process $installer -Wait
~~~

Сравнить собранную и установленную DLL:

~~~powershell
$built = "$repo\ts\src\build\task_force_radio_win64.dll"
$installed = "$env:APPDATA\TS3Client\plugins\task_force_radio_win64.dll"

Get-Item $built, $installed |
  Select-Object FullName, Length, LastWriteTime

Get-FileHash $built -Algorithm SHA256
Get-FileHash $installed -Algorithm SHA256
~~~

Размеры и SHA-256 должны совпасть.

## 9. Чек-лист тестирования

Один и тот же .ts3_plugin проверяется без пересборки:

- TeamSpeak 3.5.x: плагин загружается через API 23;
- TeamSpeak 3.6.x: плагин загружается через API 26;
- Arma показывает подключение к TeamSpeak;
- работает локальный голос;
- работает коротковолновая рация;
- работает длинноволновая рация;
- работают основной и дополнительный каналы;
- после смерти, потери сознания и возрождения звук восстанавливается;
- после выхода из Arma обычный звук TeamSpeak восстанавливается.

## 10. Частые ошибки

### MSB8020: не найден toolset v142

Использовать параметр:

~~~text
/p:PlatformToolset=v143
~~~

Либо установить MSVC v142 через Visual Studio Installer.

### MSB8036: не найден Windows SDK 8.1

Использовать:

~~~text
/p:WindowsTargetPlatformVersion=10.0
~~~

### Не найдены masm.props или masm.targets

Установить компоненты MSVC C++ x86/x64. MASM входит в комплект инструментов C++.

### Установленная DLL имеет размер 0 байт

Проверить, что:

- TeamSpeak полностью закрыт;
- новые DLL лежат внутри plugins\;
- в корне архива нет дополнительных DLL;
- архив обновлялся 7-Zip из каталога stage.

### Плагин показывает несовместимую версию API

Сравнить размер и SHA-256 установленной DLL с текущей сборкой. Возможно, TeamSpeak загрузил старую официальную DLL.

## 11. Что не добавлять в Git

Результаты локальной сборки и упаковки не входят в исходный код:

~~~text
.idea/
ts/src/build/
ts/src/obj/
dist/
~~~

Перед коммитом всегда выполнять:

~~~powershell
git status
~~~