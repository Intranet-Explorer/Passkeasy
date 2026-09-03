#Requires -Version 7.0
<#
.SYNOPSIS
    Simple menu-driven wrapper for the YubiEnroll CLI.
.NOTES
    Run as a normal user. YubiEnroll handles its own UAC elevation when needed.
    Default path: C:\Program Files\Yubico\YubiEnroll\yubienroll.exe
#>

# $Script: scope makes these variables available to all functions in the file,
# but not outside of it. Good for shared config that nothing else should touch.
$Script:YubiEnrollPath = "C:\Program Files\Yubico\YubiEnroll\yubienroll.exe"
$Script:Version        = "1.0.0"


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

# Downloads the YubiEnroll MSI from Yubico's download page and installs it silently.
# Returns $true on success, $false on failure.
function Install-YubiEnroll {
    $downloadPage = "https://www.yubico.com/support/download/"

    # Fallback URL in case the download page can't be parsed.
    $fallbackUrl = "https://downloads.yubico.com/support/yubienroll-1.1.1-win64.msi"

    Write-Host "`nAttempting to download YubiEnroll from Yubico..." -ForegroundColor Cyan

    try {
        # Try to find the latest MSI link from the downloads page.
        # The link is a plain <a> tag so -UseBasicParsing is sufficient (no JS needed).
        Write-Host "Checking for latest version..." -ForegroundColor DarkGray
        $html = Invoke-WebRequest -Uri $downloadPage -UseBasicParsing -ErrorAction Stop
        $msiUrl = ($html.Links |
            Where-Object { $_.href -match 'yubienroll.*\.msi($|\?)' } |
            Select-Object -First 1).href

        if ([string]::IsNullOrWhiteSpace($msiUrl)) {
            Write-Host "Could not find link on download page, using fallback URL." -ForegroundColor DarkYellow
            $msiUrl = $fallbackUrl
        }

        # Resolve relative URLs just in case.
        if ($msiUrl -notmatch '^https?://') {
            $base = [System.Uri]$downloadPage
            $msiUrl = "$($base.Scheme)://$($base.Host)$msiUrl"
        }

        $installerPath = Join-Path $env:TEMP "YubiEnrollSetup.msi"
        Write-Host "Downloading: $msiUrl" -ForegroundColor DarkGray

        # -OutFile streams directly to disk so large files don't sit in memory.
        Invoke-WebRequest -Uri $msiUrl -OutFile $installerPath -UseBasicParsing -ErrorAction Stop

        Write-Host "Running installer (a UAC prompt may appear)..." -ForegroundColor Cyan

        # msiexec /quiet suppresses the UI; /norestart prevents an automatic reboot.
        # -Verb RunAs triggers UAC elevation. -Wait blocks until the installer exits.
        $proc = Start-Process msiexec.exe `
            -ArgumentList "/i `"$installerPath`" /quiet /norestart" `
            -Verb RunAs -PassThru -Wait -ErrorAction Stop

        # Clean up the temporary installer regardless of outcome.
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

        if (Test-Path $Script:YubiEnrollPath) {
            Write-Host "YubiEnroll installed successfully!`n" -ForegroundColor Green
            return $true
        }

        # Installer ran but exe isn't where we expect — likely a non-default install dir.
        Write-Host "Installation finished, but YubiEnroll was not found at:" -ForegroundColor Red
        Write-Host "  $Script:YubiEnrollPath" -ForegroundColor Yellow
        Write-Host "If you installed to a custom location, update `$Script:YubiEnrollPath at the top of this script." -ForegroundColor Yellow
        return $false

    } catch {
        Write-Host "Auto-install failed: $_" -ForegroundColor Red
        Write-Host "Please install manually from: $downloadPage" -ForegroundColor Yellow

        # Open the downloads page in the default browser as a fallback.
        Start-Process $downloadPage
        return $false
    }
}

# Checks whether the executable exists. Returns $true or $false.
# If missing, offers to auto-download and install before giving up.
# PowerShell functions implicitly return the last value in the pipeline,
# but 'return' makes intent explicit and exits the function immediately.
function Test-YubiEnrollInstalled {
    if (Test-Path $Script:YubiEnrollPath) { return $true }

    Write-Host "YubiEnroll not found at: $Script:YubiEnrollPath" -ForegroundColor Yellow
    Write-Host ""

    $answer = Read-Host "Download and install YubiEnroll now? [Y/n]"

    # -notmatch '^[Nn]' means anything other than N/n is treated as yes.
    if ($answer -notmatch '^[Nn]') {
        return (Install-YubiEnroll)
    }

    Write-Host "Download manually from: https://www.yubico.com/support/download/yubienroll/" -ForegroundColor Yellow
    return $false
}

# Runs a YubiEnroll command and prints separators around the output.
# [string[]] declares the parameter as a string array.
# Without a param() block, PS7 still accepts positional parameters like this.
function Invoke-YubiEnroll ([string[]]$Arguments) {
    # -join ' ' collapses the array into a single display string with spaces between elements.
    # $(...) is a subexpression — needed here so -join applies before string interpolation.
    Write-Host "`n> yubienroll $($Arguments -join ' ')" -ForegroundColor DarkGray
    Write-Host ("-" * 60) -ForegroundColor DarkGray

    # & is the call operator — it runs an executable stored in a variable.
    # @Arguments is splatting: unpacks the array and passes each element as a
    # separate argument, just as if you had typed them out individually.
    & $Script:YubiEnrollPath @Arguments

    Write-Host ("-" * 60) -ForegroundColor DarkGray
}

# Waits for Enter before returning to the menu.
# $null = discards the return value of Read-Host (we don't care what they typed).
function Pause-ForUser {
    $null = Read-Host "`nPress Enter to return to the menu"
}

# Keeps prompting until the user enters something non-blank.
# do/while always runs the body at least once, then checks the condition.
# [string]::IsNullOrWhiteSpace() is a .NET static method — :: calls static members.
function Read-NonEmptyInput ([string]$Prompt) {
    do {
        $value = Read-Host $Prompt
    } while ([string]::IsNullOrWhiteSpace($value))

    # .Trim() removes leading and trailing whitespace from the string.
    return $value.Trim()
}

# Clears the screen and prints the header. Called at the start of every menu.
function Show-Header {
    Clear-Host   # equivalent to 'cls' — wipes the terminal for a clean menu
    Write-Host ""
    Write-Host "    ____  ___   __________ __ __ _________   _______  __  " -ForegroundColor Cyan
    Write-Host "   / __ \/   | / ___/ ___// //_// ____/   | / ___/\ \/ /  " -ForegroundColor Cyan
    Write-Host "  / /_/ / /| | \__ \\__ \/ ,<  / __/ / /| | \__ \  \  /  " -ForegroundColor Cyan
    Write-Host " / ____/ ___ |___/ /__/ / /| |/ /___/ ___ |___/ /  / /   " -ForegroundColor Cyan
    Write-Host "/_/   /_/  |_/____/____/_/ |_/_____/_/  |_/____/  /_/    " -ForegroundColor Cyan
    Write-Host ""
    Write-Host "       .: yubikey enrollment made easy  ·  v$($Script:Version) :." -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  ·─────────────────────────────────────────────────────·  " -ForegroundColor DarkGray
    Write-Host ""
}


# ─────────────────────────────────────────────────────────────────────────────
# MENU ACTIONS
# One function per menu option. Each calls Invoke-YubiEnroll with the right
# arguments, then waits for the user before returning to the menu.
# ─────────────────────────────────────────────────────────────────────────────

function Show-Status {
    Show-Header
    Write-Host "[ Status & Authentication ]`n" -ForegroundColor Yellow
    # Passing a single string to a [string[]] parameter — PS7 auto-wraps it in an array.
    Invoke-YubiEnroll "status"
    Pause-ForUser
}

function Invoke-Login {
    Show-Header
    Write-Host "[ Login to Identity Provider ]`n" -ForegroundColor Yellow
    $answer = Read-Host "Open browser automatically? [Y/n]"

    # PS7 ternary operator: condition ? value-if-true : value-if-false
    # -match tests a string against a regex pattern. '^[Nn]' means: starts with N or n.
    # The comma between strings builds an array inline — no @() required.
    $loginArgs = $answer -match '^[Nn]' ? ("login", "--no-launch-browser") : ("login")
    Invoke-YubiEnroll $loginArgs
    Pause-ForUser
}

function Invoke-Logout {
    Show-Header
    Write-Host "[ Logout from Active Provider ]`n" -ForegroundColor Yellow
    Write-Host "Note: Logout is currently only supported for Okta." -ForegroundColor DarkYellow
    Invoke-YubiEnroll "logout"
    Pause-ForUser
}

function Invoke-EnrollUser {
    Show-Header
    Write-Host "[ Enroll YubiKey for End User ]`n" -ForegroundColor Yellow
    Write-Host "Tip: Use 'Search Users' to find the UPN or Object ID first." -ForegroundColor DarkGray

    $userId = Read-NonEmptyInput "Enter User UPN or Object ID (e.g. user@domain.com)"

    # Start with the required base arguments.
    # @() creates an array. These three are always included.
    $enrollArgs = @("credentials", "add", $userId)

    # For each optional flag, only add it if the user typed something.
    # += on an array creates a new array each time — fine for small collections like this.
    # Note: named $profileName, not $profile — $profile is a PowerShell automatic
    # variable (the current user's profile script path) and shadowing it is a trap.
    $profileName = Read-Host "Enrollment profile name? (leave blank to skip)"
    if (-not [string]::IsNullOrWhiteSpace($profileName)) {
        $enrollArgs += "--profile", $profileName.Trim()   # comma builds a 2-element array, += appends it
    }

    $displayName = Read-Host "Display name for the Security Key? (leave blank to skip)"
    if (-not [string]::IsNullOrWhiteSpace($displayName)) {
        $enrollArgs += "--name", $displayName.Trim()
    }

    $reader = Read-Host "NFC smart card reader name? (leave blank to skip)"
    if (-not [string]::IsNullOrWhiteSpace($reader)) {
        $enrollArgs += "--reader", $reader.Trim()
    }

    $confirm = Read-Host "Skip confirmation prompts? [y/N]"
    if ($confirm -match '^[Yy]') {
        $enrollArgs += "--yes"
    }

    Invoke-YubiEnroll $enrollArgs
    Pause-ForUser
}

function Show-UserCredentials {
    Show-Header
    Write-Host "[ List Credentials for User ]`n" -ForegroundColor Yellow
    $userId = Read-NonEmptyInput "Enter User UPN or Object ID"
    # Passing multiple strings separated by commas — PS7 builds them into an array on the spot.
    Invoke-YubiEnroll "credentials", "list", $userId
    Pause-ForUser
}

function Remove-UserCredentials {
    Show-Header
    Write-Host "[ Delete Credentials for User ]`n" -ForegroundColor Yellow
    Write-Host "Tip: Run 'List Credentials' first to find the credential ID." -ForegroundColor DarkGray

    $userId = Read-NonEmptyInput "Enter User UPN or Object ID"
    $credId = Read-Host "Credential ID to delete? (leave blank to select interactively)"

    # Ternary to pick which argument set to use based on whether $credId was provided.
    # The backtick ` at the end of a line is PS line continuation — lets us split a long
    # expression across two lines for readability.
    $deleteArgs = [string]::IsNullOrWhiteSpace($credId) `
        ? @("credentials", "delete", $userId) `
        : @("credentials", "delete", $userId, $credId.Trim())

    Invoke-YubiEnroll $deleteArgs
    Pause-ForUser
}

function Search-Users {
    Show-Header
    Write-Host "[ Search for Users ]`n" -ForegroundColor Yellow
    $query = Read-NonEmptyInput "Enter search query (name, username, or email)"
    Invoke-YubiEnroll "users", $query
    Pause-ForUser
}

function Show-Readers {
    Show-Header
    Write-Host "[ List Smart Card / NFC Readers ]`n" -ForegroundColor Yellow
    Invoke-YubiEnroll "readers"
    Pause-ForUser
}


# ─────────────────────────────────────────────────────────────────────────────
# PROFILES SUBMENU
# ─────────────────────────────────────────────────────────────────────────────

function Show-ProfilesMenu {
    # do/while $true is an infinite loop. The only exits are 'return' inside the loop.
    do {
        Show-Header
        Write-Host "[ Enrollment Profiles ]`n" -ForegroundColor Yellow
        Write-Host "  1. List profiles"
        Write-Host "  2. Add a profile"
        Write-Host "  3. Delete a profile"
        Write-Host "  B. Back"
        Write-Host ""

        # Wrapping Read-Host in (...).ToUpper() normalizes input so 'b' and 'B' both match.
        # switch evaluates the value against each label and runs the matching block.
        switch ((Read-Host "Select option").ToUpper()) {
            "1" {
                Invoke-YubiEnroll "profiles", "list"
                Pause-ForUser
            }
            "2" {
                $name = Read-NonEmptyInput "New profile name"
                Invoke-YubiEnroll "profiles", "add", $name
                Pause-ForUser
            }
            "3" {
                $name = Read-NonEmptyInput "Profile name to delete"
                # -match against '^[Yy]' checks if they typed Y or y
                if ((Read-Host "Delete '$name'? [y/N]") -match '^[Yy]') {
                    Invoke-YubiEnroll "profiles", "delete", $name
                } else {
                    Write-Host "Cancelled." -ForegroundColor DarkGray
                }
                Pause-ForUser
            }
            "B"     { return }   # 'return' exits the function, breaking out of the loop
            default { Write-Host "Invalid option." -ForegroundColor Red; Start-Sleep 1 }
        }
    } while ($true)
}


# ─────────────────────────────────────────────────────────────────────────────
# PROVIDERS SUBMENU
# ─────────────────────────────────────────────────────────────────────────────

function Show-ProvidersMenu {
    do {
        Show-Header
        Write-Host "[ Identity Provider Configurations ]`n" -ForegroundColor Yellow
        Write-Host "  1. List providers"
        Write-Host "  2. Show provider details"
        Write-Host "  3. Add a provider"
        Write-Host "  4. Activate a provider"
        Write-Host "  5. Delete a provider"
        Write-Host "  B. Back"
        Write-Host ""

        switch ((Read-Host "Select option").ToUpper()) {
            "1" { Invoke-YubiEnroll "providers", "list";                                             Pause-ForUser }
            "2" { $n = Read-NonEmptyInput "Provider name";        Invoke-YubiEnroll "providers", "show", $n;     Pause-ForUser }
            "3" { $n = Read-NonEmptyInput "New provider name";    Invoke-YubiEnroll "providers", "add", $n;      Pause-ForUser }
            "4" { $n = Read-NonEmptyInput "Provider to activate"; Invoke-YubiEnroll "providers", "activate", $n; Pause-ForUser }
            "5" {
                $n = Read-NonEmptyInput "Provider name to delete"
                if ((Read-Host "Delete '$n'? [y/N]") -match '^[Yy]') {
                    # --yes tells YubiEnroll to skip its own confirmation prompt
                    Invoke-YubiEnroll "providers", "delete", "--yes", $n
                } else {
                    Write-Host "Cancelled." -ForegroundColor DarkGray
                }
                Pause-ForUser
            }
            "B"     { return }
            default { Write-Host "Invalid option." -ForegroundColor Red; Start-Sleep 1 }
        }
    } while ($true)
}


# ─────────────────────────────────────────────────────────────────────────────
# MAIN MENU
# ─────────────────────────────────────────────────────────────────────────────

function Show-MainMenu {
    # Guard clause: check the prerequisite up front and bail early if it fails.
    # This avoids wrapping everything in a big if-block.
    if (-not (Test-YubiEnrollInstalled)) { return }

    do {
        Show-Header
        Write-Host "  1.  Show Status / Auth State"
        Write-Host "  2.  Login to Identity Provider"
        Write-Host "  3.  Logout from Identity Provider"
        Write-Host ""
        Write-Host "  4.  Search for Users"
        Write-Host "  5.  Enroll YubiKey for User"
        Write-Host "  6.  List Credentials for User"
        Write-Host "  7.  Delete Credentials for User"
        Write-Host ""
        Write-Host "  8.  Manage Enrollment Profiles"
        Write-Host "  9.  Manage Identity Providers"
        Write-Host "  10. List Smart Card Readers"
        Write-Host ""
        Write-Host "  Q.  Quit"
        Write-Host ""

        switch ((Read-Host "Select option").ToUpper()) {
            "1"     { Show-Status }
            "2"     { Invoke-Login }
            "3"     { Invoke-Logout }
            "4"     { Search-Users }
            "5"     { Invoke-EnrollUser }
            "6"     { Show-UserCredentials }
            "7"     { Remove-UserCredentials }
            "8"     { Show-ProfilesMenu }
            "9"     { Show-ProvidersMenu }
            "10"    { Show-Readers }
            "Q"     { Write-Host "`nGoodbye.`n" -ForegroundColor Cyan; return }
            default { Write-Host "Invalid option. Please try again." -ForegroundColor Red; Start-Sleep 1 }
        }
    } while ($true)
}


# ─────────────────────────────────────────────────────────────────────────────
# ENTRY POINT
# Everything above is just function definitions — nothing actually runs until here.
# ─────────────────────────────────────────────────────────────────────────────
Show-MainMenu