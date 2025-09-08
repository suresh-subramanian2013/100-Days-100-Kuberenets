# Windows Setup Script for Kubernetes Tools
# This script installs kubectl, eksctl, and AWS CLI on Windows

Write-Host "🚀 Setting up Kubernetes tools on Windows..." -ForegroundColor Green

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

# Function to check if a command exists
function Test-Command($cmdname) {
    return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
}

# Step 1: Install Chocolatey if not present
if (-not (Test-Command choco)) {
    Write-Host "📦 Installing Chocolatey..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    refreshenv
} else {
    Write-Host "✅ Chocolatey already installed" -ForegroundColor Green
}

# Step 2: Install AWS CLI
if (-not (Test-Command aws)) {
    Write-Host "☁️ Installing AWS CLI..." -ForegroundColor Yellow
    choco install awscli -y
    refreshenv
} else {
    Write-Host "✅ AWS CLI already installed" -ForegroundColor Green
}

# Step 3: Install kubectl
if (-not (Test-Command kubectl)) {
    Write-Host "⚙️ Installing kubectl..." -ForegroundColor Yellow
    choco install kubernetes-cli -y
    refreshenv
} else {
    Write-Host "✅ kubectl already installed" -ForegroundColor Green
}

# Step 4: Install eksctl
if (-not (Test-Command eksctl)) {
    Write-Host "🔧 Installing eksctl..." -ForegroundColor Yellow
    choco install eksctl -y
    refreshenv
} else {
    Write-Host "✅ eksctl already installed" -ForegroundColor Green
}

# Step 5: Install Helm (optional but useful)
if (-not (Test-Command helm)) {
    Write-Host "📊 Installing Helm..." -ForegroundColor Yellow
    choco install kubernetes-helm -y
    refreshenv
} else {
    Write-Host "✅ Helm already installed" -ForegroundColor Green
}

# Step 6: Verify installations
Write-Host ""
Write-Host "🔍 Verifying installations..." -ForegroundColor Cyan

Write-Host "AWS CLI version:" -ForegroundColor Yellow
aws --version

Write-Host "kubectl version:" -ForegroundColor Yellow
kubectl version --client

Write-Host "eksctl version:" -ForegroundColor Yellow
eksctl version

Write-Host "Helm version:" -ForegroundColor Yellow
helm version

Write-Host ""
Write-Host "🎉 All tools installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Yellow
Write-Host "1. Configure AWS credentials: aws configure" -ForegroundColor White
Write-Host "2. Update kubeconfig: aws eks update-kubeconfig --region us-east-1 --name your-cluster-name" -ForegroundColor White
Write-Host "3. Test connection: kubectl get nodes" -ForegroundColor White
