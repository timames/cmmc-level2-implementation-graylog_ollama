#requires -version 5.1
#requires -modules GroupPolicy

<#
.SYNOPSIS
    VMware Horizon Agent CMMC Level 2 Hardening Script
    
.DESCRIPTION
    Configures VMware Horizon Agent policies for CMMC Level 2 compliance on instant clone VDI pools.
    Includes USB redirection controls, audio/video settings, PCoIP/Blast security, and ADMX template deployment.
    
.PARAMETER BackupPath
    Path for GPO backups and ADM template exports
    
.PARAMETER TargetOU
    Organizational Unit for VDI instant clones
    
.PARAMETER HorizonADMPath
    Path to VMware Horizon ADM templates (download from VMware)
    
.PARAMETER DeployADMTemplates
    Switch to copy ADM templates to PolicyDefinitions
    
.EXAMPLE
    .\VMware-Horizon-CMMC-Hardening.ps1 -TargetOU "OU=VDI-Clones,DC=domain,DC=com"
    
    Basic usage - Apply Horizon hardening to VDI instant clone OU
    
.EXAMPLE
    .\VMware-Horizon-CMMC-Hardening.ps1 -BackupPath "D:\CMMC_Backups\Horizon" -TargetOU "OU=VDI-Clones,DC=domain,DC=com"
    
    Specify custom backup location for GPO backups and reports
    
.EXAMPLE
    .\VMware-Horizon-CMMC-Hardening.ps1 -TargetOU "OU=VDI-Clones,DC=domain,DC=com" -HorizonADMPath "C:\Downloads\Horizon_ADM_Templates" -DeployADMTemplates
    
    Deploy Horizon ADM templates to PolicyDefinitions and apply hardening
    
.NOTES
    Download Horizon ADM templates from:
    https://docs.vmware.com/en/VMware-Horizon/index.html
    
    ADM templates must be imported to Group Policy Central Store or local PolicyDefinitions
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false)]
    [string]$BackupPath = "C:\CMMC_GPO_Backups\Horizon_$(Get-Date -Format 'yyyyMMdd_HHmmss')",
    
    [Parameter(Mandatory=$false)]
    [string]$TargetOU = "",
    
    [Parameter(Mandatory=$false)]
    [string]$HorizonADMPath = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$DeployADMTemplates
)

Start-Transcript -Path "$BackupPath\Horizon_Hardening_$(Get-Date -Format 'yyyyMMdd_HHmmss').log" -Force

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   VMware Horizon Agent CMMC Level 2 Hardening Script          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
New-Item -Path "$BackupPath\ADM_Templates" -ItemType Directory -Force | Out-Null

# ==================== ADM TEMPLATE DEPLOYMENT ====================
if ($DeployADMTemplates -and $HorizonADMPath) {
    Write-Host "`n[+] Deploying Horizon ADM Templates..." -ForegroundColor Cyan
    
    $CentralStore = "\\$env:USERDNSDOMAIN\SYSVOL\$env:USERDNSDOMAIN\Policies\PolicyDefinitions"
    $LocalStore = "$env:SystemRoot\PolicyDefinitions"
    
    # Check if Central Store exists
    $UseStore = if (Test-Path $CentralStore) { $CentralStore } else { $LocalStore }
    
    Write-Host "  ├─ Target Store: $UseStore" -ForegroundColor Gray
    
    try {
        if (Test-Path $HorizonADMPath) {
            # Copy ADMX files
            $ADMXFiles = Get-ChildItem -Path $HorizonADMPath -Filter "*.admx"
            foreach ($File in $ADMXFiles) {
                Copy-Item -Path $File.FullName -Destination $UseStore -Force
                Write-Host "  │  └─ Copied: $($File.Name)" -ForegroundColor Gray
            }
            
            # Copy ADML files
            $ADMLPath = Join-Path $HorizonADMPath "en-US"
            if (Test-Path $ADMLPath) {
                $ADMLFiles = Get-ChildItem -Path $ADMLPath -Filter "*.adml"
                $DestADML = Join-Path $UseStore "en-US"
                New-Item -Path $DestADML -ItemType Directory -Force | Out-Null
                
                foreach ($File in $ADMLFiles) {
                    Copy-Item -Path $File.FullName -Destination $DestADML -Force
                    Write-Host "  │  └─ Copied: $($File.Name)" -ForegroundColor Gray
                }
            }
            
            # Backup templates
            Copy-Item -Path "$HorizonADMPath\*" -Destination "$BackupPath\ADM_Templates" -Recurse -Force
            
            Write-Host "  └─ ADM Templates deployed successfully" -ForegroundColor Green
        }
        else {
            Write-Warning "Horizon ADM path not found: $HorizonADMPath"
        }
    }
    catch {
        Write-Error "Failed to deploy ADM templates: $_"
    }
}

# ==================== CREATE GPO ====================
$GPOName = "CMMC-Horizon-Agent-Hardening"

try {
    $GPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
    if (-not $GPO) {
        Write-Host "`n[+] Creating new GPO: $GPOName" -ForegroundColor Green
        $GPO = New-GPO -Name $GPOName -Comment "CMMC Level 2 VMware Horizon Agent Hardening for VDI Instant Clones"
        
        if ($TargetOU) {
            Write-Host "  └─ Linking to OU: $TargetOU" -ForegroundColor Gray
            New-GPLink -Guid $GPO.Id -Target $TargetOU | Out-Null
        }
    }
    else {
        Write-Host "`n[+] Using existing GPO: $GPOName" -ForegroundColor Yellow
        Backup-GPO -Name $GPOName -Path $BackupPath | Out-Null
    }
}
catch {
    Write-Error "Failed to create/get GPO: $_"
    Stop-Transcript
    exit 1
}

# ==================== HORIZON AGENT CONFIGURATION ====================
Write-Host "`n[1/8] Configuring Horizon Agent Core Settings..." -ForegroundColor Cyan

# Horizon Agent Configuration Base Path
$HorizonBase = "HKLM\Software\Policies\VMware, Inc.\VMware VDM\Agent"

# Enable Horizon Agent
Set-GPRegistryValue -Name $GPOName -Key $HorizonBase -ValueName "Enabled" -Type DWord -Value 1

# Disable single sign-on (require authentication)
Set-GPRegistryValue -Name $GPOName -Key "$HorizonBase\SSO" -ValueName "EnableSingleSignOn" -Type DWord -Value 0

# Configure session timeout (15 minutes idle)
Set-GPRegistryValue -Name $GPOName -Key $HorizonBase -ValueName "MaxIdleTime" -Type DWord -Value 900

# Enable client drive redirection with restrictions
Set-GPRegistryValue -Name $GPOName -Key "$HorizonBase\Configuration" -ValueName "EnableCDR" -Type DWord -Value 0  # Disable for CMMC

Write-Host "  └─ Horizon Agent Core configured" -ForegroundColor Green

# ==================== USB REDIRECTION ====================
Write-Host "`n[2/8] Configuring USB Redirection..." -ForegroundColor Cyan

$USBBase = "$HorizonBase\USB"

# Disable USB redirection by default (enable only for approved devices)
Set-GPRegistryValue -Name $GPOName -Key $USBBase -ValueName "EnableUSBAccess" -Type DWord -Value 0

# If USB is needed, configure allowlist
# Set-GPRegistryValue -Name $GPOName -Key $USBBase -ValueName "AllowVideoDevices" -Type DWord -Value 0
# Set-GPRegistryValue -Name $GPOName -Key $USBBase -ValueName "AllowHIDDevices" -Type DWord -Value 1
# Set-GPRegistryValue -Name $GPOName -Key $USBBase -ValueName "AllowAutoDeviceSplitting" -Type DWord -Value 0

# Disable split-mode USB for security
Set-GPRegistryValue -Name $GPOName -Key $USBBase -ValueName "DisableSplitUSB" -Type DWord -Value 1

Write-Host "  └─ USB Redirection configured (DISABLED for CMMC)" -ForegroundColor Green

# ==================== CLIPBOARD & FILE TRANSFER ====================
Write-Host "`n[3/8] Configuring Clipboard & File Transfer..." -ForegroundColor Cyan

$ClipboardBase = "$HorizonBase\Configuration"

# Disable clipboard redirection (or set to server-to-client only)
Set-GPRegistryValue -Name $GPOName -Key $ClipboardBase -ValueName "EnableClipboard" -Type DWord -Value 0

# If clipboard needed, restrict direction
# Set-GPRegistryValue -Name $GPOName -Key $ClipboardBase -ValueName "ClipboardDirection" -Type DWord -Value 1  # Server to client only

# Disable file transfer
Set-GPRegistryValue -Name $GPOName -Key $ClipboardBase -ValueName "EnableFileTransfer" -Type DWord -Value 0

Write-Host "  └─ Clipboard & File Transfer configured (DISABLED)" -ForegroundColor Green

# ==================== DISPLAY & GRAPHICS ====================
Write-Host "`n[4/8] Configuring Display & Graphics..." -ForegroundColor Cyan

$DisplayBase = "$HorizonBase\Configuration"

# Configure display protocol (Blast Extreme preferred)
Set-GPRegistryValue -Name $GPOName -Key $DisplayBase -ValueName "DefaultProtocol" -Type String -Value "BLAST"

# Disable PCoIP if not needed (Blast is more secure)
Set-GPRegistryValue -Name $GPOName -Key "$HorizonBase\PCoIP" -ValueName "EnablePCoIP" -Type DWord -Value 0

# Blast Security Settings
$BlastBase = "$HorizonBase\Blast"
Set-GPRegistryValue -Name $GPOName -Key $BlastBase -ValueName "AudioEncodingQuality" -Type DWord -Value 0  # Low (reduce bandwidth)
Set-GPRegistryValue -Name $GPOName -Key $BlastBase -ValueName "H264" -Type DWord -Value 1  # Enable H.264

Write-Host "  └─ Display & Graphics configured" -ForegroundColor Green

# ==================== AUDIO & VIDEO ====================
Write-Host "`n[5/8] Configuring Audio & Video..." -ForegroundColor Cyan

$AudioBase = "$HorizonBase\Configuration"

# Configure audio redirection
Set-GPRegistryValue -Name $GPOName -Key $AudioBase -ValueName "AudioRedirection" -Type DWord -Value 1  # Enable (low quality)

# Disable webcam/microphone redirection
Set-GPRegistryValue -Name $GPOName -Key "$HorizonBase\RTAV" -ValueName "EnableRealTimeAudioVideo" -Type DWord -Value 0

Write-Host "  └─ Audio & Video configured" -ForegroundColor Green

# ==================== SECURITY SETTINGS ====================
Write-Host "`n[6/8] Configuring Security Settings..." -ForegroundColor Cyan

$SecurityBase = "$HorizonBase\Security"

# Enable certificate verification
Set-GPRegistryValue -Name $GPOName -Key $SecurityBase -ValueName "EnableCertificateVerification" -Type DWord -Value 1

# Disable PowerShell execution in user sessions
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\PowerShell" -ValueName "EnableScripts" -Type DWord -Value 0

# Enable Windows Event Forwarding for Horizon events
Set-GPRegistryValue -Name $GPOName -Key $HorizonBase -ValueName "EnableEventForwarding" -Type DWord -Value 1

Write-Host "  └─ Security Settings configured" -ForegroundColor Green

# ==================== SESSION MANAGEMENT ====================
Write-Host "`n[7/8] Configuring Session Management..." -ForegroundColor Cyan

$SessionBase = "$HorizonBase\Configuration"

# Configure session timeout policies
Set-GPRegistryValue -Name $GPOName -Key $SessionBase -ValueName "SessionTimeoutMinutes" -Type DWord -Value 480  # 8 hours

# Disconnect on session timeout
Set-GPRegistryValue -Name $GPOName -Key $SessionBase -ValueName "DisconnectedSessionTimeout" -Type DWord -Value 300  # 5 minutes

# Configure logoff on disconnect
Set-GPRegistryValue -Name $GPOName -Key $SessionBase -ValueName "LogOffDisconnectedSessions" -Type DWord -Value 1

Write-Host "  └─ Session Management configured" -ForegroundColor Green

# ==================== MICROSOFT DEFENDER FOR ENDPOINT INTEGRATION ====================
Write-Host "`n[8/8] Configuring Defender for Endpoint Integration..." -ForegroundColor Cyan

# Tag VDI machines for Defender
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Advanced Threat Protection\DeviceTagging" -ValueName "Group" -Type String -Value "VDI-InstantClone"

# Configure Defender offboarding for instant clone refresh
# Note: Use group-based onboarding/offboarding, not individual scripts
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Advanced Threat Protection" -ValueName "ForceDefenderPassiveMode" -Type DWord -Value 0

# Keep Defender service running with normal priority
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows Defender" -ValueName "ServiceKeepAlive" -Type DWord -Value 1

Write-Host "  └─ Defender Integration configured" -ForegroundColor Green

# ==================== ADDITIONAL REGISTRY SETTINGS ====================
Write-Host "`n[+] Applying Additional Registry Hardening..." -ForegroundColor Cyan

# Disable printer redirection
Set-GPRegistryValue -Name $GPOName -Key "$HorizonBase\Configuration" -ValueName "EnablePrinterRedirection" -Type DWord -Value 0

# Disable COM port redirection
Set-GPRegistryValue -Name $GPOName -Key "$HorizonBase\Configuration" -ValueName "EnableCOMPortRedirection" -Type DWord -Value 0

# Disable smart card redirection (unless required)
Set-GPRegistryValue -Name $GPOName -Key "$HorizonBase\Configuration" -ValueName "EnableSmartCard" -Type DWord -Value 0

Write-Host "  └─ Additional hardening applied" -ForegroundColor Green

# ==================== CREATE CONFIGURATION DOCUMENTATION ====================
Write-Host "`n[+] Creating Configuration Documentation..." -ForegroundColor Cyan

$DocContent = @"
# VMware Horizon Agent CMMC Level 2 Configuration

## Applied Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
## GPO Name: $GPOName
## Target OU: $TargetOU

## Configuration Summary

### USB Redirection
- Status: DISABLED (CMMC requirement)
- If enabled, use device allowlist only

### Clipboard & File Transfer
- Clipboard: DISABLED
- File Transfer: DISABLED
- Rationale: Prevent data exfiltration

### Display Protocol
- Primary: VMware Blast Extreme
- PCoIP: DISABLED
- H.264 Encoding: ENABLED

### Audio/Video
- Audio Redirection: ENABLED (Low Quality)
- Webcam/Microphone: DISABLED

### Session Management
- Idle Timeout: 15 minutes
- Max Session: 8 hours
- Disconnect Timeout: 5 minutes
- Logoff on Disconnect: ENABLED

### Security
- Certificate Verification: ENABLED
- PowerShell in Sessions: DISABLED
- Event Forwarding: ENABLED

### Defender for Endpoint
- Device Tag: VDI-InstantClone
- Service Priority: Normal
- Group-based Onboarding: Required

## CMMC Practices Addressed
- AC.L2-3.1.1 (Authorized Access Control)
- AC.L2-3.1.2 (Limit Information System Access)
- AC.L2-3.1.20 (External Connection Controls)
- AC.L2-3.1.22 (Control CUI Posting/Processing)
- CM.L2-3.4.2 (Security Configuration Settings)
- SC.L2-3.13.8 (Session Lock)

## Next Steps
1. Test VDI pool functionality
2. Verify Defender for Endpoint reporting
3. Monitor Horizon events in Graylog
4. Document in CMMC SSP
5. Train users on new restrictions

## Troubleshooting
- If USB devices needed: Create allowlist in Horizon Administrator
- If clipboard needed: Enable server-to-client only
- For printing: Use network printers instead of redirection

## References
- VMware Horizon Security Guide
- CMMC Level 2 Assessment Guide
- NIST SP 800-171 Controls
"@

$DocContent | Out-File -FilePath "$BackupPath\Horizon_Configuration_Documentation.md" -Encoding UTF8

Write-Host "  └─ Documentation created: $BackupPath\Horizon_Configuration_Documentation.md" -ForegroundColor Green

# ==================== EXPORT GPO REPORT ====================
Write-Host "`n[+] Exporting GPO Report..." -ForegroundColor Cyan

Get-GPOReport -Name $GPOName -ReportType Html -Path "$BackupPath\$GPOName-Report.html"
Get-GPOReport -Name $GPOName -ReportType Xml -Path "$BackupPath\$GPOName-Report.xml"

Write-Host "  └─ GPO Report exported" -ForegroundColor Green

# ==================== CREATE HORIZON ADMINISTRATOR CHECKLIST ====================
$ChecklistContent = @"
# Horizon Administrator Console Configuration Checklist

## Global Settings
- [ ] Configure Global Policies → Security → Disable USB redirection
- [ ] Set default display protocol to Blast Extreme
- [ ] Configure TLS/SSL certificates for all Connection Servers
- [ ] Enable Smart Card authentication on UAG (Unified Access Gateway)

## Pool-Level Settings
- [ ] Set session timeout to 8 hours
- [ ] Enable automatic logoff after 5 minutes disconnect
- [ ] Disable clipboard redirection
- [ ] Disable file transfer
- [ ] Configure refresh on logoff for instant clone pools
- [ ] Set minimum number of ready machines (e.g., 10)
- [ ] Configure maximum pool size

## Connection Server Settings
- [ ] Enable FIPS mode
- [ ] Configure Event Database for CMMC auditing
- [ ] Enable syslog forwarding to Graylog
- [ ] Set up SAML authentication with Azure AD (if applicable)

## UAG (Unified Access Gateway) Settings
- [ ] Enable MFA (Azure AD, Duo, RSA, etc.)
- [ ] Configure TLS 1.2/1.3 only
- [ ] Disable weak ciphers
- [ ] Enable session timeout (15 minutes idle)
- [ ] Configure IP allowlisting for admin access

## Monitoring & Logging
- [ ] Configure syslog forwarding to Graylog (UDP 5140)
- [ ] Enable Connection Server event logging
- [ ] Enable Horizon Agent event logging on VDI pools
- [ ] Set up alerts for failed authentication attempts
- [ ] Monitor instant clone provisioning failures

## Master Image Configuration
- [ ] Apply CMMC Windows 11 GPO hardening
- [ ] Install VMware Horizon Agent (latest version)
- [ ] Install Microsoft Defender for Endpoint agent
- [ ] Configure group-based onboarding for Defender
- [ ] Disable Windows Update in image (update via recompose)
- [ ] Remove local admin rights from users
- [ ] Configure Windows Event Forwarding
- [ ] Test all required applications
- [ ] Take snapshot with descriptive name

## Monthly Maintenance
- [ ] Update master image with latest patches
- [ ] Test updated master image
- [ ] Take new snapshot
- [ ] Schedule recompose operation (off-hours)
- [ ] Verify post-recompose functionality
- [ ] Review and analyze Horizon logs in Graylog

## CMMC Documentation Requirements
- [ ] Document all Horizon configuration settings in SSP
- [ ] Maintain evidence of monthly master image updates
- [ ] Document MFA configuration and testing
- [ ] Maintain logs of all configuration changes
- [ ] Document user access reviews (quarterly)
"@

$ChecklistContent | Out-File -FilePath "$BackupPath\Horizon_Administrator_Checklist.md" -Encoding UTF8

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  VMware Horizon Hardening Completed Successfully!             ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host "`nBackup/Report Location: $BackupPath" -ForegroundColor Cyan
Write-Host "`nIMPORTANT: Additional configuration required in Horizon Administrator Console" -ForegroundColor Yellow
Write-Host "See checklist: $BackupPath\Horizon_Administrator_Checklist.md" -ForegroundColor Yellow
Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "  1. Review GPO Report" -ForegroundColor Gray
Write-Host "  2. Test VDI pool functionality" -ForegroundColor Gray
Write-Host "  3. Complete Horizon Administrator checklist" -ForegroundColor Gray
Write-Host "  4. Update CMMC documentation" -ForegroundColor Gray

Stop-Transcript
