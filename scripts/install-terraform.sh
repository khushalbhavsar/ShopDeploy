#!/bin/bash
#==============================================================================
# ShopDeploy - Terraform Installation Script
# Optimized for Amazon Linux 2 / Amazon Linux 2023
# Also supports Ubuntu/Debian as fallback
#==============================================================================

# Continue on error to complete as much as possible
set +e

TERRAFORM_VERSION="${1:-1.6.6}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=============================================="
echo "  Installing Terraform on Amazon Linux"
echo "=============================================="

# Detect OS version
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif [ -f /etc/amazon-linux-release ]; then
        OS="Amazon Linux"
        VER="2023"
    elif [ -f /etc/system-release ]; then
        OS=$(cat /etc/system-release | awk '{print $1}')
        VER="2"
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    echo "Detected OS: $OS $VER"
}

detect_os

# Install Terraform based on OS
if [[ "$OS" == *"Amazon Linux"* ]]; then
    log_info "Installing Terraform for Amazon Linux..."
    
    # Check if Amazon Linux 2023
    if [[ "$VER" == "2023" ]] || [[ -f /etc/amazon-linux-release ]]; then
        log_info "Detected Amazon Linux 2023"
        
        # Install prerequisites
        sudo dnf install -y dnf-plugins-core
        
        # Add HashiCorp repository for Amazon Linux 2023
        sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
        
        # Install Terraform
        sudo dnf install -y terraform
        
    else
        log_info "Detected Amazon Linux 2"
        
        # Install prerequisites
        sudo yum install -y yum-utils
        
        # Add HashiCorp repository for Amazon Linux 2
        sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
        
        # Install Terraform
        sudo yum install -y terraform
    fi

elif [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    log_info "Installing Terraform for Ubuntu/Debian..."
    
    sudo apt-get update
    sudo apt-get install -y gnupg software-properties-common
    
    # Add HashiCorp GPG key
    wget -O- https://apt.releases.hashicorp.com/gpg | \
        gpg --dearmor | \
        sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
    
    # Add repository
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
        https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
        sudo tee /etc/apt/sources.list.d/hashicorp.list
    
    sudo apt-get update
    sudo apt-get install -y terraform

else
    log_warn "Unsupported OS: $OS"
    log_info "Attempting manual installation..."
    
    # Manual installation fallback
    cd /tmp
    
    # Get latest version if not specified
    if [ "$TERRAFORM_VERSION" == "latest" ]; then
        TERRAFORM_VERSION=$(curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    fi
    
    log_info "Downloading Terraform ${TERRAFORM_VERSION}..."
    wget -q "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
    
    # Install unzip if not present
    sudo yum install -y unzip 2>/dev/null || sudo apt-get install -y unzip 2>/dev/null || true
    
    unzip -o "terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
    sudo mv terraform /usr/local/bin/
    rm "terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
fi

# Enable Terraform autocompletion
log_info "Configuring Terraform autocompletion..."
terraform -install-autocomplete 2>/dev/null || true

# Add to bashrc if not already present
if ! grep -q "terraform -install-autocomplete" ~/.bashrc 2>/dev/null; then
    echo 'complete -C /usr/bin/terraform terraform' >> ~/.bashrc 2>/dev/null || true
fi

echo ""
echo "=============================================="
echo "  Terraform Installation Complete!"
echo "=============================================="
echo ""
terraform --version
echo ""
log_info "Terraform is ready to use!"
log_info "Run 'terraform init' in your project directory to get started."
