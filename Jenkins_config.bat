@ECHO OFF

:: ****** Usage ******
::
:: --type         <debug|release>  Affect build by setting CMAKE_BUILD_TYPE
:: --mode         <32bit|64bit>    Bitness of built uLogR and loaded squish
:: --<testsuite>  <true|false>     Set to false to skip corresponding testsuite

:loop
IF NOT "%1"=="" (
    IF "%1"=="--type" (
        SET JENKINS_BUILD_TYPE=%2
        SHIFT
    )
    IF "%1"=="--mode" (
        SET JENKINS_BUILD_MODE=%2
        SHIFT
    )
    if "%1"=="--Api" (
        set RUN_API=%2
        IF NOT "%2"=="false" IF NOT "%2"=="true" set RUN_API=true
        SHIFT
    )
    if "%1"=="--Core" (
        set RUN_CORE=%2
        IF NOT "%2"=="false" IF NOT "%2"=="true" set RUN_CORE=true
        SHIFT
    )
    if "%1"=="--ATConsole" (
        set RUN_ATCONSOLE=%2
        IF NOT "%2"=="false" IF NOT "%2"=="true" set RUN_ATCONSOLE=true
        SHIFT
    )
    if "%1"=="--BandWidth" (
        set RUN_BANDWIDTH=%2
        IF NOT "%2"=="false" IF NOT "%2"=="true" set RUN_BANDWIDTH=true
        SHIFT
    )
    if "%1"=="--Dashboard" (
        set RUN_DASHBOARD=%2
        IF NOT "%2"=="false" IF NOT "%2"=="true" set RUN_DASHBOARD=true
        SHIFT
    )
    if "%1"=="--Evi" (
        set RUN_EVI=%2
        IF NOT "%2"=="false" IF NOT "%2"=="true" set RUN_EVI=true
        SHIFT
    )
    if "%1"=="--FlashFileSystemViewer" (
        set RUN_FLASHFILESYSTEMVIEWER=%2
        IF NOT "%2"=="false" IF NOT "%2"=="true" set RUN_FLASHFILESYSTEMVIEWER=true
        SHIFT
    )
    if "%1"=="--GenericMessageView" (
        set RUN_GENERICMESSAGEVIEW=%2
        IF NOT "%2"=="false" IF NOT "%2"=="true" set RUN_GENERICMESSAGEVIEW=true
        SHIFT
    )
    if "%1"=="--GraphViewer" (
        set RUN_GRAPHVIEWER=%2
        IF NOT "%2"=="false" IF NOT "%2"=="true" set RUN_GRAPHVIEWER=true
        SHIFT
    )
    if "%1"=="--ListView" (
        set RUN_LISTVIEW=%2
        IF NOT "%2"=="false" IF NOT "%2"=="true" set RUN_LISTVIEW=true
        SHIFT
    )
    if "%1"=="--MemoryViewer" (
        set RUN_MEMORYVIEWER=%2
        IF NOT "%2"=="false" IF NOT "%2"=="true" set RUN_MEMORYVIEWER=true
        SHIFT
    )
    if "%1"=="--MessageConsole" (
        set RUN_MESSAGECONSOLE=%2
        IF NOT "%2"=="false" IF NOT "%2"=="true" set RUN_MESSAGECONSOLE=true
        SHIFT
    )
    if "%1"=="--ObjectViewer" (
        set RUN_OBJECTVIEWER=%2
        IF NOT "%2"=="false" IF NOT "%2"=="true" set RUN_OBJECTVIEWER=true
        SHIFT
    )
    if "%1"=="--PSMessageViewer" (
        set RUN_PSMESSAGEVIEWER=%2
        IF NOT "%2"=="false" IF NOT "%2"=="true" set RUN_PSMESSAGEVIEWER=true
        SHIFT
    )
    if "%1"=="--RuntimeFilter" (
        set RUN_RUNTIMEFILTER=%2
        IF NOT "%2"=="false" IF NOT "%2"=="true" set RUN_RUNTIMEFILTER=true
        SHIFT
    )
    if "%1"=="--SettingsManager" (
        set RUN_SETTINGSMANAGER=%2
        IF NOT "%2"=="false" IF NOT "%2"=="true" set RUN_SETTINGSMANAGER=true
        SHIFT
    )
    if "%1"=="--TestManager" (
        set RUN_TESTMANAGER=%2
        IF NOT "%2"=="false" IF NOT "%2"=="true" set RUN_TESTMANAGER=true
        SHIFT
    )
    SHIFT
    GOTO :loop
)

IF NOT "%JENKINS_BUILD_TYPE%" == "release" (
    IF NOT "%JENKINS_BUILD_TYPE%" == "debug" (
        ECHO Please specify build type using ^'--type ^<release^|debug^>^' & exit /b 1
    )
)
IF NOT "%JENKINS_BUILD_MODE%" == "32bit" (
    IF NOT "%JENKINS_BUILD_MODE%" == "64bit" (
        ECHO Please specify build mode using ^'--mode ^<32bit^|64bit^>^' & exit /b 1
    )
)

ECHO =================================================================================================
ECHO Running configurations for Squish test for uLogR %JENKINS_BUILD_MODE% %JENKINS_BUILD_TYPE% build.
ECHO =================================================================================================

REM *********************************************
REM ************   PART ONE    ******************
REM ************  ENVIRONMENT  ******************
REM *********************************************


REM ============= system info ==================
systeminfo

REM ============== env vars ====================
set

REM ========== load setup_HOST =================
call app load %JENKINS_BUILD_MODE% .\cbs\setup_HOST

REM ============== App list ====================
call app list

@echo on

REM *********************************************
REM ***********    PART TWO    ******************
REM *********** BUILD & DEPLOY ******************
REM *********************************************

set ULOGRBUILD=%WORKSPACE%\BUILD
set BUILD=%ULOGRBUILD%
mkdir %BUILD%

REM Temporary workaround for Nexus
set UBX_NEXUS_SERVER=%UBX_NEXUS_MASTER%

@echo on

cd %BUILD%

REM ==============================================
ECHO Current working directory is %CD%
REM ==============================================

REM ********************************
REM *******     CMAKE     **********
REM ********************************

:: Arguments checking has been handled in the beginning, so it can only be debug or release
IF "%JENKINS_BUILD_TYPE%" == "debug" cmake-vcc -G Ninja %WORKSPACE%\uLogR\src
IF "%JENKINS_BUILD_TYPE%" == "release" cmake-vcc -G Ninja %WORKSPACE%\uLogR\src -DCMAKE_BUILD_TYPE=RelWithDebInfo

REM ********************************
REM *******     NINJA     **********
REM ********************************

ninja -v -j2

REM ********************************
REM *******     DEPLOY    **********
REM ********************************

ninja install

REM *********************************************
REM ************     PART FOUR     **************
REM ************      SQUISH       **************
REM *********************************************

@echo off

REM ==============================================
ECHO Clean up old report, settings file, crash dumps, temporary files...
REM ==============================================
:: Clean up old report
if exist %WORKSPACE%\squishrunner_report rmdir /s /q %WORKSPACE%\squishrunner_report
mkdir %WORKSPACE%\squishrunner_report
if exist %WORKSPACE%\squishrunner_report_xml rmdir /s /q %WORKSPACE%\squishrunner_report_xml
if exist %WORKSPACE%\squishserver.out del %WORKSPACE%\squishserver.out


:: Clean up old Squish crash dumps
if exist %USERPROFILE%\AppData\Local\Temp\SquishDumps rmdir /s /q %USERPROFILE%\AppData\Local\Temp\SquishDumps rmdir


:: Clean up settings file
:: uLogR settings directory should be empty to ensure tests run properly.
if exist %userprofile%\.ubx\ulogr rmdir /s /q %userprofile%\.ubx\ulogr
mkdir %userprofile%\.ubx\ulogr


:: Avoid problems with temporary files.
for /d %%d in (%TEMP%\Decompressor*) do rd /s /q %%d
for /d %%d in (%TEMP%\evi*) do rd /s /q %%d
for %%f in (%TEMP%ulogr*) do del %%f


:: Workaround for T_ULOGR-1687
:: Remove possible previously generated .ulogr files which store running records for TestManager and break test.
cd BUILD
del /q /f *.ulogr
cd %WORKSPACE%
REM ==============================================
echo Current working directory is %CD%
REM ==============================================


REM ==============================================
echo Set up squish
REM ==============================================
:: Setup environment for squish
call app load "%JENKINS_BUILD_MODE%" %ULOGRROOT%\setup_squish
@echo on


:: Needed on Windows for EVI to find evi.exe when running from delivery directory
REM set ULOGR=%ULOGRBUILD%\delivery


:: Workaround for Squish problem
::set SQUISH_NO_CRASHHANDLER=1
::reg add "HKCU\Software\Microsoft\Windows\Windows Error Reporting" /v DontShowUI /f /t ::REG_DWORD /d 1
set SQUISH_DUMP_FILE_USE_MSGBOX=0


:: Workaround for suite_BDD_ObjectViewer
:: .sv file needs to be open in a test case and hence a default program association should be configured.
:: This can be easily done by "assoc .sv=txtfile", but it requires admin rights.
:: Therefore, we opt for adding registry value for current user as a workaround.
reg add HKCU\SOFTWARE\Classes\.sv /t REG_SZ /d txtfile /f


:: Generate a license here, prevents this from getting lost when jenkins is restarted
echo JEE-2JHK2-2JU8A-2J2 > %WORKSPACE%\.squish-3-license
set SQUISH_LICENSEKEY_DIR=%WORKSPACE%


:: Make sure squishserver isn't accidentally running
squishserver --stop --port %port%


:: Start squishserver
set port=4322
start /B squishserver --port %port% --verbose  &>squishserver.out


:: Sleep for 5 seconds; give time for squishserver to start up:
ping 127.0.0.1 -n 6 >nul


set SQUISH_TEMP=%ULOGRBUILD%/squish_temp
if not exist %SQUISH_TEMP:/=\% mkdir %SQUISH_TEMP:/=\%
set DECODER_LIB_PREFIX=
set DECODER_LIB_SUFFIX=dll
set EVITA_TARGET_PORT=8890
set EVITA_BIN=%ULOGRBUILD%/Output/bin/evita


: Register AUT to squishserver
IF "%JENKINS_BUILD_MODE%" == "32bit" squishserver --config addAUT ulogr %ULOGRBUILD%\delivery\lib32
IF "%JENKINS_BUILD_MODE%" == "64bit" squishserver --config addAUT ulogr %ULOGRBUILD%\delivery\lib64
squishserver --config addAUT ulogr.bat %ULOGRBUILD%\delivery\bin
squishserver --config addAttachableAUT ulogr localhost:9999
squishrunner --config addAttachableAUT ulogr localhost:9999


REM ===========================================
REM Squish server settings:
more %USERPROFILE%\AppData\Roaming\froglogic\Squish\ver1\server.ini
REM ===========================================


::This adds this path to its settings file paths.ini
set SQUISH_SCRIPT_DIR=%ULOGRROOT%/src/tests/squish/common
squishrunner --port %PORT% --config setGlobalScriptDirs %SQUISH_SCRIPT_DIR%

goto :suitestobeselectedfrom
:: !!! suite_BDD_FlashFSViewer is the old version of suite_BDD_FlashFileSystemViewer and should NOT be used anymore
set suites=^
  %workspace%\uLogR\src\api\tests\suite_BDD_Api ^
  %workspace%\uLogR\src\core\tests\suite_BDD_Core ^
  %workspace%\uLogR\src\plugins\at_console\tests\suite_BDD_ATConsole ^
  %workspace%\uLogR\src\plugins\bandwidth\tests\suite_BDD_BandWidth ^
  %workspace%\uLogR\src\plugins\dashboard\tests\suite_BDD_Dashboard ^
  %workspace%\uLogR\src\plugins\evi_plugin\tests\suite_BDD_Evi ^
  %workspace%\uLogR\src\plugins\flashfs_viewer\tests\suite_BDD_FlashFSViewer ^
  %workspace%\uLogR\src\plugins\flash_filesystem_viewer\tests\suite_BDD_FlashFileSystemViewer ^
  %workspace%\uLogR\src\plugins\generic_message_view\tests\suite_BDD_GenericMessageView ^
  %workspace%\uLogR\src\plugins\graph_viewer\tests\suite_BDD_GraphViewer ^
  %workspace%\uLogR\src\plugins\view\tests\suite_BDD_ListView ^
  %workspace%\uLogR\src\plugins\memory_viewer\tests\suite_BDD_MemoryViewer ^
  %workspace%\uLogR\src\plugins\message_console\tests\suite_BDD_MessageConsole ^
  %workspace%\uLogR\src\plugins\object_viewer\tests\suite_BDD_ObjectViewer ^
  %workspace%\uLogR\src\plugins\ps_message_viewer\tests\suite_BDD_PSMessageViewer ^
  %workspace%\uLogR\src\plugins\runtime_filter\tests\suite_BDD_RuntimeFilter ^
  %workspace%\uLogR\src\plugins\settings_manager\tests\suite_BDD_SettingsManager ^
  %workspace%\uLogR\src\plugins\test_manager\tests\suite_BDD_TestManager
:suitestobeselectedfrom

echo off

set suites=

IF "%RUN_API%"=="true" set suites=%suites% ^
  %workspace%\uLogR\src\api\tests\suite_BDD_Api
IF "%RUN_CORE%"=="true" set suites=%suites% ^
  %workspace%\uLogR\src\core\tests\suite_BDD_Core
IF "%RUN_ATCONSOLE%"=="true" set suites=%suites% ^
  %workspace%\uLogR\src\plugins\at_console\tests\suite_BDD_ATConsole
IF "%RUN_BANDWIDTH%"=="true" set suites=%suites% ^
  %workspace%\uLogR\src\plugins\bandwidth\tests\suite_BDD_BandWidth
IF "%RUN_DASHBOARD%"=="true" set suites=%suites% ^
  %workspace%\uLogR\src\plugins\dashboard\tests\suite_BDD_Dashboard
IF "%RUN_EVI%"=="true" set suites=%suites% ^
  %workspace%\uLogR\src\plugins\evi_plugin\tests\suite_BDD_Evi
IF "%RUN_FLASHFILESYSTEMVIEWER%"=="true" set suites=%suites% ^
  %workspace%\uLogR\src\plugins\flash_filesystem_viewer\tests\suite_BDD_FlashFileSystemViewer
IF "%RUN_GENERICMESSAGEVIEW%"=="true" set suites=%suites% ^
  %workspace%\uLogR\src\plugins\generic_message_view\tests\suite_BDD_GenericMessageView
IF "%RUN_GRAPHVIEWER%"=="true" set suites=%suites% ^
  %workspace%\uLogR\src\plugins\graph_viewer\tests\suite_BDD_GraphViewer
IF "%RUN_LISTVIEW%"=="true" set suites=%suites% ^
  %workspace%\uLogR\src\plugins\view\tests\suite_BDD_ListView
IF "%RUN_MEMORYVIEWER%"=="true" set suites=%suites% ^
  %workspace%\uLogR\src\plugins\memory_viewer\tests\suite_BDD_MemoryViewer
IF "%RUN_MESSAGECONSOLE%"=="true" set suites=%suites% ^
  %workspace%\uLogR\src\plugins\message_console\tests\suite_BDD_MessageConsole
IF "%RUN_OBJECTVIEWER%"=="true" set suites=%suites% ^
  %workspace%\uLogR\src\plugins\object_viewer\tests\suite_BDD_ObjectViewer
IF "%RUN_PSMESSAGEVIEWER%"=="true" set suites=%suites% ^
  %workspace%\uLogR\src\plugins\ps_message_viewer\tests\suite_BDD_PSMessageViewer
IF "%RUN_RUNTIMEFILTER%"=="true" set suites=%suites% ^
  %workspace%\uLogR\src\plugins\runtime_filter\tests\suite_BDD_RuntimeFilter
IF "%RUN_SETTINGSMANAGER%"=="true" set suites=%suites% ^
  %workspace%\uLogR\src\plugins\settings_manager\tests\suite_BDD_SettingsManager
IF "%RUN_TESTMANAGER%"=="true" set suites=%suites% ^
  %workspace%\uLogR\src\plugins\test_manager\tests\suite_BDD_TestManager

echo on

:: Skip scenarios tagged with @target and @T_ULOGR-1346
:: Ref: https://wiki.u-blox.com/bin/view/Cellular/SquishGuiTester#List_of_TAG_39s_to_be_used_for_uLogR_test_scenarios
set tags=--tags ~@target --tags ~@T_ULOGR-1346 --tags ~@workinprogress


REM ============== env vars ====================
set


REM ============== App list ====================
call app list


@echo on
for %%s in (%suites%) do (
  set suite=%%s
  set timeout=--timeout 60

  echo ------------------ START: Suite %%s --------------------------
  echo REM Please wait ...
  ping 127.0.0.1 -n 11 >nul

  echo Wait end
  
  squishrunner --port %port% --testsuite %%s %tags% %timeout% ^
        --reportgen html,%WORKSPACE%\squishrunner_report ^
        --reportgen stdout ^
        >> %WORKSPACE%\squishrunner_report\squishrunner.out 2>&1
  
        
  echo ------------------ FINISHED: Suite %%s --------------------------
  ping 127.0.0.1 -n 6 >nul

  @echo on
)
@echo on


REM ========== Stop Squish Server ==============
squishserver --stop --port %port%


:Copy all the dump files from crashing
mkdir %WORKSPACE%\SquishDumps\
if exist %userprofile%\AppData\Local\Temp\SquishDumps\ copy %userprofile%\AppData\Local\Temp\SquishDumps\*.dmp %WORKSPACE%\SquishDumps\

goto realend

REM #
REM # Is it STABLE (Green), UNSTABLE (Yellow), or FAILED (Red)?
REM #

cd %WORKSPACE%
set evaluate_squish_report=%workspace%\uLogR\src\tests\squish\scripts\evaluate_squish_report.py
type nul >> build.status
python %WORKSPACE%\uLogR\src\tests\squish\scripts\evaluate_squish_report.py --tag @workinprogress *.xml

:realend

















































:testend

::Clean environment variables used for arguments handling
set JENKINS_BUILD_MODE=
set JENKINS_BUILD_TYPE=

:theend
