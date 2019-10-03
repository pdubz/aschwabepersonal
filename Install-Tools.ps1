Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco feature enable -n allowGlobalConfirmation
choco install microsoft-teams
choco install googlechrome
choco install git
choco install python
choco install vscode
choco install openssl.light
choco install 7zip.install 
choco install logitechgaming
choco install unifying
choco install logitech-options