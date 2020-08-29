mkdir -p C:\aks
cd C:\aks
curl -LO https://github.com/prometheus-community/windows_exporter/releases/download/v0.13.0/windows_exporter-0.13.0-amd64.msi
msiexec /i C:\aks\windows_exporter-0.13.0-amd64.msi /quiet /q /norestart /log c:\aks\install.log ENABLED_COLLECTORS=os,iis,cpu,system,container,logical_disk,net,cs,memory,terminal_services,tcp LISTEN_PORT=9100
curl -LO https://github.com/petrkle/vim-msi/releases/download/v8.1.55/vim-8.1.55.msi
msiexec /i C:\aks\vim-8.1.55.msi /quiet /q /norestart /log c:\aks\installvim.log
