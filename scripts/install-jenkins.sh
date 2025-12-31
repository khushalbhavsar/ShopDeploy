#!/bin/bash
#==============================================================================
# ShopDeploy - Jenkins Installation Script
# Optimized for Amazon Linux 2 / Amazon Linux 2023
# Also supports Ubuntu/Debian as fallback
#==============================================================================

# Continue on error to complete as much as possible
set +e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=============================================="
echo "  Installing Jenkins on Amazon Linux"
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

# Install Jenkins based on OS
if [[ "$OS" == *"Amazon Linux"* ]]; then
    log_info "Installing Jenkins for Amazon Linux..."
    
    # Check if Amazon Linux 2023
    if [[ "$VER" == "2023" ]] || [[ -f /etc/amazon-linux-release ]]; then
        log_info "Detected Amazon Linux 2023"
        
        # Install Java 17 on Amazon Linux 2023
        log_info "Installing Java 17 (Amazon Corretto)..."
        sudo dnf install -y java-17-amazon-corretto java-17-amazon-corretto-devel
        
        # Add Jenkins repository for Amazon Linux 2023
        sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
        sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
        
        # Install Jenkins
        sudo dnf install -y jenkins
        
    else
        log_info "Detected Amazon Linux 2"
        
        # Install Java 17 on Amazon Linux 2
        log_info "Installing Java 17 (Amazon Corretto)..."
        
        # Try amazon-linux-extras first, then fall back to direct install
        if command -v amazon-linux-extras &> /dev/null; then
            sudo amazon-linux-extras install java-openjdk17 -y 2>/dev/null || \
                sudo yum install -y java-17-amazon-corretto java-17-amazon-corretto-devel
        else
            sudo yum install -y java-17-amazon-corretto java-17-amazon-corretto-devel
        fi
        
        # Add Jenkins repository for Amazon Linux 2
        sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
        sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
        
        # Install Jenkins
        sudo yum install -y jenkins
    fi
    
    # Configure firewall (if firewalld is running)
    if systemctl is-active --quiet firewalld; then
        log_info "Configuring firewall..."
        sudo firewall-cmd --permanent --add-port=8080/tcp
        sudo firewall-cmd --reload
    fi

elif [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    log_info "Installing Jenkins for Ubuntu/Debian..."
    
    # Install Java 17
    sudo apt-get update
    sudo apt-get install -y fontconfig openjdk-17-jre
    
    # Add Jenkins repository
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
        /etc/apt/keyrings/jenkins-keyring.asc > /dev/null
    
    echo deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] \
        https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
        /etc/apt/sources.list.d/jenkins.list > /dev/null
    
    sudo apt-get update
    sudo apt-get install -y jenkins

else
    log_error "Unsupported OS: $OS"
    log_info "Attempting generic RHEL-based installation..."
    
    # Generic RHEL-based installation
    sudo yum install -y java-17-openjdk java-17-openjdk-devel
    sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
    sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
    sudo yum install -y jenkins
fi

# Set JAVA_HOME
log_info "Configuring JAVA_HOME..."
JAVA_PATH=$(dirname $(dirname $(readlink -f $(which java))))
echo "JAVA_HOME=$JAVA_PATH" | sudo tee -a /etc/environment
export JAVA_HOME=$JAVA_PATH

# Configure Jenkins to use correct Java
if [ -f /etc/sysconfig/jenkins ]; then
    echo "JENKINS_JAVA_CMD=$JAVA_PATH/bin/java" | sudo tee -a /etc/sysconfig/jenkins
fi

# Enable and start Jenkins
log_info "Starting Jenkins service..."
sudo systemctl daemon-reload
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Wait for Jenkins to fully start
log_info "Waiting for Jenkins to start (this may take 30-60 seconds)..."
sleep 30

# Check if Jenkins is running
max_attempts=6
attempt=1
while [ $attempt -le $max_attempts ]; do
    if sudo systemctl is-active --quiet jenkins; then
        log_info "Jenkins is running!"
        break
    else
        log_warn "Waiting for Jenkins to start... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    fi
done

echo ""
echo "=============================================="
echo "  Jenkins Installation Complete!"
echo "=============================================="
echo ""
echo "Java version:"
java -version 2>&1 | head -3
echo ""

# Display initial admin password
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    echo "=============================================="
    log_info "Jenkins Initial Admin Password:"
    echo ""
    sudo cat /var/lib/jenkins/secrets/initialAdminPassword
    echo ""
    echo "=============================================="
fi

# Get instance IP for access URL
INSTANCE_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
log_info "Jenkins URL: http://${INSTANCE_IP}:8080"
echo ""
log_info "Next steps:"
echo "  1. Open http://${INSTANCE_IP}:8080 in your browser"
echo "  2. Enter the initial admin password shown above"
echo "  3. Install suggested plugins"
echo "  4. Create your admin user"
echo ""
log_warn "Don't forget to add Jenkins user to docker group:"
echo "  sudo usermod -aG docker jenkins"
echo "  sudo systemctl restart jenkins"
