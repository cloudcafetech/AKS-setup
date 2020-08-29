mkdir -p C:\tools
cd C:\tools
curl -LO https://github.com/petrkle/vim-msi/releases/download/v8.1.55/vim-8.1.55.msi
msiexec /i C:\tools\vim-8.1.55.msi /quiet /q /norestart /log c:\aks\installvim.log
