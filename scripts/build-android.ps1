param(
    [string]$ServerUrl="http://10.0.2.2:8765",
    [string[]]$Abis=@("arm64-v8a","armeabi-v7a","x86_64"),
    [ValidateSet("debug","release")]
    [string]$Profile="release"
)

$ErrorActionPreference = "Stop"
$env:GAME_SERVER_URL=$ServerUrl

$assetTarget = "android/app/src/main/assets"
New-Item -ItemType Directory -Force -Path $assetTarget | Out-Null
Copy-Item -Recurse -Force "game_client/assets/*" $assetTarget

$args = @()
foreach ($abi in $Abis) {
    $args += @("-t", $abi)
}
$args += @("-P", "31", "-o", "android/app/src/main/jniLibs", "build", "--manifest-path", "game_client/Cargo.toml")
if ($Profile -eq "release") { $args += "--release" }

cargo ndk @args
Write-Host "Native Android libraries prepared under android/app/src/main/jniLibs."
