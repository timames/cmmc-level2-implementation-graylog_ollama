#requires -version 5.1
#requires -modules GroupPolicy

<#
.SYNOPSIS
    Windows 11 Enterprise CMMC Level 2 Hardening Script
    
.DESCRIPTION
    Applies CMMC Level 2 compliant Group Policy settings for Windows 11 Enterprise workstations.
    Includes special handling for VDI instant clones vs persistent workstations.
    
.PARAMETER BackupPath
    Path for GPO backups
    
.PARAMETER TargetOU
    Organizational Unit for workstation GPO
    
.PARAMETER IsVDIInstantClone
    Switch to apply VDI-specific settings (excludes BitLocker, Credential Guard)
    
.EXAMPLE
    .\Windows-11-CMMC-Hardening.ps1 -TargetOU "OU=Workstations,DC=contoso,DC=com"
    
    Apply Windows 11 hardening to physical/persistent workstations (includes BitLocker and Credential Guard)
    
.EXAMPLE
    .\Windows-11-CMMC-Hardening.ps1 -TargetOU "OU=VDI-Clones,DC=contoso,DC=com" -IsVDIInstantClone
    
    Apply Windows 11 hardening to VDI instant clones (excludes BitLocker and Credential Guard for non-persistent desktops)
    
.EXAMPLE
    .\Windows-11-CMMC-Hardening.ps1 -BackupPath "D:\CMMC_Backups\Win11" -TargetOU "OU=Laptops,DC=contoso,DC=com"
    
    Apply hardening to laptop OU with custom backup location
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false)]
    [string]$BackupPath = "C:\CMMC_GPO_Backups\Win11_$(Get-Date -Format 'yyyyMMdd_HHmmss')",
    
    [Parameter(Mandatory=$false)]
    [string]$TargetOU = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$IsVDIInstantClone
)

Start-Transcript -Path "$BackupPath\Win11_Hardening_$(Get-Date -Format 'yyyyMMdd_HHmmss').log" -Force

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Windows 11 Enterprise CMMC Level 2 Hardening Script         ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

if ($IsVDIInstantClone) {
    Write-Host "`n[!] VDI Instant Clone Mode: BitLocker and Credential Guard will be SKIPPED" -ForegroundColor Yellow
}

New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null

$GPOName = if ($IsVDIInstantClone) { "CMMC-Windows11-VDI-Hardening" } else { "CMMC-Windows11-Hardening" }

# Create or get GPO
try {
    $GPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
    if (-not $GPO) {
        Write-Host "[+] Creating new GPO: $GPOName" -ForegroundColor Green
        $GPO = New-GPO -Name $GPOName -Comment "CMMC Level 2 Windows 11 Enterprise Hardening"
        
        if ($TargetOU) {
            Write-Host "  └─ Linking to OU: $TargetOU" -ForegroundColor Gray
            New-GPLink -Guid $GPO.Id -Target $TargetOU | Out-Null
        }
    }
    else {
        Write-Host "[+] Using existing GPO: $GPOName" -ForegroundColor Yellow
        Backup-GPO -Name $GPOName -Path $BackupPath | Out-Null
    }
}
catch {
    Write-Error "Failed to create/get GPO: $_"
    Stop-Transcript
    exit 1
}

# ==================== WINDOWS DEFENDER ====================
Write-Host "`n[1/12] Configuring Windows Defender..." -ForegroundColor Cyan

Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Defender" -ValueName "DisableAntiSpyware" -Type DWord -Value 0
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" -ValueName "DisableBehaviorMonitoring" -Type DWord -Value 0
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" -ValueName "DisableScriptScanning" -Type DWord -Value 0
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" -ValueName "DisableIOAVProtection" -Type DWord -Value 0
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Scan" -ValueName "DisableEmailScanning" -Type DWord -Value 0
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" -ValueName "DisableRealtimeMonitoring" -Type DWord -Value 0

# Cloud Protection
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Spynet" -ValueName "SpynetReporting" -Type DWord -Value 2
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Spynet" -ValueName "SubmitSamplesConsent" -Type DWord -Value 1

Write-Host "  └─ Windows Defender configured" -ForegroundColor Green

# ==================== EXPLOIT GUARD & ASR ====================
Write-Host "`n[2/12] Configuring Exploit Guard & Attack Surface Reduction..." -ForegroundColor Cyan

# Exploit Guard Network Protection
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\Network Protection" -ValueName "EnableNetworkProtection" -Type DWord -Value 1

# Controlled Folder Access
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\Controlled Folder Access" -ValueName "EnableControlledFolderAccess" -Type DWord -Value 1

# Attack Surface Reduction Rules
$ASRRules = @{
    "BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550" = 1  # Block executable content from email
    "D4F940AB-401B-4EFC-AADC-AD5F3C50688A" = 1  # Block Office apps from creating child processes
    "3B576869-A4EC-4529-8536-B80A7769E899" = 1  # Block Office apps from creating executable content
    "75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84" = 1  # Block Office apps from injecting code
    "D3E037E1-3EB8-44C8-A917-57927947596D" = 1  # Block JavaScript/VBScript from launching executables
    "5BEB7EFE-FD9A-4556-801D-275E5FFC04CC" = 1  # Block execution of potentially obfuscated scripts
    "92E97FA1-2EDF-4476-BDD6-9DD0B4DDDC7B" = 1  # Block Win32 API calls from Office macros
    "9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2" = 1  # Block credential stealing from lsass.exe
    "b2b3f03d-6a65-4f7b-a9c7-1c7ef74a9ba4" = 1  # Block untrusted USB processes
    "26190899-1602-49e8-8b27-eb1d0a1ce869" = 1  # Block Office communication apps from creating child processes
    "7674ba52-37eb-4a4f-a9a1-f0f9a1619a2c" = 1  # Block Adobe Reader from creating child processes
    "e6db77e5-3df2-4cf1-b95a-636979351e5b" = 1  # Block persistence through WMI
}

Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\ASR" -ValueName "ExploitGuard_ASR_Rules" -Type DWord -Value 1

foreach ($RuleID in $ASRRules.Keys) {
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\ASR\Rules" -ValueName $RuleID -Type String -Value $ASRRules[$RuleID]
}

Write-Host "  └─ Exploit Guard & ASR configured" -ForegroundColor Green

# ==================== ADVANCED AUDIT POLICY ====================
Write-Host "`n[3/12] Configuring Advanced Audit Policy..." -ForegroundColor Cyan

auditpol /set /subcategory:"Credential Validation" /success:enable /failure:enable
auditpol /set /subcategory:"Security Group Management" /success:enable /failure:enable
auditpol /set /subcategory:"User Account Management" /success:enable /failure:enable
auditpol /set /subcategory:"Process Creation" /success:enable
auditpol /set /subcategory:"Logon" /success:enable /failure:enable
auditpol /set /subcategory:"Logoff" /success:enable
auditpol /set /subcategory:"File Share" /success:enable /failure:enable
auditpol /set /subcategory:"Removable Storage" /success:enable /failure:enable

Write-Host "  └─ Advanced Audit Policy configured" -ForegroundColor Green

# ==================== WINDOWS FIREWALL ====================
Write-Host "`n[4/12] Configuring Windows Firewall..." -ForegroundColor Cyan

Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\WindowsFirewall\DomainProfile" -ValueName "EnableFirewall" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\WindowsFirewall\DomainProfile" -ValueName "DefaultInboundAction" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\WindowsFirewall\DomainProfile" -ValueName "DisableNotifications" -Type DWord -Value 0
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\WindowsFirewall\PrivateProfile" -ValueName "EnableFirewall" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\WindowsFirewall\PublicProfile" -ValueName "EnableFirewall" -Type DWord -Value 1

Write-Host "  └─ Windows Firewall configured" -ForegroundColor Green

# ==================== BITLOCKER (Skip for VDI Instant Clones) ====================
if (-not $IsVDIInstantClone) {
    Write-Host "`n[5/12] Configuring BitLocker..." -ForegroundColor Cyan
    
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\FVE" -ValueName "OSRequired" -Type DWord -Value 1
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\FVE" -ValueName "OSEncryptionType" -Type DWord -Value 1
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\FVE" -ValueName "OSActiveDirectoryBackup" -Type DWord -Value 1
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\FVE" -ValueName "UseAdvancedStartup" -Type DWord -Value 1
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\FVE" -ValueName "UseTPM" -Type DWord -Value 2
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\FVE" -ValueName "UseTPMPIN" -Type DWord -Value 2
    
    Write-Host "  └─ BitLocker configured" -ForegroundColor Green
}
else {
    Write-Host "`n[5/12] Skipping BitLocker (VDI Instant Clone)" -ForegroundColor Yellow
}

# ==================== WINDOWS DEFENDER APPLICATION CONTROL ====================
Write-Host "`n[6/12] Configuring Windows Defender Application Control..." -ForegroundColor Cyan

Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\DeviceGuard" -ValueName "EnableVirtualizationBasedSecurity" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\DeviceGuard" -ValueName "RequirePlatformSecurityFeatures" -Type DWord -Value 1

Write-Host "  └─ WDAC configured" -ForegroundColor Green

# ==================== CREDENTIAL GUARD (Skip for VDI Instant Clones) ====================
if (-not $IsVDIInstantClone) {
    Write-Host "`n[7/12] Configuring Credential Guard..." -ForegroundColor Cyan
    
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\DeviceGuard" -ValueName "LsaCfgFlags" -Type DWord -Value 1
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\System\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -ValueName "Enabled" -Type DWord -Value 1
    
    Write-Host "  └─ Credential Guard configured" -ForegroundColor Green
}
else {
    Write-Host "`n[7/12] Skipping Credential Guard (VDI Instant Clone)" -ForegroundColor Yellow
}

# ==================== WINDOWS UPDATE ====================
if (-not $IsVDIInstantClone) {
    Write-Host "`n[8/12] Configuring Windows Update..." -ForegroundColor Cyan
    
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -ValueName "NoAutoUpdate" -Type DWord -Value 0
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -ValueName "AUOptions" -Type DWord -Value 4
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -ValueName "ScheduledInstallDay" -Type DWord -Value 0
    
    Write-Host "  └─ Windows Update configured" -ForegroundColor Green
}
else {
    Write-Host "`n[8/12] Disabling Windows Update (VDI Instant Clone - update via master image)" -ForegroundColor Yellow
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -ValueName "NoAutoUpdate" -Type DWord -Value 1
}

# ==================== USER ACCOUNT CONTROL ====================
Write-Host "`n[9/12] Configuring User Account Control..." -ForegroundColor Cyan

Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "FilterAdministratorToken" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "ConsentPromptBehaviorAdmin" -Type DWord -Value 2
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "ConsentPromptBehaviorUser" -Type DWord -Value 0
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "EnableInstallerDetection" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "EnableLUA" -Type DWord -Value 1

Write-Host "  └─ UAC configured" -ForegroundColor Green

# ==================== PRIVACY & TELEMETRY ====================
Write-Host "`n[10/12] Configuring Privacy & Telemetry..." -ForegroundColor Cyan

Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\DataCollection" -ValueName "AllowTelemetry" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\DataCollection" -ValueName "DoNotShowFeedbackNotifications" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\DataCollection" -ValueName "AllowDeviceNameInTelemetry" -Type DWord -Value 1

Write-Host "  └─ Privacy & Telemetry configured" -ForegroundColor Green

# ==================== REMOVABLE STORAGE ====================
Write-Host "`n[11/12] Configuring Removable Storage Control..." -ForegroundColor Cyan

Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\RemovableStorageDevices\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" -ValueName "Deny_Write" -Type DWord -Value 1

Write-Host "  └─ Removable Storage configured" -ForegroundColor Green

# ==================== MICROSOFT DEFENDER FOR ENDPOINT ====================
Write-Host "`n[12/12] Configuring Microsoft Defender for Endpoint..." -ForegroundColor Cyan

Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Advanced Threat Protection" -ValueName "ForceDefenderPassiveMode" -Type DWord -Value 0
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Defender" -ValueName "ServiceKeepAlive" -Type DWord -Value 1

if ($IsVDIInstantClone) {
    Write-Host "  ├─ Setting VDI device tag..." -ForegroundColor Gray
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Advanced Threat Protection\DeviceTagging" -ValueName "Group" -Type String -Value "VDI"
}

Write-Host "  └─ Defender for Endpoint configured" -ForegroundColor Green

# ==================== EXPORT GPO REPORT ====================
Write-Host "`n[+] Exporting GPO Report..." -ForegroundColor Cyan

Get-GPOReport -Name $GPOName -ReportType Html -Path "$BackupPath\$GPOName-Report.html"
Get-GPOReport -Name $GPOName -ReportType Xml -Path "$BackupPath\$GPOName-Report.xml"

Write-Host "  └─ GPO Report exported" -ForegroundColor Green

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  Windows 11 Hardening Completed Successfully!                 ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host "`nConfiguration Type: $(if($IsVDIInstantClone){'VDI Instant Clone'}else{'Physical/Persistent'})" -ForegroundColor Cyan
Write-Host "Backup/Report Location: $BackupPath" -ForegroundColor Cyan

Stop-Transcript
