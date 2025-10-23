# Hardening Scripts

This directory contains automation scripts for implementing CMMC Level 2 security controls with Graylog SIEM and Ollama integration.

## Directory Structure

```
scripts/
├── README.md                    # This file
├── graylog/                     # Graylog SIEM deployment and configuration
├── ollama/                      # Ollama AI integration scripts
├── system-hardening/            # OS and application hardening
├── network/                     # Network configuration and segmentation
├── monitoring/                  # Logging and monitoring setup
├── compliance/                  # Compliance validation and reporting
└── utilities/                   # Helper scripts and tools
```

## Usage

### General Prerequisites

Before running any scripts:

1. **Review the script** - Always read through scripts before execution
2. **Test in lab** - Test in a non-production environment first
3. **Backup data** - Ensure backups are current
4. **Check dependencies** - Verify all required tools are installed
5. **Set permissions** - Make scripts executable: `chmod +x script-name.sh`

### Environment Variables

Many scripts require environment variables. Create a `.env` file (which is gitignored):

```bash
# Example .env file
GRAYLOG_ADMIN_PASSWORD="your-secure-password"
ELASTICSEARCH_PASSWORD="your-secure-password"
DOMAIN_NAME="yourdomain.local"
VLAN_10_SUBNET="10.0.10.0/24"
VLAN_20_SUBNET="10.0.20.0/24"
VLAN_30_SUBNET="10.0.30.0/24"
```

### Running Scripts

```bash
# Load environment variables
source .env

# Make script executable
chmod +x script-name.sh

# Run with elevated privileges if needed
sudo ./script-name.sh
```

## Script Categories

### Graylog Deployment

Scripts for deploying and configuring Graylog SIEM:
- Graylog server installation
- MongoDB setup
- OpenSearch/Elasticsearch configuration
- Input configuration (Syslog, GELF, etc.)
- Stream and alert setup
- Dashboard creation

### Ollama Integration

Scripts for integrating Ollama AI capabilities:
- Ollama installation and setup
- Model deployment
- Integration with Graylog
- Automated log analysis
- Threat detection models
- Compliance reporting automation

### System Hardening

Operating system and application hardening:
- Ubuntu Server hardening
- Windows Server hardening
- CIS benchmark implementation
- Firewall configuration
- Service hardening
- User account lockdown

### Network Configuration

Network segmentation and security:
- VLAN configuration
- Firewall rule deployment
- Network flow monitoring
- DMZ setup
- VPN configuration
- Network access control

### Monitoring Setup

Comprehensive logging and monitoring:
- Log forwarding configuration
- Windows Event Forwarding
- Syslog configuration
- NetFlow setup
- Azure Log Analytics integration
- Alert configuration

### Compliance Validation

Automated compliance checking:
- CMMC practice validation
- Configuration auditing
- Evidence collection
- Report generation
- Gap analysis
- Continuous monitoring

## Security Best Practices

When creating or using scripts:

1. **Never hardcode credentials** - Use environment variables or secure vaults
2. **Validate inputs** - Check all user inputs and parameters
3. **Use secure protocols** - HTTPS, SSH, secure API calls only
4. **Log actions** - Maintain audit trails of script execution
5. **Error handling** - Implement proper error handling and rollback
6. **Least privilege** - Run with minimum required permissions
7. **Code review** - Have scripts reviewed before production use

## Contributing Scripts

When contributing new scripts:

1. **Documentation** - Include clear comments and usage instructions
2. **Error handling** - Implement robust error handling
3. **Idempotency** - Scripts should be safe to run multiple times
4. **Testing** - Test thoroughly in various scenarios
5. **Dependencies** - Document all dependencies and requirements
6. **Naming** - Use clear, descriptive names (e.g., `deploy-graylog-server.sh`)

## Common Dependencies

Most scripts require some or all of:

### System Tools
- bash/sh
- curl/wget
- jq (JSON processing)
- git
- sudo access

### For Graylog Scripts
- Docker and Docker Compose (recommended), or
- MongoDB 6.0+
- OpenSearch 2.x or Elasticsearch 7.x
- Java 17+

### For Ollama Scripts
- Python 3.10+
- pip3
- Ollama binary

### For Windows Scripts
- PowerShell 7.x+
- Windows Remote Management enabled
- Administrative access

## Troubleshooting

### Common Issues

**Permission Denied**
```bash
chmod +x script-name.sh
```

**Environment Variables Not Set**
```bash
source .env
# or
export VARIABLE_NAME="value"
```

**Dependencies Missing**
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install package-name

# RedHat/CentOS
sudo yum install package-name
```

**Script Fails Midway**
- Check logs in `/var/log/` or script-specific log location
- Review error messages
- Verify network connectivity
- Check service status: `systemctl status service-name`

## Support

For issues specific to these scripts:
1. Check script documentation and comments
2. Review the main repository README
3. Open an issue on GitHub with:
   - Script name
   - Error message
   - System information
   - Steps to reproduce

## Additional Resources

- [Graylog Documentation](https://docs.graylog.org/)
- [Ollama Documentation](https://ollama.ai/docs)
- [CMMC Official Resources](https://cyberab.org/)
- [NIST SP 800-171](https://csrc.nist.gov/publications/detail/sp/800-171/rev-2/final)

---

**Remember:** Always test in a lab environment before deploying to production!
