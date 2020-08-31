FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-windowsservercore-ltsc2019
RUN powershell Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'));choco install vim -y;exit
RUN mkdir C:\restic
WORKDIR "C:\restic"
COPY . .
RUN setx path '%path%;c:\tools\vim\vim82;c:\restic;c:\scripts'
