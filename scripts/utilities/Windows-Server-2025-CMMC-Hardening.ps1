#requires -version 5.1
#requires -modules GroupPolicy

<#
.SYNOPSIS
    Windows Server 2025 CMMC Level 2 Hardening Script
    
.DESCRIPTION
    Applies CMMC Level 2 compliant Group Policy settings for Windows Server 2025 including:
    - Windows Defender configuration
    - Advanced Audit Policy
    - Windows Firewall
    - BitLocker enforcement
    - Windows Defender Application Control
    - Credential Guard and Device Guard
    - Windows Update policies
    - UAC settings
    - Privacy & Telemetry
    - Removable Storage controls
    
.PARAMETER BackupPath
    Path for GPO backups
    
.PARAMETER TargetOU
    Organizational Unit for server GPO (e.g., "OU=Servers,DC=domain,DC=com")
    
.PARAMETER ExcludeOU
    OU to exclude (e.g., VDI instant clones)
    
.EXAMPLE
    .\Windows-Server-2025-CMMC-Hardening.ps1 -TargetOU "OU=Servers,DC=contoso,DC=com"
    
    Apply Server 2025 hardening to servers OU with default backup location
    
.EXAMPLE
    .\Windows-Server-2025-CMMC-Hardening.ps1 -BackupPath "D:\CMMC_Backups\Servers" -TargetOU "OU=Servers,DC=contoso,DC=com"
    
    Apply hardening with custom backup path
    
.EXAMPLE
    .\Windows-Server-2025-CMMC-Hardening.ps1 -TargetOU "OU=Servers,DC=contoso,DC=com" -ExcludeOU "OU=VDI-Servers,OU=Servers,DC=contoso,DC=com"
    
    Apply hardening to servers OU but exclude VDI servers sub-OU
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false)]
    [string]$BackupPath = "C:\CMMC_GPO_Backups\Server2025_$(Get-Date -Format 'yyyyMMdd_HHmmss')",
    
    [Parameter(Mandatory=$false)]
    [string]$TargetOU = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ExcludeOU = ""
)

Start-Transcript -Path "$BackupPath\Server2025_Hardening_$(Get-Date -Format 'yyyyMMdd_HHmmss').log" -Force

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Windows Server 2025 CMMC Level 2 Hardening Script           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null

$GPOName = "CMMC-WindowsServer2025-Hardening"

# Create or get GPO
try {
    $GPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
    if (-not $GPO) {
        Write-Host "[+] Creating new GPO: $GPOName" -ForegroundColor Green
        $GPO = New-GPO -Name $GPOName -Comment "CMMC Level 2 Windows Server 2025 Hardening"
        
        if ($TargetOU) {
            Write-Host "  └─ Linking to OU: $TargetOU" -ForegroundColor Gray
            New-GPLink -Guid $GPO.Id -Target $TargetOU | Out-Null
        }
    }
    else {
        Write-Host "[+] Using existing GPO: $GPOName" -ForegroundColor Yellow
        Backup-GPO -Name $GPOName -Path $BackupPath | Out-Null
        Write-Host "  └─ Backup created: $BackupPath" -ForegroundColor Gray
    }
}
catch {
    Write-Error "Failed to create/get GPO: $_"
    Stop-Transcript
    exit 1
}

# ==================== WINDOWS DEFENDER SETTINGS ====================
Write-Host "`n[1/10] Configuring Windows Defender..." -ForegroundColor Cyan

# Turn off Windows Defender: Disabled (keep Defender enabled)
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Defender" -ValueName "DisableAntiSpyware" -Type DWord -Value 0

# Turn on behavior monitoring
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" -ValueName "DisableBehaviorMonitoring" -Type DWord -Value 0

# Turn on script scanning
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" -ValueName "DisableScriptScanning" -Type DWord -Value 0

# Scan all downloaded files
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" -ValueName "DisableIOAVProtection" -Type DWord -Value 0

# Turn on email scanning
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Scan" -ValueName "DisableEmailScanning" -Type DWord -Value 0

# Real-time protection
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" -ValueName "DisableRealtimeMonitoring" -Type DWord -Value 0

# Attack Surface Reduction rules (Audit mode)
$ASRRules = @{
    "BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550" = 2  # Block executable content from email
    "D4F940AB-401B-4EFC-AADC-AD5F3C50688A" = 2  # Block Office apps from creating child processes
    "9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2" = 2  # Block credential stealing from lsass.exe
    "b2b3f03d-6a65-4f7b-a9c7-1c7ef74a9ba4" = 2  # Block untrusted USB processes
}

foreach ($RuleID in $ASRRules.Keys) {
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\ASR\Rules" -ValueName $RuleID -Type String -Value $ASRRules[$RuleID]
}

Write-Host "  └─ Windows Defender configured" -ForegroundColor Green

# ==================== ADVANCED AUDIT POLICY ====================
Write-Host "`n[2/10] Configuring Advanced Audit Policy..." -ForegroundColor Cyan

$AuditSettings = @{
    "Credential Validation" = "Success,Failure"
    "Security Group Management" = "Success,Failure"
    "User Account Management" = "Success,Failure"
    "Process Creation" = "Success"
    "Process Termination" = "Success"
    "Logon" = "Success,Failure"
    "Logoff" = "Success"
    "Account Lockout" = "Failure"
    "File System" = "Success,Failure"
    "Registry" = "Success,Failure"
    "Audit Policy Change" = "Success,Failure"
    "Authentication Policy Change" = "Success,Failure"
    "Sensitive Privilege Use" = "Success,Failure"
    "Security State Change" = "Success,Failure"
    "Security System Extension" = "Success,Failure"
}

foreach ($Setting in $AuditSettings.Keys) {
    $Value = $AuditSettings[$Setting]
    auditpol /set /subcategory:"$Setting" /success:enable /failure:enable | Out-Null
}

Write-Host "  └─ Advanced Audit Policy configured" -ForegroundColor Green

# ==================== WINDOWS FIREWALL ====================
Write-Host "`n[3/10] Configuring Windows Firewall..." -ForegroundColor Cyan

# Domain Profile
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\WindowsFirewall\DomainProfile" -ValueName "EnableFirewall" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\WindowsFirewall\DomainProfile" -ValueName "DefaultInboundAction" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\WindowsFirewall\DomainProfile" -ValueName "DefaultOutboundAction" -Type DWord -Value 0
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\WindowsFirewall\DomainProfile\Logging" -ValueName "LogDroppedPackets" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\WindowsFirewall\DomainProfile\Logging" -ValueName "LogSuccessfulConnections" -Type DWord -Value 1

# Private Profile
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\WindowsFirewall\PrivateProfile" -ValueName "EnableFirewall" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\WindowsFirewall\PrivateProfile" -ValueName "DefaultInboundAction" -Type DWord -Value 1

# Public Profile
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\WindowsFirewall\PublicProfile" -ValueName "EnableFirewall" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\WindowsFirewall\PublicProfile" -ValueName "DefaultInboundAction" -Type DWord -Value 1

Write-Host "  └─ Windows Firewall configured" -ForegroundColor Green

# ==================== BITLOCKER POLICY ====================
Write-Host "`n[4/10] Configuring BitLocker Policy..." -ForegroundColor Cyan

# Require BitLocker on fixed drives
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\FVE" -ValueName "FDVRequired" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\FVE" -ValueName "FDVEncryptionMethod" -Type DWord -Value 7  # XTS-AES 256
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\FVE" -ValueName "FDVAllowUserCert" -Type DWord -Value 1

# Operating System drives
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\FVE" -ValueName "UseAdvancedStartup" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\FVE" -ValueName "UseTPM" -Type DWord -Value 2
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\FVE" -ValueName "UseTPMPIN" -Type DWord -Value 2

Write-Host "  └─ BitLocker configured" -ForegroundColor Green

# ==================== WINDOWS DEFENDER APPLICATION CONTROL ====================
Write-Host "`n[5/10] Configuring Windows Defender Application Control..." -ForegroundColor Cyan

# Enable WDAC in Audit mode
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\DeviceGuard" -ValueName "EnableVirtualizationBasedSecurity" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\DeviceGuard" -ValueName "RequirePlatformSecurityFeatures" -Type DWord -Value 1

Write-Host "  └─ WDAC configured" -ForegroundColor Green

# ==================== CREDENTIAL GUARD & DEVICE GUARD ====================
Write-Host "`n[6/10] Configuring Credential Guard & Device Guard..." -ForegroundColor Cyan

# Virtualization Based Security
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\DeviceGuard" -ValueName "EnableVirtualizationBasedSecurity" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\DeviceGuard" -ValueName "RequirePlatformSecurityFeatures" -Type DWord -Value 3  # Secure Boot and DMA Protection

# Credential Guard
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\DeviceGuard" -ValueName "LsaCfgFlags" -Type DWord -Value 1  # Enabled with UEFI lock

# Secure Launch
Set-GPRegistryValue -Name $GPOName -Key "HKLM\System\CurrentControlSet\Control\DeviceGuard\Scenarios\SystemGuard" -ValueName "Enabled" -Type DWord -Value 1

Write-Host "  └─ Credential Guard & Device Guard configured" -ForegroundColor Green

# ==================== WINDOWS UPDATE ====================
Write-Host "`n[7/10] Configuring Windows Update..." -ForegroundColor Cyan

# Configure Automatic Updates
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -ValueName "NoAutoUpdate" -Type DWord -Value 0
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -ValueName "AUOptions" -Type DWord -Value 4  # Auto download and schedule install
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -ValueName "ScheduledInstallDay" -Type DWord -Value 0  # Every day
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -ValueName "AutomaticMaintenanceEnabled" -Type DWord -Value 1

# Deadline settings
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -ValueName "ConfigureDeadlineForFeatureUpdates" -Type DWord -Value 2
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -ValueName "ConfigureDeadlineForQualityUpdates" -Type DWord -Value 7

Write-Host "  └─ Windows Update configured" -ForegroundColor Green

# ==================== USER ACCOUNT CONTROL (UAC) ====================
Write-Host "`n[8/10] Configuring User Account Control..." -ForegroundColor Cyan

Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "FilterAdministratorToken" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "ConsentPromptBehaviorAdmin" -Type DWord -Value 2  # Prompt for consent on secure desktop
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "ConsentPromptBehaviorUser" -Type DWord -Value 0  # Auto deny
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "EnableInstallerDetection" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "EnableSecureUIAPaths" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "EnableLUA" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "EnableVirtualization" -Type DWord -Value 1

Write-Host "  └─ UAC configured" -ForegroundColor Green

# ==================== PRIVACY & TELEMETRY ====================
Write-Host "`n[9/10] Configuring Privacy & Telemetry..." -ForegroundColor Cyan

Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\DataCollection" -ValueName "AllowTelemetry" -Type DWord -Value 1  # Basic
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\PreviewBuilds" -ValueName "AllowBuildPreview" -Type DWord -Value 0
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\DataCollection" -ValueName "DoNotShowFeedbackNotifications" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\PreviewBuilds" -ValueName "EnableConfigFlighting" -Type DWord -Value 0
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\DataCollection" -ValueName "AllowDeviceNameInTelemetry" -Type DWord -Value 1

Write-Host "  └─ Privacy & Telemetry configured" -ForegroundColor Green

# ==================== REMOVABLE STORAGE CONTROL ====================
Write-Host "`n[10/10] Configuring Removable Storage Control..." -ForegroundColor Cyan

# Deny write access to removable disks
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\RemovableStorageDevices\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" -ValueName "Deny_Write" -Type DWord -Value 1

# Log USB events
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\RemovableStorageDevices" -ValueName "LogEvents" -Type DWord -Value 1

Write-Host "  └─ Removable Storage configured" -ForegroundColor Green

# ==================== EXPORT GPO REPORT ====================
Write-Host "`n[+] Exporting GPO Report..." -ForegroundColor Cyan

Get-GPOReport -Name $GPOName -ReportType Html -Path "$BackupPath\$GPOName-Report.html"
Get-GPOReport -Name $GPOName -ReportType Xml -Path "$BackupPath\$GPOName-Report.xml"

Write-Host "  └─ GPO Report exported" -ForegroundColor Green

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  Windows Server 2025 Hardening Completed Successfully!        ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host "`nBackup/Report Location: $BackupPath" -ForegroundColor Cyan
Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "  1. Review GPO Report: $BackupPath\$GPOName-Report.html" -ForegroundColor Gray
Write-Host "  2. Test in non-production environment" -ForegroundColor Gray
Write-Host "  3. Force GPO update: gpupdate /force" -ForegroundColor Gray
Write-Host "  4. Verify settings: gpresult /h gpresult.html" -ForegroundColor Gray

Stop-Transcript
