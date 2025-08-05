# Traditional Application Deployment Script for AVD Session Hosts
# This script installs applications during VM provisioning or as a scheduled task

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = ".\app-config.json",
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Logs\AppDeployment.log",
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

# Ensure log directory exists
$logDir = Split-Path $LogPath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $LogPath -Value $logMessage
}

function Install-Application {
    param(
        [PSCustomObject]$App
    )
    
    Write-Log "Starting installation of $($App.Name)" "INFO"
    
    try {
        # Check if already installed
        if ($App.DetectionMethod -eq "Registry") {
            if (Get-ItemProperty -Path $App.DetectionPath -Name $App.DetectionProperty -ErrorAction SilentlyContinue) {
                Write-Log "$($App.Name) is already installed" "INFO"
                return $true
            }
        }
        elseif ($App.DetectionMethod -eq "File") {
            if (Test-Path $App.DetectionPath) {
                Write-Log "$($App.Name) is already installed" "INFO"
                return $true
            }
        }
        
        # Download installer if URL provided
        if ($App.DownloadUrl) {
            $installerPath = Join-Path $env:TEMP $App.InstallerFileName
            Write-Log "Downloading $($App.Name) from $($App.DownloadUrl)" "INFO"
            
            if (-not $WhatIf) {
                Invoke-WebRequest -Uri $App.DownloadUrl -OutFile $installerPath -UseBasicParsing
            }
        }
        else {
            $installerPath = $App.InstallerPath
        }
        
        # Install application
        Write-Log "Installing $($App.Name) from $installerPath" "INFO"
        
        if (-not $WhatIf) {
            $process = Start-Process -FilePath $installerPath -ArgumentList $App.InstallArguments -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0 -or $App.SuccessExitCodes -contains $process.ExitCode) {
                Write-Log "$($App.Name) installed successfully" "SUCCESS"
                return $true
            }
            else {
                Write-Log "$($App.Name) installation failed with exit code: $($process.ExitCode)" "ERROR"
                return $false
            }
        }
        else {
            Write-Log "[WHAT-IF] Would install $($App.Name)" "INFO"
            return $true
        }
    }
    catch {
        Write-Log "Error installing $($App.Name): $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Install-FromWinget {
    param([PSCustomObject]$App)
    
    Write-Log "Installing $($App.Name) using Winget" "INFO"
    
    try {
        if (-not $WhatIf) {
            winget install --id $App.WingetId --silent --accept-source-agreements --accept-package-agreements | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Log "$($App.Name) installed successfully via Winget" "SUCCESS"
                return $true
            }
            else {
                Write-Log "$($App.Name) Winget installation failed with exit code: $LASTEXITCODE" "ERROR"
                return $false
            }
        }
        else {
            Write-Log "[WHAT-IF] Would install $($App.Name) via Winget" "INFO"
            return $true
        }
    }
    catch {
        Write-Log "Error installing $($App.Name) via Winget: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Main script execution
Write-Log "Starting application deployment script" "INFO"

# Load configuration
if (-not (Test-Path $ConfigPath)) {
    Write-Log "Configuration file not found: $ConfigPath" "ERROR"
    exit 1
}

try {
    $config = Get-Content $ConfigPath | ConvertFrom-Json
    Write-Log "Loaded configuration for $($config.Applications.Count) applications" "INFO"
}
catch {
    Write-Log "Error loading configuration: $($_.Exception.Message)" "ERROR"
    exit 1
}

# Check if Winget is available
$wingetAvailable = $false
try {
    winget --version | Out-Null
    $wingetAvailable = $true
    Write-Log "Winget is available" "INFO"
}
catch {
    Write-Log "Winget is not available - will use traditional installers only" "WARNING"
}

# Install applications
$successful = 0
$failed = 0

foreach ($app in $config.Applications) {
    Write-Log "Processing application: $($app.Name)" "INFO"
    
    # Skip if conditions not met
    if ($app.Condition -and -not (Invoke-Expression $app.Condition)) {
        Write-Log "Skipping $($app.Name) - condition not met: $($app.Condition)" "INFO"
        continue
    }
    
    $success = $false
    
    # Try Winget first if available and configured
    if ($wingetAvailable -and $app.WingetId) {
        $success = Install-FromWinget -App $app
    }
    
    # Fall back to traditional installer if Winget failed or not available
    if (-not $success -and ($app.InstallerPath -or $app.DownloadUrl)) {
        $success = Install-Application -App $app
    }
    
    if ($success) {
        $successful++
    }
    else {
        $failed++
    }
    
    # Run post-install commands
    if ($success -and $app.PostInstallCommands) {
        Write-Log "Running post-install commands for $($app.Name)" "INFO"
        foreach ($command in $app.PostInstallCommands) {
            try {
                if (-not $WhatIf) {
                    Invoke-Expression $command
                    Write-Log "Post-install command executed: $command" "INFO"
                }
                else {
                    Write-Log "[WHAT-IF] Would execute: $command" "INFO"
                }
            }
            catch {
                Write-Log "Error executing post-install command '$command': $($_.Exception.Message)" "ERROR"
            }
        }
    }
}

# Summary
Write-Log "Application deployment completed" "INFO"
Write-Log "Successfully installed: $successful applications" "INFO"
Write-Log "Failed installations: $failed applications" "INFO"

if ($failed -gt 0) {
    Write-Log "Some applications failed to install. Check the log for details." "WARNING"
    exit 1
}
else {
    Write-Log "All applications installed successfully" "SUCCESS"
    exit 0
}
