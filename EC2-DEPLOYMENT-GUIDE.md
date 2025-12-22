# 🚀 ShopDeploy - Amazon Linux EC2 Deployment Guide

This guide provides step-by-step instructions to deploy the ShopDeploy E-Commerce application on an Amazon Linux EC2 instance.

---

## 📋 Table of Contents

- [Prerequisites](#-prerequisites)
- [Step 1: Launch EC2 Instance](#step-1-launch-ec2-instance)
- [Step 2: Connect to EC2](#step-2-connect-to-ec2)
- [Step 3: Install Dependencies](#step-3-install-dependencies)
- [Step 4: Clone the Repository](#step-4-clone-the-repository)
- [Step 5: Configure Environment Variables](#step-5-configure-environment-variables)
- [Step 6: Deploy with Docker Compose](#step-6-deploy-with-docker-compose)
- [Step 7: Verify Deployment](#step-7-verify-deployment)
- [Troubleshooting](#-troubleshooting)
- [Security Best Practices](#-security-best-practices)

---

## 📦 Prerequisites

Before starting, ensure you have:

- ✅ AWS Account with EC2 access
- ✅ MongoDB Atlas account (or MongoDB instance)
- ✅ Cloudinary account (for image uploads)
- ✅ Stripe account (for payment processing)
- ✅ SSH key pair for EC2 access

---

## Step 1: Launch EC2 Instance

### 1.1 Go to AWS Console → EC2 → Launch Instance

### 1.2 Configure Instance Settings:

| Setting | Recommended Value |
|---------|-------------------|
| **Name** | `shopdeploy-server` |
| **AMI** | Amazon Linux 2023 AMI |
| **Instance Type** | `t2.medium` or `t3.medium` (minimum 2GB RAM) |
| **Key Pair** | Create new or select existing |
| **Storage** | 20 GB gp3 (minimum) |

### 1.3 Configure Security Group:

Create a new security group with the following inbound rules:

| Type | Port Range | Source | Description |
|------|------------|--------|-------------|
| SSH | 22 | Your IP | SSH access |
| HTTP | 80 | 0.0.0.0/0 | Web traffic |
| HTTPS | 443 | 0.0.0.0/0 | Secure web traffic |
| Custom TCP | 3000 | 0.0.0.0/0 | Frontend |
| Custom TCP | 5000 | 0.0.0.0/0 | Backend API |

### 1.4 Launch the Instance

Click **Launch Instance** and wait for it to start.

---

## Step 2: Connect to EC2

### Option A: SSH from Terminal

```bash
# Change permissions of your key file
chmod 400 your-key.pem

# Connect to EC2
ssh -i "your-key.pem" ec2-user@<YOUR-EC2-PUBLIC-IP>
```

### Option B: EC2 Instance Connect

1. Go to EC2 Dashboard → Instances
2. Select your instance
3. Click **Connect** → **EC2 Instance Connect**
4. Click **Connect**

---

## Step 3: Install Dependencies

### 3.1 Update System Packages

```bash
sudo yum update -y
```

### 3.2 Install Git

```bash
sudo yum install -y git
```

### 3.3 Install Docker

```bash
# Install Docker
sudo yum install -y docker

# Start Docker service
sudo systemctl start docker

# Enable Docker to start on boot
sudo systemctl enable docker

# Add ec2-user to docker group (to run docker without sudo)
sudo usermod -aG docker ec2-user

# Apply group changes (logout and login required, or run)
newgrp docker
```

### 3.4 Install Docker Compose

```bash
# Download Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Make it executable
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker-compose --version
```

### 3.5 (Optional) Install Node.js (for local development/testing)

```bash
# Install Node.js 18.x
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo yum install -y nodejs

# Verify installation
node --version
npm --version
```

---

## Step 4: Clone the Repository

```bash
# Navigate to home directory
cd ~

# Clone the repository
git clone https://github.com/YOUR-USERNAME/ShopDeploy.git

# Navigate to project directory
cd ShopDeploy
```

---

## Step 5: Configure Environment Variables

### 5.1 Create Backend Environment File

```bash
# Create .env file in the shopdeploy-backend directory
nano shopdeploy-backend/.env
```

Add the following content (replace with your actual values):

```env
# Server Configuration
NODE_ENV=production
PORT=5000

# MongoDB Configuration
MONGODB_URI=mongodb+srv://<username>:<password>@<cluster>.mongodb.net/shopdeploy?retryWrites=true&w=majority

# JWT Configuration
JWT_ACCESS_SECRET=your-super-secure-access-secret-key-here
JWT_REFRESH_SECRET=your-super-secure-refresh-secret-key-here
JWT_ACCESS_EXPIRE=15m
JWT_REFRESH_EXPIRE=7d

# Frontend URL (for CORS)
FRONTEND_URL=http://<YOUR-EC2-PUBLIC-IP>:3000

# Cloudinary Configuration (for image uploads)
CLOUDINARY_CLOUD_NAME=your-cloudinary-cloud-name
CLOUDINARY_API_KEY=your-cloudinary-api-key
CLOUDINARY_API_SECRET=your-cloudinary-api-secret

# Stripe Configuration (for payments)
STRIPE_SECRET_KEY=sk_test_your-stripe-secret-key
```

Press `Ctrl + X`, then `Y`, then `Enter` to save.

### 5.2 Create Root .env File (for Docker Compose)

```bash
# Create .env file in the root directory
nano .env
```

Add the following content:

```env
# MongoDB
MONGODB_URI=mongodb+srv://<username>:<password>@<cluster>.mongodb.net/shopdeploy?retryWrites=true&w=majority

# JWT Secrets
JWT_ACCESS_SECRET=your-super-secure-access-secret-key-here
JWT_REFRESH_SECRET=your-super-secure-refresh-secret-key-here
JWT_ACCESS_EXPIRE=15m
JWT_REFRESH_EXPIRE=7d

# URLs
FRONTEND_URL=http://<YOUR-EC2-PUBLIC-IP>:3000
VITE_API_URL=http://<YOUR-EC2-PUBLIC-IP>:5000/api

# Cloudinary
CLOUDINARY_CLOUD_NAME=your-cloudinary-cloud-name
CLOUDINARY_API_KEY=your-cloudinary-api-key
CLOUDINARY_API_SECRET=your-cloudinary-api-secret

# Stripe
STRIPE_SECRET_KEY=sk_test_your-stripe-secret-key
```

Press `Ctrl + X`, then `Y`, then `Enter` to save.

---

## Step 6: Deploy with Docker Compose

### 6.1 Build and Start Containers

```bash
# Build the containers (first time)
docker-compose build

# Start the containers in detached mode
docker-compose up -d
```

### 6.2 View Container Logs

```bash
# View all container logs
docker-compose logs -f

# View specific container logs
docker-compose logs -f backend
docker-compose logs -f frontend
```

### 6.3 Check Container Status

```bash
docker-compose ps
```

Expected output:
```
NAME                    COMMAND                  SERVICE     STATUS          PORTS
shopdeploy-backend      "node src/server.js"     backend     running (healthy)   0.0.0.0:5000->5000/tcp
shopdeploy-frontend     "nginx -g 'daemon off;'" frontend    running (healthy)   0.0.0.0:3000->80/tcp
```

---

## Step 7: Verify Deployment

### 7.1 Test Backend API

```bash
# Health check
curl http://localhost:5000/api/health/health

# Or from your browser
# http://<YOUR-EC2-PUBLIC-IP>:5000/api/health/health
```

### 7.2 Access Frontend

Open your browser and navigate to:
```
http://<YOUR-EC2-PUBLIC-IP>:3000
```

### 7.3 Seed Sample Data (Optional)

```bash
# Enter the backend container
docker exec -it shopdeploy-backend sh

# Run seed script
npm run seed

# Exit container
exit
```

---

## 🔄 Managing the Application

### Stop the Application

```bash
docker-compose down
```

### Restart the Application

```bash
docker-compose restart
```

### Update the Application

```bash
# Pull latest changes
git pull origin main

# Rebuild and restart containers
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
```

### Clean Up Docker Resources

```bash
# Remove unused images
docker image prune -a

# Remove all stopped containers
docker container prune

# Remove unused volumes
docker volume prune
```

---

## 🔧 Troubleshooting

### Issue: Docker command not found

```bash
# Verify Docker is installed
sudo systemctl status docker

# If not running, start Docker
sudo systemctl start docker
```

### Issue: Permission denied when running Docker

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply changes
newgrp docker

# Or logout and login again
```

### Issue: Port already in use

```bash
# Find process using the port
sudo lsof -i :5000
sudo lsof -i :3000

# Kill the process if needed
sudo kill -9 <PID>
```

### Issue: Container keeps restarting

```bash
# Check container logs
docker-compose logs backend

# Common issues:
# - Invalid MongoDB connection string
# - Missing environment variables
# - Incorrect Cloudinary/Stripe credentials
```

### Issue: Frontend can't connect to Backend

1. Verify `VITE_API_URL` in `.env` points to correct backend URL
2. Ensure backend container is healthy: `docker-compose ps`
3. Check security group allows port 5000

### Issue: MongoDB connection failed

1. Verify MongoDB Atlas whitelist includes EC2's public IP (or use `0.0.0.0/0`)
2. Check MongoDB URI is correct in `.env`
3. Ensure username/password don't contain special characters without URL encoding

---

## 🔒 Security Best Practices

### 1. Use Strong Secrets

Generate secure JWT secrets:
```bash
openssl rand -base64 64
```

### 2. Restrict Security Group

- Limit SSH access to your IP only
- Consider using AWS Systems Manager Session Manager instead of SSH

### 3. Enable HTTPS

Use a reverse proxy like Nginx with Let's Encrypt:

```bash
# Install Nginx
sudo yum install -y nginx

# Install Certbot
sudo yum install -y certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d yourdomain.com
```

### 4. Use AWS Secrets Manager

Store sensitive credentials in AWS Secrets Manager instead of `.env` files.

### 5. Regular Updates

```bash
# Update system packages regularly
sudo yum update -y
```

### 6. Monitor Logs

```bash
# Monitor Docker logs
docker-compose logs -f

# Monitor system logs
sudo journalctl -f
```

---

## 📊 Production Recommendations

| Aspect | Recommendation |
|--------|----------------|
| **Instance Type** | `t3.medium` or larger for production |
| **Load Balancer** | Use Application Load Balancer (ALB) |
| **Database** | Use MongoDB Atlas with dedicated cluster |
| **SSL/TLS** | Use AWS Certificate Manager with ALB |
| **Monitoring** | Enable CloudWatch monitoring |
| **Backups** | Enable EBS snapshots |
| **Auto Scaling** | Configure Auto Scaling Group |

---

## 🎯 Quick Reference Commands

```bash
# Start application
docker-compose up -d

# Stop application
docker-compose down

# View logs
docker-compose logs -f

# Restart application
docker-compose restart

# Rebuild containers
docker-compose build --no-cache

# Check container status
docker-compose ps

# Enter backend container
docker exec -it shopdeploy-backend sh

# Enter frontend container
docker exec -it shopdeploy-frontend sh
```

---

## 📞 Support

If you encounter issues:

1. Check the [Troubleshooting](#-troubleshooting) section
2. Review container logs: `docker-compose logs -f`
3. Open an issue on GitHub

---

**Happy Deploying! 🚀**
