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
:: Setup's own state (chosen folders, finished steps), so a re-run picks up where the last one left off.
set "setupRegKey=HKLM\SOFTWARE\RationalTabs\ZeymalSetup"

:: Base64 (UTF-16LE) of a small PowerShell helper used by :RunWithProgress to run a silent
:: installer/downloader while printing a live elapsed-time line (and, when RP_WATCHDIR is set,
:: live downloaded bytes/speed), instead of leaving the console looking frozen for several
:: minutes. Kept as one encoded constant so no quoting inside it can break the batch parser.
set "RunProgressB64=JABFAHIAcgBvAHIAQQBjAHQAaQBvAG4AUAByAGUAZgBlAHIAZQBuAGMAZQAgAD0AIAAnAFMAdABvAHAAJwAKACQAUAByAG8AZwByAGUAcwBzAFAAcgBlAGYAZQByAGUAbgBjAGUAIAA9ACAAJwBTAGkAbABlAG4AdABsAHkAQwBvAG4AdABpAG4AdQBlACcACgBmAHUAbgBjAHQAaQBvAG4AIABGAG0AdABTAGkAegBlACgAJABiACkAIAB7AAoAIAAgACAAIABpAGYAIAAoACQAYgAgAC0AZwBlACAAMQBHAEIAKQAgAHsAIAAnAHsAMAA6AE4AMgB9ACAARwBCACcAIAAtAGYAIAAoACQAYgAvADEARwBCACkAIAB9AAoAIAAgACAAIABlAGwAcwBlAGkAZgAgACgAJABiACAALQBnAGUAIAAxAE0AQgApACAAewAgACcAewAwADoATgAyAH0AIABNAEIAJwAgAC0AZgAgACgAJABiAC8AMQBNAEIAKQAgAH0ACgAgACAAIAAgAGUAbABzAGUAaQBmACAAKAAkAGIAIAAtAGcAZQAgADEASwBCACkAIAB7ACAAJwB7ADAAOgBOADIAfQAgAEsAQgAnACAALQBmACAAKAAkAGIALwAxAEsAQgApACAAfQAKACAAIAAgACAAZQBsAHMAZQAgAHsAIAAnAHsAMAB9ACAAQgAnACAALQBmACAAWwBpAG4AdABdACQAYgAgAH0ACgB9AAoAdAByAHkAIAB7AAoAIAAgACAAIAAkAGUAeABlACAAPQAgACQAZQBuAHYAOgBSAFAAXwBFAFgARQAKACAAIAAgACAAJABhAHIAZwBMAGkAbgBlACAAPQAgACQAZQBuAHYAOgBSAFAAXwBBAFIARwBTAAoAIAAgACAAIAAkAGwAYQBiAGUAbAAgAD0AIAAkAGUAbgB2ADoAUgBQAF8ATABBAEIARQBMAAoAIAAgACAAIAAkAHcAYQB0AGMAaAAgAD0AIAAkAGUAbgB2ADoAUgBQAF8AVwBBAFQAQwBIAEQASQBSAAoAIAAgACAAIAAkAHMAdABhAHIAdAAgAD0AIABHAGUAdAAtAEQAYQB0AGUACgAgACAAIAAgAGkAZgAgACgAJABhAHIAZwBMAGkAbgBlACkAIAB7AAoAIAAgACAAIAAgACAAIAAgACQAcAAgAD0AIABTAHQAYQByAHQALQBQAHIAbwBjAGUAcwBzACAALQBGAGkAbABlAFAAYQB0AGgAIAAkAGUAeABlACAALQBBAHIAZwB1AG0AZQBuAHQATABpAHMAdAAgACQAYQByAGcATABpAG4AZQAgAC0AUABhAHMAcwBUAGgAcgB1ACAALQBXAGkAbgBkAG8AdwBTAHQAeQBsAGUAIABIAGkAZABkAGUAbgAKACAAIAAgACAAfQAgAGUAbABzAGUAIAB7AAoAIAAgACAAIAAgACAAIAAgACQAcAAgAD0AIABTAHQAYQByAHQALQBQAHIAbwBjAGUAcwBzACAALQBGAGkAbABlAFAAYQB0AGgAIAAkAGUAeABlACAALQBQAGEAcwBzAFQAaAByAHUAIAAtAFcAaQBuAGQAbwB3AFMAdAB5AGwAZQAgAEgAaQBkAGQAZQBuAAoAIAAgACAAIAB9AAoAIAAgACAAIAAkAGQAcgBhAHcAbgAgAD0AIABbAGQAYQB0AGUAdABpAG0AZQBdADoAOgBNAGkAbgBWAGEAbAB1AGUACgAgACAAIAAgAHcAaABpAGwAZQAgACgALQBuAG8AdAAgACQAcAAuAEgAYQBzAEUAeABpAHQAZQBkACkAIAB7AAoAIAAgACAAIAAgACAAIAAgAGkAZgAgACgAKAAoAEcAZQB0AC0ARABhAHQAZQApACAALQAgACQAZAByAGEAdwBuACkALgBUAG8AdABhAGwATQBpAGwAbABpAHMAZQBjAG8AbgBkAHMAIAAtAGcAZQAgADEAMAAwADAAKQAgAHsACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAkAGQAcgBhAHcAbgAgAD0AIABHAGUAdAAtAEQAYQB0AGUACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAkAGUAbAAgAD0AIAAoAEcAZQB0AC0ARABhAHQAZQApACAALQAgACQAcwB0AGEAcgB0AAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAJAB0AHMAIAA9ACAAJwB7ADAAOgBEADIAfQA6AHsAMQA6AEQAMgB9ADoAewAyADoARAAyAH0AJwAgAC0AZgAgAFsAaQBuAHQAXQAkAGUAbAAuAFQAbwB0AGEAbABIAG8AdQByAHMALAAgACQAZQBsAC4ATQBpAG4AdQB0AGUAcwAsACAAJABlAGwALgBTAGUAYwBvAG4AZABzAAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAaQBmACAAKAAkAHcAYQB0AGMAaAApACAAewAKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAJABiAHkAdABlAHMAIAA9ACAAMAAKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAaQBmACAAKABUAGUAcwB0AC0AUABhAHQAaAAgAC0ATABpAHQAZQByAGEAbABQAGEAdABoACAAJAB3AGEAdABjAGgAKQAgAHsACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAJABtACAAPQAgAEcAZQB0AC0AQwBoAGkAbABkAEkAdABlAG0AIAAtAEwAaQB0AGUAcgBhAGwAUABhAHQAaAAgACQAdwBhAHQAYwBoACAALQBSAGUAYwB1AHIAcwBlACAALQBGAGkAbABlACAALQBFAHIAcgBvAHIAQQBjAHQAaQBvAG4AIABTAGkAbABlAG4AdABsAHkAQwBvAG4AdABpAG4AdQBlACAAfAAgAE0AZQBhAHMAdQByAGUALQBPAGIAagBlAGMAdAAgAC0AUAByAG8AcABlAHIAdAB5ACAATABlAG4AZwB0AGgAIAAtAFMAdQBtAAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgAGkAZgAgACgAJABtAC4AUwB1AG0AKQAgAHsAIAAkAGIAeQB0AGUAcwAgAD0AIAAkAG0ALgBTAHUAbQAgAH0ACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgAH0ACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACQAcwBwAGQAIAA9ACAAaQBmACAAKAAkAGUAbAAuAFQAbwB0AGEAbABTAGUAYwBvAG4AZABzACAALQBnAHQAIAAwACkAIAB7ACAAJABiAHkAdABlAHMAIAAvACAAJABlAGwALgBUAG8AdABhAGwAUwBlAGMAbwBuAGQAcwAgAH0AIABlAGwAcwBlACAAewAgADAAIAB9AAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIABbAEMAbwBuAHMAbwBsAGUAXQA6ADoAVwByAGkAdABlACgAKAAiAGAAcgAgACAAIAAgAFsAewAwAH0AXQAgAHsAMQB9ACAALQAgAGQAbwB3AG4AbABvAGEAZABlAGQAIAB7ADIAfQAsACAAewAzAH0ALwBzACAAIAAgACAAIAAgACIAIAAtAGYAIAAkAHQAcwAsACAAJABsAGEAYgBlAGwALAAgACgARgBtAHQAUwBpAHoAZQAgACQAYgB5AHQAZQBzACkALAAgACgARgBtAHQAUwBpAHoAZQAgACQAcwBwAGQAKQApACkACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAB9ACAAZQBsAHMAZQAgAHsACgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgAFsAQwBvAG4AcwBvAGwAZQBdADoAOgBXAHIAaQB0AGUAKAAoACIAYAByACAAIAAgACAAWwB7ADAAfQBdACAAewAxAH0AIAAtACAAcwB0AGkAbABsACAAcgB1AG4AbgBpAG4AZwAsACAAcABsAGUAYQBzAGUAIAB3AGEAaQB0AC4ALgAuACAAIAAgACAAIAAgACIAIAAtAGYAIAAkAHQAcwAsACAAJABsAGEAYgBlAGwAKQApAAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAfQAKACAAIAAgACAAIAAgACAAIAB9AAoAIAAgACAAIAAgACAAIAAgAFMAdABhAHIAdAAtAFMAbABlAGUAcAAgAC0ATQBpAGwAbABpAHMAZQBjAG8AbgBkAHMAIAAyADUAMAAKACAAIAAgACAAfQAKACAAIAAgACAAWwBDAG8AbgBzAG8AbABlAF0AOgA6AFcAcgBpAHQAZQBMAGkAbgBlACgAKQAKACAAIAAgACAAJABlAGwAIAA9ACAAKABHAGUAdAAtAEQAYQB0AGUAKQAgAC0AIAAkAHMAdABhAHIAdAAKACAAIAAgACAAJAB0AHMAIAA9ACAAJwB7ADAAOgBEADIAfQA6AHsAMQA6AEQAMgB9ADoAewAyADoARAAyAH0AJwAgAC0AZgAgAFsAaQBuAHQAXQAkAGUAbAAuAFQAbwB0AGEAbABIAG8AdQByAHMALAAgACQAZQBsAC4ATQBpAG4AdQB0AGUAcwAsACAAJABlAGwALgBTAGUAYwBvAG4AZABzAAoAIAAgACAAIABbAEMAbwBuAHMAbwBsAGUAXQA6ADoAVwByAGkAdABlAEwAaQBuAGUAKAAnACAAIAAgACAARgBpAG4AaQBzAGgAZQBkACAAaQBuACAAJwAgACsAIAAkAHQAcwAgACsAIAAnAC4AJwApAAoAIAAgACAAIABlAHgAaQB0ACAAJABwAC4ARQB4AGkAdABDAG8AZABlAAoAfQAgAGMAYQB0AGMAaAAgAHsACgAgACAAIAAgAFsAQwBvAG4AcwBvAGwAZQBdADoAOgBXAHIAaQB0AGUATABpAG4AZQAoACkACgAgACAAIAAgAFsAQwBvAG4AcwBvAGwAZQBdADoAOgBXAHIAaQB0AGUATABpAG4AZQAoACcAIAAgACAAIABbAEUAUgBSAE8AUgBdACAAJwAgACsAIAAkAF8ALgBFAHgAYwBlAHAAdABpAG8AbgAuAE0AZQBzAHMAYQBnAGUAKQAKACAAIAAgACAAZQB4AGkAdAAgADEACgB9AAoA"

:: ============================================================
::  Zeymal Environment Setup
:: ============================================================
echo.
echo ============================================================
echo   Zeymal Environment Setup
echo ============================================================
echo   This script will:
echo     * Create the "RT" user (IIS/FTP and app account)
echo     * Prepare application and download folders (off the system drive if possible)
echo     * Install SQL Server Express (2022 on Win10/11, 2014 on Win7/8)
echo     * Install Java Runtime Environment 8u271
echo     * Download and deploy the Zeymal application files
echo     * Configure SQL Server (TCP/IP, port 1433)
echo     * Install IIS + FTP and configure the RT site
echo     * Restore the Ashley database
echo     * Delete the downloads once they are installed
echo ============================================================
echo.

:: ------------------------------------------------------------
:: [1/13] Check administrator privileges
:: ------------------------------------------------------------
echo [1/13] Checking administrator privileges...
net session >nul 2>&1
if errorlevel 1 (
    set "failStep=1/13 admin privileges check"
    echo   [ERROR] This script requires administrator privileges.
    echo           Right-click the script and choose "Run as administrator".
    goto :fatal
)
echo   [ OK  ] Running with administrator privileges.
echo.

:: ------------------------------------------------------------
:: [2/13] Detect and validate Windows version
:: ------------------------------------------------------------
echo [2/13] Detecting Windows version...
for /f "delims=" %%A in ('powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).Caption"') do set "windowsName=%%A"
echo   Detected OS: %windowsName%

echo %windowsName% | findstr /I /C:"Windows 7" /C:"Windows 8" /C:"Windows 10" /C:"Windows 11" >nul
if errorlevel 1 (
    set "failStep=2/13 Windows version detection"
    echo   [ERROR] Unsupported Windows version.
    echo           This installer supports Windows 7, 8, 10, and 11 only.
    goto :fatal
)
echo   [ OK  ] Supported Windows version detected.
echo.

:: ------------------------------------------------------------
:: [3/13] Create the "RT" user (used by IIS/FTP and as app account)
:: ------------------------------------------------------------
echo [3/13] Configuring "RT" user account...
:: RT's password includes the year of the first run (masterYY). The year is saved, so a re-run,
:: even in a later year, expects the same password.
call :RegGet PasswordYear pwYear
if not defined pwYear for /f %%Y in ('powershell -NoProfile -Command "(Get-Date).Year"') do set "pwYear=%%Y"
call :RegSet PasswordYear "!pwYear!"
set "newUser=RT"
set "newPassword=master!pwYear:~-2!"
call :EnsureUser "%newUser%" "%newPassword%" "1"
if !errorlevel! neq 0 ( set "failStep=3/13 create RT user" & goto :fatal )
:: How setup signs in to SQL Server: Windows authentication until it knows a working sa password.
set "SQLAUTH=-E"
call :AskSaPassword
if !errorlevel! neq 0 ( set "failStep=3/13 choose the sa password" & goto :fatal )
call :SqlSignIn
echo.

:: ------------------------------------------------------------
:: [4/13] Choose and create the application folder
:: ------------------------------------------------------------
echo [4/13] Preparing application folder...
:: Where the old script put everything; only used to reuse or clear what it left behind.
set "legacyApp=%SystemDrive%\Users\%newUser%\zeymal"
set "legacyFiles=%legacyApp%\files"
set "legacyDownloads=%SystemDrive%\Users\%newUser%\Downloads"
call :ChooseFolders
if !errorlevel! neq 0 ( set "failStep=4/13 choose application folder" & goto :fatal )
call :PrepareFolder "!appFolder!" "%newUser%"
if !errorlevel! neq 0 ( set "failStep=4/13 create application folder" & goto :fatal )
echo.

:: ------------------------------------------------------------
:: [5/13] Create the Downloads folder
:: ------------------------------------------------------------
echo [5/13] Preparing Downloads folder...
set "ZeymalFiles=%DownloadPath%\files"
call :PrepareFolder "!DownloadPath!"
if !errorlevel! neq 0 ( set "failStep=5/13 create Downloads folder" & goto :fatal )
call :PrepareFolder "!ZeymalFiles!"
if !errorlevel! neq 0 ( set "failStep=5/13 create Downloads folder" & goto :fatal )
echo   [NOTE ] Each download is deleted once what it installs is in place.
echo.

:: ------------------------------------------------------------
:: [6/13] Install SQL Server (edition depends on Windows version)
:: ------------------------------------------------------------
echo [6/13] Installing SQL Server and SSMS...
echo %windowsName% | findstr /I /C:"Windows 11" /C:"Windows 10" >nul
if not errorlevel 1 (
    call :InstallSqlModern
    if !errorlevel! neq 0 ( set "failStep=6/13 SQL Server 2022 install" & goto :fatal )
) else (
    echo %windowsName% | findstr /I /C:"Windows 7" /C:"Windows 8" >nul
    if not errorlevel 1 (
        call :InstallSqlLegacy
        if !errorlevel! neq 0 ( set "failStep=6/13 SQL Server 2014 install" & goto :fatal )
    ) else (
        set "failStep=6/13 SQL Server install (unsupported Windows)"
        echo   [ERROR] Unsupported Windows version for SQL Server install.
        goto :fatal
    )
)
call :InstallSSMS
echo.

:: ------------------------------------------------------------
:: [7/13] Download Zeymal application files
:: ------------------------------------------------------------
echo [7/13] Downloading Zeymal application files...
call :DownloadZeymalFiles
if !errorlevel! neq 0 (
    echo   [WARN ] Zeymal file download had issues.
    echo           You can complete this manually:
    echo             Source URL : %ZeymalBaseUrl%
    echo             Target dir : %ZeymalFiles%
    echo           Continuing so the rest of the setup can run.
    call :ackWarn
)
echo.

:: ------------------------------------------------------------
:: [8/13] Install Java Runtime Environment 8u271
:: ------------------------------------------------------------
echo [8/13] Installing Java Runtime Environment 8u271...
call :InstallJava
if !errorlevel! neq 0 (
    echo   [WARN ] Java installation reported an error or was skipped.
    echo           You can install Java manually from:
    echo             %ZeymalFiles%\jre_extract\jre-8u271-windows-i586-iftw.exe
    echo           Continuing with the rest of the setup...
    call :ackWarn
)
echo.
:: ------------------------------------------------------------
:: [9/13] Deploy files and install Zeymal application
:: ------------------------------------------------------------
echo [9/13] Deploying Zeymal application files...
call :DeployZeymalFiles
if !errorlevel! neq 0 (
    echo   [WARN ] Deployment finished with warnings.
    call :ackWarn
)
echo.

call :RunZeymalInstaller

:: ------------------------------------------------------------
:: [9.5/13] Copy the Zeymal base files into the app folder
:: ------------------------------------------------------------
echo [9.5/13] Copying Zeymal base files to %appFolder%...
call :CopyBaseFiles
if !errorlevel! neq 0 (
    echo   [WARN ] Copying the base files had issues.
    call :ackWarn
)
echo.

:: ------------------------------------------------------------
:: [10/13] Configure SQL Server (TCP/IP, port 1433, service LogOn)
:: ------------------------------------------------------------
echo [10/13] Configuring SQL Server networking and service...
call :ConfigureSqlServer
echo.

:: ------------------------------------------------------------
:: [11/13] Enable IIS + FTP Windows features
:: ------------------------------------------------------------
echo [11/13] Enabling IIS + FTP features...
call :EnableIisFeatures
echo.

:: ------------------------------------------------------------
:: [12/13] Configure IIS virtual directory and FTP site
:: ------------------------------------------------------------
echo [12/13] Configuring IIS "RT" virtual directory and FTP site...
call :ConfigureIisSites
echo.

:: ------------------------------------------------------------
:: [13/13] Restore Ashley database
:: ------------------------------------------------------------
echo [13/13] Restoring Ashley database...
call :RestoreAshleyDb
call :SetAppFtpPassword
echo.

:: ------------------------------------------------------------
:: [Cleanup] Delete the downloads whose contents are in place
:: ------------------------------------------------------------
echo [Cleanup] Deleting setup downloads that are no longer needed...
call :CleanupDownloads
echo.

:: ------------------------------------------------------------
:: [Lockdown] Restrict SQL Server to the sa login
:: ------------------------------------------------------------
echo [Lockdown] Turning off Windows sign-in to SQL Server...
call :RestrictSqlToSa
echo.

echo ============================================================
echo   Setup complete
echo ============================================================
echo   User account     : %newUser%   (password: %newPassword%)
echo   App folder       : %appFolder%   (Zeymal, IIS /RT and FTP root)
echo   Setup downloads  : !downloadsState!
echo   SQL instance     : .\SQLEXPRESS  (TCP 1433)
if defined sqlSaPassword (
    echo   SQL SA password  : !sqlSaPassword!   ^(the school's Zeymal config must use it^)
) else (
    echo   SQL SA password  : the one chosen when SQL Server was installed
)
echo   SQL sign-in      : !sqlLockState!
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
    echo   will detect existing state and skip; step [12/13] will
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
:: An existing user must already have <password>: IIS, FTP and the
:: app's network sources are set up with it. If not (servers set up
:: before used "master"), the operator is asked before it is changed.
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
    goto :EU_groups
)
echo   [ OK  ] User "%eu_user%" already exists.
call :CheckUserPassword "%eu_user%" "%eu_pass%"
if !errorlevel! equ 0 (
    echo   [ OK  ] Its password is already %eu_pass%.
    goto :EU_groups
)
echo   [WARN ] "%eu_user%" has another password ^(servers set up before used "master"^).
echo           Setup changes it to %eu_pass% and updates IIS, FTP and the app's network
echo           sources in the Ashley database to match. Zeymal on the other PCs picks it
echo           up at its next sign-in. Anything else that signs in as %eu_user%, such as a
echo           scheduled task, needs the new password by hand.
choice /c YN /m "  Change the password of %eu_user% to %eu_pass% now"
if errorlevel 2 (
    echo   [ERROR] Setup needs %eu_user%'s password to be %eu_pass%. Nothing was changed.
    exit /b 1
)
net user "%eu_user%" "%eu_pass%" >nul
if !errorlevel! neq 0 (
    echo   [ERROR] Failed to change the password of "%eu_user%".
    exit /b 1
)
echo   [ OK  ] Password of "%eu_user%" changed.

:EU_groups
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


:: Returns 0 when <user> can sign in with <password>. A network logon, which starts nothing.
:CheckUserPassword
set "CU_USER=%~1"
set "CU_PASS=%~2"
powershell -NoProfile -Command "Add-Type -Namespace ZeymalSetup -Name Logon -MemberDefinition '[DllImport(\"advapi32.dll\", SetLastError = true)] public static extern bool LogonUser(string user, string domain, string password, int type, int provider, out System.IntPtr token); [DllImport(\"kernel32.dll\")] public static extern bool CloseHandle(System.IntPtr handle);'; $t = [IntPtr]::Zero; if ([ZeymalSetup.Logon]::LogonUser($env:CU_USER, '.', $env:CU_PASS, 3, 0, [ref]$t)) { [void][ZeymalSetup.Logon]::CloseHandle($t); exit 0 } else { exit 1 }"
set "cuRc=!errorlevel!"
set "CU_USER="
set "CU_PASS="
exit /b %cuRc%


:: ============================================================
:: :AskSaPassword - when SQL Server is about to be installed, asks
:: for the password of its "sa" login. Setup appends #<YYMMDD> of
:: the install day to what is typed (DbPass -> DbPass#261103);
:: Enter takes DbPass. The password itself is not stored; the date
:: is (SqlInstallDate), so a later run can ask for the part before #.
:: ============================================================
:AskSaPassword
set "sqlSaPassword="
sc query "MSSQL$SQLEXPRESS" >nul 2>&1 && exit /b 0
for /f %%D in ('powershell -NoProfile -Command "(Get-Date).ToString('yyMMdd')"') do set "sqlDate=%%D"
call :RegSet SqlInstallDate "!sqlDate!"
echo.
echo   SQL Server will be installed. Choose the password of its "sa" login:
echo   setup adds #!sqlDate! ^(today^) to what you type. Press Enter for DbPass#!sqlDate!.
echo   Use at least 3 characters, at least one a letter: letters, digits, @ $ _ . - + *
:ASP_prompt
set "saBase="
set /p "saBase=  sa password > "
if not defined saBase set "saBase=DbPass"
:: Checked in PowerShell, so no character of it is ever run through cmd.
set "CHK_PW=!saBase!"
powershell -NoProfile -Command "if ($env:CHK_PW -cmatch '^[A-Za-z0-9@$_.+*-]{3,100}$' -and $env:CHK_PW -match '[A-Za-z]') { exit 0 } else { exit 1 }"
set "chkRc=!errorlevel!"
set "CHK_PW="
if !chkRc! neq 0 (
    echo   [ERROR] At least 3 characters, at least one a letter, using only letters, digits
    echo           and @ $ _ . - + *
    goto :ASP_prompt
)
set "sqlSaPassword=!saBase!#!sqlDate!"
set "saBase="
echo   [ OK  ] The sa password will be: !sqlSaPassword!
echo           Note it down: the school's Zeymal config ^(Load Config^) must use it.
echo           At the end, SQL Server is restricted to sa ^(Windows sign-in is turned off^).
exit /b 0


:: ============================================================
:: :SqlSignIn - SQL Server is already installed: find out how setup
:: can sign in. Windows authentication works on a server that was
:: never restricted; then a typed sa password lets setup restrict it
:: at the end. On a restricted server only sa works, so setup needs
:: its password for the database steps. Enter skips either way.
:: ============================================================
:SqlSignIn
sc query "MSSQL$SQLEXPRESS" >nul 2>&1 || exit /b 0
if defined sqlSaPassword exit /b 0
call :FindSqlcmd || exit /b 0
call :RegGet SqlInstallDate sqlDate
call :SqlTry -E
if !errorlevel! equ 0 (
    echo   Windows administrators can sign in to SQL Server. To restrict it to the sa login
    echo   at the end of setup, type the sa password. Press Enter to leave it as it is.
) else (
    echo   SQL Server accepts only the sa login. Type its password for setup's database steps.
    echo   Press Enter to skip those steps.
)
if defined sqlDate echo   The part before #!sqlDate! is enough.
set "ssTries=0"
:SSI_prompt
set "saTyped="
set /p "saTyped=  sa password > "
if not defined saTyped (
    echo   [SKIP ] No sa password: SQL Server sign-in is left as it is.
    exit /b 0
)
set /a ssTries+=1
set "SQLCMDPASSWORD=!saTyped!"
call :SqlTry -U sa
if !errorlevel! neq 0 if defined sqlDate (
    set "SQLCMDPASSWORD=!saTyped!#!sqlDate!"
    call :SqlTry -U sa
)
if !errorlevel! equ 0 (
    set "sqlSaPassword=!SQLCMDPASSWORD!"
    set "SQLAUTH=-U sa"
    set "saTyped="
    echo   [ OK  ] Signed in to SQL Server as sa.
    exit /b 0
)
set "SQLCMDPASSWORD="
if !ssTries! LSS 3 (
    echo   [ERROR] sa did not sign in with that password. Try again, or press Enter to skip.
    goto :SSI_prompt
)
set "saTyped="
echo   [WARN ] sa did not sign in after 3 tries ^(more could lock the login^). Skipping.
call :ackWarn
exit /b 0


:: Returns 0 when sqlcmd can sign in to .\SQLEXPRESS with <auth> (-E, or -U sa with the
:: password in SQLCMDPASSWORD, which sqlcmd reads itself: it never shows on a command line).
:: sqlcmd gets no input: it would otherwise share, and move, the input the prompts read.
:SqlTry
sqlcmd -S .\SQLEXPRESS %* -C -b -l 15 -Q "SET NOCOUNT ON; SELECT 1" <nul >nul 2>&1
if !errorlevel! equ 0 exit /b 0
sqlcmd -S .\SQLEXPRESS %* -b -l 15 -Q "SET NOCOUNT ON; SELECT 1" <nul >nul 2>&1
exit /b !errorlevel!


:: ============================================================
:: :FindSqlcmd - returns 0 when sqlcmd can be run. In the window
:: that has just installed SQL Server, PATH is from before the
:: install, so sqlcmd's own folder is looked up and added to PATH.
:: ============================================================
:FindSqlcmd
where sqlcmd >nul 2>&1 && exit /b 0
set "sqlcmdDir="
for /d %%D in ("%ProgramFiles%\Microsoft SQL Server\*") do if exist "%%~D\Tools\Binn\SQLCMD.EXE" set "sqlcmdDir=%%~D\Tools\Binn"
for /d %%D in ("%ProgramFiles%\Microsoft SQL Server\Client SDK\ODBC\*") do if exist "%%~D\Tools\Binn\SQLCMD.EXE" set "sqlcmdDir=%%~D\Tools\Binn"
if not defined sqlcmdDir exit /b 1
set "PATH=!sqlcmdDir!;!PATH!"
exit /b 0


:: ============================================================
:: :RestrictSqlToSa - once sa signs in, turns Windows sign-in to
:: SQL Server off: every Windows user and group login (including
:: BUILTIN\Administrators, which the install made sysadmin, and so
:: RT) is denied CONNECT SQL and disabled - what used to be done by
:: hand. SQL Server's own service accounts (NT SERVICE\..., NT
:: AUTHORITY\...) are left alone. Undo for one login:
::   ALTER LOGIN [x] ENABLE; REVOKE CONNECT SQL FROM [x];
:: ============================================================
:RestrictSqlToSa
set "sqlLockState=Windows administrators and sa"
if not defined sqlSaPassword (
    echo   [SKIP ] The sa password is not known in this run, so Windows sign-in is left on.
    exit /b 0
)
sc query "MSSQL$SQLEXPRESS" >nul 2>&1 || exit /b 0
call :FindSqlcmd
if !errorlevel! neq 0 (
    echo   [WARN ] sqlcmd not found, so Windows sign-in to SQL Server is left on.
    call :ackWarn
    exit /b 0
)
set "SQLCMDPASSWORD=!sqlSaPassword!"
call :SqlTry -U sa
if !errorlevel! neq 0 (
    echo   [WARN ] sa does not sign in with the password set at install, so Windows sign-in
    echo           to SQL Server is left on. Check sa in SSMS, then run setup.bat again.
    call :ackWarn
    exit /b 0
)
set "LOCK_SQL=SET NOCOUNT ON; DECLARE @name sysname, @sql nvarchar(max); DECLARE logins CURSOR LOCAL FAST_FORWARD FOR SELECT sp.name FROM sys.server_principals sp WHERE sp.type IN ('U', 'G') AND LEFT(sp.name, 11) <> N'NT SERVICE\' AND LEFT(sp.name, 13) <> N'NT AUTHORITY\' AND (sp.is_disabled = 0 OR NOT EXISTS (SELECT 1 FROM sys.server_permissions pe WHERE pe.grantee_principal_id = sp.principal_id AND pe.permission_name = 'CONNECT SQL' AND pe.state = 'D')); OPEN logins; FETCH NEXT FROM logins INTO @name; WHILE @@FETCH_STATUS = 0 BEGIN SET @sql = N'DENY CONNECT SQL TO ' + QUOTENAME(@name) + N'; ALTER LOGIN ' + QUOTENAME(@name) + N' DISABLE;'; EXEC (@sql); PRINT '  Windows sign-in turned off for ' + @name; FETCH NEXT FROM logins INTO @name; END; CLOSE logins; DEALLOCATE logins;"
sqlcmd -S .\SQLEXPRESS -U sa -C -b -l 15 -Q "!LOCK_SQL!"
if !errorlevel! neq 0 sqlcmd -S .\SQLEXPRESS -U sa -b -l 15 -Q "!LOCK_SQL!"
set "lockRc=!errorlevel!"
set "LOCK_SQL="
set "SQLAUTH=-U sa"
call :SqlTry -E
if !errorlevel! equ 0 (
    echo   [WARN ] Windows sign-in to SQL Server still works ^(exit !lockRc!^). Check the logins in SSMS.
    call :ackWarn
    exit /b 0
)
echo   [ OK  ] SQL Server accepts only sa now; Windows sign-in is off.
set "sqlLockState=sa only (Windows sign-in off)"
exit /b 0


:: ============================================================
:: :SetAppFtpPassword - the app signs in to FTP with the user and
:: password in dbo.Ash_NetworkSource, so every source that uses RT
:: gets RT's password (the restored backup has the old "master").
:: Runs on every run; a source that already has it is not touched.
:: ============================================================
:SetAppFtpPassword
call :QueryAshleyDb
if /i not "!dbExists!"=="YES" exit /b 0
set "FTP_SQL=SET NOCOUNT ON; UPDATE dbo.Ash_NetworkSource SET AsH_Password = N'$(APP_PASSWORD)', Ash_ModifiedBy = N'Admin', Ash_ModifiedDate = GETDATE() WHERE AsH_User = N'$(APP_USER)' AND (AsH_Password IS NULL OR CAST(AsH_Password AS varbinary(2000)) <> CAST(N'$(APP_PASSWORD)' AS varbinary(2000))); PRINT CAST(@@ROWCOUNT AS varchar(10)) + ' network source(s) updated';"
sqlcmd -S .\SQLEXPRESS %SQLAUTH% -C -d Ashley -b -h -1 -v APP_USER="%newUser%" APP_PASSWORD="%newPassword%" -Q "!FTP_SQL!"
if !errorlevel! neq 0 sqlcmd -S .\SQLEXPRESS %SQLAUTH% -d Ashley -b -h -1 -v APP_USER="%newUser%" APP_PASSWORD="%newPassword%" -Q "!FTP_SQL!"
if !errorlevel! neq 0 (
    echo   [WARN ] Could not set the app's FTP password in the Ashley database. In Zeymal,
    echo           set the password of every network source that uses %newUser% to %newPassword%.
    call :ackWarn
) else (
    echo   [ OK  ] The app's FTP sources use %newUser% / %newPassword%.
)
set "FTP_SQL="
exit /b 0



:: ============================================================
:: :ChooseFolders - sets appFolder (where Zeymal is installed; also
:: the IIS /RT and FTP root, where the school's photos and documents
:: go) and DownloadPath (what setup downloads, in a separate
:: Zeymal-Setup folder on the same drive; each item is deleted once
:: it is installed).
::
:: Neither goes under C:\Users any more. An administrator other than
:: RT is not sure to be able to write into RT's profile (some
:: machines ended up with corrupt zips there), and making
:: C:\Users\RT before RT's first logon pushes RT's real profile to
:: C:\Users\RT.<PC>. A drive other than the system drive is used
:: when there is one.
::
:: Both are saved in the registry, so the re-run after the IIS reboot
:: uses the same folders. An existing IIS /RT folder is kept unless
:: it is the old script's C:\Users\RT\zeymal: then a new folder is
:: chosen and step 12 moves the school's files into it.
:: ============================================================
:ChooseFolders
call :RegGet AppFolder appFolder
call :RegGet DownloadFolder DownloadPath

:: The fixed NTFS drive, other than the system drive, with the most free space (at least 4 GB).
set "dataDrive="
set "dataFree="
for /f "tokens=1,2" %%A in ('powershell -NoProfile -Command "$s = $env:SystemDrive; Get-WmiObject Win32_LogicalDisk -Filter 'DriveType=3' | Where-Object { $_.DeviceID -ne $s -and $_.FileSystem -eq 'NTFS' -and $_.FreeSpace -ge 4GB } | Sort-Object FreeSpace -Descending | Select-Object -First 1 | ForEach-Object { '{0} {1:N0}' -f $_.DeviceID, ($_.FreeSpace / 1GB) }" 2^>nul') do (
    set "dataDrive=%%A"
    set "dataFree=%%B"
)

if defined appFolder (
    echo   [ OK  ] Using the folder chosen on an earlier run.
) else (
    call :IisRootFolder
)
if not defined appFolder (
    if exist "%legacyApp%\" (
        echo   [NOTE ] This server's files are in %legacyApp%. Step 12 moves them
        echo           into the folder chosen here and points IIS and FTP at it.
    )
    call :AskAppFolder
)
if not defined appFolder exit /b 1

:: Downloads go on the app folder's drive, or on the other drive when the app folder is on the system drive.
if not defined DownloadPath (
    set "workDrive=!appFolder:~0,2!"
    if /I "!workDrive!"=="%SystemDrive%" if defined dataDrive set "workDrive=!dataDrive!"
    set "DownloadPath=!workDrive!\Zeymal-Setup"
)
call :RegSet AppFolder "!appFolder!"
call :RegSet DownloadFolder "!DownloadPath!"
echo   App folder       : !appFolder!
echo   Downloads folder : !DownloadPath!
exit /b 0


:: Reuse the folder an earlier setup gave the IIS /RT virtual directory, if IIS has one,
:: unless it is under C:\Users (the old script's folder, which is moved instead).
:IisRootFolder
set "iisRoot="
if exist "%windir%\system32\inetsrv\appcmd.exe" for /f "delims=" %%P in ('%windir%\system32\inetsrv\appcmd.exe list vdir "Default Web Site/RT/" /text:physicalPath 2^>nul') do set "iisRoot=%%P"
if defined iisRoot if /I "!iisRoot:~0,9!"=="%SystemDrive%\Users\" set "iisRoot="
if defined iisRoot if exist "!iisRoot!\" (
    set "appFolder=!iisRoot!"
    echo   [ OK  ] Keeping the folder IIS /RT already uses: !appFolder!
)
exit /b 0


:: Ask the operator, suggesting <data drive>\Zeymal.
:AskAppFolder
if defined dataDrive (
    set "suggest=!dataDrive!\Zeymal"
    echo   Suggested drive: !dataDrive! ^(!dataFree! GB free^), not the system drive %SystemDrive%.
) else (
    set "suggest=%SystemDrive%\Zeymal"
    echo   [WARN ] No other NTFS drive with 4 GB free was found, so only %SystemDrive% is left.
)
:AAF_prompt
set "answer="
echo   Zeymal folder. Press Enter for !suggest!, or type another full path:
set /p "answer=  > "
if not defined answer set "answer=!suggest!"
set "answer=!answer:"=!"
if "!answer:~-1!"=="\" set "answer=!answer:~0,-1!"
:: Letters, digits, spaces and _ . - only: other characters break the batch file or appcmd.
set "CHK_PATH=!answer!"
powershell -NoProfile -Command "if ($env:CHK_PATH -match '^[A-Za-z]:\\[A-Za-z0-9 _.\\-]+$' -and (Test-Path -LiteralPath $env:CHK_PATH.Substring(0,3))) { exit 0 } else { exit 1 }"
set "chkRc=!errorlevel!"
set "CHK_PATH="
if !chkRc! neq 0 (
    echo   [ERROR] Type a full path on an existing drive, e.g. D:\Zeymal, using only
    echo           letters, digits, spaces and _ . -
    goto :AAF_prompt
)
if /I "!answer:~0,9!"=="%SystemDrive%\Users\" (
    echo   [ERROR] Not under %SystemDrive%\Users: setup is not sure to be able to write there.
    goto :AAF_prompt
)
if /I "!answer:~0,2!"=="%SystemDrive%" if defined dataDrive (
    choice /c YN /m "  !answer! is on the system drive. Use it anyway"
    if errorlevel 2 goto :AAF_prompt
)
set "appFolder=!answer!"
exit /b 0


:: ============================================================
:: :PrepareFolder <path> [user] - creates the folder, gives the
:: Administrators and SYSTEM full control (by SID, so any Windows
:: language works) and [user] modify rights, then proves setup can
:: write there. A folder setup can't write to stops the run here
:: instead of ending in a half-written download.
:: ============================================================
:PrepareFolder
set "pf_path=%~1"
set "pf_user=%~2"
if not exist "!pf_path!\" (
    mkdir "!pf_path!" >nul 2>&1
    if not exist "!pf_path!\" (
        echo   [ERROR] Could not create: !pf_path!
        exit /b 1
    )
    echo   [ OK  ] Created: !pf_path!
) else (
    echo   [ OK  ] Already exists: !pf_path!
)
icacls "!pf_path!" /grant "*S-1-5-32-544:(OI)(CI)F" "*S-1-5-18:(OI)(CI)F" >nul 2>&1
if defined pf_user icacls "!pf_path!" /grant "!pf_user!:(OI)(CI)M" >nul 2>&1
set "pf_probe=!pf_path!\zeymal-setup-write-test.tmp"
>"!pf_probe!" echo probe
if not exist "!pf_probe!" (
    echo   [ERROR] Setup cannot write to: !pf_path!
    echo           Check the folder's Security tab, or choose another folder.
    exit /b 1
)
del /f /q "!pf_probe!" >nul 2>&1
exit /b 0


:: ============================================================
:: :RegGet <valueName> <varName> / :RegSet <valueName> <data>
:: Read and write setup's state under %setupRegKey%.
:: ============================================================
:RegGet
set "%~2="
for /f "tokens=2,*" %%A in ('reg query "%setupRegKey%" /v "%~1" 2^>nul ^| findstr /C:"REG_"') do set "%~2=%%B"
exit /b 0

:RegSet
reg add "%setupRegKey%" /v "%~1" /t REG_SZ /d "%~2" /f >nul 2>&1
exit /b %errorlevel%


:: ============================================================
:: :CheckDone - what is already in place, so its download is not
:: fetched again (step 7) and can be deleted (cleanup). Sets
:: doneSql, doneSsms, doneJava, doneInstaller and doneBase to 1 or
:: leaves them empty, and oldInstall to the folder of a Zeymal that
:: an earlier setup installed in Program Files on C:.
:: ============================================================
:CheckDone
set "doneSql=" & set "doneSsms=" & set "doneJava=" & set "doneInstaller=" & set "doneBase=" & set "oldInstall="
sc query "MSSQL$SQLEXPRESS" >nul 2>&1 && set "doneSql=1"
call :DetectSsms
if "!SsmsFound!"=="1" set "doneSsms=1"
call :JavaInstalled
if defined javaOk set "doneJava=1"
:: Servers set up before Zeymal went into the app folder run it from Program Files. That
:: install is left where it is: it is neither installed again nor given the base files again.
for %%P in ("%ProgramFiles(x86)%\Zeymal" "%ProgramFiles%\Zeymal") do if exist "%%~P\Zeymal.jar" set "oldInstall=%%~P"
if exist "%appFolder%\Zeymal.jar" set "doneInstaller=1"
if defined oldInstall set "doneInstaller=1"
:: The base is copied once only: copying it again would overwrite the settings and the
:: updated Zeymal.jar of a school that is already using the app.
call :RegGet BaseCopied baseCopied
if "!baseCopied!"=="1" if exist "%appFolder%\Zeymal.jar" set "doneBase=1"
if defined oldInstall set "doneBase=1"
exit /b 0


:: Sets javaOk=1 when JRE 8u271 is installed.
:JavaInstalled
set "javaOk="
reg query "HKLM\SOFTWARE\JavaSoft\Java Runtime Environment\1.8.0_271" /reg:32 >nul 2>&1 && set "javaOk=1"
if exist "%ProgramFiles(x86)%\Java\jre1.8.0_271\bin\java.exe" set "javaOk=1"
if exist "%ProgramFiles%\Java\jre1.8.0_271\bin\java.exe" set "javaOk=1"
exit /b 0


:: Sets SsmsFound=1 when any SSMS is installed.
:DetectSsms
set "SsmsFound=0"

reg query "HKLM\SOFTWARE\Microsoft\Microsoft SQL Server Management Studio" >nul 2>&1
if !errorlevel! equ 0 set "SsmsFound=1"

reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Microsoft SQL Server Management Studio" >nul 2>&1
if !errorlevel! equ 0 set "SsmsFound=1"

for %%D in (17 18 19 20 21) do (
    if exist "%ProgramFiles(x86)%\Microsoft SQL Server Management Studio %%D\Common7\IDE\Ssms.exe" set "SsmsFound=1"
    if exist "%ProgramFiles%\Microsoft SQL Server Management Studio %%D\Common7\IDE\Ssms.exe"      set "SsmsFound=1"
    if exist "%ProgramFiles%\Microsoft SQL Server Management Studio %%D\Release\Common7\IDE\Ssms.exe" set "SsmsFound=1"
)
exit /b 0


:: ============================================================
:: :QueryAshleyDb - sets dbExists to YES or NO, or leaves it empty
:: when SQL Server can't be asked (not installed or running, sqlcmd
:: not found, setup not allowed in). Signs in with %SQLAUTH%:
:: Windows authentication (setup runs as an administrator, and the
:: install makes Administrators sysadmin), or sa once SQL Server is
:: restricted to it.
:: ============================================================
:QueryAshleyDb
set "dbExists="
sc query "MSSQL$SQLEXPRESS" >nul 2>&1 || exit /b 0
call :FindSqlcmd || exit /b 0
set "DB_CHECK=SET NOCOUNT ON; SELECT CASE WHEN DB_ID(N'Ashley') IS NULL THEN 'NO' ELSE 'YES' END"
for /f "usebackq delims=" %%R in (`sqlcmd -S .\SQLEXPRESS %SQLAUTH% -C -h -1 -W -b -Q "%DB_CHECK%" 2^>nul`) do set "dbExists=%%R"
if not defined dbExists for /f "usebackq delims=" %%R in (`sqlcmd -S .\SQLEXPRESS %SQLAUTH% -h -1 -W -b -Q "%DB_CHECK%" 2^>nul`) do set "dbExists=%%R"
set "DB_CHECK="
exit /b 0


:: ============================================================
:: :Discard <path> [<path> ...] - deletes setup downloads (files or
:: folders) that are no longer needed. A zip goes together with its
:: .part and .extracted companions.
:: ============================================================
:Discard
if "%~1"=="" exit /b 0
set "dc_path=%~1"
for %%X in ("" ".part" ".extracted") do (
    set "dc_item=!dc_path!%%~X"
    if exist "!dc_item!\" (
        rd /s /q "!dc_item!" >nul 2>&1
        call :DiscardReport
    ) else if exist "!dc_item!" (
        del /f /q "!dc_item!" >nul 2>&1
        call :DiscardReport
    )
)
shift
goto :Discard

:DiscardReport
if exist "!dc_item!" (
    echo   [WARN ] Could not delete: !dc_item!
) else (
    echo   [CLEAN] Deleted: !dc_item!
)
exit /b 0


:: ============================================================
:: :CleanupDownloads - deletes each download once what it installs
:: is in place. A download whose step did not finish is kept, so the
:: next run reuses it. Also clears what the old script left in
:: C:\Users\RT (only the files it put there); C:\Users\RT\zeymal
:: itself goes once step 12 has moved the school's files out of it.
:: ============================================================
:CleanupDownloads
call :CheckDone
call :QueryAshleyDb

for %%D in ("%DownloadPath%" "%legacyDownloads%") do (
    if defined doneSql  call :Discard "%%~D\SQL2022-SSEI-Expr.exe" "%%~D\SQLMedia" "%%~D\SQLEXPRWT.exe"
    if defined doneSsms call :Discard "%%~D\SSMS-Setup-ENU.exe" "%%~D\SSMS-Setup-17.exe"
)
if defined doneInstaller call :Discard "%DownloadPath%\Zeymal.exe"
for %%D in ("%ZeymalFiles%" "%legacyFiles%") do (
    if defined doneBase      call :Discard "%%~D\(Z_Replace_Base).zip" "%%~D\(Z_Replace_Base)"
    if defined doneJava      call :Discard "%%~D\jre-8u271-windows-i586-iftw.zip" "%%~D\jre_extract"
    if defined doneInstaller call :Discard "%%~D\Zeymal.zip"
    if /i "!dbExists!"=="YES" call :Discard "%%~D\Z_Reset_1034.zip" "%%~D\ashley_restore"
)
:: The old script extracted the base and its installers into C:\Users\RT\zeymal itself.
if defined doneBase      call :Discard "%legacyApp%\(Z_Replace_Base)"
if defined doneInstaller call :Discard "%legacyApp%\Zeymal.exe"
if defined doneJava      call :Discard "%legacyApp%\jre-8u271-windows-i586-iftw.exe"
:: Folders are removed only once empty.
rd "%legacyFiles%" >nul 2>&1
rd "%legacyApp%" >nul 2>&1
rd "%ZeymalFiles%" >nul 2>&1
rd "%DownloadPath%" >nul 2>&1

if exist "%DownloadPath%\" (
    echo   [KEEP ] Kept for the next run, because their steps did not finish:
    for /f "delims=" %%F in ('dir /b "%DownloadPath%" 2^>nul') do if /i not "%%F"=="files" echo             %%F
    for /f "delims=" %%F in ('dir /b "%ZeymalFiles%" 2^>nul') do echo             files\%%F
    set "downloadsState=some kept in %DownloadPath%"
) else (
    echo   [ OK  ] All setup downloads are deleted.
    set "downloadsState=all deleted"
)
exit /b 0


:: ============================================================
:: :Download  -  Generic downloader with progress bar
:: Downloads into <dest>.part and renames it to <dest> only when the
:: transfer ended without an error and has the size the server
:: announced, so <dest> never holds a partial file. Gives up after
:: 5 minutes without data rather than a fixed total time.
:: It reads the response in a plain loop that draws the progress bar
:: itself (the old WebClient event handler could not see its helper
:: functions, so the bar never showed) and whose read timeout ends a
:: stalled transfer.
:: ============================================================
:Download
set "DL_URL=%~1"
set "DL_DEST=%~2"
set "DL_NAME=%~3"
echo.
echo   [Download] !DL_NAME!
echo     From: !DL_URL!
echo     To:   !DL_DEST!
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; function FmtSize($b) { if ($b -ge 1GB) { '{0,7:N2} GB' -f ($b/1GB) } elseif ($b -ge 1MB) { '{0,7:N2} MB' -f ($b/1MB) } elseif ($b -ge 1KB) { '{0,7:N2} KB' -f ($b/1KB) } else { '{0,7} B ' -f [int]$b } }; function FmtTime($s) { if ($s -le 0 -or [double]::IsInfinity($s) -or [double]::IsNaN($s)) { return '--:--' }; $ts = [TimeSpan]::FromSeconds([int]$s); if ($ts.TotalHours -ge 1) { '{0:D2}:{1:D2}:{2:D2}' -f [int]$ts.TotalHours,$ts.Minutes,$ts.Seconds } else { '{0:D2}:{1:D2}' -f $ts.Minutes,$ts.Seconds } }; function Draw($r, $t, $start) { $el = ((Get-Date) - $start).TotalSeconds; $p = if ($t -gt 0) { [int][math]::Floor(100.0 * $r / $t) } else { 0 }; $spd = if ($el -gt 0) { $r / $el } else { 0 }; $eta = if ($spd -gt 0 -and $t -gt 0) { ($t - $r) / $spd } else { 0 }; $bw = 30; $fill = [int][math]::Floor(($p / 100.0) * $bw); if ($fill -gt $bw) { $fill = $bw }; if ($fill -lt 0) { $fill = 0 }; if ($fill -eq $bw) { $bar = '=' * $bw } else { $bar = ('=' * $fill) + '>' + (' ' * ($bw - $fill - 1)) }; Write-Host -NoNewline (\"`r    [{0}] {1,3}%% {2} / {3}  {4}/s  ETA {5}   \" -f $bar,$p,(FmtSize $r),(FmtSize $t),(FmtSize $spd),(FmtTime $eta)) }; $dest = $env:DL_DEST; $part = $dest + '.part'; Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue; $start = Get-Date; $drawn = [datetime]::MinValue; $r = 0; $t = -1; $rs = $null; $in = $null; $out = $null; try { $rq = [Net.WebRequest]::Create($env:DL_URL); $rq.Timeout = 60000; $rq.ReadWriteTimeout = 300000; $rs = $rq.GetResponse(); $t = $rs.ContentLength; $in = $rs.GetResponseStream(); $out = [IO.File]::Create($part); $buf = New-Object byte[] 65536; while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) { $out.Write($buf, 0, $n); $r += $n; if (((Get-Date) - $drawn).TotalMilliseconds -ge 250) { $drawn = Get-Date; Draw $r $t $start } }; $out.Close(); $out = $null; if ($t -gt 0 -and $r -ne $t) { throw ('only {0} of {1} bytes arrived' -f $r, $t) }; Draw $r $t $start; Write-Host '' } catch { Write-Host ''; $x = $_.Exception; while ($x.InnerException) { $x = $x.InnerException }; Write-Host ('    Download failed: ' + $x.Message); if ($out) { $out.Close() }; Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue; exit 1 } finally { if ($in) { $in.Close() }; if ($rs) { $rs.Close() } }; Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue; Move-Item -LiteralPath $part -Destination $dest; $secs = ((Get-Date) - $start).TotalSeconds; Write-Host (\"    Done. Saved {0} in {1}.\" -f (FmtSize $r).Trim(),(FmtTime $secs)); exit 0 }"
set "rc=!errorlevel!"
set "DL_URL="
set "DL_DEST="
set "DL_NAME="
exit /b %rc%


:: ============================================================
:: :RunWithProgress - runs a silent installer/downloader while
:: printing a live "[hh:mm:ss] <label> - still running..." line
:: instead of leaving the console looking frozen for several
:: minutes (the old behaviour for SQL Server/SSMS/Java installs).
::
:: Expects, set by the caller before the call:
::   RP_EXE       - program to run
::   RP_ARGS      - its argument string (may be empty)
::   RP_LABEL     - text shown next to the elapsed time
::   RP_WATCHDIR  - optional folder to watch; while set, the line
::                  shows live downloaded bytes and speed instead
::                  of just "still running" (used for the SQL
::                  Server media download, which writes into it)
:: Returns the launched program's own exit code.
:: ============================================================
:RunWithProgress
powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand %RunProgressB64%
set "rc=!errorlevel!"
set "RP_EXE=" & set "RP_ARGS=" & set "RP_LABEL=" & set "RP_WATCHDIR="
exit /b %rc%


:: ============================================================
:: SQL Server 2022 Express + SSMS  (Windows 10/11)
:: ============================================================
:InstallSqlModern
echo   --- SQL Server 2022 Express ---

:: Which SQL Server the SQLEXPRESS instance is, if there is one: MSSQL16 = 2022, MSSQL17 = 2025.
:: Microsoft's "SQL Server 2022 Express" link now gives SQL Server 2025, whose setup fails here
:: on PolyBase ("Cannot find the user '<PC>\PdwComputeNodeAccess'") and brings Azure and AI
:: features. Setup installs 2022 only, engine only, and stops on what an earlier attempt left.
set "sqlInstId="
for /f "tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL" /v SQLEXPRESS 2^>nul ^| findstr /C:"REG_"') do set "sqlInstId=%%B"
set "sqlInstVer=0"
if defined sqlInstId set "sqlInstVer=!sqlInstId:~5,2!"
:: A newer SQL Server that already holds the school's database is kept; one without it is most
:: likely the failed attempt, so setup stops and asks for it to be removed.
if !sqlInstVer! GEQ 17 (
    call :QueryAshleyDb
    if /i "!dbExists!"=="YES" (
        echo   [WARN ] SQLEXPRESS is a newer SQL Server than 2022 ^(!sqlInstId!^). It holds the
        echo           Ashley database, so it is kept. Skipping engine install.
        exit /b 0
    )
    echo   [ERROR] SQLEXPRESS is a newer SQL Server than 2022 ^(!sqlInstId!^), probably left by an
    echo           earlier attempt, and it has no Ashley database. Setup installs SQL Server 2022
    echo           only. Uninstall it first: Settings ^> Apps ^> Installed apps, every "Microsoft
    echo           SQL Server 2025" entry. Restart Windows, then run setup.bat again.
    echo           If it holds other databases you need, back them up before uninstalling.
    exit /b 1
)
sc query "MSSQL$SQLEXPRESS" >nul 2>&1
if !errorlevel! equ 0 (
    echo   [ OK  ] SQLEXPRESS instance already installed. Skipping engine install.
    exit /b 0
)
if defined sqlInstId (
    echo   [ERROR] An unfinished SQL Server install ^(!sqlInstId!^) is left by an earlier attempt.
    echo           Uninstall it first: Settings ^> Apps ^> Installed apps, the "Microsoft SQL
    echo           Server" entries. Restart Windows, then run setup.bat again.
    exit /b 1
)

set "SqlBootstrap=%DownloadPath%\SQL2022-SSEI-Expr.exe"
set "SqlMediaDir=%DownloadPath%\SQLMedia"
set "SqlMediaFile=%SqlMediaDir%\SQLEXPR_x64_ENU.exe"
set "SqlSetupDir=%SqlMediaDir%\extract"

echo   Step 1/3: Fetching SQL Server 2022 Express bootstrapper...
call :FetchSql2022Bootstrap "https://download.microsoft.com/download/29654887-7cde-4397-bba3-d7f087970845/SQL2022-SSEI-Expr.exe"
if !errorlevel! neq 0 call :FetchSql2022Bootstrap "https://go.microsoft.com/fwlink/p/?linkid=2215160"
if !errorlevel! neq 0 (
    echo   [ERROR] Could not get the SQL Server 2022 Express bootstrapper from Microsoft.
    echo           Download SQL Server 2022 Express ^(SQL2022-SSEI-Expr.exe^), save it as
    echo             %SqlBootstrap%
    echo           and run setup.bat again.
    exit /b 1
)

if not exist "%SqlMediaDir%" mkdir "%SqlMediaDir%"

:: Media an earlier attempt left here is reused only if it is SQL Server 2022.
if exist "%SqlMediaFile%" (
    call :SqlExeCheck "%SqlMediaFile%" 0
    if !errorlevel! neq 0 (
        echo   [WARN ] The SQL Server media already here is not SQL Server 2022 ^(version !sqlExeMajor!^).
        call :Discard "%SqlMediaDir%"
        mkdir "%SqlMediaDir%" >nul 2>&1
    )
)

if exist "%SqlMediaFile%" (
    echo   [ OK  ] Media package already present. Skipping media download.
) else (
    echo.
    echo   Step 2/3: Downloading full SQL Server media ^(~280 MB^)...
    echo           This can take 5-15 minutes on a home connection. Please wait.
    echo           Do NOT close this window.
    set "RP_EXE=%SqlBootstrap%"
    set "RP_ARGS=/ACTION=Download /MEDIAPATH="%SqlMediaDir%" /MEDIATYPE=Core /LANGUAGE=en-US /QUIET"
    set "RP_LABEL=Downloading SQL Server 2022 Express media"
    set "RP_WATCHDIR=%SqlMediaDir%"
    call :RunWithProgress
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
    call :SqlExeCheck "%SqlMediaFile%" 0
    if !errorlevel! neq 0 (
        echo   [ERROR] The downloaded media is not SQL Server 2022 ^(version !sqlExeMajor!, !sqlExeVerdict!^).
        call :Discard "%SqlMediaDir%"
        exit /b 1
    )
    echo   [ OK  ] Media package downloaded.
)

echo.
echo   Step 3/3: Extracting media and running silent install...
:: Extract into an empty folder: files of another version left there would mix with these.
if exist "%SqlSetupDir%\" rd /s /q "%SqlSetupDir%" >nul 2>&1
mkdir "%SqlSetupDir%" >nul 2>&1
:: Media that won't extract is most likely an interrupted download. It is deleted, otherwise
:: every later run would find it, skip the download and fail here again.
start "SQL Server Media Extract" /wait "%SqlMediaFile%" /X:"%SqlSetupDir%" /Q
if !errorlevel! neq 0 (
    echo   [ERROR] Failed to extract SQL Server media.
    call :Discard "%SqlMediaDir%"
    echo           The media was deleted; the next run downloads it again.
    exit /b 1
)
if not exist "%SqlSetupDir%\setup.exe" (
    echo   [ERROR] setup.exe not found after extraction:
    echo           %SqlSetupDir%\setup.exe
    call :Discard "%SqlMediaDir%"
    echo           The media was deleted; the next run downloads it again.
    exit /b 1
)
call :SqlExeCheck "%SqlSetupDir%\setup.exe" 0
if !errorlevel! neq 0 (
    echo   [ERROR] This setup.exe is not SQL Server 2022 ^(version !sqlExeMajor!, !sqlExeVerdict!^).
    call :Discard "%SqlMediaDir%"
    echo           The media was deleted; the next run downloads it again.
    exit /b 1
)

:: Engine only: no PolyBase, full-text, replication, Azure extension or anything else.
echo   Running SQL Server setup ^(this can take several minutes^)...
echo   Do NOT close this window.
set "RP_EXE=%SqlSetupDir%\setup.exe"
set "RP_ARGS=/Q /IACCEPTSQLSERVERLICENSETERMS /ACTION=INSTALL /FEATURES=SQLENGINE /INSTANCENAME=SQLEXPRESS /SQLSVCACCOUNT="NT Service\MSSQL$SQLEXPRESS" /SQLSYSADMINACCOUNTS="BUILTIN\ADMINISTRATORS" /SECURITYMODE=SQL /SAPWD="%sqlSaPassword%" /TCPENABLED=1 /NPENABLED=1 /UPDATEENABLED=False"
set "RP_LABEL=Installing SQL Server 2022 Express engine"
set "RP_WATCHDIR="
call :RunWithProgress
set "SqlSetupExit=!errorlevel!"
echo   SQL Server setup exit code: !SqlSetupExit!

if !SqlSetupExit! neq 0 (
    echo   [ERROR] SQL Server installation reported an error.
    echo           Check setup logs at:
    echo           %ProgramFiles%\Microsoft SQL Server\160\Setup Bootstrap\Log
    exit /b 1
)
echo   [ OK  ] SQL Server 2022 Express installed successfully.
exit /b 0


:: Gets the SQL Server 2022 Express bootstrapper from <url>, unless a good one is already here.
:: What is not a Microsoft-signed SQL Server 2022 file is deleted (the link may move to 2025).
:FetchSql2022Bootstrap
if exist "%SqlBootstrap%" (
    call :SqlExeCheck "%SqlBootstrap%" 1
    if !errorlevel! equ 0 (
        echo   [ OK  ] SQL Server 2022 Express bootstrapper already downloaded.
        exit /b 0
    )
    del /f /q "%SqlBootstrap%" >nul 2>&1
)
call :Download "%~1" "%SqlBootstrap%" "SQL Server 2022 Express bootstrapper"
if !errorlevel! neq 0 exit /b 1
call :SqlExeCheck "%SqlBootstrap%" 1
if !errorlevel! equ 0 exit /b 0
echo   [WARN ] That link did not give the SQL Server 2022 installer ^(version !sqlExeMajor!, !sqlExeVerdict!^).
del /f /q "%SqlBootstrap%" >nul 2>&1
exit /b 1


:: ============================================================
:: :SqlExeCheck <file> <strict 0/1> - returns 0 when <file> is
:: signed by Microsoft and is SQL Server 2022 (product version 16).
:: Not strict: a file without version information is accepted too.
:: Sets sqlExeMajor and sqlExeVerdict (ok, version or unsigned).
:: ============================================================
:SqlExeCheck
set "SX_PATH=%~1"
set "SX_STRICT=%~2"
set "sqlExeMajor=?"
set "sqlExeVerdict=unreadable"
for /f "tokens=1,2" %%A in ('powershell -NoProfile -Command "$f = $env:SX_PATH; $s = $null; $m = 0; try { $s = Get-AuthenticodeSignature -LiteralPath $f; $m = (Get-Item -LiteralPath $f).VersionInfo.ProductMajorPart } catch {}; if (-not $s -or $s.Status -ne 'Valid' -or $s.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') { $v = 'unsigned' } elseif ($m -eq 16 -or ($m -eq 0 -and $env:SX_STRICT -ne '1')) { $v = 'ok' } else { $v = 'version' }; Write-Output ('{0} {1}' -f $m, $v)"') do (
    set "sqlExeMajor=%%A"
    set "sqlExeVerdict=%%B"
)
set "SX_PATH="
set "SX_STRICT="
if "!sqlExeVerdict!"=="ok" exit /b 0
exit /b 1


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

echo   Running SQL Server setup ^(this can take several minutes^)...
echo   Do NOT close this window.
set "RP_EXE=%SqlLegacyInstaller%"
set "RP_ARGS=/Q /IACCEPTSQLSERVERLICENSETERMS /ACTION=INSTALL /FEATURES=SQLENGINE /INSTANCENAME=SQLEXPRESS /SQLSVCACCOUNT="NT AUTHORITY\Network Service" /SQLSYSADMINACCOUNTS="BUILTIN\ADMINISTRATORS" /SECURITYMODE=SQL /SAPWD="%sqlSaPassword%" /TCPENABLED=1"
set "RP_LABEL=Installing SQL Server 2014 Express engine"
set "RP_WATCHDIR="
call :RunWithProgress
set "SqlLegacyExit=!errorlevel!"
echo   SQL Server setup exit code: !SqlLegacyExit!

if !SqlLegacyExit! neq 0 (
    echo   [ERROR] SQL Server installation reported an error. Check the setup logs.
    exit /b 1
)
echo   [ OK  ] SQL Server 2014 Express installed successfully.
exit /b 0


:: ============================================================
:: Install SSMS - modern (Win10/11) or legacy 17.9.1 (Win7/8)
:: ============================================================
:InstallSSMS
echo.
echo   --- SQL Server Management Studio (SSMS) ---

call :DetectSsms
if "!SsmsFound!"=="1" (
    echo   [ OK  ] SSMS is already installed. Skipping.
    exit /b 0
)

echo %windowsName% | findstr /I /C:"Windows 10" /C:"Windows 11" >nul
if not errorlevel 1 (
    set "SsmsUrl=https://aka.ms/ssmsfullsetup"
    set "SsmsInstaller=%DownloadPath%\SSMS-Setup-ENU.exe"
    echo   Downloading SSMS ^(latest^)...
) else (
    set "SsmsUrl=https://go.microsoft.com/fwlink/?linkid=2043154&clcid=0x409"
    set "SsmsInstaller=%DownloadPath%\SSMS-Setup-17.exe"
    echo   Downloading SSMS 17.9.1 ^(last version supporting Windows 7/8^)...
)

call :Download "!SsmsUrl!" "!SsmsInstaller!" "SSMS"
if !errorlevel! neq 0 (
    echo   [WARN ] Failed to download SSMS.
    echo           Install it manually from: !SsmsUrl!
    call :ackWarn
    exit /b 0
)

echo   Installing SSMS ^(this can take several minutes^)...
echo   Do NOT close this window.
set "RP_EXE=!SsmsInstaller!"
set "RP_ARGS=/install /quiet /norestart"
set "RP_LABEL=Installing SQL Server Management Studio"
set "RP_WATCHDIR="
call :RunWithProgress
if !errorlevel! neq 0 (
    echo   [WARN ] SSMS installation reported an error. You can install it manually later.
    call :ackWarn
) else (
    echo   [ OK  ] SSMS installed successfully.
)
exit /b 0


:: ============================================================
:: Download the Zeymal application files (with real filenames)
:: ============================================================
:DownloadZeymalFiles
set "ZeymalBaseUrl=https://zml-installer.blr1.digitaloceanspaces.com/"


set "ZeymalRplaceXip=%ZeymalBaseUrl%(Z_Replace_Base).zip"
set "ZeymalIftwInstaller=%ZeymalBaseUrl%jre-8u271-windows-i586-iftw.zip"
set "Zeymalexe=%ZeymalBaseUrl%Zeymal.zip"
set "ZeymalResetxip=%ZeymalBaseUrl%Z_Reset_1034.zip"

:: What an earlier run already installed is not downloaded again (its download was deleted).
call :CheckDone
call :QueryAshleyDb
set "skipBase=" & set "skipJava=" & set "skipExe=" & set "skipReset="
if defined doneBase      set "skipBase=its files are already in place"
if defined doneJava      set "skipJava=Java 8u271 is already installed"
if defined doneInstaller set "skipExe=Zeymal is already installed"
if /i "!dbExists!"=="YES" set "skipReset=the Ashley database already exists"

echo   Checking existing files ^(each is verified against the server before it is reused^)...
echo   Target folder: %ZeymalFiles%
for %%F in ("(Z_Replace_Base).zip" "jre-8u271-windows-i586-iftw.zip" "Zeymal.zip" "Z_Reset_1034.zip") do (
    if exist "%ZeymalFiles%\%%~F" (
        for %%A in ("%ZeymalFiles%\%%~F") do echo     [FOUND] %%~F  ^(%%~zA bytes^)
    ) else (
        echo     [MISS ] %%~F  ^(will download^)
    )
)

call :DownloadZeymalItem "ZeymalRplaceXip"     "(Z_Replace_Base).zip"            1 4 "!skipBase!"
if !errorlevel! neq 0 exit /b 1
call :DownloadZeymalItem "ZeymalIftwInstaller" "jre-8u271-windows-i586-iftw.zip" 2 4 "!skipJava!"
if !errorlevel! neq 0 exit /b 1
call :DownloadZeymalItem "Zeymalexe"           "Zeymal.zip"                      3 4 "!skipExe!"
if !errorlevel! neq 0 exit /b 1
call :DownloadZeymalItem "ZeymalResetxip"      "Z_Reset_1034.zip"                4 4 "!skipReset!"
if !errorlevel! neq 0 exit /b 1

echo   [ OK  ] All Zeymal files downloaded successfully.
exit /b 0


:: ============================================================
:: :DownloadZeymalItem <urlVarName> <destFileName> <idx> <total> [skipReason]
:: Downloads a single Zeymal asset with full validation:
::   - not at all when [skipReason] says what it installs is in place
::   - checks inputs, URL variable is set, target folder exists
::   - reuses an existing copy only if :VerifyDownload passes (an
::     interrupted run can leave a partial file); a copy the old
::     script left in C:\Users\RT\zeymal\files is moved here first
::   - downloads into <name>.part and renames it only once verified,
::     so a file with the real name is always complete; curl resumes
::     a .part left by a dropped connection
::   - prefers curl.exe; falls back to PowerShell WebClient
::   - retries up to 3 times on failure
:: ============================================================
:DownloadZeymalItem
set "varName=%~1"
set "fileName=%~2"
set "idx=%~3"
set "total=%~4"
set "skipWhy=%~5"
set "fileUrl=!%varName%!"
set "fileDest=%ZeymalFiles%\%fileName%"
set "filePart=!fileDest!.part"

echo.
echo   [File %idx%/%total%] %fileName%

if defined skipWhy (
    echo     [ OK  ] Not needed: !skipWhy!.
    exit /b 0
)

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

:: --- Pick a downloader (curl preferred, PowerShell fallback) ----------
set "haveCurl=0"
where curl.exe >nul 2>&1
if !errorlevel! equ 0 set "haveCurl=1"

set "attempt=0"
set "maxAttempts=3"

:: --- The old script downloaded into C:\Users\RT\zeymal\files: move its copy rather than download again
if not exist "!fileDest!" if exist "%legacyFiles%\!fileName!" (
    echo     Moving the copy left in %legacyFiles% ...
    move /y "%legacyFiles%\!fileName!" "!fileDest!" >nul 2>&1
)

:: --- Reuse an existing copy only if it verifies ---------------------
if exist "!fileDest!" (
    call :VerifyDownload "!fileDest!" "!fileUrl!"
    if !errorlevel! equ 0 (
        echo     [ OK  ] Already downloaded and verified. Skipping.
        echo            !fileDest!
        exit /b 0
    )
    echo     [WARN ] The existing copy is incomplete or damaged. Downloading it again.
    del /f /q "!fileDest!" >nul 2>&1
)
if exist "!filePart!" (
    call :VerifyDownload "!filePart!" "!fileUrl!"
    if !errorlevel! equ 0 goto :DZI_accept
    echo     A partial download was left by an earlier attempt; resuming it.
)

:DZI_retry
set /a attempt+=1
echo     Attempt !attempt!/%maxAttempts% ...

if "!haveCurl!"=="1" (
    curl.exe -L --fail --show-error --connect-timeout 30 --speed-limit 1024 --speed-time 120 -C - -o "!filePart!" "!fileUrl!"
    set "dlRc=!errorlevel!"
) else (
    del /f /q "!filePart!" >nul 2>&1
    set "DL_URL=!fileUrl!"
    set "DL_DEST=!filePart!"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object System.Net.WebClient).DownloadFile($env:DL_URL, $env:DL_DEST); exit 0 } catch { Write-Host ('     [ERROR] ' + $_.Exception.Message); exit 1 }"
    set "dlRc=!errorlevel!"
    set "DL_URL="
    set "DL_DEST="
)

:: A dropped connection keeps the .part for curl to resume. It is deleted when the server
:: refused the request or the resume (curl 22, 33, 36) or the file could not be written (23).
if !dlRc! neq 0 (
    echo     [ERROR] Downloader exited with code !dlRc!.
    for %%C in (22 23 33 36) do if !dlRc! equ %%C del /f /q "!filePart!" >nul 2>&1
    if !dlRc! equ 23 echo             The file could not be written: check free space on !DownloadPath:~0,2!
    goto :DZI_check_retry
)

call :VerifyDownload "!filePart!" "!fileUrl!"
if !errorlevel! neq 0 (
    echo     [ERROR] The download did not verify. Deleting it.
    del /f /q "!filePart!" >nul 2>&1
    goto :DZI_check_retry
)

:DZI_accept
:: A new copy must be extracted again, so drop the old one's marker.
del /f /q "!fileDest!.extracted" >nul 2>&1
move /y "!filePart!" "!fileDest!" >nul 2>&1
if not exist "!fileDest!" (
    echo     [ERROR] Could not rename the download to !fileName!.
    goto :DZI_check_retry
)
set "dlSize=0"
for %%A in ("!fileDest!") do set "dlSize=%%~zA"
echo     [ OK  ] Saved and verified !dlSize! bytes: !fileDest!
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
:: :VerifyDownload <file> <url> - returns 0 when <file> is a whole,
:: undamaged copy of <url>:
::   - at least 10 KB (not an error page)
::   - the size the server reports (Content-Length)
::   - the MD5 the server reports: DigitalOcean Spaces, like S3,
::     sends a file's MD5 as its ETag when it was uploaded in one
::     part (a multipart ETag has a "-" and is not checked)
::   - a .zip opens as a ZIP archive
:: When the server can't be reached, only the file itself is checked.
:: ============================================================
:VerifyDownload
set "VF_PATH=%~1"
set "VF_URL=%~2"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p = $env:VF_PATH; try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}; if (-not (Test-Path -LiteralPath $p)) { exit 1 }; $len = (Get-Item -LiteralPath $p).Length; if ($len -lt 10240) { Write-Host ('     [CHECK] Only {0} bytes.' -f $len); exit 1 }; $size = -1; $etag = ''; try { $rq = [Net.WebRequest]::Create($env:VF_URL); $rq.Method = 'HEAD'; $rq.Timeout = 30000; $rs = $rq.GetResponse(); $size = $rs.ContentLength; $etag = ([string]$rs.Headers['ETag']).Trim([char]34); $rs.Close() } catch { Write-Host '     [CHECK] Server not reachable; checking the file alone.' }; if ($size -gt 0 -and $len -ne $size) { Write-Host ('     [CHECK] {0} of {1} bytes.' -f $len, $size); exit 1 }; if ($etag -match '^[0-9a-fA-F]{32}$') { $md5 = $null; try { $fs = [IO.File]::OpenRead($p); try { $md5 = -join ([Security.Cryptography.MD5]::Create().ComputeHash($fs) | ForEach-Object { $_.ToString('x2') }) } finally { $fs.Dispose() } } catch {}; if ($md5 -and $md5 -ne $etag.ToLower()) { Write-Host '     [CHECK] Checksum differs from the server copy.'; exit 1 } }; if ($p -match '\.zip(\.part)?$') { try { Add-Type -AssemblyName System.IO.Compression.FileSystem; $z = [IO.Compression.ZipFile]::OpenRead($p); $n = $z.Entries.Count; $z.Dispose(); if ($n -lt 1) { throw 'empty' } } catch { Write-Host '     [CHECK] Not a valid ZIP archive.'; exit 1 } }; exit 0"
set "vfRc=!errorlevel!"
set "VF_PATH="
set "VF_URL="
exit /b %vfRc%


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

call :JavaInstalled
if defined javaOk (
    echo   [ OK  ] Java JRE 8u271 is already installed. Skipping.
    exit /b 0
)

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

echo   Installing Java (auto-update disabled)...
set "RP_EXE=%JavaInstaller%"
set "RP_ARGS=/s AUTO_UPDATE=Disable STATIC=1 REBOOT=Disable EULA=Disable NOSTARTMENU=Enable WEB_ANALYTICS=Disable"
set "RP_LABEL=Installing Java JRE 8u271"
set "RP_WATCHDIR="
call :RunWithProgress
set "javaInstallRc=!errorlevel!"
if !javaInstallRc! neq 0 (
    echo   [WARN ] Java installer exit code !javaInstallRc!.
    exit /b 1
)
echo   [ OK  ] Java JRE 8u271 installed successfully.
exit /b 0




:: ============================================================
:: Deploy Zeymal files: extract (Z_Replace_Base).zip (step 9.5
:: copies it into the app folder) and Zeymal.zip (the Zeymal.exe
:: installer) into the downloads folder.
:: ============================================================
:DeployZeymalFiles
call :CheckDone

if defined doneBase (
    echo   [ OK  ] The base files are already in place. Skipping.
) else (
    call :ExtractZip "%ZeymalFiles%\(Z_Replace_Base).zip" "%ZeymalFiles%" "(Z_Replace_Base).zip"
    if !errorlevel! neq 0 call :ackWarn
)

if defined doneInstaller (
    echo   [ OK  ] Zeymal is already installed. Skipping its installer.
) else (
    if not exist "%DownloadPath%\Zeymal.exe" del /f /q "%ZeymalFiles%\Zeymal.zip.extracted" >nul 2>&1
    call :ExtractZip "%ZeymalFiles%\Zeymal.zip" "%DownloadPath%" "Zeymal.zip"
    if !errorlevel! neq 0 call :ackWarn
)
exit /b 0


:: ============================================================
:: :RunZeymalInstaller - asks the operator to run Zeymal.exe and to
:: install into the app folder, unless Zeymal is already installed.
:: An install that lands in Program Files on C: instead is caught,
:: and the operator is asked to install it again into the app folder.
:: ============================================================
:RunZeymalInstaller
call :CheckDone
if defined oldInstall (
    echo   [ OK  ] Zeymal is already installed in !oldInstall!. Not installed again.
    echo.
    exit /b 0
)
if defined doneInstaller (
    echo   [ OK  ] Zeymal is already installed in !appFolder!. Not installed again.
    echo.
    exit /b 0
)
set "pf86=%ProgramFiles(x86)%\Zeymal"
set "pf64=%ProgramFiles%\Zeymal"
set "had86=" & set "had64="
if exist "!pf86!\" set "had86=1"
if exist "!pf64!\" set "had64=1"

echo ============================================================
echo.
echo   ACTION REQUIRED: Install the Zeymal application
echo.
echo   The Zeymal installer is located here:
echo.
echo     %DownloadPath%\Zeymal.exe
echo.
echo   Run it now. When it asks where to install, choose this folder
echo   ^(not a C:\Program Files folder it may suggest^):
echo.
echo     %appFolder%
echo.
echo   When you are done, press any key to continue setup.
echo.
echo ============================================================
echo.
pause >nul
:RZI_check
set "wrongDir="
if not defined had86 if exist "!pf86!\" set "wrongDir=!pf86!"
if not defined had64 if exist "!pf64!\" set "wrongDir=!pf64!"
if not defined wrongDir (
    echo.
    exit /b 0
)
echo   [WARN ] Zeymal was installed in !wrongDir!, on the system drive.
echo           Uninstall it ^(Control Panel ^> Programs^), run Zeymal.exe again and
echo           choose !appFolder!.
choice /c RC /m "  R = check again after reinstalling, C = continue anyway"
if errorlevel 2 (
    echo.
    exit /b 0
)
goto :RZI_check


:: ============================================================
:: :CopyBaseFiles - copies the extracted (Z_Replace_Base) over the
:: Zeymal installed in the app folder. Once only.
:: ============================================================
:CopyBaseFiles
echo.
echo ============================================================
echo [9.5/13] Copying the base files
echo ============================================================

set "sourceFolder=%ZeymalFiles%\(Z_Replace_Base)"
set "destFolder=%appFolder%"

echo.
echo Source Folder      : "%sourceFolder%"
echo Destination Folder : "%destFolder%"
echo.

:: Once only: a second copy would overwrite the settings and any updated Zeymal.jar.
call :CheckDone
if defined oldInstall (
    echo   [ OK  ] Zeymal runs from !oldInstall!, installed by an earlier setup.
    echo           It is left as it is: the base files are not copied again.
    exit /b 0
)
if defined doneBase (
    echo   [ OK  ] Copied on an earlier run. Not copied again, so the settings and
    echo           updates already in the app folder are kept.
    exit /b 0
)

echo Checking source folder...
if exist "%sourceFolder%" (
    echo   [OK] Source folder exists.
) else (
    echo   [ERROR] Source folder DOES NOT EXIST!
    dir "%sourceFolder%" 2>nul
    pause
    exit /b 1
)

echo.
echo Listing source folder...
dir "%sourceFolder%"
echo.

echo ============================================================
echo Starting ROBOCOPY...
echo ============================================================
echo robocopy "%sourceFolder%" "%destFolder%" /E /COPY:DAT /R:2 /W:2
echo.

robocopy "%sourceFolder%" "%destFolder%" /E /COPY:DAT /R:2 /W:2

set "RC=%ERRORLEVEL%"

echo.
echo ============================================================
echo ROBOCOPY FINISHED
echo ============================================================
echo Robocopy Exit Code : %RC%
echo.

:: Robocopy exit codes 8 and above mean some files were not copied.
if %RC% GEQ 8 (
    echo [ERROR] Robocopy could not copy every file. The downloaded base files are kept
    echo         so the next run can copy them again.
    echo ============================================================
    pause
    exit /b 1
)
call :RegSet BaseCopied 1

echo [SUCCESS] Copy and registration completed successfully.
echo ============================================================
pause
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

echo   Adding Windows Firewall inbound rule for SQL Server TCP 1433...
netsh advfirewall firewall delete rule name="SQL Server TCP 1433" >nul 2>&1
netsh advfirewall firewall add rule name="SQL Server TCP 1433" protocol=TCP dir=in localport=1433 action=allow
if !errorlevel! neq 0 (
    echo   [WARN ] Failed to add firewall rule. Add it manually in Windows Firewall.
    call :ackWarn
) else (
    echo   [ OK  ] Firewall rule added: TCP inbound port 1433.
)

echo   Stopping SQL Server service to apply Log On changes...
net stop "MSSQL$SQLEXPRESS" >nul 2>&1

echo   Setting SQL Server service Log On to Local System...
sc config "MSSQL$SQLEXPRESS" obj= "LocalSystem" password= ""
if !errorlevel! neq 0 (
    echo   [WARN ] Failed to set service Log On to Local System. Check services.msc manually.
    call :ackWarn
) else (
    echo   [ OK  ] Service Log On set to Local System.
)

echo   Starting SQL Server service...
net start "MSSQL$SQLEXPRESS"
if !errorlevel! neq 0 (
    echo   [WARN ] Failed to start MSSQL$SQLEXPRESS. Start it manually via services.msc.
    call :ackWarn
) else (
    echo   [ OK  ] SQL Server started.
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

:: A server set up by the old script keeps the school's files in C:\Users\RT\zeymal. They move
:: to the app folder now, right before IIS and FTP are pointed there. If the move fails, IIS
:: and FTP are left on the old folder so nothing goes missing; the next run tries again.
if exist "%legacyApp%\" (
    call :MoveOldAppFolder
    if !errorlevel! neq 0 (
        call :ackWarn
        exit /b 0
    )
)

echo   Creating virtual directory "RT" under Default Web Site...
"%appcmd%" delete vdir "Default Web Site/RT" >nul 2>&1
"%appcmd%" add vdir /app.name:"Default Web Site/" /path:"/RT" /physicalPath:"%appFolder%" /userName:"%newUser%" /password:"%newPassword%"
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
    "%appcmd%" set config -section:system.ftpServer/security/authorization /+"[accessType='Allow',users='%newUser%',permissions='Read,Write']" /commit:apphost >nul 2>&1
    "%appcmd%" set vdir "RT/" /userName:"%newUser%" /password:"%newPassword%" >nul 2>&1
    echo   [ OK  ] FTP site created and secured for user "%newUser%".
)

echo   Restarting Default Web Site and FTP site "RT"...
"%appcmd%" stop  site "Default Web Site" >nul 2>&1
"%appcmd%" start site "Default Web Site" >nul 2>&1
"%appcmd%" stop  site "RT" >nul 2>&1
"%appcmd%" start site "RT" >nul 2>&1
echo   [ OK  ] IIS sites restarted.

echo   Allowing FTP Server through Windows Firewall...
netsh advfirewall firewall set rule group="FTP Server" new enable=yes >nul 2>&1
netsh advfirewall firewall delete rule name="IIS FTP Server (TCP 21)" >nul 2>&1
netsh advfirewall firewall add rule name="IIS FTP Server (TCP 21)" protocol=TCP dir=in localport=21 action=allow
if !errorlevel! neq 0 (
    echo   [WARN ] Failed to add FTP firewall rule. Add it manually in Windows Firewall.
    call :ackWarn
) else (
    echo   [ OK  ] Firewall: FTP Server program group enabled, TCP inbound port 21 allowed.
)
exit /b 0


:: ============================================================
:: :MoveOldAppFolder - moves the school's files (photos, documents,
:: plugins...) from the old script's C:\Users\RT\zeymal into the app
:: folder. The FTP site is stopped first, so nothing is written there
:: during the move. Setup's own leftovers (files\, the extracted
:: base, Zeymal.exe, the Java installer) are not moved: the cleanup
:: deletes them. Returns 1 when some files could not be moved.
:: ============================================================
:MoveOldAppFolder
echo   Moving the school's files from %legacyApp% to %appFolder% ...
"%appcmd%" stop site "RT" >nul 2>&1
robocopy "%legacyApp%" "%appFolder%" /E /MOVE /COPY:DAT /R:2 /W:2 /NP /NFL /NDL /XD "%legacyFiles%" "%legacyApp%\(Z_Replace_Base)" /XF "%legacyApp%\Zeymal.exe" "%legacyApp%\jre-8u271-windows-i586-iftw.exe"
set "mvRc=!errorlevel!"
if !mvRc! GEQ 8 (
    echo   [ERROR] Some files could not be moved ^(robocopy exit !mvRc!^). IIS and FTP still
    echo           use %legacyApp%. Close whatever holds those files, then run setup.bat again.
    "%appcmd%" start site "RT" >nul 2>&1
    exit /b 1
)
echo   [ OK  ] Moved. %legacyApp% keeps only setup's leftovers, deleted at the end.
exit /b 0


:: ============================================================
:: Restore the Ashley database from Z_Reset*.zip
:: ============================================================
:RestoreAshleyDb
set "resetZip=%ZeymalFiles%\Z_Reset_1034.zip"
set "restoreDir=%ZeymalFiles%\ashley_restore"

sc query "MSSQL$SQLEXPRESS" >nul 2>&1
if !errorlevel! neq 0 (
    echo   [SKIP ] MSSQL$SQLEXPRESS not installed; skipping DB restore.
    exit /b 0
)

:: Never overwrite a school's data. setup.bat is meant to be run again after a reboot, and step 13
:: runs every time, so an existing [Ashley] database is left exactly as it is. If the check itself
:: gets no answer, nothing is restored either (below): better to stop than to guess.
call :QueryAshleyDb
if /i "!dbExists!"=="YES" (
    echo   [SKIP ] The "Ashley" database already exists on .\SQLEXPRESS - it was NOT restored.
    echo           A re-run never overwrites a school's data. To start over on purpose, drop
    echo           the database first ^(SSMS^), then run setup.bat again.
    exit /b 0
)

if not exist "%resetZip%" (
    echo   [SKIP ] Z_Reset_1034.zip not found; skipping DB restore.
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

call :FindSqlcmd
if !errorlevel! neq 0 (
    echo   [SKIP ] sqlcmd not found. Install SSMS/mssql-tools, then restore manually
    echo           using SSMS ^(Restore Database ^> Options ^> Relocate files^) or via sqlcmd
    echo           with WITH MOVE to your server's default DATA folder ^(the .bak was created
    echo           on a different install path, so a straight RESTORE will fail with error 3156^).
    exit /b 0
)

if /i not "!dbExists!"=="NO" (
    echo   [WARN ] Could not check whether the "Ashley" database exists, so it was NOT restored.
    echo           Make sure SQL Server ^(MSSQL$SQLEXPRESS^) is running and setup can sign in to it ^(a
    echo           restricted server needs the sa password at step 3^),
    echo           then run setup.bat again.
    call :ackWarn
    exit /b 0
)

echo   Restoring "Ashley" via sqlcmd ^(with WITH MOVE to this server's default data folder^)...
set "RESTORE_SQL=SET NOCOUNT ON; DECLARE @dataPath NVARCHAR(500)=ISNULL(CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(500)),N'C:\'); DECLARE @logPath NVARCHAR(500)=ISNULL(CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS NVARCHAR(500)),@dataPath); DECLARE @mdf NVARCHAR(500)=@dataPath+N'Ashley.mdf'; DECLARE @ldf NVARCHAR(500)=@logPath+N'Ashley_log.ldf'; RESTORE DATABASE [Ashley] FROM DISK=N'$(BAKPATH)' WITH NOUNLOAD, STATS=10, MOVE N'Ashley' TO @mdf, MOVE N'Ashley_log' TO @ldf;"
sqlcmd -S .\SQLEXPRESS %SQLAUTH% -C -b -v BAKPATH="!bakFile!" -Q "!RESTORE_SQL!"
set "restoreRc=!errorlevel!"
if !restoreRc! neq 0 (
    echo   [INFO ] Retrying without -C flag ^(older sqlcmd^)...
    sqlcmd -S .\SQLEXPRESS %SQLAUTH% -b -v BAKPATH="!bakFile!" -Q "!RESTORE_SQL!"
    set "restoreRc=!errorlevel!"
)
set "RESTORE_SQL="
if !restoreRc! neq 0 (
    echo   [WARN ] RESTORE reported an error. You can restore manually from SSMS using WITH MOVE.
    call :ackWarn
) else (
    echo   [ OK  ] Ashley database restored.
)
exit /b 0
