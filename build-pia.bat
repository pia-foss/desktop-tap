@echo off
setlocal EnableDelayedExpansion
pushd %~dp0

rem Specify these arguments in the environment before calling the script:
rem EWDK = path to EWDK (e.g. C:\EWDK\1804, tries to auto-detect)
rem PIA_TAP_SHA256_CERT = thumbprint of SHA256 EV certificate (needed for installable driver)
rem PIA_TAP_SHA1_CERT = thumbprint of SHA1 EV certificate (optional)
rem PIA_TAP_CROSSCERT = CA certificate file for EV certificate (default: DigiCert EV)
rem PIA_TAP_TIMESTAMP = timestamp server for signing (default: DigiCert)

if [%PIA_TAP_CROSSCERT%] == [] set "PIA_TAP_CROSSCERT=DigiCert-High-Assurance-EV-Root-CA.crt"
if [%PIA_TAP_TIMESTAMP%] == [] set "PIA_TAP_TIMESTAMP=http://timestamp.digicert.com"

if [%EWDK%] == [] (
  for /D %%G in ("C:\EWDK\*") do set "EWDK=%%G"
)
if not exist "%EWDK%" (
  echo Error: EWDK not found.
  goto error
)
echo * Using EWDK in %EWDK%

call "%EWDK%\BuildEnv\SetupBuildEnv.cmd"
@echo off

del /Q /F dist

echo * Building TAP adapter...
rem Patch paths.py with provided/detected EWDK path
powershell -Command "(Get-Content paths.py) -replace '^EWDK\s*=\s*.*', ('EWDK = """"%EWDK%""""').Replace('\','\\') | Out-File -encoding ASCII paths.py"
if %errorlevel% neq 0 goto error
echo.
python buildtap.py -c -b
if %errorlevel% neq 0 goto error
echo.

if not [%PIA_TAP_SHA256_CERT%] == [] (
  for %%G in (i386,amd64) do (
    for %%H in ("dist\%%G\*.cat") do set "CAT_%%G=%%H"
  )
  if not [%PIA_TAP_SHA1_CERT%] == [] (
    echo * Double-signing drivers with SHA1 and SHA256 certificates...
    echo * Signing with SHA1...
    signtool.exe sign /ac "%PIA_TAP_CROSSCERT%" /fd sha1 /tr "%PIA_TAP_TIMESTAMP%" /td sha1 /sha1 "%PIA_TAP_SHA1_CERT%" "!CAT_i386!" "!CAT_amd64!"
    if !errorlevel! neq 0 goto error
    echo * Signing with SHA256...
    signtool.exe sign /as /ac "%PIA_TAP_CROSSCERT%" /fd sha256 /tr "%PIA_TAP_TIMESTAMP%" /td sha256 /sha1 "%PIA_TAP_SHA256_CERT%" "!CAT_i386!" "!CAT_amd64!"
    if !errorlevel! neq 0 goto error
  ) else (
    echo * Signing drivers with SHA256 certificate...
    signtool.exe sign /ac "%PIA_TAP_CROSSCERT%" /fd sha256 /tr "%PIA_TAP_TIMESTAMP%" /td sha256 /sha1 "%PIA_TAP_SHA256_CERT%" "!CAT_i386!" "!CAT_amd64!"
    if !errorlevel! neq 0 goto error
  )
  echo * Making CAB files...
  for %%G in (i386,amd64) do (
    for %%H in ("!CAT_%%G!") do (
      >"dist\tap-%%G.ddf" (
        echo .option explicit
        echo .set CabinetFileCountThreshold=0
        echo .set FolderFileCountThreshold=0
        echo .set FolderSizeThreshold=0
        echo .set MaxCabinetSize=0
        echo .set MaxDiskFileCount=0
        echo .set MaxDiskSize=0
        echo .set Cabinet=on
        echo .set Compress=on
        echo .set DiskDirectoryTemplate=dist
        echo .set DestinationDir=Package
        echo .set CabinetNameTemplate=tap-%%G.cab
        echo .set SourceDir=dist\%%G
        echo OemVista.inf
        echo %%~nH.sys
        echo %%~nxH
      )
      makecab /F "dist\tap-%%G.ddf" >NUL
      if !errorlevel! neq 0 (
        set errorlevel=!errorlevel!
        del /Q /F "dist\tap-%%G.ddf"
        goto error
      )
      del /Q /F "dist\tap-%%G.ddf"
    )
  )
  echo * Signing CAB files for Microsoft submission...
  signtool.exe sign /ac "%PIA_TAP_CROSSCERT%" /fd sha256 /tr "%PIA_TAP_TIMESTAMP%" /td sha256 /sha1 "%PIA_TAP_SHA256_CERT%" "dist\tap-i386.cab" "dist\tap-amd64.cab"
  if !errorlevel! neq 0 goto error

  echo.
  echo To get Microsoft certified drivers for Windows 10, submit the
  echo signed CAB files to the Microsoft Dev Center at:
  echo.
  echo https://developer.microsoft.com/en-us/dashboard/hardware
  echo.
) else (
  echo * No certificates specified; drivers will not be installable.
)

echo * Build successful.

:end
popd
endlocal
exit /b %errorlevel%

:error
if %errorlevel% equ 0 (
  set errorlevel=1
) else (
  echo.
  echo Build failed with error %errorlevel%!
)
goto end
