# Download windows_exporter and install
mkdir -p C:\aks
cd C:\aks
curl -LO https://github.com/prometheus-community/windows_exporter/releases/download/v0.13.0/windows_exporter-0.13.0-amd64.msi
Start-Process msiexec.exe -Wait -ArgumentList '/i "C:\aks\windows_exporter-0.13.0-amd64.msi ENABLED_COLLECTORS='os,iis,cpu,system,container,logical_disk,net,cs,memory,terminal_services,tcp' LISTEN_PORT=9100" /q /le "c:\aks\install.log" /n'
#msiexec /i C:\aks\windows_exporter-0.13.0-amd64.msi /quiet /n /norestart /log c:\aks\install.log ENABLED_COLLECTORS=os,iis,cpu,system,container,logical_disk,net,cs,memory,terminal_services,tcp LISTEN_PORT=9100
#msiexec /i C:\aks\windows_exporter-0.13.0-amd64.msi ENABLED_COLLECTORS=os,iis,cpu,system,container,memory,logical_disk,net,cs,memory,terminal_services,tcp LISTEN_PORT=9182
