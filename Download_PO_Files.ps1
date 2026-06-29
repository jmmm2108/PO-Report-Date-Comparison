# ─────────────────────────────────────────────────────────────────
#  Download_PO_Files.ps1
#  Downloads the latest PO_ProjectHistoryReport .xlsx files from
#  SharePoint and opens the comparison tool automatically.
# ─────────────────────────────────────────────────────────────────

$ScriptDir   = $PSScriptRoot
$HtmlTool    = Join-Path $ScriptDir "index.html"
$TokenCache  = Join-Path $ScriptDir ".sp_token_cache.json"

$TenantId    = "retiina.com"
$ClientId    = "04b07795-8ddb-461a-bbee-02f9e1bf7b46"   # Azure CLI (Microsoft first-party)
$Scopes      = "https://graph.microsoft.com/Files.Read openid profile offline_access"
$SiteHost    = "retiina.sharepoint.com"
$SitePath    = "/sites/MARS_INTERNAL"
$FolderPath  = "SUPPLY CHAIN & PROCUREMENT/Procurement Project JM/PO Changes Analysis tool"

# ── Helper: try to refresh an existing token ─────────────────────
function Refresh-Token($cache) {
    try {
        $body = @{
            client_id     = $ClientId
            grant_type    = "refresh_token"
            refresh_token = $cache.refresh_token
            scope         = $Scopes
        }
        $r = Invoke-RestMethod -Method POST `
             -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
             -Body $body -ErrorAction Stop
        return $r
    } catch { return $null }
}

# ── Helper: device-code sign-in flow ─────────────────────────────
function SignIn-DeviceCode {
    Write-Host ""
    Write-Host " Requesting sign-in..." -ForegroundColor Cyan
    $dc = Invoke-RestMethod -Method POST `
          -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/devicecode" `
          -Body @{ client_id = $ClientId; scope = $Scopes }

    Write-Host ""
    Write-Host " ┌──────────────────────────────────────────────────────┐"
    Write-Host " │  Open your browser and go to:                        │"
    Write-Host " │  https://microsoft.com/devicelogin                   │"
    Write-Host " │                                                      │"
    Write-Host " │  Enter code:  $($dc.user_code)                             │"
    Write-Host " └──────────────────────────────────────────────────────┘"
    Write-Host ""

    Start-Process "https://microsoft.com/devicelogin"

    $deadline = (Get-Date).AddSeconds($dc.expires_in)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds ([math]::Max($dc.interval, 5))
        try {
            $t = Invoke-RestMethod -Method POST `
                 -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
                 -Body @{
                     client_id   = $ClientId
                     device_code = $dc.device_code
                     grant_type  = "urn:ietf:params:oauth:grant-type:device_code"
                 } -ErrorAction Stop
            return $t
        } catch {
            $msg = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($msg.error -eq "authorization_pending") { continue }
            if ($msg.error -eq "authorization_declined") { throw "Sign-in was cancelled." }
            if ($msg.error -eq "expired_token")          { throw "Code expired. Run script again." }
        }
    }
    throw "Sign-in timed out. Run the script again."
}

# ── Get a valid access token (refresh or sign in) ────────────────
function Get-AccessToken {
    if (Test-Path $TokenCache) {
        $cache = Get-Content $TokenCache | ConvertFrom-Json
        $expiry = [datetime]$cache.expires_at
        if ((Get-Date) -lt $expiry.AddMinutes(-5)) {
            Write-Host " Using cached credentials." -ForegroundColor Green
            return $cache.access_token
        }
        Write-Host " Refreshing credentials..." -ForegroundColor Yellow
        $refreshed = Refresh-Token $cache
        if ($refreshed) {
            Save-TokenCache $refreshed
            return $refreshed.access_token
        }
    }
    $tokenResp = SignIn-DeviceCode
    Save-TokenCache $tokenResp
    return $tokenResp.access_token
}

function Save-TokenCache($t) {
    $expiry = (Get-Date).AddSeconds($t.expires_in)
    $t | Add-Member -NotePropertyName "expires_at" -NotePropertyValue $expiry.ToString("o") -Force
    $t | ConvertTo-Json | Set-Content $TokenCache -Encoding UTF8
}

# ── Main ──────────────────────────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "  PO Report Downloader" -ForegroundColor White
Write-Host "  ──────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  SharePoint folder: PO Changes Analysis tool"
Write-Host ""

try {
    $token   = Get-AccessToken
    $headers = @{ Authorization = "Bearer $token" }

    Write-Host " Fetching file list from SharePoint..." -ForegroundColor Cyan
    $graphUrl = "https://graph.microsoft.com/v1.0/sites/${SiteHost}:${SitePath}:/drive/root:/" +
                [Uri]::EscapeDataString($FolderPath) +
                ":/children?`$filter=endswith(name,'.xlsx')" +
                "&`$select=name,id,lastModifiedDateTime" +
                "&`$orderby=lastModifiedDateTime asc"

    $files = (Invoke-RestMethod -Uri $graphUrl -Headers $headers).value

    if (-not $files -or $files.Count -eq 0) {
        Write-Host " No .xlsx files found in the SharePoint folder." -ForegroundColor Yellow
        Read-Host "`n Press Enter to close"
        exit
    }

    Write-Host " Found $($files.Count) file(s):" -ForegroundColor Green
    $files | ForEach-Object { Write-Host "    $($_.name)" -ForegroundColor White }
    Write-Host ""

    foreach ($file in $files) {
        $outPath = Join-Path $ScriptDir $file.name
        Write-Host " Downloading: $($file.name)..." -NoNewline
        $dlUrl = "https://graph.microsoft.com/v1.0/sites/${SiteHost}:${SitePath}:/drive/items/$($file.id)/content"
        Invoke-RestMethod -Uri $dlUrl -Headers $headers -OutFile $outPath
        Write-Host "  Done" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host " All files downloaded. Opening comparison tool..." -ForegroundColor Cyan
    Start-Sleep -Seconds 1
    Start-Process $HtmlTool

} catch {
    Write-Host ""
    Write-Host " ERROR: $_" -ForegroundColor Red
    Write-Host ""
    # Clear bad token cache so next run forces fresh sign-in
    if (Test-Path $TokenCache) { Remove-Item $TokenCache -Force }
    Read-Host " Press Enter to close"
}
