# MSIX App Attach Package Creation Script
# This script helps create MSIX packages for Azure Virtual Desktop

param(
    [Parameter(Mandatory=$true)]
    [string]$AppPath,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputPath,
    
    [Parameter(Mandatory=$true)]
    [string]$PackageName,
    
    [Parameter(Mandatory=$false)]
    [string]$VHDSize = "1GB",
    
    [Parameter(Mandatory=$false)]
    [string]$DriveLetter = "X"
)

# Check if MSIX Packaging Tool is available
if (-not (Get-Command "MsixPackagingTool.exe" -ErrorAction SilentlyContinue)) {
    Write-Error "MSIX Packaging Tool not found. Please install it from Microsoft Store or download from Microsoft."
    Write-Host "Download: https://www.microsoft.com/en-us/p/msix-packaging-tool/9n5lw3jbp7m5"
    exit 1
}

Write-Host "🚀 Starting MSIX App Attach package creation for: $PackageName" -ForegroundColor Green

# Step 1: Create VHD for the MSIX package
Write-Host "📦 Creating VHD file..." -ForegroundColor Yellow

$vhdPath = Join-Path $OutputPath "$PackageName.vhd"

# Create VHD using PowerShell
$vhd = New-VHD -Path $vhdPath -SizeBytes ([int64]::Parse($VHDSize.Replace("GB", "")) * 1GB) -Dynamic

# Mount VHD
$mountedVhd = Mount-VHD -Path $vhdPath -Passthru
$disk = $mountedVhd | Get-Disk

# Initialize and format the VHD
$disk | Initialize-Disk -PartitionStyle GPT
$partition = $disk | New-Partition -UseMaximumSize -DriveLetter $DriveLetter
$partition | Format-Volume -FileSystem NTFS -NewFileSystemLabel $PackageName -Confirm:$false

Write-Host "✅ VHD created and mounted at $DriveLetter`:" -ForegroundColor Green

# Step 2: Create MSIX package configuration
Write-Host "🔧 Preparing MSIX package configuration..." -ForegroundColor Yellow

$msixConfig = @{
    PackageName = $PackageName
    VHDPath = $vhdPath
    MountPath = "$DriveLetter`:"
    AppPath = $AppPath
}

# Create manifest template
$manifestTemplate = @"
<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
         xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
         xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities">
  <Identity Name="$PackageName"
            Publisher="CN=YourCompany"
            Version="1.0.0.0" />
  <Properties>
    <DisplayName>$PackageName</DisplayName>
    <PublisherDisplayName>Your Company</PublisherDisplayName>
    <Description>$PackageName for Azure Virtual Desktop</Description>
  </Properties>
  <Dependencies>
    <TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.19041.0" MaxVersionTested="10.0.22000.0" />
  </Dependencies>
  <Capabilities>
    <rescap:Capability Name="runFullTrust" />
  </Capabilities>
</Package>
"@

$manifestPath = Join-Path $OutputPath "AppxManifest.xml"
$manifestTemplate | Out-File -FilePath $manifestPath -Encoding UTF8

Write-Host "✅ MSIX configuration prepared" -ForegroundColor Green

# Step 3: Instructions for manual MSIX creation
Write-Host "`n📋 Next Steps for MSIX Package Creation:" -ForegroundColor Cyan
Write-Host "1. Open MSIX Packaging Tool" -ForegroundColor White
Write-Host "2. Select 'Create your app package'" -ForegroundColor White
Write-Host "3. Choose 'Create package on this computer'" -ForegroundColor White
Write-Host "4. Select the installer: $AppPath" -ForegroundColor White
Write-Host "5. Configure package information:" -ForegroundColor White
Write-Host "   - Package name: $PackageName" -ForegroundColor Gray
Write-Host "   - Package display name: $PackageName" -ForegroundColor Gray
Write-Host "   - Publisher: CN=YourCompany" -ForegroundColor Gray
Write-Host "   - Version: 1.0.0.0" -ForegroundColor Gray
Write-Host "6. Follow the installation wizard" -ForegroundColor White
Write-Host "7. Save the package to: $OutputPath" -ForegroundColor White

# Step 4: Create PowerShell script for MSIX App Attach
$msixAttachScript = @"
# MSIX App Attach Configuration Script for $PackageName
# Run this on session hosts to configure MSIX App Attach

# Variables
`$vhdPath = "\\\\storageaccount.file.core.windows.net\\msixapps\\$PackageName.vhd"
`$packageName = "$PackageName"

Write-Host "Configuring MSIX App Attach for: `$packageName"

try {
    # Mount VHD
    `$mountResult = Mount-VHD -Path `$vhdPath -ReadOnly -Passthru
    `$driveLetter = (`$mountResult | Get-Disk | Get-Partition | Get-Volume).DriveLetter
    
    Write-Host "VHD mounted successfully at drive `$driveLetter"
    
    # Register MSIX package
    `$msixPath = "`$driveLetter`:\\*.msix"
    Add-AppxPackage -Path `$msixPath -DisableDevelopmentMode
    
    Write-Host "MSIX package registered successfully"
    
    # Create registry entries for app attach
    `$regPath = "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\`$packageName"
    New-Item -Path `$regPath -Force
    Set-ItemProperty -Path `$regPath -Name "(Default)" -Value "`$driveLetter`:\\app.exe"
    
    Write-Host "Registry entries created"
}
catch {
    Write-Error "Failed to configure MSIX App Attach: `$(`$_.Exception.Message)"
}
"@

$attachScriptPath = Join-Path $OutputPath "Configure-$PackageName-AppAttach.ps1"
$msixAttachScript | Out-File -FilePath $attachScriptPath -Encoding UTF8

Write-Host "`n🎯 Additional Files Created:" -ForegroundColor Cyan
Write-Host "- VHD file: $vhdPath" -ForegroundColor White
Write-Host "- Manifest template: $manifestPath" -ForegroundColor White
Write-Host "- App Attach script: $attachScriptPath" -ForegroundColor White

# Step 5: Create deployment instructions
$deploymentInstructions = @"
# MSIX App Attach Deployment Instructions for $PackageName

## Prerequisites
1. Azure Virtual Desktop environment with Entra ID join
2. Premium file share for MSIX packages
3. Proper RBAC permissions on storage account

## Deployment Steps

### 1. Upload VHD to Azure Files
Upload the created VHD file to your Azure Files share:
- VHD Path: $vhdPath
- Target: \\\\<storageaccount>.file.core.windows.net\\msixapps\\

### 2. Configure Host Pool
Use Azure Portal or PowerShell to add MSIX package to host pool:

```powershell
# Add MSIX package to host pool
`$hostPoolName = "your-host-pool"
`$resourceGroupName = "your-resource-group"
`$imagePath = "\\\\<storageaccount>.file.core.windows.net\\msixapps\\$PackageName.vhd"

New-AzWvdMsixPackage -HostPoolName `$hostPoolName -ResourceGroupName `$resourceGroupName -PackageAlias "$PackageName" -ImagePath `$imagePath -IsActive:`$true
```

### 3. Assign to Users
Assign the MSIX package to user groups through Azure Portal or PowerShell.

### 4. Test Deployment
1. Log in to AVD session
2. Verify application appears in Start menu
3. Launch application and test functionality

## Troubleshooting
- Check VHD file permissions
- Verify storage account connectivity
- Review AVD agent logs
- Ensure proper MSIX package signing
"@

$instructionsPath = Join-Path $OutputPath "Deployment-Instructions-$PackageName.md"
$deploymentInstructions | Out-File -FilePath $instructionsPath -Encoding UTF8

Write-Host "- Deployment instructions: $instructionsPath" -ForegroundColor White

# Cleanup - Dismount VHD
Write-Host "`n🧹 Cleaning up..." -ForegroundColor Yellow
Dismount-VHD -Path $vhdPath
Write-Host "✅ VHD dismounted" -ForegroundColor Green

Write-Host "`n🎉 MSIX App Attach package preparation complete!" -ForegroundColor Green
Write-Host "Next: Follow the manual steps above to create the actual MSIX package" -ForegroundColor Yellow
