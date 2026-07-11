@echo off

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
) else (
    echo Supported Windows version detected.
    echo Continuing installation...
)

:: THIRD: Create user
set "newUser=postgres"
set "newPassword=362611"

net user "%newUser%" >nul 2>&1
if errorlevel 1 (
    echo User account %newUser% does not exist.
    echo Creating user account...
    net user "%newUser%" "%newPassword%" /add >nul 2>&1
    if errorlevel 1 (
        echo Failed to create user account.
        pause
        exit /b 1
    )
    echo User account %newUser% created successfully.
) else (
    echo User account %newUser% already exists.
)

:: FOURTH: Create folder
set "appFolder=C:\Users\%newUser%\zeymal"
if not exist "%appFolder%" (
    mkdir "%appFolder%"
    if errorlevel 1 (
        echo Failed to create application folder.
        pause
        exit /b 1
    )
    echo Application folder created successfully:
    echo %appFolder%
) else (
    echo Application folder already exists:
    echo %appFolder%
)

:: FIFTH: Create Downloads folder
set "DownloadPath=C:\Users\postgres\Downloads"
if not exist "%DownloadPath%" (
    mkdir "%DownloadPath%"
    if errorlevel 1 (
        echo Failed to create Downloads folder.
        pause
        exit /b 1
    )
    echo Downloads folder created successfully:
    echo %DownloadPath%
) else (
    echo Downloads folder already exists:
    echo %DownloadPath%
)

:: SIXTH: Install SQL Server based on Windows version (REPLACED PostgreSQL with SQL Server)
echo %windowsName% | findstr /I /C:"Windows 11" /C:"Windows 10" >nul
if not errorlevel 1 (
    echo Windows 10/11 detected. Installing SQL Server 2022 Express...
    echo Downloading SQL Server 2022 Express...
    powershell -Command "Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/p/?linkid=2216019&clcid=0x409&culture=en-us&country=us' -OutFile '%DownloadPath%\SQLEXPR.exe'"
    if errorlevel 1 (
        echo Failed to download SQL Server 2022 Express.
        pause
        exit /b 1
    )
    echo Download complete. Starting installation...
    
    "%DownloadPath%\SQLEXPR.exe" /Q /IACCEPTSQLSERVERLICENSETERMS /ACTION=INSTALL /FEATURES=SQLENGINE /INSTANCENAME=SQLEXPRESS /SQLSVCACCOUNT="NT AUTHORITY\Network Service" /SQLSYSADMINACCOUNTS="BUILTIN\ADMINISTRATORS" /SECURITYMODE=SQL /SAPWD="%newPassword%" /ADDCURRENTUSERASSQLADMIN=false /TCPENABLED=1
    
    if errorlevel 1 (
        echo SQL Server installation may have failed. Check the logs.
        pause
        exit /b 1
    )
    echo SQL Server 2022 Express installed successfully!
    
    echo Downloading SQL Server Management Studio (SSMS)...
    powershell -Command "Invoke-WebRequest -Uri 'https://aka.ms/ssms/22/release/vs_SSMS.exe' -OutFile '%DownloadPath%\SSMS.exe'"
    if errorlevel 1 (
        echo Failed to download SSMS. You can manually install it later.
    ) else (
        echo Download complete. Installing SSMS...
        "%DownloadPath%\SSMS.exe" /install /quiet /norestart
        if errorlevel 1 (
            echo SSMS installation may have failed. You can manually install it later.
        ) else (
            echo SSMS installed successfully!
        )
    )
) else (
    echo %windowsName% | findstr /I /C:"Windows 7" /C:"Windows 8" >nul
    if not errorlevel 1 (
        echo Windows 7/8 detected. Installing SQL Server 2014 Express...
        echo Downloading SQL Server 2014 Express with Tools...
        powershell -Command "Invoke-WebRequest -Uri 'https://download.microsoft.com/download/E/A/E/EAE6F7FC-767A-4038-A954-49B8B05D04EB/ExpressAndTools%2064BIT/SQLEXPRWT_x64_ENU.exe' -OutFile '%DownloadPath%\SQLEXPRWT.exe'"
        if errorlevel 1 (
            echo Failed to download SQL Server 2014 Express.
            pause
            exit /b 1
        )
        echo Download complete. Starting installation...
        
        "%DownloadPath%\SQLEXPRWT.exe" /Q /IACCEPTSQLSERVERLICENSETERMS /ACTION=INSTALL /FEATURES=SQLENGINE /INSTANCENAME=SQLEXPRESS /SQLSVCACCOUNT="NT AUTHORITY\Network Service" /SQLSYSADMINACCOUNTS="BUILTIN\ADMINISTRATORS" /SECURITYMODE=SQL /SAPWD="%newPassword%" /TCPENABLED=1
        
        if errorlevel 1 (
            echo SQL Server installation may have failed. Check the logs.
            pause
            exit /b 1
        )
        echo SQL Server 2014 Express installed successfully!
        
        echo Note: SSMS is not included in this download. You can manually download it.
    ) else (
        echo Unsupported Windows version.
        pause
        exit /b 1
    )
)

pause
exit /b 0