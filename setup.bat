@echo off
:: ============================================================
:: Persistent-window guard.
:: When the script is launched by double-click / "Run as
:: administrator", Windows invokes it with cmd /c, which closes
:: the window the moment the batch exits (or errors, or hits a
:: parse fault). Re-launch ourselves once under cmd /k so the
:: console stays open no matter how or where the script exits.
:: ============================================================
if /I not "%~1"=="__keepopen__" (
    %comspec% /k call "%~f0" __keepopen__
    exit /b
)
shift
setlocal enabledelayedexpansion
title Zeymal Environment Setup

:: ============================================================
::  Zeymal Environment Setup
:: ============================================================
echo.
echo ============================================================
echo   Zeymal Environment Setup
echo ============================================================
echo   This script will:
echo     * Create the "postgres" (SQL admin) and "RT" (IIS/FTP) users
echo     * Prepare application and download folders
echo     * Install SQL Server Express (2022 on Win10/11, 2014 on Win7/8)
echo     * Install Java Runtime Environment 8u271
echo     * Download and deploy the Zeymal application files
echo     * Configure SQL Server (TCP/IP, port 1433)
echo     * Install IIS + FTP and configure the RT site
echo     * Restore the Ashley database
echo ============================================================
echo.

:: ------------------------------------------------------------
:: [1/14] Check administrator privileges
:: ------------------------------------------------------------
echo [1/14] Checking administrator privileges...
net session >nul 2>&1
if errorlevel 1 (
    set "failStep=1/14 admin privileges check"
    echo   [ERROR] This script requires administrator privileges.
    echo           Right-click the script and choose "Run as administrator".
    goto :fatal
)
echo   [ OK  ] Running with administrator privileges.
echo.

:: ------------------------------------------------------------
:: [2/14] Detect and validate Windows version
:: ------------------------------------------------------------
echo [2/14] Detecting Windows version...
for /f "delims=" %%A in ('powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).Caption"') do set "windowsName=%%A"
echo   Detected OS: %windowsName%

echo %windowsName% | findstr /I /C:"Windows 7" /C:"Windows 8" /C:"Windows 10" /C:"Windows 11" >nul
if errorlevel 1 (
    set "failStep=2/14 Windows version detection"
    echo   [ERROR] Unsupported Windows version.
    echo           This installer supports Windows 7, 8, 10, and 11 only.
    goto :fatal
)
echo   [ OK  ] Supported Windows version detected.
echo.

:: ------------------------------------------------------------
:: [3/14] Create the "postgres" user (used as SQL SA password holder)
:: ------------------------------------------------------------
echo [3/14] Configuring "postgres" user account...
set "newUser=postgres"
set "newPassword=362611"
call :EnsureUser "%newUser%" "%newPassword%" "0"
if !errorlevel! neq 0 ( set "failStep=3/14 create postgres user" & goto :fatal )
echo.

:: ------------------------------------------------------------
:: [4/14] Create the "RT" user (used by IIS + FTP)
:: ------------------------------------------------------------
echo [4/14] Configuring "RT" user account for IIS/FTP...
set "rtUser=RT"
set "rtPassword=master"
call :EnsureUser "%rtUser%" "%rtPassword%" "1"
if !errorlevel! neq 0 ( set "failStep=4/14 create RT user" & goto :fatal )
echo.

:: ------------------------------------------------------------
:: [5/14] Create the application folder
:: ------------------------------------------------------------
echo [5/14] Preparing application folder...
set "appFolder=C:\Users\%newUser%\zeymal"
if not exist "%appFolder%" (
    mkdir "%appFolder%"
    if !errorlevel! neq 0 (
        set "failStep=5/14 create application folder"
        echo   [ERROR] Failed to create application folder.
        echo           Path: %appFolder%
        goto :fatal
    )
    echo   [ OK  ] Created: %appFolder%
) else (
    echo   [ OK  ] Already exists: %appFolder%
)
echo   [NOTE ] The manual suggests using a non-C drive if available.
echo.

:: ------------------------------------------------------------
:: [6/14] Create the Downloads folder
:: ------------------------------------------------------------
echo [6/14] Preparing Downloads folder...
set "DownloadPath=C:\Users\%newUser%\Downloads"
if not exist "%DownloadPath%" (
    mkdir "%DownloadPath%"
    if !errorlevel! neq 0 (
        set "failStep=6/14 create Downloads folder"
        echo   [ERROR] Failed to create Downloads folder.
        echo           Path: %DownloadPath%
        goto :fatal
    )
    echo   [ OK  ] Created: %DownloadPath%
) else (
    echo   [ OK  ] Already exists: %DownloadPath%
)
echo.

:: ------------------------------------------------------------
:: [7/14] Install SQL Server (edition depends on Windows version)
:: ------------------------------------------------------------
echo [7/14] Installing SQL Server...
echo %windowsName% | findstr /I /C:"Windows 11" /C:"Windows 10" >nul
if not errorlevel 1 (
    call :InstallSqlModern
    if !errorlevel! neq 0 ( set "failStep=7/14 SQL Server 2022 install" & goto :fatal )
) else (
    echo %windowsName% | findstr /I /C:"Windows 7" /C:"Windows 8" >nul
    if not errorlevel 1 (
        call :InstallSqlLegacy
        if !errorlevel! neq 0 ( set "failStep=7/14 SQL Server 2014 install" & goto :fatal )
    ) else (
        set "failStep=7/14 SQL Server install (unsupported Windows)"
        echo   [ERROR] Unsupported Windows version for SQL Server install.
        goto :fatal
    )
)
echo.

:: ------------------------------------------------------------
:: [8/14] Download Zeymal application files
:: ------------------------------------------------------------
echo [8/14] Downloading Zeymal application files...
call :DownloadZeymalFiles
if !errorlevel! neq 0 (
    echo   [WARN ] Zeymal file download had issues.
    echo           You can complete this manually:
    echo             Source URL : %ZeymalBaseUrl%
    echo             Target dir : %appFolder%\files
    echo           Continuing so the rest of the setup can run.
    call :ackWarn
)
echo.

:: ------------------------------------------------------------
:: [9/14] Install Java Runtime Environment 8u271
:: ------------------------------------------------------------
echo [9/14] Installing Java Runtime Environment 8u271...
call :InstallJava
if !errorlevel! neq 0 (
    echo   [WARN ] Java installation reported an error or was skipped.
    echo           You can install Java manually from:
    echo             %appFolder%\files\jre-8u271-windows-i586-iftw.exe
    echo           Continuing with the rest of the setup...
    call :ackWarn
)
echo.
:: ------------------------------------------------------------
:: [10/14] Deploy files into the Zeymal folder
:: ------------------------------------------------------------
echo [10/14] Deploying files into %appFolder%...
call :DeployZeymalFiles
if !errorlevel! neq 0 (
    echo   [WARN ] Deployment finished with warnings.
    call :ackWarn
)
echo.

echo [10/0/14] Install Zeymal.exe
call :InstallZeymalExe
if !errorlevel! neq 0 (
    echo   [WARN ] Zeymal.exe installation had issues.
    call :ackWarn
)

:: ------------------------------------------------------------
:: [10.5/14] Copy Zeymal files to Program Files folder
:: ------------------------------------------------------------
echo [10.5/14] Copying Zeymal files to C:\Program Files\Zeymal...
call :CopyToProgramFiles
if !errorlevel! neq 0 (
    echo   [WARN ] Copy to Program Files had issues.
    call :ackWarn
)
echo.

:: ------------------------------------------------------------
:: [11/14] Configure SQL Server (TCP/IP, port 1433, service LogOn)
:: ------------------------------------------------------------
echo [11/14] Configuring SQL Server networking and service...
call :ConfigureSqlServer
echo.

:: ------------------------------------------------------------
:: [12/14] Enable IIS + FTP Windows features
:: ------------------------------------------------------------
echo [12/14] Enabling IIS + FTP features...
call :EnableIisFeatures
echo.

:: ------------------------------------------------------------
:: [13/14] Configure IIS virtual directory and FTP site
:: ------------------------------------------------------------
echo [13/14] Configuring IIS "RT" virtual directory and FTP site...
call :ConfigureIisSites
echo.

:: ------------------------------------------------------------
:: [14/14] Restore Ashley database
:: ------------------------------------------------------------
echo [14/14] Restoring Ashley database...
call :RestoreAshleyDb
echo.

echo ============================================================
echo   Setup complete
echo ============================================================
echo   SQL admin user   : %newUser%   (SA password: %newPassword%)
echo   IIS/FTP user     : %rtUser%    (password:   %rtPassword%)
echo   App folder       : %appFolder%
echo   Files folder     : %appFolder%\files
echo   Downloads        : %DownloadPath%
echo   SQL instance     : .\SQLEXPRESS  (TCP 1433)
echo   IIS Virtual Dir  : http://localhost/RT
echo   FTP site         : ftp://localhost/  (site name: RT)
echo ============================================================
echo   Next manual steps (per install guide):
echo     * Start Zeymal, copy File ^> Zeymal Signature, share for license
echo     * Load the license via File ^> Zeymal Configuration ^> Load Config
echo     * Restart Zeymal and login with admin/admin
echo ============================================================
echo.
if defined needsReboot (
    echo ============================================================
    echo   REBOOT REQUIRED
    echo ============================================================
    echo   Windows must restart to finish activating IIS management
    echo   tools ^(appcmd.exe^). Without this, the "RT" virtual
    echo   directory and FTP site cannot be configured.
    echo.
    echo   After the machine reboots and you log back in, run
    echo   setup.bat AGAIN ^(as Administrator^). The earlier steps
    echo   will detect existing state and skip; step [13/14] will
    echo   then complete successfully.
    echo ============================================================
    echo.
    choice /c YN /t 30 /d Y /m "Reboot now to finish IIS setup"
    if !errorlevel! equ 1 (
        echo   Rebooting in 10 seconds. Save any open work now.
        shutdown /r /t 10 /c "Zeymal setup: rebooting to activate IIS. Re-run setup.bat after login."
        exit /b 0
    )
    echo   Reboot skipped. You MUST reboot manually before re-running setup.bat,
    echo   otherwise IIS configuration will keep failing.
    echo.
)

echo   Setup finished successfully.
echo   THIS WINDOW WILL NOT CLOSE. Close it manually (X button) when done reading.
echo.
:done_wait
pause
echo   Still here. Close this window manually when you are done.
goto :done_wait


:: ============================================================
:: :ackWarn - print a "press key to continue" prompt so the user
:: sees any warning before the script moves on. NEVER let the
:: window close silently on any failure.
:: ============================================================
:ackWarn
echo.
echo   ^>^> A warning/error occurred above. Press any key to continue...
pause >nul
exit /b 0


:: ============================================================
:: :fatal - central error handler. NEVER let the window close
:: without user acknowledgment.
:: ============================================================
:fatal
echo.
echo ============================================================
echo   SETUP FAILED
echo ============================================================
if defined failStep (
    echo   Failed at step: !failStep!
) else (
    echo   Failed at an unknown step.
)
echo.
echo   Scroll up to read the error above.
echo   THIS WINDOW WILL NOT CLOSE. Close it manually (X button)
echo   when you are done reading the errors.
echo ============================================================
echo.
:fatal_wait
pause >nul
echo   Still here. Close this window manually when you are done.
goto :fatal_wait


:: ============================================================
:: :EnsureUser <username> <password> <admin? 0/1>
:: Creates the user if missing, sets password-never-expires,
:: and optionally adds to the Administrators group.
:: ============================================================
:EnsureUser
set "eu_user=%~1"
set "eu_pass=%~2"
set "eu_admin=%~3"

net user "%eu_user%" >nul 2>&1
if errorlevel 1 (
    echo   User "%eu_user%" not found. Creating...
    net user "%eu_user%" "%eu_pass%" /add
    if !errorlevel! neq 0 (
        echo   [ERROR] Failed to create user "%eu_user%".
        exit /b 1
    )
    echo   [ OK  ] User "%eu_user%" created.
) else (
    echo   [ OK  ] User "%eu_user%" already exists.
)

if "%eu_admin%"=="1" (
    net localgroup "Administrators" "%eu_user%" /add >nul 2>&1
    echo   [ OK  ] "%eu_user%" ensured in Administrators group.
)

powershell -NoProfile -Command "try { Set-LocalUser -Name '%eu_user%' -PasswordNeverExpires $true -ErrorAction Stop } catch { exit 1 }"
if !errorlevel! neq 0 (
    echo   [WARN ] Could not set PasswordNeverExpires on "%eu_user%".
    call :ackWarn
) else (
    echo   [ OK  ] PasswordNeverExpires set on "%eu_user%".
)
exit /b 0


:: ============================================================
:: :Download  -  Generic downloader with progress bar
:: ============================================================
:Download
set "DL_URL=%~1"
set "DL_DEST=%~2"
set "DL_NAME=%~3"
echo.
echo   [Download] !DL_NAME!
echo     From: !DL_URL!
echo     To:   !DL_DEST!
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; function FmtSize($b) { if ($b -ge 1GB) { '{0,7:N2} GB' -f ($b/1GB) } elseif ($b -ge 1MB) { '{0,7:N2} MB' -f ($b/1MB) } elseif ($b -ge 1KB) { '{0,7:N2} KB' -f ($b/1KB) } else { '{0,7} B ' -f [int]$b } }; function FmtTime($s) { if ($s -le 0 -or [double]::IsInfinity($s) -or [double]::IsNaN($s)) { return '--:--' }; $ts = [TimeSpan]::FromSeconds([int]$s); if ($ts.TotalHours -ge 1) { '{0:D2}:{1:D2}:{2:D2}' -f [int]$ts.TotalHours,$ts.Minutes,$ts.Seconds } else { '{0:D2}:{1:D2}' -f $ts.Minutes,$ts.Seconds } }; $url = $env:DL_URL; $dest = $env:DL_DEST; $script:start = Get-Date; $wc = New-Object System.Net.WebClient; $null = Register-ObjectEvent $wc DownloadProgressChanged -SourceIdentifier DP -Action { $now = Get-Date; $el = ($now - $script:start).TotalSeconds; $r = [double]$EventArgs.BytesReceived; $t = [double]$EventArgs.TotalBytesToReceive; $p = [int]$EventArgs.ProgressPercentage; $spd = if ($el -gt 0) { $r / $el } else { 0 }; $eta = if ($spd -gt 0 -and $t -gt 0) { ($t - $r) / $spd } else { 0 }; $bw = 30; $fill = [int][math]::Floor(($p / 100.0) * $bw); if ($fill -gt $bw) { $fill = $bw }; if ($fill -lt 0) { $fill = 0 }; if ($fill -eq $bw) { $bar = '=' * $bw } else { $bar = ('=' * $fill) + '>' + (' ' * ($bw - $fill - 1)) }; Write-Host -NoNewline (\"`r    [{0}] {1,3}%% {2} / {3}  {4}/s  ETA {5}   \" -f $bar,$p,(FmtSize $r),(FmtSize $t),(FmtSize $spd),(FmtTime $eta)) }; $null = Register-ObjectEvent $wc DownloadFileCompleted -SourceIdentifier DC; try { $wc.DownloadFileAsync([Uri]$url, $dest); $null = Wait-Event -SourceIdentifier DC -Timeout 1800; Write-Host ''; if (Test-Path $dest) { $sz = FmtSize (Get-Item $dest).Length; $secs = ((Get-Date) - $script:start).TotalSeconds; Write-Host (\"    Done. Saved {0} in {1}.\" -f $sz.Trim(),(FmtTime $secs)); exit 0 } else { Write-Host '    Download failed.'; exit 1 } } finally { Unregister-Event DP -ErrorAction SilentlyContinue; Unregister-Event DC -ErrorAction SilentlyContinue; $wc.Dispose() } }"
set "rc=!errorlevel!"
set "DL_URL="
set "DL_DEST="
set "DL_NAME="
exit /b %rc%


:: ============================================================
:: SQL Server 2022 Express + SSMS  (Windows 10/11)
:: ============================================================
:InstallSqlModern
echo   --- SQL Server 2022 Express ---

sc query "MSSQL$SQLEXPRESS" >nul 2>&1
if !errorlevel! equ 0 (
    echo   [ OK  ] SQLEXPRESS instance already installed. Skipping engine install.
    goto :InstallSqlModern_SSMS
)

set "SqlBootstrap=%DownloadPath%\SQL2022-SSEI-Expr.exe"
set "SqlMediaDir=%DownloadPath%\SQLMedia"
set "SqlMediaFile=%SqlMediaDir%\SQLEXPR_x64_ENU.exe"
set "SqlSetupDir=%SqlMediaDir%\extract"

echo   Step 1/3: Fetching SQL Server 2022 Express bootstrapper...
call :Download "https://go.microsoft.com/fwlink/p/?linkid=2216019&clcid=0x409&culture=en-us&country=us" "%SqlBootstrap%" "SQL Server 2022 Express bootstrapper"
if !errorlevel! neq 0 (
    echo   [ERROR] Failed to download SQL Server 2022 Express bootstrapper.
    exit /b 1
)
if not exist "%SqlBootstrap%" (
    echo   [ERROR] Bootstrapper file missing after download:
    echo           %SqlBootstrap%
    exit /b 1
)
for %%A in ("%SqlBootstrap%") do set "SqlBootstrapSize=%%~zA"
if !SqlBootstrapSize! LSS 100000 (
    echo   [ERROR] Bootstrapper file looks too small ^(!SqlBootstrapSize! bytes^).
    echo           The download probably returned an error page instead of the exe.
    echo           Delete "%SqlBootstrap%" and re-run.
    exit /b 1
)

if not exist "%SqlMediaDir%" mkdir "%SqlMediaDir%"

if exist "%SqlMediaFile%" (
    echo   [ OK  ] Media package already present. Skipping media download.
) else (
    echo.
    echo   Step 2/3: Downloading full SQL Server media ^(~280 MB^)...
    echo           Microsoft's downloader will open its own progress window.
    echo           This can take 5-15 minutes on a home connection. Please wait.
    echo           Do NOT close this window.
    start "SQL Server 2022 Express Media Download" /wait "%SqlBootstrap%" /ACTION=Download /MEDIAPATH="%SqlMediaDir%" /MEDIATYPE=Core /LANGUAGE=en-US /QUIET
    set "SqlBootExit=!errorlevel!"
    echo           Bootstrapper exit code: !SqlBootExit!
    if !SqlBootExit! neq 0 (
        echo   [ERROR] SQL Server media download failed ^(exit !SqlBootExit!^).
        echo           You can download the media manually from:
        echo             https://www.microsoft.com/en-us/download/details.aspx?id=104781
        echo           and place SQLEXPR_x64_ENU.exe at:
        echo             %SqlMediaFile%
        exit /b 1
    )
    if not exist "%SqlMediaFile%" (
        echo   [ERROR] Expected media file was not produced:
        echo           %SqlMediaFile%
        exit /b 1
    )
    echo   [ OK  ] Media package downloaded.
)

echo.
echo   Step 3/3: Extracting media and running silent install...
if not exist "%SqlSetupDir%" mkdir "%SqlSetupDir%"
start "SQL Server Media Extract" /wait "%SqlMediaFile%" /X:"%SqlSetupDir%" /Q
if !errorlevel! neq 0 (
    echo   [ERROR] Failed to extract SQL Server media.
    exit /b 1
)
if not exist "%SqlSetupDir%\setup.exe" (
    echo   [ERROR] setup.exe not found after extraction:
    echo           %SqlSetupDir%\setup.exe
    exit /b 1
)

echo   Running SQL Server setup ^(silent, this can take several minutes^)...
echo   Do NOT close this window.
"%SqlSetupDir%\setup.exe" /Q /IACCEPTSQLSERVERLICENSETERMS /ACTION=INSTALL ^
    /FEATURES=SQLENGINE ^
    /INSTANCENAME=SQLEXPRESS ^
    /SQLSVCACCOUNT="NT Service\MSSQL$SQLEXPRESS" ^
    /SQLSYSADMINACCOUNTS="BUILTIN\ADMINISTRATORS" ^
    /SECURITYMODE=SQL ^
    /SAPWD="%newPassword%" ^
    /TCPENABLED=1 ^
    /NPENABLED=1 ^
    /UPDATEENABLED=False
set "SqlSetupExit=!errorlevel!"
echo   SQL Server setup exit code: !SqlSetupExit!

if !SqlSetupExit! neq 0 (
    echo   [ERROR] SQL Server installation reported an error.
    echo           Check setup logs at:
    echo           %ProgramFiles%\Microsoft SQL Server\160\Setup Bootstrap\Log
    exit /b 1
)
echo   [ OK  ] SQL Server 2022 Express installed successfully.

:InstallSqlModern_SSMS

echo.
echo   --- SQL Server Management Studio (SSMS) ---

set "SsmsFound=0"

reg query "HKLM\SOFTWARE\Microsoft\Microsoft SQL Server Management Studio" >nul 2>&1
if !errorlevel! equ 0 set "SsmsFound=1"

reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Microsoft SQL Server Management Studio" >nul 2>&1
if !errorlevel! equ 0 set "SsmsFound=1"

for %%D in (18 19 20 21) do (
    if exist "%ProgramFiles(x86)%\Microsoft SQL Server Management Studio %%D\Common7\IDE\Ssms.exe" set "SsmsFound=1"
    if exist "%ProgramFiles%\Microsoft SQL Server Management Studio %%D\Common7\IDE\Ssms.exe"      set "SsmsFound=1"
    if exist "%ProgramFiles%\Microsoft SQL Server Management Studio %%D\Release\Common7\IDE\Ssms.exe" set "SsmsFound=1"
)

if "!SsmsFound!"=="1" (
    echo   [ OK  ] SSMS is already installed. Skipping download and install.
    exit /b 0
)

set "SsmsInstaller=%DownloadPath%\SSMS-Setup-ENU.exe"
call :Download "https://aka.ms/ssmsfullsetup" "%SsmsInstaller%" "SSMS"
if !errorlevel! neq 0 (
    echo   [WARN ] Failed to download SSMS.
    echo           You can install it manually from https://aka.ms/ssmsfullsetup
    call :ackWarn
    exit /b 0
)

echo   Installing SSMS (silent)...
"%SsmsInstaller%" /install /quiet /norestart
if !errorlevel! neq 0 (
    echo   [WARN ] SSMS installation reported an error. You can install it manually later.
    call :ackWarn
) else (
    echo   [ OK  ] SSMS installed successfully.
)
exit /b 0


:: ============================================================
:: SQL Server 2014 Express with Tools  (Windows 7/8)
:: ============================================================
:InstallSqlLegacy
echo   --- SQL Server 2014 Express with Tools ---

set "SqlLegacyUrl=https://download.microsoft.com/download/E/A/E/EAE6F7FC-767A-4038-A954-49B8B05D04EB/ExpressAndTools 64BIT/SQLEXPRWT_x64_ENU.exe"
set "SqlLegacyInstaller=%DownloadPath%\SQLEXPRWT.exe"

call :Download "%SqlLegacyUrl%" "%SqlLegacyInstaller%" "SQL Server 2014 Express with Tools"
if !errorlevel! neq 0 (
    echo   [ERROR] Failed to download SQL Server 2014 Express.
    echo           Manual download: https://www.microsoft.com/en-us/download/details.aspx?id=42299
    exit /b 1
)

echo   Running SQL Server setup ^(silent, this can take several minutes^)...
echo   Do NOT close this window.
"%SqlLegacyInstaller%" /Q /IACCEPTSQLSERVERLICENSETERMS /ACTION=INSTALL ^
    /FEATURES=SQLENGINE ^
    /INSTANCENAME=SQLEXPRESS ^
    /SQLSVCACCOUNT="NT AUTHORITY\Network Service" ^
    /SQLSYSADMINACCOUNTS="BUILTIN\ADMINISTRATORS" ^
    /SECURITYMODE=SQL ^
    /SAPWD="%newPassword%" ^
    /TCPENABLED=1
set "SqlLegacyExit=!errorlevel!"
echo   SQL Server setup exit code: !SqlLegacyExit!

if !SqlLegacyExit! neq 0 (
    echo   [ERROR] SQL Server installation reported an error. Check the setup logs.
    exit /b 1
)
echo   [ OK  ] SQL Server 2014 Express installed successfully.
echo   [NOTE ] SSMS 2014 is not bundled here. Install it manually if needed.
exit /b 0


:: ============================================================
:: Download the Zeymal application files (with real filenames)
:: ============================================================
:DownloadZeymalFiles
set "ZeymalFiles=%appFolder%\files"

if not exist "%ZeymalFiles%" (
    mkdir "%ZeymalFiles%"
    if !errorlevel! neq 0 (
        echo   [ERROR] Failed to create Zeymal files folder.
        echo           Path: %ZeymalFiles%
        exit /b 1
    )
    echo   [ OK  ] Created: %ZeymalFiles%
) else (
    echo   [ OK  ] Already exists: %ZeymalFiles%
)

set "ZeymalBaseUrl=https://zml-installer.blr1.digitaloceanspaces.com/"


set "ZeymalRplaceXip=%ZeymalBaseUrl%(Z_Replace_Base).zip"
set "ZeymalIftwInstaller=%ZeymalBaseUrl%jre-8u271-windows-i586-iftw.zip"
set "Zeymalexe=%ZeymalBaseUrl%Zeymal.zip"
set "ZeymalResetxip=%ZeymalBaseUrl%Z_Reset_1034.zip"

echo   Checking existing files ^(complete files ^>= 10 KB will be skipped^)...
echo   Target folder: %ZeymalFiles%
for %%F in ("(Z_Replace_Base).zip" "jre-8u271-windows-i586-iftw.zip" "Zeymal.zip" "Z_Reset_1034.zip") do (
    if exist "%ZeymalFiles%\%%~F" (
        for %%A in ("%ZeymalFiles%\%%~F") do echo     [FOUND] %%~F  ^(%%~zA bytes^)
    ) else (
        echo     [MISS ] %%~F  ^(will download^)
    )
)

call :DownloadZeymalItem "ZeymalRplaceXip"     "(Z_Replace_Base).zip"            1 4
if !errorlevel! neq 0 exit /b 1
call :DownloadZeymalItem "ZeymalIftwInstaller" "jre-8u271-windows-i586-iftw.zip" 2 4
if !errorlevel! neq 0 exit /b 1
call :DownloadZeymalItem "Zeymalexe"           "Zeymal.zip"                      3 4
if !errorlevel! neq 0 exit /b 1
call :DownloadZeymalItem "ZeymalResetxip"      "Z_Reset_1034.zip"                4 4
if !errorlevel! neq 0 exit /b 1

echo   [ OK  ] All Zeymal files downloaded successfully.
exit /b 0


:: ============================================================
:: :DownloadZeymalItem <urlVarName> <destFileName> <idx> <total>
:: Downloads a single Zeymal asset with full validation:
::   - checks inputs, URL variable is set, target folder exists
::   - skips only if an existing file is above the minimum size
::   - prefers curl.exe; falls back to PowerShell WebClient
::   - retries up to 3 times on failure
::   - after download: file must exist, be non-tiny, and (for
::     .zip files) open as a valid ZIP archive
:: ============================================================
:DownloadZeymalItem
set "varName=%~1"
set "fileName=%~2"
set "idx=%~3"
set "total=%~4"
set "fileUrl=!%varName%!"
set "fileDest=%ZeymalFiles%\%fileName%"
set "minSize=10240"

echo.
echo   [File %idx%/%total%] %fileName%

:: --- Input validation --------------------------------------------------
if "%varName%"=="" (
    echo     [ERROR] Missing URL variable name argument.
    exit /b 1
)
if "%fileName%"=="" (
    echo     [ERROR] Missing destination filename argument.
    exit /b 1
)
if "!fileUrl!"=="" (
    echo     [ERROR] URL variable "%varName%" is not set or is empty.
    exit /b 1
)
if not defined ZeymalFiles (
    echo     [ERROR] ZeymalFiles target folder variable is not set.
    exit /b 1
)
if not exist "%ZeymalFiles%\" (
    echo     [ERROR] Target folder does not exist: %ZeymalFiles%
    exit /b 1
)

:: --- Skip only if an existing file looks complete ----------------------
if exist "!fileDest!" (
    set "existingSize=0"
    for %%A in ("!fileDest!") do set "existingSize=%%~zA"
    if !existingSize! GEQ %minSize% (
        echo     [ OK  ] Already exists ^(!existingSize! bytes^). Skipping.
        echo            !fileDest!
        exit /b 0
    )
    echo     [WARN ] Existing file too small ^(!existingSize! bytes^). Re-downloading.
    del /f /q "!fileDest!" >nul 2>&1
)

:: --- Pick a downloader (curl preferred, PowerShell fallback) ----------
set "haveCurl=0"
where curl.exe >nul 2>&1
if !errorlevel! equ 0 set "haveCurl=1"

set "isZip=0"
if /I "!fileName:~-4!"==".zip" set "isZip=1"

set "attempt=0"
set "maxAttempts=3"

:DZI_retry
set /a attempt+=1
echo     Attempt !attempt!/%maxAttempts% ...

if "!haveCurl!"=="1" (
    curl.exe -L --fail --show-error --connect-timeout 30 -o "!fileDest!" "!fileUrl!"
    set "dlRc=!errorlevel!"
) else (
    set "DL_URL=!fileUrl!"
    set "DL_DEST=!fileDest!"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object System.Net.WebClient).DownloadFile($env:DL_URL, $env:DL_DEST); exit 0 } catch { Write-Host ('     [ERROR] ' + $_.Exception.Message); exit 1 }"
    set "dlRc=!errorlevel!"
    set "DL_URL="
    set "DL_DEST="
)

if !dlRc! neq 0 (
    echo     [ERROR] Downloader exited with code !dlRc!.
    if exist "!fileDest!" del /f /q "!fileDest!" >nul 2>&1
    goto :DZI_check_retry
)

if not exist "!fileDest!" (
    echo     [ERROR] File was not created after download.
    goto :DZI_check_retry
)

set "dlSize=0"
for %%A in ("!fileDest!") do set "dlSize=%%~zA"
if !dlSize! LSS %minSize% (
    echo     [ERROR] Downloaded file too small ^(!dlSize! bytes^).
    echo             Likely an error/redirect page rather than the real asset.
    del /f /q "!fileDest!" >nul 2>&1
    goto :DZI_check_retry
)

if "!isZip!"=="1" (
    set "ZIP_PATH=!fileDest!"
    powershell -NoProfile -Command "try { Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue; $z = [System.IO.Compression.ZipFile]::OpenRead($env:ZIP_PATH); $z.Dispose(); exit 0 } catch { exit 1 }"
    set "zipRc=!errorlevel!"
    set "ZIP_PATH="
    if !zipRc! neq 0 (
        echo     [ERROR] File is not a valid ZIP archive.
        del /f /q "!fileDest!" >nul 2>&1
        goto :DZI_check_retry
    )
)

echo     [ OK  ] Saved !dlSize! bytes to: !fileDest!
exit /b 0

:DZI_check_retry
if !attempt! LSS %maxAttempts% (
    echo     Retrying in 3 seconds...
    timeout /t 3 /nobreak >nul 2>&1
    goto :DZI_retry
)
echo     [ERROR] Download failed after %maxAttempts% attempts.
echo             URL: !fileUrl!
exit /b 1


:: ============================================================
:: :ExtractZip <zipPath> <destDir> <label>
:: Extracts a zip once and drops a "<zip>.extracted" marker
:: next to the zip so subsequent runs skip it.
:: ============================================================
:ExtractZip
set "ez_zip=%~1"
set "ez_dest=%~2"
set "ez_label=%~3"
set "ez_marker=!ez_zip!.extracted"

echo.
echo   [Extract] !ez_label!
if exist "!ez_marker!" (
    echo     [ OK  ] Already extracted. Skipping.
    exit /b 0
)
if not exist "!ez_zip!" (
    echo     [WARN] !ez_label! not found: !ez_zip!
    exit /b 1
)
if not exist "!ez_dest!\" mkdir "!ez_dest!"

for %%A in ("!ez_zip!") do echo     Source: !ez_zip! ^(%%~zA bytes^)
echo     Target: !ez_dest!
echo     Extracting ^(verbose - each file shown^)...
echo     ------------------------------------------------------------
tar -xvf "!ez_zip!" -C "!ez_dest!"
set "ez_rc=!errorlevel!"
echo     ------------------------------------------------------------
if !ez_rc! neq 0 (
    echo     [ERROR] Failed to extract !ez_label! ^(tar exit !ez_rc!^)
    exit /b 1
)
echo     [ OK  ] Extracted !ez_label!
> "!ez_marker!" echo extracted
exit /b 0



:: ============================================================
:: Java JRE 8u271 (from extracted zip file)
:: Returns 0 on successful install, 1 if anything went wrong.
:: The caller is responsible for warning + continuing on 1.
:: ============================================================
:InstallJava
echo   --- Java JRE 8u271 ---

set "JavaZip=%ZeymalFiles%\jre-8u271-windows-i586-iftw.zip"
set "JavaExtractDir=%ZeymalFiles%\jre_extract"
set "JavaInstaller=%JavaExtractDir%\jre-8u271-windows-i586-iftw.exe"

if not exist "%JavaInstaller%" (
    call :ExtractZip "%JavaZip%" "%JavaExtractDir%" "Java JRE 8u271 installer"
    if !errorlevel! neq 0 (
        echo   [WARN ] Failed to extract Java installer zip.
        exit /b 1
    )
)

if not exist "%JavaInstaller%" (
    echo   [WARN ] Java installer executable not found at:
    echo           %JavaInstaller%
    exit /b 1
)

echo   Installing Java silently (auto-update disabled)...
"%JavaInstaller%" /s AUTO_UPDATE=Disable STATIC=1 REBOOT=Disable EULA=Disable NOSTARTMENU=Enable WEB_ANALYTICS=Disable
set "javaInstallRc=!errorlevel!"
if !javaInstallRc! neq 0 (
    echo   [WARN ] Java installer exit code !javaInstallRc!.
    exit /b 1
)
echo   [ OK  ] Java JRE 8u271 installed successfully.
exit /b 0




:: ============================================================
:: Deploy Zeymal files: extract (Z_Replace_Base).zip into the app
:: folder and copy Zeymal.jar / .exe / jre alongside.
:: ============================================================
:DeployZeymalFiles
set "ZeymalFiles=%appFolder%\files"

call :ExtractZip "%ZeymalFiles%\(Z_Replace_Base).zip" "%appFolder%" "(Z_Replace_Base).zip"
if !errorlevel! neq 0 call :ackWarn

call :ExtractZip "%ZeymalFiles%\Zeymal.zip" "%appFolder%" "Zeymal.zip"
if !errorlevel! neq 0 call :ackWarn

set "javaExe=%ZeymalFiles%\jre_extract\jre-8u271-windows-i586-iftw.exe"
if exist "%javaExe%" (
    copy /Y "%javaExe%" "%appFolder%\jre-8u271-windows-i586-iftw.exe" >nul
    if !errorlevel! equ 0 (
        echo   [ OK  ] Copied Java installer into %appFolder%
    ) else (
        echo   [WARN ] Failed to copy Java installer into %appFolder%.
    )
) else (
    echo   [WARN ] Java installer not found at %javaExe%. Skipping copy.
)
exit /b 0
:: ============================================================
:: Install Zeymal.exe - extract and copy the executable
:: ============================================================
:InstallZeymalExe
echo.
echo [10.0/14] Installing Zeymal.exe...

set "zeymalZip=%appFolder%\files\Zeymal.zip"
set "zeymalExtract=%appFolder%\Zeymal_extract"

if not exist "%zeymalZip%" (
    echo   [ERROR] Zeymal.zip not found at: %zeymalZip%
    exit /b 1
)

:: Extract Zeymal.zip if not already extracted
if not exist "%zeymalExtract%\Zeymal.exe" (
    echo   Extracting Zeymal.zip...
    if not exist "%zeymalExtract%" mkdir "%zeymalExtract%"
    tar -xvf "%zeymalZip%" -C "%zeymalExtract%"
    if !errorlevel! neq 0 (
        echo   [ERROR] Failed to extract Zeymal.zip
        exit /b 1
    )
    echo   [ OK  ] Extracted Zeymal.zip
) else (
    echo   [ OK  ] Zeymal.exe already extracted
)

:: Find Zeymal.exe (might be in a subfolder)
set "zeymalExe="
for /f "delims=" %%F in ('dir /b /s "%zeymalExtract%\Zeymal.exe" 2^>nul') do (
    if not defined zeymalExe set "zeymalExe=%%F"
)

if not defined zeymalExe (
    echo   [ERROR] Zeymal.exe not found in extracted files
    echo   Looking for any .exe files in extraction folder...
    dir /s "%zeymalExtract%\*.exe"
    exit /b 1
)

echo   Found Zeymal.exe at: !zeymalExe!

:: Copy Zeymal.exe to app folder
copy /Y "!zeymalExe!" "%appFolder%\Zeymal.exe" >nul
if !errorlevel! neq 0 (
    echo   [ERROR] Failed to copy Zeymal.exe to %appFolder%
    exit /b 1
)

echo   [ OK  ] Zeymal.exe copied to %appFolder%\Zeymal.exe
exit /b 0


:: ============================================================
:: Copy Zeymal files to Program Files folder (Fixed version)
:: ============================================================
:CopyToProgramFiles
echo.
echo ============================================================
echo [10.5/14] Copying Zeymal files to Program Files...
echo ============================================================

set "sourceFolder=%appFolder%\(Z_Replace_Base)"
set "destFolder=%ProgramFiles(x86)%\Zeymal"

echo Source Folder      : "%sourceFolder%"
echo Destination Folder : "%destFolder%"
echo.

:: Check if source exists (try alternative location if not)
if not exist "%sourceFolder%" (
    echo [WARN] Source folder not found: %sourceFolder%
    echo Trying alternative: %appFolder%\files\(Z_Replace_Base)
    set "sourceFolder=%appFolder%\files\(Z_Replace_Base)"
)

if not exist "%sourceFolder%" (
    echo [ERROR] Source folder not found in either location!
    echo Looking for any extracted folder...
    dir /ad /b "%appFolder%"
    dir /ad /b "%appFolder%\files"
    exit /b 1
)

echo [ OK  ] Source folder exists: %sourceFolder%

:: Create destination
if not exist "%destFolder%" (
    echo Creating "%destFolder%"...
    mkdir "%destFolder%" 2>nul
    if errorlevel 1 (
        echo [ERROR] Failed to create destination folder.
        exit /b 1
    )
    echo [ OK  ] Destination folder created.
) else (
    echo [ OK  ] Destination folder already exists.
)

:: Copy files using robocopy
echo.
echo Copying files from "%sourceFolder%" to "%destFolder%"...
echo ============================================================

robocopy "%sourceFolder%" "%destFolder%" /E /COPY:DAT /R:3 /W:5 /NP /NFL

set "RC=%ERRORLEVEL%"

echo ============================================================
echo Robocopy Exit Code : %RC%
echo.

if %RC% GEQ 8 (
    echo [ERROR] Robocopy failed with error level %RC%
    echo Errors occurred during copy.
    exit /b 1
) else if %RC% GEQ 4 (
    echo [WARN ] Some files may have been skipped (mismatch).
    echo Check the output above for details.
) else if %RC% LEQ 1 (
    echo [ OK  ] Copy completed successfully.
)

:: Also ensure Zeymal.exe is in Program Files
if exist "%appFolder%\Zeymal.exe" (
    copy /Y "%appFolder%\Zeymal.exe" "%destFolder%\Zeymal.exe" >nul
    if !errorlevel! equ 0 (
        echo [ OK  ] Zeymal.exe copied to Program Files folder
    )
)

:: Create shortcut on Desktop
set "desktop=%USERPROFILE%\Desktop"
if exist "%destFolder%\Zeymal.exe" (
    echo Creating desktop shortcut...
    powershell -NoProfile -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%desktop%\Zeymal.lnk'); $Shortcut.TargetPath = '%destFolder%\Zeymal.exe'; $Shortcut.WorkingDirectory = '%destFolder%'; $Shortcut.Save()"
    if !errorlevel! equ 0 (
        echo [ OK  ] Desktop shortcut created
    )
)

echo.
echo ============================================================
echo [SUCCESS] Zeymal copied to Program Files
echo ============================================================
exit /b 0


:: ============================================================
:: Configure SQL Server: enable TCP/IP on port 1433 and set the
:: service to Local System account, then restart.
:: ============================================================
:ConfigureSqlServer
sc query "MSSQL$SQLEXPRESS" >nul 2>&1
if !errorlevel! neq 0 (
    echo   [SKIP ] MSSQL$SQLEXPRESS service not found. Skipping SQL config.
    exit /b 0
)

echo   Enabling TCP/IP and setting port 1433 via registry...
powershell -NoProfile -Command "$root='HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server'; $inst = Get-ItemProperty -Path (Join-Path $root 'Instance Names\SQL') | Select-Object -ExpandProperty SQLEXPRESS -ErrorAction SilentlyContinue; if (-not $inst) { Write-Host '  [WARN ] Could not find SQLEXPRESS instance registry key.'; exit 0 }; $tcp = \"$root\$inst\MSSQLServer\SuperSocketNetLib\Tcp\"; Set-ItemProperty -Path $tcp -Name Enabled -Value 1 -ErrorAction SilentlyContinue; Set-ItemProperty -Path (Join-Path $tcp 'IPAll') -Name TcpPort -Value '1433' -ErrorAction SilentlyContinue; Set-ItemProperty -Path (Join-Path $tcp 'IPAll') -Name TcpDynamicPorts -Value '' -ErrorAction SilentlyContinue; Write-Host '  [ OK  ] Registry updated.'"

echo   Setting SQL Server service to Local System account (with desktop interaction)...
sc config "MSSQL$SQLEXPRESS" obj= "LocalSystem" type= own type= interact >nul 2>&1
if !errorlevel! neq 0 (
    echo   [WARN ] sc config for MSSQL$SQLEXPRESS failed. Check permissions.
    call :ackWarn
) else (
    echo   [ OK  ] Service configured for Local System.
)

echo   Restarting SQL Server service...
net stop "MSSQL$SQLEXPRESS" >nul 2>&1
net start "MSSQL$SQLEXPRESS" >nul 2>&1
if !errorlevel! neq 0 (
    echo   [WARN ] Failed to restart MSSQL$SQLEXPRESS. Restart manually.
    call :ackWarn
) else (
    echo   [ OK  ] SQL Server restarted with new settings.
)
exit /b 0


:: ============================================================
:: Enable IIS + FTP Windows features
:: ============================================================
:EnableIisFeatures
echo   Enabling IIS + FTP Windows features (this can take a minute)...
powershell -NoProfile -Command "$features = 'IIS-WebServerRole','IIS-WebServer','IIS-CommonHttpFeatures','IIS-DefaultDocument','IIS-DirectoryBrowsing','IIS-HttpErrors','IIS-StaticContent','IIS-HttpRedirect','IIS-ApplicationDevelopment','IIS-NetFxExtensibility45','IIS-ISAPIExtensions','IIS-ISAPIFilter','IIS-ASPNET45','IIS-HealthAndDiagnostics','IIS-HttpLogging','IIS-Security','IIS-RequestFiltering','IIS-BasicAuthentication','IIS-Performance','IIS-WebServerManagementTools','IIS-ManagementConsole','IIS-ManagementScriptingTools','IIS-FTPServer','IIS-FTPSvc','IIS-FTPExtensibility'; $bad=$false; foreach ($f in $features) { try { Enable-WindowsOptionalFeature -Online -FeatureName $f -All -NoRestart -ErrorAction Stop | Out-Null } catch { Write-Host ('  [WARN ] Could not enable ' + $f + ': ' + $_.Exception.Message); $bad=$true } }; if ($bad) { exit 1 } else { exit 0 }"
if !errorlevel! neq 0 (
    echo   [WARN ] Some IIS/FTP features did not enable cleanly. Check "Turn Windows features on or off".
    call :ackWarn
) else (
    echo   [ OK  ] IIS + FTP features enabled.
)
exit /b 0


:: ============================================================
:: Configure IIS: virtual directory "RT" under Default Web Site,
:: MIME type for ".", and FTP site "RT" bound to appFolder.
:: ============================================================
:ConfigureIisSites
set "appcmd=%windir%\system32\inetsrv\appcmd.exe"
if not exist "%appcmd%" (
    echo   [SKIP ] appcmd.exe not found. IIS management tools become available only after a reboot.
    echo           A reboot will be scheduled after this run finishes. Re-run setup.bat after login.
    set "needsReboot=1"
    exit /b 0
)

echo   Creating virtual directory "RT" under Default Web Site...
"%appcmd%" delete vdir "Default Web Site/RT" >nul 2>&1
"%appcmd%" add vdir /app.name:"Default Web Site/" /path:"/RT" /physicalPath:"%appFolder%" /userName:"%rtUser%" /password:"%rtPassword%"
if !errorlevel! neq 0 (
    echo   [WARN ] Failed to create RT virtual directory.
    call :ackWarn
) else (
    echo   [ OK  ] Virtual directory /RT created.
)

echo   Adding MIME type "." = application/octet-stream ...
"%appcmd%" set config "Default Web Site/RT" -section:staticContent /+"[fileExtension='.',mimeType='application/octet-stream']" /commit:apphost >nul 2>&1
if !errorlevel! neq 0 (
    echo   [WARN ] MIME type add failed ^(may already exist^).
) else (
    echo   [ OK  ] MIME type added.
)

echo   Creating FTP site "RT" bound to %appFolder% ...
"%appcmd%" delete site "RT" >nul 2>&1
"%appcmd%" add site /name:"RT" /physicalPath:"%appFolder%" /bindings:"ftp/*:21:"
if !errorlevel! neq 0 (
    echo   [WARN ] Failed to create FTP site.
    call :ackWarn
) else (
    "%appcmd%" set site "RT" /ftpServer.security.ssl.controlChannelPolicy:"SslAllow" /ftpServer.security.ssl.dataChannelPolicy:"SslAllow" >nul 2>&1
    "%appcmd%" set site "RT" /ftpServer.security.authentication.basicAuthentication.enabled:"true" >nul 2>&1
    "%appcmd%" set site "RT" /ftpServer.security.authentication.anonymousAuthentication.enabled:"false" >nul 2>&1
    "%appcmd%" set config -section:system.ftpServer/security/authorization /+"[accessType='Allow',users='%rtUser%',permissions='Read,Write']" /commit:apphost >nul 2>&1
    "%appcmd%" set vdir "RT/" /userName:"%rtUser%" /password:"%rtPassword%" >nul 2>&1
    echo   [ OK  ] FTP site created and secured for user "%rtUser%".
)

echo   Restarting Default Web Site and FTP site "RT"...
"%appcmd%" stop  site "Default Web Site" >nul 2>&1
"%appcmd%" start site "Default Web Site" >nul 2>&1
"%appcmd%" stop  site "RT" >nul 2>&1
"%appcmd%" start site "RT" >nul 2>&1
echo   [ OK  ] IIS sites restarted.
exit /b 0


:: ============================================================
:: Restore the Ashley database from Z_Reset*.zip
:: ============================================================
:RestoreAshleyDb
set "resetZip=%appFolder%\files\Z_Reset_1034.zip"
set "restoreDir=%appFolder%\files\ashley_restore"

if not exist "%resetZip%" (
    echo   [SKIP ] Z_Reset_1034.zip not found; skipping DB restore.
    exit /b 0
)

sc query "MSSQL$SQLEXPRESS" >nul 2>&1
if !errorlevel! neq 0 (
    echo   [SKIP ] MSSQL$SQLEXPRESS not installed; skipping DB restore.
    exit /b 0
)

call :ExtractZip "%resetZip%" "%restoreDir%" "Z_Reset_1034.zip"
if !errorlevel! neq 0 (
    echo   [ERROR] Failed to extract Z_Reset_1034.zip.
    exit /b 1
)

set "bakFile="
for /f "delims=" %%F in ('dir /b /s "%restoreDir%\*.bak" 2^>nul') do (
    if not defined bakFile set "bakFile=%%F"
)
if not defined bakFile (
    echo   [INFO ] No .bak file found; scanning extracted files for a SQL backup ^(TAPE header^)...
    for /f "delims=" %%F in ('dir /b /s /a-d "%restoreDir%" 2^>nul') do (
        if not defined bakFile (
            powershell -NoProfile -Command "$b=[System.IO.File]::ReadAllBytes('%%F') | Select-Object -First 4; if(($b.Count -eq 4) -and ($b[0] -eq 0x54) -and ($b[1] -eq 0x41) -and ($b[2] -eq 0x50) -and ($b[3] -eq 0x45)){exit 0}else{exit 1}" >nul 2>&1
            if !errorlevel! equ 0 (
                echo   [ OK  ] Detected SQL backup in "%%~nxF" ^(no extension^). Renaming to Ashley.bak.
                ren "%%F" "Ashley.bak" >nul 2>&1
                set "bakFile=%%~dpFAshley.bak"
            )
        )
    )
)
if not defined bakFile (
    echo   [ERROR] No .bak file ^(and no TAPE-format backup^) found inside Z_Reset_1034.zip.
    exit /b 1
)
echo   Backup file: !bakFile!

where sqlcmd >nul 2>&1
if !errorlevel! neq 0 (
    echo   [SKIP ] sqlcmd not found on PATH. Install SSMS/mssql-tools, then restore manually
    echo           using SSMS ^(Restore Database ^> Options ^> Relocate files^) or via sqlcmd
    echo           with WITH MOVE to your server's default DATA folder ^(the .bak was created
    echo           on a different install path, so a straight RESTORE will fail with error 3156^).
    exit /b 0
)

echo   Restoring "Ashley" via sqlcmd ^(with WITH MOVE to this server's default data folder^)...
sqlcmd -S .\SQLEXPRESS -U sa -P "%newPassword%" -C -b -Q "SET NOCOUNT ON; DECLARE @dataPath NVARCHAR(500)=ISNULL(CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(500)),N'C:\'); DECLARE @logPath NVARCHAR(500)=ISNULL(CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS NVARCHAR(500)),@dataPath); DECLARE @mdf NVARCHAR(500)=@dataPath+N'Ashley.mdf'; DECLARE @ldf NVARCHAR(500)=@logPath+N'Ashley_log.ldf'; RESTORE DATABASE [Ashley] FROM DISK=N'!bakFile!' WITH REPLACE, NOUNLOAD, STATS=10, MOVE N'Ashley' TO @mdf, MOVE N'Ashley_log' TO @ldf;"
if !errorlevel! neq 0 (
    echo   [WARN ] RESTORE reported an error. You can restore manually from SSMS using WITH MOVE.
    call :ackWarn
) else (
    echo   [ OK  ] Ashley database restored.
)
exit /b 0
