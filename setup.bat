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

:: Skip if the SQLEXPRESS instance is already present
sc query "MSSQL$SQLEXPRESS" >nul 2>&1
if !errorlevel! equ 0 (
    echo SQL Server SQLEXPRESS instance already installed. Skipping.
    goto :InstallSqlModern_SSMS
)

set "SqlBootstrap=%DownloadPath%\SQL2022-SSEI-Expr.exe"
set "SqlMediaDir=%DownloadPath%\SQLMedia"
set "SqlMediaFile=%SqlMediaDir%\SQLEXPR_x64_ENU.exe"
set "SqlSetupDir=%SqlMediaDir%\extract"

call :Download "https://go.microsoft.com/fwlink/p/?linkid=2216019&clcid=0x409&culture=en-us&country=us" "%SqlBootstrap%" "SQL Server 2022 Express bootstrapper"
if !errorlevel! neq 0 (
    echo Failed to download SQL Server 2022 Express bootstrapper.
    pause
    exit /b 1
)

if not exist "%SqlMediaDir%" mkdir "%SqlMediaDir%"

if exist "%SqlMediaFile%" (
    echo Media package already present, skipping download.
) else (
    echo.
    echo Step 1/3: Downloading full SQL Server media package ^(~280 MB^)...
    echo   This uses Microsoft's downloader and shows its own progress window.
    "%SqlBootstrap%" /ACTION=Download /MEDIAPATH="%SqlMediaDir%" /MEDIATYPE=Core /LANGUAGE=en-US /QUIET /HIDEPROGRESSBAR
    if !errorlevel! neq 0 (
        echo Failed to download SQL Server media.
        pause
        exit /b 1
    )
    if not exist "%SqlMediaFile%" (
        echo Expected media file was not produced: %SqlMediaFile%
        pause
        exit /b 1
    )
)

echo.
echo Step 2/3: Extracting media to %SqlSetupDir% ...
if not exist "%SqlSetupDir%" mkdir "%SqlSetupDir%"
"%SqlMediaFile%" /X:"%SqlSetupDir%" /Q
if !errorlevel! neq 0 (
    echo Failed to extract SQL Server media.
    pause
    exit /b 1
)
if not exist "%SqlSetupDir%\setup.exe" (
    echo setup.exe not found after extraction at %SqlSetupDir%\setup.exe
    pause
    exit /b 1
)

echo.
echo Step 3/3: Running SQL Server setup ^(silent^)...
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

if !errorlevel! neq 0 (
    echo SQL Server installation reported an error. Check logs at:
    echo   %ProgramFiles%\Microsoft SQL Server\160\Setup Bootstrap\Log
    pause
    exit /b 1
)
echo SQL Server 2022 Express installed successfully.

:InstallSqlModern_SSMS

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

set ZeymalFiles=C:\Users\%newUser%\zeymal\files

if not exist "%ZeymalFiles%" ( 
    mkdir "%ZeymalFiles%"
    if !errorlevel! neq 0 (
        echo Failed to create Zeymal files folder.
        pause
        exit /b 1
    )
    echo Zeymal files folder created successfully: %ZeymalFiles%
) else (
    echo Zeymal files folder already exists: %ZeymalFiles%
)

set ZeymalRplaceXip=https://my.microsoftpersonalcontent.com/personal/1d15c3c5a76b8f6e/_layouts/15/download.aspx?UniqueId=b8e3d0ba-18d9-4feb-bbfd-6b71d09ea928&Translate=false&tempauth=v1e.eyJzaXRlaWQiOiJhNzRiMGExYi03ODhmLTRlNTktYTI0OC0xYTZkZTBkYTBkZWQiLCJhdWQiOiIwMDAwMDAwMy0wMDAwLTBmZjEtY2UwMC0wMDAwMDAwMDAwMDAvbXkubWljcm9zb2Z0cGVyc29uYWxjb250ZW50LmNvbUA5MTg4MDQwZC02YzY3LTRjNWItYjExMi0zNmEzMDRiNjZkYWQiLCJleHAiOiIxNzgzOTE5MjQzIn0.m7I2ZmTod3uMKcBc0mXi5KvZX4H3k5ikcyeDpdtZag0glDGpB-lEQ9u5zS0a1cPIXw7-i9miz_mqfnRXewntpPhj3w2ygWZhHu-UvGhYxK0uUwCYy4rmLW9Ark2YdFlKaEBspq34740L89f8I46pgLI8U4C40T5FYjDlHw3FnYSQiPRGSDsCT98H9AKOpSFLWHV1T6xZodwPNNzivoEMPWImdEhkVWOysV1dau2o47IpUxqa1MlBqmE09TxbisHCKy_r_VgW5Rojim_gzcJLQ95VImaWwae4FN1VAe1h2ywrYoecbnIehvkIsrMAsvSpEdMoCfm0dzHqDcStZprg1cfTnfTlatTxgZmvpDCCtfjf92vJyIlSGoLereB63nZLCemrWZiFZ7U0RRLTUWzd9rxU9F48D3lDmqI1n-aYPKa-zO7LtX_2BAmx8F1xfP9bT6QpPhdgPTe27JbQwQ_HulLbwIC2PFKMsBe6h-DHby-e9tlEViNCTYz4Mf9UgyyZajD5jZV7mBbqC4nRMs4vZI2q6hl_A-eFyA36HBUnmG3O8f2GhXxUG9dLla4gJZEquyRxMNO6LGOanW9CtB3l6qn8Br1gUXtMsho4DdSCSVk.PbWtsEDxyIC25Aez8vltFHaOPBDLeD6BSH_9X-ykRwc&ApiVersion=2.0

set ZeymalIftwInstaller=https://my.microsoftpersonalcontent.com/personal/1d15c3c5a76b8f6e/_layouts/15/download.aspx?UniqueId=dc901bc0-8554-4038-b514-4b9216f322e4&Translate=false&tempauth=v1e.eyJzaXRlaWQiOiJhNzRiMGExYi03ODhmLTRlNTktYTI0OC0xYTZkZTBkYTBkZWQiLCJhdWQiOiIwMDAwMDAwMy0wMDAwLTBmZjEtY2UwMC0wMDAwMDAwMDAwMDAvbXkubWljcm9zb2Z0cGVyc29uYWxjb250ZW50LmNvbUA5MTg4MDQwZC02YzY3LTRjNWItYjExMi0zNmEzMDRiNjZkYWQiLCJleHAiOiIxNzgzOTE5Njc5In0.VzZ55tKZPFJXr4Lj9aNMhodOZkZx5OVTumKAC1Eksp0Ogy5S1DGwqOz4Bm0s3p7jABLff-jBVBiBz4hvkLD8r437ggCJ411cdQzCpBcs9HNPesGXUbZ4WKPwgQ6r3LYRdbSAr31F1oPq4Aw551OJTZhphcRQbWVkWmIR5wC1HiED-POlHoCWKAD6294RrwpL_aLdII2ccJgjkut6bSdHVRXQ6jgZJWnmTr6qAp4-o1lwpQomCWIn7MmHnp-mRULtF_8gep7k9rpCOk1pzNVyPT3XHgNJ_ryirz7Rr-Wz3t_PNLTAN4bPwrAHMB2GSUVizGErFsosD3lQl59T__Nt0UH-i8tSDE-mosVb0VtvuEdUKu4IbQhGlUoufSw0EwAagWdyFfeqAtZkz6UWUaI9ExKb9pIO-wv8lQYsNpodP2wo65RtCvCOl0866zCjdo5FD2_BD0WfrtZkPNUwIDvskz5pQrDEPzwtA8bX1mDb9V0DCgs6c4VZdrzmWPsj7bCXTyO16xSf1aSsJHUVA3QuRiyh3mGhu1r1T_tMJ1xzdBdlZdaDjO0hG6M3sI6lyZl2lbAybmlsXkr7sSx-Uz_cHWpuMbCqtNU3ZaEiZVZ_Ack.B6pNrnurOUDkxrggDZjkAtjdkrZINVBEjkKjUNoOBiU&ApiVersion=2.0

set Zeymalexe=https://my.microsoftpersonalcontent.com/personal/1d15c3c5a76b8f6e/_layouts/15/download.aspx?UniqueId=c68c6fa3-6aa4-43b3-b4ff-e071ecf34daa&Translate=false&tempauth=v1e.eyJzaXRlaWQiOiJhNzRiMGExYi03ODhmLTRlNTktYTI0OC0xYTZkZTBkYTBkZWQiLCJhdWQiOiIwMDAwMDAwMy0wMDAwLTBmZjEtY2UwMC0wMDAwMDAwMDAwMDAvbXkubWljcm9zb2Z0cGVyc29uYWxjb250ZW50LmNvbUA5MTg4MDQwZC02YzY3LTRjNWItYjExMi0zNmEzMDRiNjZkYWQiLCJleHAiOiIxNzgzOTE5ODUxIn0.QU6Jlf3ddhc5PcHufu8dBHCn5a2ETV3YZFmV6N80xjGkqXJThoUU0rrm5VOR47TYQ36ngkfP9N2vPEDuJEj3s6_InByRO-TIRUQ8hord1vbhp_kAu8l9so9qs5C7XiWJ8UfpMRjhFBC6DMTtur1GrCEozZkBwYvRtGBlbzdTRGqkojIaYEr6ojg9UJyhd8aqGGuaS57_RQGiHVzZ0uefVk8rpAPsg3E3zWqzCAMhLVlOAi9emcGV4p4R9UXCiJ1ZnjetkH0l5RFZWShJ-3s0SY23LvPcNvWzQcrRlMBW9Tpisb9X7hCfayizGgsj4kC23WPwpQitkzL6T4hvlDqLk1UejliBHELBjtMSC82Rno37_aE-vHZy_LsHQdpSIdz6AY5r_ilX8GrYkDg5P9xP_X71Kbde25stIkITYMlsGBNGaFWBwh6hLT561kUFa-6O2z6rm_7UuxbQlPZKuksaBOEV_lukNudGmjjngPeherk1am_Hyb9RxNm4ITjXyeC1Hab6fnGomAxpX3AAV6oJEJh-9RbFemlkeJUlttoxRZwcNgZK4Klju3c75dR1vdypOY6arOyHub_Ukc5ZiOA4ezQzllsip9mldmpvcUj1xhLo1KBw0-cAGpwndEXpMsW0.S5qZPH7XkJrN_PoV6EWhIyzn6SJPhv2KkKEdfZoY3wc&ApiVersion=2.0

set Zeymaljar=https://my.microsoftpersonalcontent.com/personal/1d15c3c5a76b8f6e/_layouts/15/download.aspx?UniqueId=82bbef8c-25f0-452d-8b75-1c56e8dcf547&Translate=false&tempauth=v1e.eyJzaXRlaWQiOiJhNzRiMGExYi03ODhmLTRlNTktYTI0OC0xYTZkZTBkYTBkZWQiLCJhdWQiOiIwMDAwMDAwMy0wMDAwLTBmZjEtY2UwMC0wMDAwMDAwMDAwMDAvbXkubWljcm9zb2Z0cGVyc29uYWxjb250ZW50LmNvbUA5MTg4MDQwZC02YzY3LTRjNWItYjExMi0zNmEzMDRiNjZkYWQiLCJleHAiOiIxNzgzOTIwMDMyIn0.YB5PYRYmw4LUu7kr4Za3hA0zQskt87Lotx3zJt4pSg39FoSziHd5A7PLwrfI4UqJXIPgn9s_tuTqtJY0YAPO0mhb5kBvbPCVbUPZYLYIWzE1TjF3D8PX8RFEHWNt9XWQvNAv7JFXS-9HdKT93W0WRGvlnLZvQMIKz4zOZ7t-4Uf8cIsDKMx8CajEKJtZYLfybpDvyNhJbk7YgOB58LD_8jBsN6NZtcPjrlA94aWiJ_hJbzeyPBWHN-jIEkcWSme58-l-18oZWy6cU4_9kMOTx6ZHuY2YG3rBbALXgS1SJZ_4cL4tzRvJfiuijjlCXt4nHwIcU6tkrq84tB_ZOmc9PRzmfbLd5KI9WTwfRatH0XEZqsFRaYU1FsutRlkma1-2Dl3tAEVFVdi7CiJdf_Mi168TyY4hPZGYA2lFtOpKbHX48DgOSuAMAnmIDss9OVgOVCCgWZnX42ahII26CXcNe_Pcepq0fO_1UvhcVJDjbnCTGrLEO2SrLIKkd6Gjycd7kY6w0CmGqFQ5uEVGIApWrS9NNzryo9GivKeYKeTkTwGvCUz81_bTylRyDB6EWUwmO22a4Xj81KnaTo8RUorgEP5QCca6Fb5sxhNpsMQ3hNk.uwpAooX1rADI06h3iZF80jYEG8CDmfNbV-QerfEM5Ms&ApiVersion=2.0

set ZeymalResetxip=https://my.microsoftpersonalcontent.com/personal/1d15c3c5a76b8f6e/_layouts/15/download.aspx?UniqueId=087a7d24-c60b-4420-b48f-74477eb77454&Translate=false&tempauth=v1e.eyJzaXRlaWQiOiJhNzRiMGExYi03ODhmLTRlNTktYTI0OC0xYTZkZTBkYTBkZWQiLCJhdWQiOiIwMDAwMDAwMy0wMDAwLTBmZjEtY2UwMC0wMDAwMDAwMDAwMDAvbXkubWljcm9zb2Z0cGVyc29uYWxjb250ZW50LmNvbUA5MTg4MDQwZC02YzY3LTRjNWItYjExMi0zNmEzMDRiNjZkYWQiLCJleHAiOiIxNzgzOTIwMTY5In0.fHpi_7-QgzhUS8ZdNevoaKNCAU9daLH5d6L1ljyQrBG8IxXULP4r_NunbJYVQiccDGyJdNABmFplyb9qxkylntgn8YBDbBBowlUR5NXIctBcDmjthCmnSRTCXDsLIsVMWSm1nEh8Aj2_Dwl8G7T_quIQ_MjO9nscq_l-_fw633x5Ig1j07xe-OJlbSEtUBmP_oM8Te1HdXhFDujnrUM-kld1drTPO_QVqT1p3FO2fexZYW7PPmqTLSpyyXtaXiSN-7078AaZLGcpC_QW210rdwWHbpMuHFk_Kby0youDAvDYtX9oZW9iPeoa-BHEZs4OxVJ28Y7z2lxAM7cLeefHyiPRNpJtkpsgzyrW457VFOtg8WQWJwjMWHjFaLohkUgzETcQDt6yIqzqzFgsrIXVFLx5csjiK7wVAqVO5hIsWLdu_r-OdATZwMaSDKc5h7BdxhH7ai8ZUwcUBr-KenyeVpUpNQMzU_h8TutNHMYHI6mLWdp1nQPzc4cLrhgDwYQu6MiJx5mfEElKxMCD_wkB3WpL6rxVesY751nbnlpZl49dOypNu0GAvMq2xJJ25MZWzz0PyKPtsczj_R95OL5xTWUbU_bDKldH5BsdS94OE1o.GT2ruZ2FXmsuvc0ojYOKs43aYC-KvoYcSVo90P-DnNk&ApiVersion=2.0

:: Define list of files to download
set "fileList=ZeymalRplaceXip ZeymalIftwInstaller Zeymalexe Zeymaljar ZeymalResetxip"

:: Download each file
for %%V in (%fileList%) do (
    call :DownloadFile %%V
    if !errorlevel! neq 0 (
        echo Failed to download %%V.
        pause
        exit /b 1
    )
)

echo All files downloaded successfully!
pause
exit /b 0

:DownloadFile
set "varName=%~1"
set "fileUrl=!%varName%!"
set "fileName=%varName%.exe"
set "fileDest=%ZeymalFiles%\%fileName%"

echo Downloading %fileName%...
if exist "!fileDest!" (
    echo File already exists: !fileDest!, skipping download.
    exit /b 0
)

:: Use PowerShell to download the file
powershell -Command "& {Invoke-WebRequest -Uri '!fileUrl!' -OutFile '!fileDest!'}"
if !errorlevel! neq 0 (
    echo Failed to download from: !fileUrl!
    exit /b 1
)
echo Successfully downloaded: !fileDest!
exit /b 0