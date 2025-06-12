@echo off
setlocal enabledelayedexpansion

:: Simple Web Spider in Batch
:: This script downloads web pages and extracts links

echo ================================
echo    Simple Web Spider v1.0
echo ================================
echo.

:: Configuration
set "USER_AGENT=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
set "MAX_DEPTH=10"
set "DELAY=1"
set "OUTPUT_DIR=spider_output"

:: Create output directory// all output will be placed in this directory
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

:: Get starting URL from user
if "%1"=="" (
    set /p START_URL="Enter starting URL: "
) else (
    set "START_URL=%1"
)

echo Starting spider with URL: %START_URL%
echo Max depth: %MAX_DEPTH%
echo Output directory: %OUTPUT_DIR%
echo.

:: Initialize sequence
set "CURRENT_DEPTH=0"
set "PAGE_COUNT=0"

:: Create lists for URLs to process
echo %START_URL% > "%OUTPUT_DIR%\urls_to_process.txt"
type nul > "%OUTPUT_DIR%\processed_urls.txt"
type nul > "%OUTPUT_DIR%\found_links.txt"

:MAIN_LOOP
if %CURRENT_DEPTH% geq %MAX_DEPTH% goto END_SPIDER

echo Processing depth level: %CURRENT_DEPTH%
set "NEXT_URLS_FILE=%OUTPUT_DIR%\urls_depth_%CURRENT_DEPTH%.txt"

:: Processes each URL at current depth
for /f "delims=" %%U in (%OUTPUT_DIR%\urls_to_process.txt) do (
    call :PROCESS_URL "%%U"
)

:: next depth level preparation will be done here
if exist "%OUTPUT_DIR%\urls_depth_%CURRENT_DEPTH%.txt" (
    copy "%OUTPUT_DIR%\urls_depth_%CURRENT_DEPTH%.txt" "%OUTPUT_DIR%\urls_to_process.txt" >nul
    set /a CURRENT_DEPTH+=1
    goto MAIN_LOOP
) else (
    echo No more URLs to process.
    goto END_SPIDER
)

:PROCESS_URL
set "URL=%~1"
set /a PAGE_COUNT+=1

echo [%PAGE_COUNT%] Processing: %URL%

:: Checks if url has been processed
findstr /c:"%URL%" "%OUTPUT_DIR%\processed_urls.txt" >nul 2>&1
if not errorlevel 1 (
    echo   - Already processed, skipping
    goto :eof
)

:: Adds processed url to processed list
echo %URL% >> "%OUTPUT_DIR%\processed_urls.txt"

:: Creates safe filename
set "FILENAME=page_%PAGE_COUNT%.html"

:: Downloads the page using PowerShell (more reliable than pure batch or at least i think so)
echo   - Downloading...
powershell -Command "try { $web = New-Object System.Net.WebClient; $web.Headers.Add('User-Agent', '%USER_AGENT%'); $content = $web.DownloadString('%URL%'); $content | Out-File -FilePath '%OUTPUT_DIR%\%FILENAME%' -Encoding UTF8; Write-Host '   - Downloaded successfully' } catch { Write-Host '   - Download failed:' $_.Exception.Message }"

:: Extract links if download was successful
if exist "%OUTPUT_DIR%\%FILENAME%" (
    call :EXTRACT_LINKS "%OUTPUT_DIR%\%FILENAME%" "%URL%"
)

:: Delay between requests
echo   - Waiting %DELAY% seconds...
timeout /t %DELAY% >nul

goto :eof

:EXTRACT_LINKS
set "FILE=%~1"
set "BASE_URL=%~2"

echo   - Extracting links...

:: Use PowerShell to extract links
powershell -Command "$content = Get-Content '%FILE%' -Raw; $matches = [regex]::Matches($content, 'href=[''\""]([^''\"">]+)[''\""]', 'IgnoreCase'); foreach($match in $matches) { $link = $match.Groups[1].Value; if($link -match '^https?://') { $link } elseif($link -match '^//') { 'http:' + $link } elseif($link -match '^/') { $base = '%BASE_URL%' -replace '(https?://[^/]+).*', '$1'; $base + $link } }" >> "%OUTPUT_DIR%\temp_links.txt"

:: Filter and add unique links for next depth
if exist "%OUTPUT_DIR%\temp_links.txt" (
    for /f "delims=" %%L in (%OUTPUT_DIR%\temp_links.txt) do (
        echo %%L | findstr "^http" >nul && (
            findstr /c:"%%L" "%OUTPUT_DIR%\processed_urls.txt" >nul || (
                findstr /c:"%%L" "%NEXT_URLS_FILE%" >nul 2>&1 || (
                    echo %%L >> "%NEXT_URLS_FILE%"
                    echo %%L >> "%OUTPUT_DIR%\found_links.txt"
                )
            )
        )
    )
    del "%OUTPUT_DIR%\temp_links.txt"
)

goto :eof

:END_SPIDER
echo.
echo ================================
echo     Spider Completed!
echo ================================
echo Pages processed: %PAGE_COUNT%
echo Max depth reached: %CURRENT_DEPTH%
echo.
echo Results saved in: %OUTPUT_DIR%\
echo - Downloaded pages: *.html files
echo - All found links: found_links.txt
echo - Processed URLs: processed_urls.txt
echo.

:: Display summary
if exist "%OUTPUT_DIR%\found_links.txt" (
    for /f %%A in ('type "%OUTPUT_DIR%\found_links.txt" ^| find /c /v ""') do set "LINK_COUNT=%%A"
    echo Total unique links found: !LINK_COUNT!
)

echo.
echo Press any key to exit...
pause >nul