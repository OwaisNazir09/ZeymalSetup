@echo off
setlocal enabledelayedexpansion

:: FIRST: Check admin rights
net session >nul 2>&1
if errorlevel 1 (
    echo This script requires administrative privileges.
    echo Please run it as administrator.
    pause
    exit /b 1
)
echo Running with administrative privileges.

:: SECOND: Check Windows version
for /f "delims=" %%A in ('powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).Caption"') do set "windowsName=%%A"
echo Detected OS: %windowsName%

echo %windowsName% | findstr /I /C:"Windows 7" /C:"Windows 8" /C:"Windows 10" /C:"Windows 11" >nul
if errorlevel 1 (
    echo Unsupported Windows version detected.
    echo This installer only supports Windows 7, 8, 10, and 11.
    pause
    exit /b 1
)
echo Supported Windows version detected.
echo Continuing installation...

:: THIRD: Create user
set "newUser=postgres"
set "newPassword=362611"

net user "%newUser%" >nul 2>&1
if errorlevel 1 (
    echo User account %newUser% does not exist.
    echo Creating user account...
    net user "%newUser%" "%newPassword%" /add
    if !errorlevel! neq 0 (
        echo Failed to create user account.
        pause
        exit /b 1
    )
    echo User account %newUser% created successfully.
) else (
    echo User account %newUser% already exists.
)

:: FOURTH: Create app folder
set "appFolder=C:\Users\%newUser%\zeymal"
if not exist "%appFolder%" (
    mkdir "%appFolder%"
    if !errorlevel! neq 0 (
        echo Failed to create application folder.
        pause
        exit /b 1
    )
    echo Application folder created successfully: %appFolder%
) else (
    echo Application folder already exists: %appFolder%
)

:: FIFTH: Create Downloads folder
set "DownloadPath=C:\Users\%newUser%\Downloads"
if not exist "%DownloadPath%" (
    mkdir "%DownloadPath%"
    if !errorlevel! neq 0 (
        echo Failed to create Downloads folder.
        pause
        exit /b 1
    )
    echo Downloads folder created successfully: %DownloadPath%
) else (
    echo Downloads folder already exists: %DownloadPath%
)

:: SIXTH: Install SQL Server based on Windows version
echo %windowsName% | findstr /I /C:"Windows 11" /C:"Windows 10" >nul
if not errorlevel 1 (
    call :InstallSqlModern
) else (
    echo %windowsName% | findstr /I /C:"Windows 7" /C:"Windows 8" >nul
    if not errorlevel 1 (
        call :InstallSqlLegacy
    ) else (
        echo Unsupported Windows version.
        pause
        exit /b 1
    )
)

:: SEVENTH: Install Java (JRE 8u271)
call :InstallJava

echo.
echo === Setup complete ===
pause
exit /b 0


:: ============================================================
:: :Download   URL   Destination   FriendlyName
:: Linux-style progress: [====>   ] 47% 12.3MB/26.1MB 2.1MB/s ETA 00:07
:: ============================================================
:Download
set "DL_URL=%~1"
set "DL_DEST=%~2"
set "DL_NAME=%~3"
echo.
echo [Download] %DL_NAME%
echo   From: %DL_URL%
echo   To:   %DL_DEST%
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; function FmtSize($b) { if ($b -ge 1GB) { '{0,7:N2} GB' -f ($b/1GB) } elseif ($b -ge 1MB) { '{0,7:N2} MB' -f ($b/1MB) } elseif ($b -ge 1KB) { '{0,7:N2} KB' -f ($b/1KB) } else { '{0,7} B ' -f [int]$b } }; function FmtTime($s) { if ($s -le 0 -or [double]::IsInfinity($s) -or [double]::IsNaN($s)) { return '--:--' }; $ts = [TimeSpan]::FromSeconds([int]$s); if ($ts.TotalHours -ge 1) { '{0:D2}:{1:D2}:{2:D2}' -f [int]$ts.TotalHours,$ts.Minutes,$ts.Seconds } else { '{0:D2}:{1:D2}' -f $ts.Minutes,$ts.Seconds } }; $url = $env:DL_URL; $dest = $env:DL_DEST; $script:start = Get-Date; $wc = New-Object System.Net.WebClient; $null = Register-ObjectEvent $wc DownloadProgressChanged -SourceIdentifier DP -Action { $now = Get-Date; $el = ($now - $script:start).TotalSeconds; $r = [double]$EventArgs.BytesReceived; $t = [double]$EventArgs.TotalBytesToReceive; $p = [int]$EventArgs.ProgressPercentage; $spd = if ($el -gt 0) { $r / $el } else { 0 }; $eta = if ($spd -gt 0 -and $t -gt 0) { ($t - $r) / $spd } else { 0 }; $bw = 30; $fill = [int][math]::Floor(($p / 100.0) * $bw); if ($fill -gt $bw) { $fill = $bw }; if ($fill -lt 0) { $fill = 0 }; if ($fill -eq $bw) { $bar = '=' * $bw } else { $bar = ('=' * $fill) + '>' + (' ' * ($bw - $fill - 1)) }; Write-Host -NoNewline (\"`r  [{0}] {1,3}%% {2} / {3}  {4}/s  ETA {5}   \" -f $bar,$p,(FmtSize $r),(FmtSize $t),(FmtSize $spd),(FmtTime $eta)) }; $null = Register-ObjectEvent $wc DownloadFileCompleted -SourceIdentifier DC; try { $wc.DownloadFileAsync([Uri]$url, $dest); $null = Wait-Event -SourceIdentifier DC -Timeout 1800; Write-Host ''; if (Test-Path $dest) { $sz = FmtSize (Get-Item $dest).Length; $secs = ((Get-Date) - $script:start).TotalSeconds; Write-Host (\"  Done. Saved {0} in {1}.\" -f $sz.Trim(),(FmtTime $secs)); exit 0 } else { Write-Host '  Download failed.'; exit 1 } } finally { Unregister-Event DP -ErrorAction SilentlyContinue; Unregister-Event DC -ErrorAction SilentlyContinue; $wc.Dispose() } }"
set "rc=!errorlevel!"
set "DL_URL="
set "DL_DEST="
set "DL_NAME="
exit /b %rc%


:: ============================================================
:: SQL Server 2022 Express + SSMS  (Windows 10/11)
:: ============================================================
:InstallSqlModern
echo.
echo === Installing SQL Server 2022 Express ===

set "SqlBootstrap=%DownloadPath%\SQL2022-SSEI-Expr.exe"
call :Download "https://go.microsoft.com/fwlink/p/?linkid=2216019&clcid=0x409&culture=en-us&country=us" "%SqlBootstrap%" "SQL Server 2022 Express bootstrapper"
if !errorlevel! neq 0 (
    echo Failed to download SQL Server 2022 Express.
    pause
    exit /b 1
)

echo Starting SQL Server installation...
"%SqlBootstrap%" /ACTION=Install /IACCEPTSQLSERVERLICENSETERMS /QUIET /HIDEPROGRESSBAR ^
    /INSTANCENAME=SQLEXPRESS ^
    /FEATURES=SQLENGINE ^
    /SQLSVCACCOUNT="NT Service\MSSQL$SQLEXPRESS" ^
    /SQLSYSADMINACCOUNTS="BUILTIN\ADMINISTRATORS" ^
    /SECURITYMODE=SQL ^
    /SAPWD="%newPassword%" ^
    /TCPENABLED=1

if !errorlevel! neq 0 (
    echo SQL Server installation reported an error. Check logs at:
    echo   %ProgramFiles%\Microsoft SQL Server\160\Setup Bootstrap\Log
    pause
    exit /b 1
)
echo SQL Server 2022 Express installed successfully.

echo.
echo === Installing SQL Server Management Studio (SSMS) ===
set "SsmsInstaller=%DownloadPath%\SSMS-Setup-ENU.exe"
call :Download "https://aka.ms/ssmsfullsetup" "%SsmsInstaller%" "SSMS"
if !errorlevel! neq 0 (
    echo Failed to download SSMS. Install manually from https://aka.ms/ssmsfullsetup
    exit /b 0
)

echo Installing SSMS...
"%SsmsInstaller%" /install /quiet /norestart
if !errorlevel! neq 0 (
    echo SSMS installation reported an error. Install manually later.
) else (
    echo SSMS installed successfully.
)
exit /b 0


:: ============================================================
:: SQL Server 2014 Express  (Windows 7/8)
:: ============================================================
:InstallSqlLegacy
echo.
echo === Installing SQL Server 2014 Express with Tools ===

set "SqlLegacyUrl=https://download.microsoft.com/download/E/A/E/EAE6F7FC-767A-4038-A954-49B8B05D04EB/ExpressAndTools 64BIT/SQLEXPRWT_x64_ENU.exe"
set "SqlLegacyInstaller=%DownloadPath%\SQLEXPRWT.exe"

call :Download "%SqlLegacyUrl%" "%SqlLegacyInstaller%" "SQL Server 2014 Express with Tools"
if !errorlevel! neq 0 (
    echo Failed to download SQL Server 2014 Express.
    echo Manual: https://www.microsoft.com/en-us/download/details.aspx?id=42299
    pause
    exit /b 1
)

echo Starting SQL Server installation...
"%SqlLegacyInstaller%" /Q /IACCEPTSQLSERVERLICENSETERMS /ACTION=INSTALL ^
    /FEATURES=SQLENGINE ^
    /INSTANCENAME=SQLEXPRESS ^
    /SQLSVCACCOUNT="NT AUTHORITY\Network Service" ^
    /SQLSYSADMINACCOUNTS="BUILTIN\ADMINISTRATORS" ^
    /SECURITYMODE=SQL ^
    /SAPWD="%newPassword%" ^
    /TCPENABLED=1

if !errorlevel! neq 0 (
    echo SQL Server installation reported an error. Check the setup logs.
    pause
    exit /b 1
)
echo SQL Server 2014 Express installed successfully.
echo Note: SSMS 2014 is not bundled here. Install it manually if needed.
exit /b 0


:: ============================================================
:: Java JRE 8u271 (32-bit iftw web installer)
:: Also disables auto-update (covers doc step 9).
:: ============================================================
:InstallJava
echo.
echo === Installing Java JRE 8u271 ===

set "JavaInstaller=%DownloadPath%\jre-8u271-windows-i586-iftw.exe"
set "JavaUrl=https://javadl.oracle.com/webapps/download/GetFile/1.8.0_271-b09/61ae65e088624f5aaa0b1d2d801741d9/windows-i586/jre-8u271-windows-i586-iftw.exe"

if exist "%JavaInstaller%" (
    echo Found existing installer at %JavaInstaller%, skipping download.
) else (
    call :Download "%JavaUrl%" "%JavaInstaller%" "Java JRE 8u271"
    if !errorlevel! neq 0 (
        echo Failed to download Java JRE 8u271.
        echo Oracle now gates JRE 8 downloads. Place the file manually at:
        echo   %JavaInstaller%
        echo Then re-run this script, or install Java by hand.
        pause
        exit /b 1
    )
)

echo Installing Java silently (auto-update disabled)...
"%JavaInstaller%" /s AUTO_UPDATE=Disable STATIC=1 REBOOT=Disable EULA=Disable NOSTARTMENU=Enable WEB_ANALYTICS=Disable
if !errorlevel! neq 0 (
    echo Java installation reported an error. Install manually if needed.
    exit /b 0
)
echo Java JRE 8u271 installed successfully.
exit /b 0
