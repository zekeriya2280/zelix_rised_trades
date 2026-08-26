param([string]$ServerUrl="")
$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($ServerUrl)) {
    Write-Host "GAME_SERVER_URL not supplied; web client will use the current page origin."
    Remove-Item Env:GAME_SERVER_URL -ErrorAction SilentlyContinue
} else {
    if ($ServerUrl -notmatch '^https?://') { throw "ServerUrl must start with http:// or https://." }
    $env:GAME_SERVER_URL=$ServerUrl.TrimEnd('/')
}
trunk build web/index.html
