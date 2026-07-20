@echo off
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
call :stepPause

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
call :stepPause

:: ------------------------------------------------------------
:: [3/14] Create the "postgres" user (used as SQL SA password holder)
:: ------------------------------------------------------------
echo [3/14] Configuring "postgres" user account...
set "newUser=postgres"
set "newPassword=362611"
call :EnsureUser "%newUser%" "%newPassword%" "0"
if !errorlevel! neq 0 ( set "failStep=3/14 create postgres user" & goto :fatal )
call :stepPause

:: ------------------------------------------------------------
:: [4/14] Create the "RT" user (used by IIS + FTP)
:: ------------------------------------------------------------
echo [4/14] Configuring "RT" user account for IIS/FTP...
set "rtUser=RT"
set "rtPassword=master"
call :EnsureUser "%rtUser%" "%rtPassword%" "1"
if !errorlevel! neq 0 ( set "failStep=4/14 create RT user" & goto :fatal )
call :stepPause

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
call :stepPause

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
call :stepPause

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
call :stepPause

:: ------------------------------------------------------------
:: [8/14] Install Java Runtime Environment (from extracted zip)
:: ------------------------------------------------------------
echo [8/14] Installing Java Runtime Environment...

call :DownloadZeymalFiles
if !errorlevel! neq 0 (
    set "failStep=9/14 download Zeymal application files"
    echo   [ERROR] One or more Zeymal files failed to download.
    goto :fatal
)
call :stepPause

:: ------------------------------------------------------------
:: [9/14] Download Zeymal application files
:: ------------------------------------------------------------
echo [9/14] Downloading Zeymal application files...
call :InstallJava
call :stepPause

:: ------------------------------------------------------------
:: [10/14] Deploy files into the Zeymal folder
:: ------------------------------------------------------------
echo [10/14] Deploying files into %appFolder%...
call :DeployZeymalFiles
if !errorlevel! neq 0 (
    echo   [WARN ] Deployment finished with warnings.
    call :ackWarn
)
call :stepPause

:: ------------------------------------------------------------
:: [11/14] Configure SQL Server (TCP/IP, port 1433, service LogOn)
:: ------------------------------------------------------------
echo [11/14] Configuring SQL Server networking and service...
call :ConfigureSqlServer
call :stepPause

:: ------------------------------------------------------------
:: [12/14] Enable IIS + FTP Windows features
:: ------------------------------------------------------------
echo [12/14] Enabling IIS + FTP features...
call :EnableIisFeatures
call :stepPause

:: ------------------------------------------------------------
:: [13/14] Configure IIS virtual directory and FTP site
:: ------------------------------------------------------------
echo [13/14] Configuring IIS "RT" virtual directory and FTP site...
call :ConfigureIisSites
call :stepPause

:: ------------------------------------------------------------
:: [14/14] Restore Ashley database
:: ------------------------------------------------------------
echo [14/14] Restoring Ashley database...
call :RestoreAshleyDb
call :stepPause

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
echo   Setup finished successfully. Press any key to close this window...
pause >nul
exit /b 0


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
:: :stepPause - pause after every step so the user can review
:: output before the next step runs. NEVER auto-advance.
:: ============================================================
:stepPause
echo.
echo   -- Press any key to continue to the next step --
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

call :DownloadZeymalItem "ZeymalRplaceXip"     "(Z_Replace_Base).zip"            1 4
if !errorlevel! neq 0 exit /b 1
call :DownloadZeymalItem "ZeymalIftwInstaller" "jre-8u271-windows-i586-iftw.zip" 2 4
if !errorlevel! neq 0 exit /b 1
call :DownloadZeymalItem "Zeymalexe"           "Zeymal.zip"                      3 4
if !errorlevel! neq 0 exit /b 1
call :DownloadZeymalItem "ZeymalResetxip"      "Z_Reset_1034.zip"                4 4
if !errorlevel! neq 0 exit /b 1

echo   [ OK  ] All Zeymal files downloaded successfully.
echo.
echo   Extracting all zip files...

call :UnzipZeymalFiles

if !errorlevel! neq 0 (
    echo   [ERROR] Failed to extract some files.
    exit /b 1
)

echo   [ OK  ] All files extracted and zip files removed.
exit /b 0


:DownloadZeymalItem
set "varName=%~1"
set "fileName=%~2"
set "idx=%~3"
set "total=%~4"
set "fileUrl=!%varName%!"
set "fileDest=%ZeymalFiles%\%fileName%"

echo.
echo   [File %idx%/%total%] %fileName%

if exist "!fileDest!" (
    echo     [ OK  ] Already exists. Skipping.
    echo            !fileDest!
    exit /b 0
)

echo     Downloading...
curl.exe -L --fail --show-error --output "!fileDest!" "!fileUrl!"
set "curlRc=!errorlevel!"
echo     Exit code: !curlRc!
if !curlRc! neq 0 (
    echo     [ERROR] Download failed (rc=!curlRc!).
    echo            URL: !fileUrl!
    if exist "!fileDest!" del /q "!fileDest!" >nul 2>&1
    echo.
    echo     Window will stay open. Press any key to continue...
    pause >nul
    exit /b 1
)
echo     [ OK  ] Saved to: !fileDest!
exit /b 0


:UnzipZeymalFiles
set "unzipFailed=0"

call :ExtractZeymalItem "(Z_Replace_Base).zip"            1 4
call :ExtractZeymalItem "jre-8u271-windows-i586-iftw.zip" 2 4
call :ExtractZeymalItem "Zeymal.zip"                      3 4
call :ExtractZeymalItem "Z_Reset_1034.zip"                4 4

if !unzipFailed! neq 0 (
    exit /b 1
)
exit /b 0


:ExtractZeymalItem
set "ez_name=%~1"
set "ez_idx=%~2"
set "ez_total=%~3"
set "ez_zip=%ZeymalFiles%\%ez_name%"
set "ez_marker=%ZeymalFiles%\%ez_name%.extracted"

echo.
echo   [%ez_idx%/%ez_total%] %ez_name%
if exist "!ez_marker!" (
    echo     [ OK  ] Already extracted. Skipping.
    exit /b 0
)
if not exist "!ez_zip!" (
    echo     [WARN] %ez_name% not found. Skipping extraction.
    exit /b 0
)

echo     Extracting...
powershell -NoProfile -command "try { Expand-Archive -Path '!ez_zip!' -DestinationPath '%ZeymalFiles%' -Force } catch { exit 1 }"
if !errorlevel! neq 0 (
    echo     [ERROR] Failed to extract %ez_name%
    set "unzipFailed=1"
    exit /b 1
)
echo     [ OK  ] Extracted %ez_name%
> "!ez_marker!" echo extracted
exit /b 0



:: ============================================================
:: Java JRE 8u271 (from extracted zip file)
:: ============================================================
:InstallJava
echo   --- Java JRE 8u271 ---

set "JavaZip=%ZeymalFiles%\jre-8u271-windows-i586-iftw.zip"
set "JavaExtractDir=%ZeymalFiles%\jre_extract"
set "JavaInstaller=%JavaExtractDir%\jre-8u271-windows-i586-iftw.exe"

if exist "%JavaInstaller%" (
    echo   [ OK  ] Java installer already extracted.
) else if exist "%JavaZip%" (
    echo   Extracting Java installer from zip...
    if not exist "%JavaExtractDir%" mkdir "%JavaExtractDir%"
    powershell -NoProfile -Command "try { Expand-Archive -Path '%JavaZip%' -DestinationPath '%JavaExtractDir%' -Force } catch { exit 1 }"
    if !errorlevel! neq 0 (
        echo   [ERROR] Failed to extract Java installer zip.
        echo   [WARN ] You may need to manually extract and install Java.
        call :ackWarn
        exit /b 0
    )
    echo   [ OK  ] Java installer extracted.
) else (
    echo   [WARN ] Java zip file not found at: %JavaZip%
    echo   [WARN ] Java was not downloaded or extracted properly.
    echo   [WARN ] You may need to manually install Java.
    call :ackWarn
    exit /b 0
)

if not exist "%JavaInstaller%" (
    echo   [WARN ] Java installer executable not found at: %JavaInstaller%
    echo   [WARN ] You may need to manually install Java.
    call :ackWarn
    exit /b 0
)

echo   Installing Java silently (auto-update disabled)...
"%JavaInstaller%" /s AUTO_UPDATE=Disable STATIC=1 REBOOT=Disable EULA=Disable NOSTARTMENU=Enable WEB_ANALYTICS=Disable
if !errorlevel! neq 0 (
    echo   [WARN ] Java installation reported an error. You can install it manually if needed.
    call :ackWarn
    exit /b 0
)
echo   [ OK  ] Java JRE 8u271 installed successfully.
exit /b 0




:: ============================================================
:: Deploy Zeymal files: extract (Z_Replace_Base).zip into the app
:: folder and copy Zeymal.jar / .exe / jre alongside.
:: ============================================================
:DeployZeymalFiles
set "ZeymalFiles=%appFolder%\files"

set "zRepZip=%ZeymalFiles%\(Z_Replace_Base).zip"
if exist "%zRepZip%" (
    echo   Extracting "(Z_Replace_Base).zip" into %appFolder% ...
    powershell -NoProfile -Command "try { Expand-Archive -Path '%zRepZip%' -DestinationPath '%appFolder%' -Force } catch { exit 1 }"
    if !errorlevel! neq 0 (
        echo   [WARN ] Failed to extract "(Z_Replace_Base).zip".
        call :ackWarn
    ) else (
        echo   [ OK  ] Extracted.
    )
) else (
    echo   [WARN ] "(Z_Replace_Base).zip" not found in %ZeymalFiles%.
    call :ackWarn
)

call :CopyIfPresent "%ZeymalFiles%\Zeymal.jar"                      "%appFolder%\Zeymal.jar"
call :CopyIfPresent "%ZeymalFiles%\Zeymal.exe"                      "%appFolder%\Zeymal.exe"
call :CopyIfPresent "%ZeymalFiles%\jre-8u271-windows-i586-iftw.exe" "%appFolder%\jre-8u271-windows-i586-iftw.exe"
exit /b 0


:CopyIfPresent
if exist "%~1" (
    copy /Y "%~1" "%~2" >nul
    if !errorlevel! equ 0 (
        echo   [ OK  ] Copied: %~nx1
    ) else (
        echo   [WARN ] Failed to copy: %~nx1
    )
) else (
    echo   [WARN ] Missing (skip copy): %~1
)
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
    echo   [SKIP ] appcmd.exe not found. Ensure IIS is installed then re-run.
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
    echo   [WARN ] MIME type add failed (may already exist).
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

echo   Extracting Z_Reset_1034.zip ...
if not exist "%restoreDir%" mkdir "%restoreDir%"
powershell -NoProfile -Command "try { Expand-Archive -Path '%resetZip%' -DestinationPath '%restoreDir%' -Force } catch { exit 1 }"
if !errorlevel! neq 0 (
    echo   [ERROR] Failed to extract Z_Reset_1034.zip.
    exit /b 1
)

set "bakFile="
for /f "delims=" %%F in ('dir /b /s "%restoreDir%\*.bak" 2^>nul') do (
    if not defined bakFile set "bakFile=%%F"
)
if not defined bakFile (
    echo   [ERROR] No .bak file found inside Z_Reset_1034.zip.
    exit /b 1
)
echo   Backup file: !bakFile!

where sqlcmd >nul 2>&1
if !errorlevel! neq 0 (
    echo   [SKIP ] sqlcmd not found on PATH. Install SSMS/mssql-tools, then run:
    echo           sqlcmd -S .\SQLEXPRESS -U sa -P %newPassword% ^-Q ^"RESTORE DATABASE Ashley FROM DISK='!bakFile!' WITH REPLACE^"
    exit /b 0
)

echo   Restoring "Ashley" via sqlcmd ...
sqlcmd -S .\SQLEXPRESS -U sa -P "%newPassword%" -Q "RESTORE DATABASE [Ashley] FROM DISK=N'!bakFile!' WITH REPLACE, NOUNLOAD, STATS=10"
if !errorlevel! neq 0 (
    echo   [WARN ] RESTORE reported an error. You can restore manually from SSMS.
    call :ackWarn
) else (
    echo   [ OK  ] Ashley database restored.
)
exit /b 0