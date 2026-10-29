@if "%DEBUG%"=="" @echo off
@rem Set local directory if specified
@if "%CD%"=="" set CD=%~dp0
@rem Resolve any "." and ".." in CD
@setlocal enabledelayedexpansion
@set "CD=%CD%"
@if not "%CD:~-1%"=="\" set "CD=%CD%\"
@for /f "delims=" %%i in ('"%CD%"') do @set CD=%%~fi
@endlocal & set CD=%CD%

@rem Set Classpath
@set DEFAULT_JVM_OPTS="-Xmx64m" "-Xms64m"
@set JAVA_EXE=java.exe
%JAVA_EXE% -version >NUL 2>&1 @if %ERRORLEVEL% equ 0 @set JAVA_EXE=java.exe
@set JAVA_EXE=%JAVA_EXE%
@rem Setup the command line
@set CLASSPATH=%CLASSPATH%;"%CD%\gradle\wrapper\gradle-wrapper.jar"

@rem Execute Gradle
"%JAVA_EXE%" %DEFAULT_JVM_OPTS% %JAVA_OPTS% %GRADLE_OPTS% "-Dorg.gradle.appname=%APP_BASE_NAME%" -classpath "%CLASSPATH%" org.gradle.wrapper.GradleWrapperMain %*
