# Set PowerShell execution policy to RemoteSigned for the current user
$ExecutionPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($ExecutionPolicy -eq "RemoteSigned") {
    Write-Verbose "Execution policy is already set to RemoteSigned for the current user, skipping..." -Verbose
} 
else {
    Write-Verbose "Setting execution policy to RemoteSigned for the current user..." -Verbose
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
}

# Install chocolatey
if ([bool](Get-Command -Name 'choco' -ErrorAction SilentlyContinue)) {
    Write-Verbose "Chocolatey is already installed, skip installation." -Verbose
}
else {
    Write-Verbose "Installing Chocolatey..." -Verbose
    Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

# Install scoop
if (!(Get-Command -Name 'scoop' -ErrorAction SilentlyContinue)) {
    Write-Verbose "Installing Scoop..." -Verbose
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://get.scoop.sh'))
}

# Install Python via Scoop
if (!(Get-Command -Name 'python' -ErrorAction SilentlyContinue)) {
    Write-Verbose "Installing Python..." -Verbose
    Invoke-Expression (scoop bucket add versions)
    Invoke-Expression (scoop install versions/python310)
}

# Install OpenSSH Server
if ([bool](Get-Service -Name sshd -ErrorAction SilentlyContinue)) {
    Write-Verbose "OpenSSH is already installed, skip installation." -Verbose
}
else {
    Write-Verbose "Installing OpenSSH..." -Verbose
    $openSSHpackages = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*' | Select-Object -ExpandProperty Name

    foreach ($package in $openSSHpackages) {
        Add-WindowsCapability -Online -Name $package
    }

    # Check again if the service exists, and if not, prompt for reboot
    if (!(Get-Service -Name sshd -ErrorAction SilentlyContinue)) {
        Write-Host "The OpenSSH service wasn't detected. It's recommended to reboot your system now. Do you wish to reboot now? [Y/N]" -ForegroundColor Yellow
        $response = Read-Host
        if ($response -eq 'Y' -or $response -eq 'y') {
            Restart-Computer
        } else {
            Write-Host "Please manually reboot your system later to ensure OpenSSH is properly installed." -ForegroundColor Yellow
        }
    }
}

# Start the sshd service
Write-Verbose "Starting OpenSSH service..." -Verbose
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'

# Confirm the Firewall rule is configured
Write-Verbose "Confirming the Firewall rule is configured..." -Verbose
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
    Write-Verbose "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist, creating it..."
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
} else {
    Write-Verbose "Firewall rule 'OpenSSH-Server-In-TCP' already exists."
}
