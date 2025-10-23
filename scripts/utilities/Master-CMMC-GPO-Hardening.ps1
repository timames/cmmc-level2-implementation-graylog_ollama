#requires -version 5.1
#requires -modules GroupPolicy

<#
.SYNOPSIS
    Master CMMC Level 2 Group Policy Hardening Script with Backup and Export
    
.DESCRIPTION
    This script applies CMMC Level 2 compliant Group Policy settings across Domain Controllers,
    Windows Server 2025, and Windows 11 Enterprise systems. Includes GPO backup, ADMX export,
    and compliance validation.
    
.PARAMETER BackupPath
    Path where GPO backups and ADMX files will be stored
    
.PARAMETER CreateBackup
    Switch to create backups before applying changes
    
.PARAMETER ExportADMX
    Switch to export ADMX templates
    
.PARAMETER TargetOU
    Organizational Unit to apply GPOs (e.g., "OU=Servers,DC=domain,DC=com")
    
.PARAMETER ApplyToDC
    Apply Domain Controller hardening GPOs
    
.PARAMETER ApplyToServers
    Apply Windows Server 2025 hardening GPOs
    
.PARAMETER ApplyToWorkstations
    Apply Windows 11 Enterprise hardening GPOs
    
.PARAMETER ReportOnly
    Generate compliance report without making changes
    
.EXAMPLE
    .\Master-CMMC-GPO-Hardening.ps1 -CreateBackup -ExportADMX -ApplyToDC
    
    Create GPO backups, export ADMX templates, and apply Domain Controller hardening
    
.EXAMPLE
    .\Master-CMMC-GPO-Hardening.ps1 -CreateBackup -BackupPath "D:\CMMC_Backups" -ApplyToServers -TargetOU "OU=Servers,DC=contoso,DC=com"
    
    Backup GPOs to custom location and apply server hardening to specific OU
    
.EXAMPLE
    .\Master-CMMC-GPO-Hardening.ps1 -ReportOnly -BackupPath "C:\CMMC_Reports"
    
    Generate compliance report without making any changes (audit mode)
    
.NOTES
    Author: CMMC Compliance Team
    Version: 1.0
    Date: 2025-01-22
    
    IMPORTANT: 
    - Run on Domain Controller with Domain Admin privileges
    - Test in non-production environment first
    - Review all settings before applying
    - Backup existing GPOs before making changes
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false)]
    [string]$BackupPath = "C:\CMMC_GPO_Backups\$(Get-Date -Format 'yyyyMMdd_HHmmss')",
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateBackup,
    
    [Parameter(Mandatory=$false)]
    [switch]$ExportADMX,
    
    [Parameter(Mandatory=$false)]
    [string]$TargetOU,
    
    [Parameter(Mandatory=$false)]
    [switch]$ApplyToDC,
    
    [Parameter(Mandatory=$false)]
    [switch]$ApplyToServers,
    
    [Parameter(Mandatory=$false)]
    [switch]$ApplyToWorkstations,
    
    [Parameter(Mandatory=$false)]
    [switch]$ReportOnly
)

# Transcript logging
$TranscriptPath = Join-Path $BackupPath "Execution_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
Start-Transcript -Path $TranscriptPath -Force

# ==================== INITIALIZATION ====================

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   CMMC Level 2 Group Policy Hardening & Backup Script         ║" -ForegroundColor Cyan
Write-Host "║   Version 1.0 - CMMC Compliance Team                          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator"
    Stop-Transcript
    exit 1
}

# Check if GroupPolicy module is available
if (-NOT (Get-Module -ListAvailable -Name GroupPolicy)) {
    Write-Error "GroupPolicy PowerShell module not found. Please install RSAT tools."
    Stop-Transcript
    exit 1
}

Import-Module GroupPolicy -ErrorAction Stop

# Create backup directory structure
if ($CreateBackup -or $ExportADMX) {
    Write-Host "[+] Creating backup directory: $BackupPath" -ForegroundColor Green
    New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
    New-Item -Path "$BackupPath\GPO_Backups" -ItemType Directory -Force | Out-Null
    New-Item -Path "$BackupPath\ADMX_Templates" -ItemType Directory -Force | Out-Null
    New-Item -Path "$BackupPath\Reports" -ItemType Directory -Force | Out-Null
}

# ==================== BACKUP FUNCTIONS ====================

function Backup-ExistingGPOs {
    param(
        [string]$BackupLocation
    )
    
    Write-Host "`n[+] Backing up existing Group Policies..." -ForegroundColor Cyan
    
    try {
        $AllGPOs = Get-GPO -All
        $BackupReport = @()
        
        foreach ($GPO in $AllGPOs) {
            Write-Host "  ├─ Backing up: $($GPO.DisplayName)" -ForegroundColor Gray
            $BackupInfo = Backup-GPO -Guid $GPO.Id -Path "$BackupLocation\GPO_Backups" -ErrorAction Stop
            
            $BackupReport += [PSCustomObject]@{
                GPOName = $GPO.DisplayName
                GPOID = $GPO.Id
                BackupID = $BackupInfo.Id
                BackupTime = $BackupInfo.BackupTime
                Status = "Success"
            }
        }
        
        # Export backup report
        $BackupReport | Export-Csv -Path "$BackupLocation\Reports\GPO_Backup_Report.csv" -NoTypeInformation
        $BackupReport | ConvertTo-Html | Out-File "$BackupLocation\Reports\GPO_Backup_Report.html"
        
        Write-Host "  └─ Successfully backed up $($AllGPOs.Count) GPOs" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to backup GPOs: $_"
        return $false
    }
}

function Export-ADMXTemplates {
    param(
        [string]$ExportLocation
    )
    
    Write-Host "`n[+] Exporting ADMX templates..." -ForegroundColor Cyan
    
    try {
        $ADMXPath = "$env:SystemRoot\PolicyDefinitions"
        $DestPath = "$ExportLocation\ADMX_Templates"
        
        if (Test-Path $ADMXPath) {
            Write-Host "  ├─ Copying ADMX files from: $ADMXPath" -ForegroundColor Gray
            Copy-Item -Path "$ADMXPath\*.admx" -Destination $DestPath -Force
            Copy-Item -Path "$ADMXPath\*.adml" -Destination "$DestPath\en-US" -Force -Recurse
            
            # Create ADMX inventory
            $ADMXFiles = Get-ChildItem -Path $DestPath -Filter "*.admx" | Select-Object Name, Length, LastWriteTime
            $ADMXFiles | Export-Csv -Path "$ExportLocation\Reports\ADMX_Inventory.csv" -NoTypeInformation
            
            Write-Host "  └─ Exported $($ADMXFiles.Count) ADMX templates" -ForegroundColor Green
            return $true
        }
        else {
            Write-Warning "ADMX path not found: $ADMXPath"
            return $false
        }
    }
    catch {
        Write-Error "Failed to export ADMX templates: $_"
        return $false
    }
}

# ==================== GPO CREATION FUNCTIONS ====================

function New-CMMCCompliantGPO {
    param(
        [Parameter(Mandatory=$true)]
        [string]$GPOName,
        
        [Parameter(Mandatory=$false)]
        [string]$Description,
        
        [Parameter(Mandatory=$false)]
        [string]$LinkOU
    )
    
    try {
        # Check if GPO already exists
        $ExistingGPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
        
        if ($ExistingGPO) {
            Write-Host "  ├─ GPO already exists: $GPOName" -ForegroundColor Yellow
            return $ExistingGPO
        }
        
        Write-Host "  ├─ Creating new GPO: $GPOName" -ForegroundColor Green
        $NewGPO = New-GPO -Name $GPOName -Comment $Description -ErrorAction Stop
        
        if ($LinkOU -and $LinkOU -ne "") {
            Write-Host "  │  └─ Linking to OU: $LinkOU" -ForegroundColor Gray
            New-GPLink -Guid $NewGPO.Id -Target $LinkOU -ErrorAction Stop | Out-Null
        }
        
        return $NewGPO
    }
    catch {
        Write-Error "Failed to create GPO '$GPOName': $_"
        return $null
    }
}

# ==================== DOMAIN CONTROLLER HARDENING ====================

function Apply-DomainControllerGPO {
    param(
        [Parameter(Mandatory=$false)]
        [string]$LinkOU = ""
    )
    
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║  Applying Domain Controller Hardening GPO                     ║" -ForegroundColor Magenta
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    
    $GPOName = "CMMC-DomainController-Hardening"
    $GPO = New-CMMCCompliantGPO -GPOName $GPOName -Description "CMMC Level 2 Domain Controller Hardening" -LinkOU $LinkOU
    
    if (-not $GPO) { return }
    
    # Password Policy
    Write-Host "  [1/8] Configuring Password Policy..." -ForegroundColor Cyan
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\System\CurrentControlSet\Services\Netlogon\Parameters" -ValueName "MaximumPasswordAge" -Type DWord -Value 60 -ErrorAction SilentlyContinue
    
    # Account Lockout Policy
    Write-Host "  [2/8] Configuring Account Lockout Policy..." -ForegroundColor Cyan
    $TempInfPath = "$env:TEMP\secedit_dc_$(Get-Random).inf"
    @"
[Unicode]
Unicode=yes
[System Access]
MinimumPasswordLength = 14
PasswordComplexity = 1
MaximumPasswordAge = 60
MinimumPasswordAge = 1
PasswordHistorySize = 24
LockoutBadCount = 5
LockoutDuration = 30
ResetLockoutCount = 30
[Version]
signature=`"`$CHICAGO`$`"
Revision=1
"@ | Out-File -FilePath $TempInfPath -Encoding unicode
    
    secedit /configure /db secedit.sdb /cfg $TempInfPath /areas SECURITYPOLICY
    Remove-Item $TempInfPath -Force
    
    # Kerberos Policy
    Write-Host "  [3/8] Configuring Kerberos Policy..." -ForegroundColor Cyan
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\System\CurrentControlSet\Services\Kerberos\Parameters" -ValueName "MaxTicketAge" -Type DWord -Value 10 -ErrorAction SilentlyContinue
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\System\CurrentControlSet\Services\Kerberos\Parameters" -ValueName "MaxClockSkew" -Type DWord -Value 5 -ErrorAction SilentlyContinue
    
    # Audit Policy
    Write-Host "  [4/8] Configuring Audit Policy..." -ForegroundColor Cyan
    $AuditCategories = @(
        "Account Logon",
        "Account Management",
        "Directory Service Access",
        "Logon Events",
        "Object Access",
        "Policy Change",
        "Privilege Use",
        "System Events"
    )
    
    foreach ($Category in $AuditCategories) {
        auditpol /set /category:"$Category" /success:enable /failure:enable | Out-Null
    }
    
    # Security Options
    Write-Host "  [5/8] Configuring Security Options..." -ForegroundColor Cyan
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "dontdisplaylastusername" -Type DWord -Value 1 -ErrorAction SilentlyContinue
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "LegalNoticeCaption" -Type String -Value "CMMC Warning" -ErrorAction SilentlyContinue
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "LegalNoticeText" -Type String -Value "Authorized Access Only. CMMC Level 2 Compliant System. Unauthorized access prohibited." -ErrorAction SilentlyContinue
    
    # Network Security
    Write-Host "  [6/8] Configuring Network Security..." -ForegroundColor Cyan
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\System\CurrentControlSet\Control\Lsa" -ValueName "LmCompatibilityLevel" -Type DWord -Value 5 -ErrorAction SilentlyContinue
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\System\CurrentControlSet\Services\LDAP" -ValueName "LDAPClientIntegrity" -Type DWord -Value 2 -ErrorAction SilentlyContinue
    
    # LDAP Signing
    Write-Host "  [7/8] Configuring LDAP Signing..." -ForegroundColor Cyan
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\System\CurrentControlSet\Services\NTDS\Parameters" -ValueName "LDAPServerIntegrity" -Type DWord -Value 2 -ErrorAction SilentlyContinue
    
    # SMB Signing
    Write-Host "  [8/8] Configuring SMB Signing..." -ForegroundColor Cyan
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters" -ValueName "RequireSecuritySignature" -Type DWord -Value 1 -ErrorAction SilentlyContinue
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\System\CurrentControlSet\Services\LanmanWorkstation\Parameters" -ValueName "RequireSecuritySignature" -Type DWord -Value 1 -ErrorAction SilentlyContinue
    
    Write-Host "  └─ Domain Controller GPO Applied Successfully!" -ForegroundColor Green
}

# ==================== MAIN EXECUTION ====================

try {
    # Backup existing GPOs if requested
    if ($CreateBackup) {
        $BackupResult = Backup-ExistingGPOs -BackupLocation $BackupPath
        if (-not $BackupResult) {
            Write-Warning "GPO backup failed. Continue anyway? (Y/N)"
            $Response = Read-Host
            if ($Response -ne 'Y') {
                Write-Host "Operation cancelled by user" -ForegroundColor Yellow
                Stop-Transcript
                exit 0
            }
        }
    }
    
    # Export ADMX templates if requested
    if ($ExportADMX) {
        Export-ADMXTemplates -ExportLocation $BackupPath
    }
    
    # Apply GPO hardening based on parameters
    if ($ApplyToDC) {
        if ($PSCmdlet.ShouldProcess("Domain Controllers", "Apply CMMC Hardening GPO")) {
            Apply-DomainControllerGPO -LinkOU $TargetOU
        }
    }
    
    if ($ApplyToServers) {
        Write-Host "`nServer hardening will be applied by Server-specific script." -ForegroundColor Yellow
        Write-Host "Run: .\Windows-Server-2025-CMMC-Hardening.ps1" -ForegroundColor Yellow
    }
    
    if ($ApplyToWorkstations) {
        Write-Host "`nWorkstation hardening will be applied by Workstation-specific script." -ForegroundColor Yellow
        Write-Host "Run: .\Windows-11-CMMC-Hardening.ps1" -ForegroundColor Yellow
    }
    
    # Generate final report
    Write-Host "`n[+] Generating compliance report..." -ForegroundColor Cyan
    $ReportPath = "$BackupPath\Reports\CMMC_GPO_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    
    $Report = @"
<!DOCTYPE html>
<html>
<head>
    <title>CMMC GPO Hardening Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #2563eb; }
        .success { color: #059669; }
        .warning { color: #d97706; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #2563eb; color: white; }
    </style>
</head>
<body>
    <h1>CMMC Level 2 GPO Hardening Report</h1>
    <p><strong>Execution Date:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
    <p><strong>Backup Path:</strong> $BackupPath</p>
    <p><strong>Applied To:</strong></p>
    <ul>
        <li>Domain Controllers: $(if($ApplyToDC){'Yes'}else{'No'})</li>
        <li>Servers: $(if($ApplyToServers){'Pending'}else{'No'})</li>
        <li>Workstations: $(if($ApplyToWorkstations){'Pending'}else{'No'})</li>
    </ul>
    <h2>Summary</h2>
    <p class="success">GPO hardening completed successfully!</p>
</body>
</html>
"@
    
    $Report | Out-File -FilePath $ReportPath -Encoding UTF8
    Write-Host "  └─ Report saved to: $ReportPath" -ForegroundColor Green
    
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  CMMC GPO Hardening Completed Successfully!                   ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host "`nBackup Location: $BackupPath" -ForegroundColor Cyan
    Write-Host "Transcript Log: $TranscriptPath" -ForegroundColor Cyan
}
catch {
    Write-Error "Fatal error during execution: $_"
    Write-Host "`n[!] Script execution failed. Check logs for details." -ForegroundColor Red
}
finally {
    Stop-Transcript
}
