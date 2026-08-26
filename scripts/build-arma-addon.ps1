[CmdletBinding()]
param(
    [string]$Hemtt = "hemtt",
    [switch]$KeepStage
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Test-GitLfsPointer {
    param([Parameter(Mandatory)][string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $buffer = New-Object byte[] 64
        $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
        $header = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $bytesRead)
        return $header.StartsWith("version https://git-lfs.github.com/spec/v1")
    }
    finally {
        $stream.Dispose()
    }
}

$repo = (& git -C $PSScriptRoot rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0 -or -not $repo) {
    throw "Не удалось определить корень Git-репозитория"
}

$sourceAddon = Join-Path $repo "arma3/@task_force_radio/addons/task_force_radio"
$stageRoot = Join-Path $repo "dist/arma-addon-stage"
$stageAddon = Join-Path $stageRoot "addons/radio"
$projectConfigDirectory = Join-Path $stageRoot ".hemtt"
$artifactRoot = Join-Path $repo "dist/game-addon"
$artifactMod = Join-Path $artifactRoot "@task_force_radio"
$artifactAddons = Join-Path $artifactMod "addons"
$artifactKeys = Join-Path $artifactRoot "keys"
$archive = Join-Path $artifactRoot "tfar-classic-game.zip"
$hemttLog = Join-Path $stageRoot "hemtt-release.log"

if (-not (Test-Path $sourceAddon)) {
    throw "Исходники игрового аддона не найдены: $sourceAddon"
}

$lfsPointers = Get-ChildItem $sourceAddon -File -Recurse |
    Where-Object { Test-GitLfsPointer -Path $_.FullName }

if ($lfsPointers) {
    $paths = ($lfsPointers | ForEach-Object { $_.FullName }) -join [Environment]::NewLine
    throw "Не загружены Git LFS-файлы игрового аддона. Выполните git lfs pull.`n$paths"
}

$hemttCommand = Get-Command $Hemtt -ErrorAction SilentlyContinue
if (-not $hemttCommand) {
    throw "HEMTT не найден. Установите его командой: winget install hemtt"
}

if (Test-Path $stageRoot) {
    Remove-Item $stageRoot -Recurse -Force
}
if (Test-Path $artifactRoot) {
    Remove-Item $artifactRoot -Recurse -Force
}

New-Item $stageAddon -ItemType Directory -Force | Out-Null
New-Item $projectConfigDirectory -ItemType Directory -Force | Out-Null
New-Item $artifactAddons -ItemType Directory -Force | Out-Null
New-Item $artifactKeys -ItemType Directory -Force | Out-Null

Copy-Item (Join-Path $sourceAddon "*") $stageAddon -Recurse -Force

# HEMTT rejects UTF-8 BOM markers in included config files. Classic 0.9.12
# contains one in description.h, so normalize text files only in the temporary
# staging tree and leave the historical source files untouched.
$textExtensions = @(".cpp", ".h", ".hpp", ".inc", ".sqf", ".xml")
Get-ChildItem $stageAddon -File -Recurse |
    Where-Object { $_.Extension.ToLowerInvariant() -in $textExtensions } |
    ForEach-Object {
        $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
        if (
            $bytes.Length -ge 3 -and
            $bytes[0] -eq 0xEF -and
            $bytes[1] -eq 0xBB -and
            $bytes[2] -eq 0xBF
        ) {
            $withoutBom = New-Object byte[] ($bytes.Length - 3)
            [System.Array]::Copy($bytes, 3, $withoutBom, 0, $withoutBom.Length)
            [System.IO.File]::WriteAllBytes($_.FullName, $withoutBom)
        }
    }

Set-Content -Path (Join-Path $stageAddon '$PBOPREFIX$') -Value "task_force_radio" -NoNewline

@'
ignore_pboprefix = true

[binarize]
enabled = false

# Classic UI resources use legacy runtime expressions (for example,
# `safezoneW`) that Arma accepts but modern HEMTT rapify rejects.
[rapify]
enabled = false

[files]
exclude = [
    "**/.gitattributes",
    "**/*.psd",
]
'@ | Set-Content -Path (Join-Path $stageAddon "addon.toml")

@'
name = "TFAR Classic"
prefix = "task_force"

[version]
major = 0
minor = 9
patch = 12
git_hash = 8

[signing]
authority = "tfar_classic_dev"

[hemtt.release]
archive = false
'@ | Set-Content -Path (Join-Path $projectConfigDirectory "project.toml")

Push-Location $stageRoot
try {
    & $hemttCommand.Source release --no-bin --no-archive *> $hemttLog
    $hemttExitCode = $LASTEXITCODE

    $hemttLines = Get-Content $hemttLog
    $hemttDiagnostics = $hemttLines |
        Where-Object { $_ -notmatch "TRACE" } |
        Select-Object -Last 80

    Write-Host "Диагностика HEMTT:"
    if ($hemttDiagnostics) {
        $hemttDiagnostics | ForEach-Object { Write-Host $_ }
    }
    else {
        $hemttLines | Select-Object -Last 20 | ForEach-Object { Write-Host $_ }
    }

    if ($hemttExitCode -ne 0) {
        throw "HEMTT завершил сборку с кодом $hemttExitCode. Полный журнал: $hemttLog"
    }
}
finally {
    Pop-Location
}

$releaseRoot = Join-Path $stageRoot ".hemttout/release"
$pbo = Get-ChildItem $releaseRoot -Filter "task_force_radio.pbo" -File -Recurse |
    Select-Object -First 1
$signature = Get-ChildItem $releaseRoot -Filter "task_force_radio.pbo.*.bisign" -File -Recurse |
    Select-Object -First 1
$publicKey = Get-ChildItem $releaseRoot -Filter "*.bikey" -File -Recurse |
    Select-Object -First 1

if (-not $pbo) {
    throw "HEMTT не создал task_force_radio.pbo"
}
if (-not $signature -or -not $publicKey) {
    throw "HEMTT не создал подпись PBO или публичный ключ"
}

Copy-Item $pbo.FullName $artifactAddons -Force
Copy-Item $signature.FullName $artifactAddons -Force
Copy-Item $publicKey.FullName $artifactKeys -Force

@'
TFAR Classic — тестовый игровой аддон

Архив не является самостоятельным модом. Наложите папку @task_force_radio
на установленный оригинальный TFAR 0.9.12 с заменой task_force_radio.pbo.
Остальные файлы оригинального мода, включая task_force_radio_items.pbo и
task_force_radio_pipe.dll, должны остаться на месте.

Для сервера с verifySignatures скопируйте приложенный .bikey в серверную
папку keys. Ключ CI предназначен только для тестовых сборок.
'@ | Set-Content -Path (Join-Path $artifactRoot "README.txt")

Compress-Archive -Path (Join-Path $artifactRoot "@task_force_radio"), (Join-Path $artifactRoot "keys"), (Join-Path $artifactRoot "README.txt") -DestinationPath $archive -CompressionLevel Optimal -Force

Write-Host ""
Write-Host "Игровой аддон собран:"
Get-Item $pbo.FullName, $signature.FullName, $publicKey.FullName, $archive |
    Select-Object FullName, Length, LastWriteTime

Write-Host ""
Write-Host "SHA-256:"
Get-FileHash $pbo.FullName, $signature.FullName, $publicKey.FullName, $archive -Algorithm SHA256 |
    Select-Object Path, Hash

if (-not $KeepStage) {
    Remove-Item $stageRoot -Recurse -Force
}
