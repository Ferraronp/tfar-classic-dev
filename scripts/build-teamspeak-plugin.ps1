[CmdletBinding()]
param(
    [ValidateSet("Release", "Debug")]
    [string]$Configuration = "Release",

    [string]$OutputDirectory,

    [switch]$SkipPackage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repo "dist\teamspeak-plugin"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory = Join-Path $repo $OutputDirectory
}

$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$solution = Join-Path $repo "ts\src\task_force_radio_plugin.sln"
$buildDirectory = Join-Path $repo "ts\src\build"
$objectDirectory = Join-Path $repo "ts\src\obj"

function Assert-LastExitCode {
    param([Parameter(Mandatory = $true)][string]$Operation)

    if ($LASTEXITCODE -ne 0) {
        throw "$Operation завершилась с кодом $LASTEXITCODE"
    }
}

function Find-VisualStudioTools {
    $programFilesX86 = [Environment]::GetFolderPath("ProgramFilesX86")
    $vswhere = Join-Path $programFilesX86 "Microsoft Visual Studio\Installer\vswhere.exe"

    if (-not (Test-Path -LiteralPath $vswhere)) {
        throw "vswhere.exe не найден: $vswhere"
    }

    $installPath = & $vswhere `
      -latest `
      -products * `
      -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
      -property installationPath
    Assert-LastExitCode "Поиск Visual Studio"

    $installPath = @($installPath)[0]
    if ([string]::IsNullOrWhiteSpace($installPath)) {
        throw "Не установлены MSVC C++ Build Tools x86/x64"
    }

    $msbuild = Join-Path $installPath "MSBuild\Current\Bin\MSBuild.exe"
    if (-not (Test-Path -LiteralPath $msbuild)) {
        throw "MSBuild.exe не найден: $msbuild"
    }

    $dumpbinFile = Get-ChildItem `
      (Join-Path $installPath "VC\Tools\MSVC\*\bin\Hostx64\x64\dumpbin.exe") `
      -File `
      -ErrorAction SilentlyContinue |
      Sort-Object FullName -Descending |
      Select-Object -First 1

    if ($null -eq $dumpbinFile) {
        throw "dumpbin.exe не найден в установленном MSVC toolchain"
    }

    return [PSCustomObject]@{
        InstallPath = $installPath
        MsBuild = $msbuild
        DumpBin = $dumpbinFile.FullName
    }
}

function Find-SevenZip {
    $command = Get-Command 7z.exe -ErrorAction SilentlyContinue
    $candidates = @()

    if ($null -ne $command) {
        $candidates += $command.Source
    }

    $candidates += @(
        "C:\Programs\7-Zip\7z.exe",
        "C:\Program Files\7-Zip\7z.exe",
        "D:\Programs\7-Zip\7z.exe"
    )

    $sevenZip = $candidates |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path -LiteralPath $_) } |
      Select-Object -First 1

    if ([string]::IsNullOrWhiteSpace($sevenZip)) {
        throw "7z.exe не найден. Установите 7-Zip или добавьте его в PATH"
    }

    return $sevenZip
}

function Invoke-PluginBuild {
    param(
        [Parameter(Mandatory = $true)][string]$Platform,
        [Parameter(Mandatory = $true)][string]$IntermediateDirectory,
        [Parameter(Mandatory = $true)][string]$MsBuild
    )

    if (-not $IntermediateDirectory.EndsWith('\')) {
        $IntermediateDirectory += '\'
    }

    New-Item -ItemType Directory -Path $IntermediateDirectory -Force | Out-Null

    Write-Host "::group::Сборка $Configuration|$Platform"
    try {
        & $MsBuild $solution `
          /t:Rebuild `
          /m `
          "/p:Configuration=$Configuration" `
          "/p:Platform=$Platform" `
          /p:PlatformToolset=v143 `
          /p:WindowsTargetPlatformVersion=10.0 `
          "/p:IntDir=$IntermediateDirectory"
        Assert-LastExitCode "Сборка $Configuration|$Platform"
    } finally {
        Write-Host "::endgroup::"
    }
}

function Assert-PluginExports {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$Dll,
        [Parameter(Mandatory = $true)][string]$DumpBin
    )

    $requiredExports = @(
        "ts3plugin_apiVersion",
        "ts3plugin_onPluginCommandEvent",
        "ts3plugin_onPluginCommandEventNew",
        "ts3plugin_onPluginCommandEventOld"
    )

    $dumpbinOutput = (& $DumpBin /exports $Dll.FullName 2>&1 | Out-String)
    Assert-LastExitCode "Проверка экспортов $($Dll.Name)"

    $exportNames = @(
        $dumpbinOutput -split "`r?`n" |
          ForEach-Object {
              if ($_ -match '^\s*\d+\s+\w+\s+[0-9A-Fa-f]+\s+(\S+)') {
                  $Matches[1]
              }
          }
    )

    foreach ($export in $requiredExports) {
        if ($exportNames -notcontains $export) {
            throw "В $($Dll.Name) отсутствует обязательный экспорт $export"
        }
    }
}

if (-not (Test-Path -LiteralPath $solution)) {
    throw "Solution не найден: $solution"
}

$visualStudio = Find-VisualStudioTools
Write-Host "Visual Studio: $($visualStudio.InstallPath)"
Write-Host "MSBuild: $($visualStudio.MsBuild)"
Write-Host "dumpbin: $($visualStudio.DumpBin)"

New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$platforms = @(
    [PSCustomObject]@{
        Name = "x64"
        DllName = "task_force_radio_win64.dll"
        IntermediateDirectory = Join-Path $objectDirectory "x64\$Configuration"
    },
    [PSCustomObject]@{
        Name = "Win32"
        DllName = "task_force_radio_win32.dll"
        IntermediateDirectory = Join-Path $objectDirectory "Win32\$Configuration"
    }
)

foreach ($platform in $platforms) {
    Remove-Item `
      (Join-Path $buildDirectory $platform.DllName) `
      -Force `
      -ErrorAction SilentlyContinue
}

foreach ($platform in $platforms) {
    Invoke-PluginBuild `
      -Platform $platform.Name `
      -IntermediateDirectory $platform.IntermediateDirectory `
      -MsBuild $visualStudio.MsBuild
}

$builtDlls = @()

foreach ($platform in $platforms) {
    $dllPath = Join-Path $buildDirectory $platform.DllName
    if (-not (Test-Path -LiteralPath $dllPath)) {
        throw "После сборки не найдена DLL: $dllPath"
    }

    $dll = Get-Item -LiteralPath $dllPath
    if ($dll.Length -le 0) {
        throw "Собрана пустая DLL: $dllPath"
    }

    Assert-PluginExports -Dll $dll -DumpBin $visualStudio.DumpBin

    $artifactDll = Join-Path $OutputDirectory $dll.Name
    Copy-Item -LiteralPath $dll.FullName -Destination $artifactDll -Force
    $builtDlls += Get-Item -LiteralPath $artifactDll
}

if (-not $SkipPackage) {
    $sevenZip = Find-SevenZip
    $upstreamDirectory = Join-Path $OutputDirectory "_upstream"
    $stageDirectory = Join-Path $OutputDirectory "_package-stage"
    $verifyDirectory = Join-Path $OutputDirectory "_package-verify"
    $originalPackage = Join-Path $upstreamDirectory "task_force_radio.ts3_plugin"
    $workingZip = Join-Path $OutputDirectory "tfar-classic-api26.zip"
    $installer = Join-Path $OutputDirectory "tfar-classic-api26.ts3_plugin"
    $upstreamUrl = "https://github.com/michail-nikolaev/task-force-arma-3-radio/releases/download/0.9.12/task_force_radio.ts3_plugin"
    $expectedUpstreamSize = 7694208

    New-Item -ItemType Directory -Path $upstreamDirectory -Force | Out-Null

    $needsDownload = -not (Test-Path -LiteralPath $originalPackage)
    if (-not $needsDownload) {
        $needsDownload = (Get-Item -LiteralPath $originalPackage).Length -ne $expectedUpstreamSize
    }

    if ($needsDownload) {
        $temporaryDownload = "$originalPackage.download"
        Remove-Item -LiteralPath $temporaryDownload -Force -ErrorAction SilentlyContinue
        Invoke-WebRequest -Uri $upstreamUrl -OutFile $temporaryDownload -UseBasicParsing

        if ((Get-Item -LiteralPath $temporaryDownload).Length -ne $expectedUpstreamSize) {
            throw "Размер загруженного официального пакета TFAR 0.9.12 не совпадает с ожидаемым"
        }

        Move-Item -LiteralPath $temporaryDownload -Destination $originalPackage -Force
    }

    Remove-Item -LiteralPath $stageDirectory -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $verifyDirectory -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $workingZip -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue

    $stagePlugins = Join-Path $stageDirectory "plugins"
    New-Item -ItemType Directory -Path $stagePlugins -Force | Out-Null

    foreach ($dll in $builtDlls) {
        Copy-Item -LiteralPath $dll.FullName -Destination (Join-Path $stagePlugins $dll.Name) -Force
    }

    Copy-Item -LiteralPath $originalPackage -Destination $workingZip -Force

    Write-Host "::group::Упаковка .ts3_plugin"
    Push-Location $stageDirectory
    try {
        & $sevenZip u `
          -tzip `
          $workingZip `
          ".\plugins" `
          -r `
          -mm=Deflate `
          -mx=9
        Assert-LastExitCode "Упаковка TeamSpeak-плагина"
    } finally {
        Pop-Location
        Write-Host "::endgroup::"
    }

    Copy-Item -LiteralPath $workingZip -Destination $installer -Force

    New-Item -ItemType Directory -Path $verifyDirectory -Force | Out-Null
    & $sevenZip x $installer "-o$verifyDirectory" -y | Out-Null
    Assert-LastExitCode "Распаковка установщика для проверки"

    if (-not (Test-Path -LiteralPath (Join-Path $verifyDirectory "package.ini"))) {
        throw "В установщике отсутствует package.ini"
    }

    if (-not (Test-Path -LiteralPath (Join-Path $verifyDirectory "plugins\radio-sounds"))) {
        throw "В установщике отсутствует plugins\radio-sounds"
    }

    $rootDlls = @(
        Get-ChildItem `
          -LiteralPath $verifyDirectory `
          -Filter "task_force_radio_win*.dll" `
          -File `
          -ErrorAction SilentlyContinue
    )

    if ($rootDlls.Count -ne 0) {
        throw "DLL ошибочно добавлены в корень установщика вместо plugins"
    }

    foreach ($dll in $builtDlls) {
        $packagedDllPath = Join-Path $verifyDirectory ("plugins\" + $dll.Name)
        if (-not (Test-Path -LiteralPath $packagedDllPath)) {
            throw "В установщике отсутствует plugins\$($dll.Name)"
        }

        $packagedDll = Get-Item -LiteralPath $packagedDllPath
        if ($packagedDll.Length -ne $dll.Length) {
            throw "Размер plugins\$($dll.Name) не совпадает с результатом сборки"
        }
    }

    Remove-Item -LiteralPath $stageDirectory -Recurse -Force
    Remove-Item -LiteralPath $verifyDirectory -Recurse -Force
    Remove-Item -LiteralPath $workingZip -Force
}

$resultFiles = @($builtDlls)
if (-not $SkipPackage) {
    $resultFiles += Get-Item -LiteralPath (Join-Path $OutputDirectory "tfar-classic-api26.ts3_plugin")
}

Write-Host ""
Write-Host "Готовые файлы:"
$resultFiles |
  Select-Object FullName, Length, LastWriteTime |
  Format-Table -AutoSize

Write-Host "SHA-256:"
$resultFiles |
  ForEach-Object { Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256 } |
  Select-Object Path, Hash |
  Format-Table -AutoSize