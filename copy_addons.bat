@echo off
:: Check for administrative privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Administrative privileges detected. Copying files...
) else (
    echo.
    echo ============================================================
    echo ERROR: Please right-click this file and select "Run as administrator".
    echo ============================================================
    echo.
    pause
    exit /b 1
)

set "error_occurred=0"

copy /y "C:\Users\skrol\OneDrive\Documentos\GitHub\SkQuests\SKquests.lua" "c:\Program Files\Ascension Launcher\resources\client\Interface\AddOns\SKquests\SKquests.lua"
if %errorlevel% neq 0 set "error_occurred=1"

copy /y "C:\Users\skrol\OneDrive\Documentos\GitHub\SkQuests\SKquests_Localization.lua" "c:\Program Files\Ascension Launcher\resources\client\Interface\AddOns\SKquests\SKquests_Localization.lua"
if %errorlevel% neq 0 set "error_occurred=1"

copy /y "C:\Users\skrol\OneDrive\Documentos\GitHub\SkQuests\SKquests_UI.lua" "c:\Program Files\Ascension Launcher\resources\client\Interface\AddOns\SKquests\SKquests_UI.lua"
if %errorlevel% neq 0 set "error_occurred=1"

copy /y "C:\Users\skrol\OneDrive\Documentos\GitHub\SkQuests\SKquests_Themes.lua" "c:\Program Files\Ascension Launcher\resources\client\Interface\AddOns\SKquests\SKquests_Themes.lua"
if %errorlevel% neq 0 set "error_occurred=1"

if "%error_occurred%" == "1" (
    echo.
    echo ============================================================
    echo ERROR: One or more files could not be copied!
    echo This usually happens because World of Warcraft is running.
    echo PLEASE CLOSE THE GAME CLIENT and run this script again.
    echo ============================================================
    echo.
) else (
    echo.
    echo ============================================================
    echo Files copied successfully to the game folder!
    echo ============================================================
    echo.
)
pause
