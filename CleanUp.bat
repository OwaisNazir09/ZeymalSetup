@echo off
:: ============================================================
:: Zeymal Environment Cleanup Script - NO CONFIRMATION
:: Removes all components created by the Zeymal setup script
:: ============================================================

:: Keep window open
if "%1"=="" (
    start "" cmd /k "%~f0" keepopen
    exit /b
)
if "%1"=="keepopen" shift

setlocal enabledelayedexpansion
title Zeymal Environment Cleanup

echo.
echo ============================================================
echo   ZEYMAL ENVIRONMENT CLEANUP
echo ============================================================
echo   Removing all Zeymal components...
echo ============================================================
echo.

:: ------------------------------------------------------------
:: [1/8] Remove IIS virtual directory and FTP site
:: ------------------------------------------------------------
echo [1/8] Removing IIS "RT" virtual directory and FTP site...
set "appcmd=%windir%\system32\inetsrv\appcmd.exe"
if exist "%appcmd%" (
    echo   Removing FTP site "RT"...
    "%appcmd%" delete site "RT" >nul 2>&1
    echo   Removing virtual directory "Default Web Site/RT"...
    "%appcmd%" delete vdir "Default Web Site/RT" >nul 2>&1
    echo   [ OK  ] IIS entries removed.
) else (
    echo   [SKIP ] appcmd.exe not found.
)
echo.

:: ------------------------------------------------------------
:: [2/8] Stop and remove SQL Server
:: ------------------------------------------------------------
echo [2/8] Removing SQL Server Express instance...
sc query "MSSQL$SQLEXPRESS" >nul 2>&1
if !errorlevel! equ 0 (
    echo   Stopping SQL Server service...
    net stop "MSSQL$SQLEXPRESS" >nul 2>&1
    
    echo   Removing SQL Server instance...
    if exist "C:\Users\postgres\Downloads\SQLMedia\extract\setup.exe" (
        "C:\Users\postgres\Downloads\SQLMedia\extract\setup.exe" /Q /ACTION=UNINSTALL /INSTANCENAME=SQLEXPRESS
        echo   [ OK  ] SQL Server uninstall initiated.
    ) else if exist "C:\Users\postgres\Downloads\SQLEXPR.exe" (
        "C:\Users\postgres\Downloads\SQLEXPR.exe" /Q /ACTION=UNINSTALL /INSTANCENAME=SQLEXPRESS
        echo   [ OK  ] SQL Server uninstall initiated.
    ) else if exist "C:\Users\postgres\Downloads\SQLEXPRWT.exe" (
        "C:\Users\postgres\Downloads\SQLEXPRWT.exe" /Q /ACTION=UNINSTALL /INSTANCENAME=SQLEXPRESS
        echo   [ OK  ] SQL Server uninstall initiated.
    ) else (
        echo   [WARN ] SQL Server setup.exe not found. Uninstall manually.
    )
    
    sc delete "MSSQL$SQLEXPRESS" >nul 2>&1
) else (
    echo   [SKIP ] SQL Server Express not installed.
)
echo.

:: ------------------------------------------------------------
:: [3/8] Remove the Ashley database files
:: ------------------------------------------------------------
echo [3/8] Removing Ashley database files...
set "dataPath=C:\Program Files\Microsoft SQL Server"
if exist "%dataPath%" (
    for /d %%D in ("%dataPath%\MSSQL*SQLEXPRESS") do (
        if exist "%%D\MSSQL\DATA\Ashley.mdf" (
            del /f /q "%%D\MSSQL\DATA\Ashley.mdf" >nul 2>&1
            echo   Removed Ashley.mdf
        )
        if exist "%%D\MSSQL\DATA\Ashley_log.ldf" (
            del /f /q "%%D\MSSQL\DATA\Ashley_log.ldf" >nul 2>&1
            echo   Removed Ashley_log.ldf
        )
    )
)
echo.

:: ------------------------------------------------------------
:: [4/8] Remove Java JRE 8u271
:: ------------------------------------------------------------
echo [4/8] Removing Java JRE 8u271...
for /f "delims=" %%J in ('wmic product where "name like '%%Java 8%%' and name like '%%Update 271%%'" get name 2^>nul ^| findstr /I "Java"') do (
    echo   Uninstalling: %%J
    wmic product where "name='%%J'" call uninstall /nointeractive >nul 2>&1
)
echo   [ OK  ] Java uninstall attempted.
echo.

:: ------------------------------------------------------------
:: [5/8] Remove the "RT" user
:: ------------------------------------------------------------
echo [5/8] Removing "RT" user account...
net user "RT" >nul 2>&1
if !errorlevel! equ 0 (
    net localgroup "Administrators" "RT" /delete >nul 2>&1
    net user "RT" /delete >nul 2>&1
    echo   [ OK  ] User "RT" removed.
) else (
    echo   [SKIP ] User "RT" not found.
)
echo.

:: ------------------------------------------------------------
:: [6/8] Remove the "postgres" user
:: ------------------------------------------------------------
echo [6/8] Removing "postgres" user account...
net user "postgres" >nul 2>&1
if !errorlevel! equ 0 (
    net localgroup "Administrators" "postgres" /delete >nul 2>&1
    net user "postgres" /delete >nul 2>&1
    echo   [ OK  ] User "postgres" removed.
) else (
    echo   [SKIP ] User "postgres" not found.
)
echo.

:: ------------------------------------------------------------
:: [7/8] Remove application folder
:: ------------------------------------------------------------
echo [7/8] Removing Zeymal application folder...
set "appFolder=C:\Users\postgres\zeymal"
if exist "%appFolder%" (
    rmdir /s /q "%appFolder%" >nul 2>&1
    echo   [ OK  ] Application folder removed.
) else (
    echo   [SKIP ] Application folder not found.
)
echo.

:: ------------------------------------------------------------
:: [8/8] Remove Downloads folder (if empty)
:: ------------------------------------------------------------
echo [8/8] Removing Downloads folder (if empty)...
set "DownloadPath=C:\Users\postgres\Downloads"
if exist "%DownloadPath%" (
    dir /a /b "%DownloadPath%" | findstr . >nul 2>&1
    if !errorlevel! equ 1 (
        rmdir "%DownloadPath%" >nul 2>&1
        echo   [ OK  ] Downloads folder removed (was empty).
    ) else (
        echo   [SKIP ] Downloads folder not empty.
    )
) else (
    echo   [SKIP ] Downloads folder not found.
)
echo.

:: ------------------------------------------------------------
:: Cleanup complete
:: ------------------------------------------------------------
echo ============================================================
echo   CLEANUP COMPLETE
echo ============================================================
echo   All Zeymal components have been removed.
echo ============================================================

:done_wait
echo.
echo   Press any key to close this window...
pause >nul
exit