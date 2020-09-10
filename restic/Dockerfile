# escape=`
# Args used by from statements must be defined here
ARG InstallerVersion=nanoserver-1809
ARG InstallerRepo=mcr.microsoft.com/powershell
# Use powershell with nanoserver
FROM ${InstallerRepo}:$InstallerVersion
USER ContainerAdministrator
# In the following line, the /M is required to address a known Docker issue in Windows Nano Server 2019.
RUN setx PATH "%PATH%;%ProgramFiles%\PowerShell;" /M
#Pull in netapi32.dll from servercore
## FROM mcr.microsoft.com/windows/servercore as core
COPY --from=mcr.microsoft.com/windows/servercore:1809 ["\\Windows\\System32\\netapi32.dll", "\\Windows\\System32"]
# intialize powershell module cache
RUN pwsh `
-NoLogo `
-NoProfile `
-Command " `
$stopTime = (get-date).AddMinutes(15); `
$ErrorActionPreference = 'Stop' ; `
$ProgressPreference = 'SilentlyContinue' ; `
while(!(Test-Path -Path $env:PSModuleAnalysisCachePath)) { `
Write-Host "'Waiting for $env:PSModuleAnalysisCachePath'" ; `
if((get-date) -gt $stopTime) { throw 'timout expired'} `
Start-Sleep -Seconds 6 ; `
}"
RUN mkdir C:\restic
WORKDIR "C:\restic"
COPY . .
RUN setx PATH "%PATH%;%ProgramFiles%\PowerShell;c:\restic;c:\scripts" /M
CMD ["pwsh.exe"]
