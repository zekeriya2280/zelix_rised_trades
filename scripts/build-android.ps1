param([string]$ServerUrl="http://10.0.2.2:8765", [string]$OutputDir="android/app/src/main/jniLibs")
$env:GAME_SERVER_URL=$ServerUrl
cargo ndk -t arm64-v8a -P 31 -o $OutputDir build --manifest-path game_client/Cargo.toml
