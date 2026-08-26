param(
    [string]$ServerUrl="",
    [string[]]$Abis=@("arm64-v8a","armeabi-v7a","x86_64"),
    [ValidateSet("debug","release")]
    [string]$Profile="release"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ServerUrl)) {
    if ($Profile -eq "release") {
        throw "Release Android build requires -ServerUrl with the public HTTPS/WSS-capable game server endpoint."
    }
    $ServerUrl = "http://10.0.2.2:8765"
}
if ($Profile -eq "release" -and $ServerUrl -notmatch '^https://') {
    throw "Release ServerUrl must use https:// so browser/WebSocket traffic can use secure wss:// transport."
}
if ($Profile -eq "debug" -and $ServerUrl -notmatch '^https?://') {
    throw "ServerUrl must start with http:// or https://."
}
$env:GAME_SERVER_URL=$ServerUrl

$assetTarget = "android/app/src/main/assets"
New-Item -ItemType Directory -Force -Path $assetTarget | Out-Null
Copy-Item -Recurse -Force "game_client/assets/*" $assetTarget
@{ server_url = $ServerUrl } | ConvertTo-Json -Compress | Set-Content -Path "$assetTarget/game_config.json" -Encoding utf8

$args = @()
foreach ($abi in $Abis) {
    $args += @("-t", $abi)
}
$args += @("-P", "31", "-o", "android/app/src/main/jniLibs", "build", "--manifest-path", "game_client/Cargo.toml")
if ($Profile -eq "release") { $args += "--release" }

cargo ndk @args
Write-Host "Native Android libraries prepared under android/app/src/main/jniLibs."
