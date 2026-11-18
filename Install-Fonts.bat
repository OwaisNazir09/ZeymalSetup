@echo off
:: ============================================================
:: Install-Fonts.bat - installs the fonts Zeymal's reports use
:: (the base files' __\Fonts: Fake Receipt, which the receipt
:: layouts need, and four more) for ALL users of this PC: copied
:: into C:\Windows\Fonts and registered under HKLM.
::
:: Installing a font by double-click only installs it for the one
:: Windows user who did it (Windows 10 1809 and later). Zeymal then
:: stops for everyone else with "Font 'Fake Receipt' is not
:: available to the JVM".
::
:: Run as administrator. Put it in the Zeymal folder (it uses the
:: __\Fonts folder next to it) and double-click, or give a folder:
::     Install-Fonts.bat "D:\Zeymal\__\Fonts"
:: setup.bat does the same at step 9.6 on the server; this is for
:: client PCs and servers set up before that.
:: ============================================================
setlocal enabledelayedexpansion
net session >nul 2>&1
if errorlevel 1 (
    echo   [ERROR] This needs administrator rights: right-click Install-Fonts.bat, Run as administrator.
    pause
    exit /b 1
)
set "FONT_DIR=%~1"
if not defined FONT_DIR set "FONT_DIR=%~dp0__\Fonts"
if not exist "!FONT_DIR!\*.ttf" (
    echo   [ERROR] No fonts found in: !FONT_DIR!
    echo           Put this file in the Zeymal folder, or give the fonts folder as an argument.
    pause
    exit /b 1
)
echo Installing the fonts in !FONT_DIR! for all users...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$src = $env:FONT_DIR; $dst = Join-Path $env:WINDIR 'Fonts'; $key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'; Add-Type -AssemblyName PresentationCore; Add-Type -Namespace ZeymalSetup -Name FontApi -MemberDefinition '[DllImport(\"gdi32.dll\", CharSet = CharSet.Unicode)] public static extern int AddFontResource(string file); [DllImport(\"user32.dll\")] public static extern int PostMessage(System.IntPtr hwnd, uint msg, System.IntPtr w, System.IntPtr l);'; $registered = @((Get-ItemProperty -LiteralPath $key).PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } | ForEach-Object { [string]$_.Value }); $bad = 0; $added = 0; foreach ($f in (Get-ChildItem -LiteralPath $src -File | Where-Object { $_.Extension -match '^\.(ttf|otf)$' })) { try { $target = Join-Path $dst $f.Name; if ((Test-Path -LiteralPath $target) -and ($registered -contains $f.Name)) { Write-Host ('  [ OK  ] Already installed for all users: ' + $f.Name); continue }; $g = New-Object System.Windows.Media.GlyphTypeface ([uri]$f.FullName); $en = [Globalization.CultureInfo]'en-US'; $name = $g.Win32FamilyNames[$en]; if (-not $name) { $name = [IO.Path]::GetFileNameWithoutExtension($f.Name) }; $face = $g.Win32FaceNames[$en]; if ($face -and $face -ne 'Regular') { $name = $name + ' ' + $face }; $type = if ($f.Extension -match 'otf') { 'OpenType' } else { 'TrueType' }; if (-not (Test-Path -LiteralPath $target)) { Copy-Item -LiteralPath $f.FullName -Destination $target }; Set-ItemProperty -LiteralPath $key -Name ($name + ' (' + $type + ')') -Value $f.Name; [void][ZeymalSetup.FontApi]::AddFontResource($target); $added++; Write-Host ('  [ OK  ] Installed for all users: ' + $name + ' (' + $f.Name + ')') } catch { $bad++; Write-Host ('  [WARN ] ' + $f.Name + ': ' + $_.Exception.Message) } }; if ($added -gt 0) { [void][ZeymalSetup.FontApi]::PostMessage([IntPtr]0xffff, 0x1D, [IntPtr]::Zero, [IntPtr]::Zero) }; if ($bad -gt 0) { exit 1 } else { exit 0 }"
if errorlevel 1 (
    echo   [WARN ] Some fonts were not installed; see above.
) else (
    echo   [ OK  ] Done. Restart Zeymal to use them.
)
pause
