param(
    [switch]$Web,
    [switch]$Android
)

$ErrorActionPreference = "Stop"

Write-Host "== Zelix Rised Trades verification ==" -ForegroundColor Cyan

if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    throw "Cargo/Rust is required. Install Rust and ensure cargo is on PATH."
}
if (-not (Get-Command gleam -ErrorAction SilentlyContinue)) {
    throw "Gleam is required. Install Gleam and ensure gleam is on PATH."
}

Write-Host "[1/4] Rust format check"
cargo fmt --manifest-path game_client/Cargo.toml -- --check

Write-Host "[2/4] Rust tests/check"
cargo test --manifest-path game_client/Cargo.toml
cargo check --manifest-path game_client/Cargo.toml

Write-Host "[3/4] Gleam format/check/tests"
gleam format --check
Push-Location .
try {
    gleam check
    gleam test
} finally {
    Pop-Location
}

Write-Host "[4/4] Asset/config sanity"
$required = @(
    "game_client/assets/bank.png",
    "game_client/assets/factory.png",
    "game_client/assets/farm.png",
    "game_client/assets/gatherer.png",
    "game_client/assets/vehicle.png",
    "game_client/assets/warehouse.png",
    "game_client/assets/game_config.json",
    "android/app/src/main/java/com/zelix_rised_trades/MainActivity.java"
)
foreach ($file in $required) {
    if (-not (Test-Path $file)) { throw "Required project file is missing: $file" }
}

if ($Web) {
    if (-not (Get-Command trunk -ErrorAction SilentlyContinue)) { throw "Trunk is required for -Web." }
    trunk build web/index.html
}

if ($Android) {
    if (-not (Get-Command cargo-ndk -ErrorAction SilentlyContinue)) { throw "cargo-ndk is required for -Android." }
    if ([string]::IsNullOrWhiteSpace($env:GAME_SERVER_URL)) {
        throw "Set GAME_SERVER_URL to a reachable server before an Android verification build."
    }
    ./scripts/build-android.ps1 -ServerUrl $env:GAME_SERVER_URL
}

Write-Host "Verification completed successfully." -ForegroundColor Green
