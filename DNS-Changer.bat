@echo off
setlocal DisableDelayedExpansion
title DNS Changer

net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

set "adapter="
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "@(Get-NetConnectionProfile)[0].InterfaceAlias"`) do set "adapter=%%a"
if not defined adapter (
    for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "@(Get-NetIPConfiguration)[0].InterfaceAlias"`) do set "adapter=%%a"
)
if not defined adapter (
    echo [ERROR] Cannot detect active adapter.
    powershell -NoProfile -Command "Get-NetAdapter | Format-Table Name,Status -AutoSize"
    set "adapter="
    set /p "adapter=Enter adapter name manually: "
    if not defined adapter exit /b 1
)

:menu
cls
echo ============================================
echo  Active adapter: "%adapter%"
echo ============================================
echo Current DNS (IPv4):
netsh interface ip show dns name="%adapter%"
echo.
echo Current DNS (IPv6):
netsh interface ipv6 show dns name="%adapter%"
echo.
echo Select DNS provider:
echo 1) Google DNS          8.8.8.8          [8.8.4.4]
echo 2) Cloudflare DNS      1.1.1.1          [1.0.0.1]
echo 3) Quad9 DNS           9.9.9.9          [9.9.9.10]
echo 4) OpenDNS             208.67.222.222   [208.67.220.220]
echo 5) AdGuard DNS         94.140.14.14     [94.140.15.15]
echo 6) DNS.Watch           84.200.69.80     [84.200.70.40]
echo 7) CleanBrowsing DNS   185.228.168.168  [185.228.169.168]
echo 8) Control D           76.76.2.0        [76.76.10.0]
echo 9) Own Format (IPv4/IPv6)
echo 10) Automatic (DHCP)
echo 11) Close
echo ============================================
set "choice="
set /p "choice=Enter number (1-11): "
if not defined choice goto menu

if "%choice%"=="1"  (set "dns1=8.8.8.8"           & set "dns2=8.8.4.4"         & goto apply)
if "%choice%"=="2"  (set "dns1=1.1.1.1"           & set "dns2=1.0.0.1"         & goto apply)
if "%choice%"=="3"  (set "dns1=9.9.9.9"           & set "dns2=9.9.9.10"        & goto apply)
if "%choice%"=="4"  (set "dns1=208.67.222.222"    & set "dns2=208.67.220.220"  & goto apply)
if "%choice%"=="5"  (set "dns1=94.140.14.14"      & set "dns2=94.140.15.15"    & goto apply)
if "%choice%"=="6"  (set "dns1=84.200.69.80"      & set "dns2=84.200.70.40"    & goto apply)
if "%choice%"=="7"  (set "dns1=185.228.168.168"   & set "dns2=185.228.169.168" & goto apply)
if "%choice%"=="8"  (set "dns1=76.76.2.0"         & set "dns2=76.76.10.0"      & goto apply)
if "%choice%"=="9"  goto own
if "%choice%"=="10" goto dhcp
if "%choice%"=="11" exit /b 0

echo Invalid input.
timeout /t 2 >nul
goto menu

:own
echo.
set "dns1="
set "dns2="
set /p "dns1=Primary DNS: "
set /p "dns2=Secondary DNS: "
call :validate_ip "%dns1%"
if errorlevel 1 ( echo Invalid primary DNS. & timeout /t 2 >nul & goto menu )
call :validate_ip "%dns2%"
if errorlevel 1 ( echo Invalid secondary DNS. & timeout /t 2 >nul & goto menu )
goto apply

:dhcp
echo.
echo Setting DNS to automatic (DHCP)...
netsh interface ip   set dns name="%adapter%" source=dhcp >nul 2>&1
netsh interface ipv6 set dns name="%adapter%" source=dhcp >nul 2>&1
ipconfig /flushdns >nul 2>&1
echo Done. DNS cache flushed.
timeout /t 2 >nul
goto menu

:apply
echo.
echo Setting DNS: %dns1% [%dns2%] ...
set "isv6=0"
echo %dns1%| findstr ":" >nul && set "isv6=1"
if "%isv6%"=="1" (
    netsh interface ipv6 set dns name="%adapter%" static %dns1% primary >nul 2>&1
    if errorlevel 1 ( echo Failed to set primary IPv6 DNS. & pause & goto menu )
    netsh interface ipv6 add dns name="%adapter%" %dns2% index=2 >nul 2>&1
    if errorlevel 1 ( echo Failed to set secondary IPv6 DNS. & pause & goto menu )
) else (
    netsh interface ip set dns name="%adapter%" static %dns1% primary >nul 2>&1
    if errorlevel 1 ( echo Failed to set primary IPv4 DNS. & pause & goto menu )
    netsh interface ip add dns name="%adapter%" %dns2% index=2 >nul 2>&1
    if errorlevel 1 ( echo Failed to set secondary IPv4 DNS. & pause & goto menu )
)
ipconfig /flushdns >nul 2>&1
echo Done. DNS cache flushed.
echo.
pause
goto menu

:validate_ip
powershell -NoProfile -Command "if (-not [System.Net.IPAddress]::TryParse('%~1',[ref]$null)) { exit 1 }"
exit /b %errorlevel%