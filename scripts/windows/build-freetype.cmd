@echo off
setlocal
REM Must run after Windows SDK 7.1 SetEnv.cmd has loaded MSVC 2010 x64.
if not defined FT_SOURCE (echo ERROR: FT_SOURCE missing 1>&2 & exit /b 2)
if not defined FT_INSTALL (echo ERROR: FT_INSTALL missing 1>&2 & exit /b 2)
if not defined CMAKE_EXE (echo ERROR: CMAKE_EXE missing 1>&2 & exit /b 2)
where nmake.exe
if errorlevel 1 (echo ERROR: SDK 7.1 NMake not found 1>&2 & exit /b 2)
set "FT_BUILD=%~dp0..\..\work\freetype-build"
echo Building FreeType 2.10.4 with the Windows SDK 7.1 MSVC compiler...
"%CMAKE_EXE%" -S "%FT_SOURCE%" -B "%FT_BUILD%" -G "NMake Makefiles" -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="%FT_INSTALL%" -DCMAKE_DISABLE_FIND_PACKAGE_ZLIB=TRUE -DCMAKE_DISABLE_FIND_PACKAGE_BZip2=TRUE -DCMAKE_DISABLE_FIND_PACKAGE_PNG=TRUE -DCMAKE_DISABLE_FIND_PACKAGE_HarfBuzz=TRUE -DCMAKE_DISABLE_FIND_PACKAGE_BrotliDec=TRUE
if errorlevel 1 exit /b %ERRORLEVEL%
"%CMAKE_EXE%" --build "%FT_BUILD%" --parallel 2
if errorlevel 1 exit /b %ERRORLEVEL%
"%CMAKE_EXE%" --install "%FT_BUILD%"
if errorlevel 1 exit /b %ERRORLEVEL%
if not exist "%FT_INSTALL%\include\freetype2\ft2build.h" (echo ERROR: FreeType headers missing 1>&2 & exit /b 2)
if not exist "%FT_INSTALL%\lib\freetype.lib" (echo ERROR: FreeType import library missing 1>&2 & exit /b 2)
if not exist "%FT_INSTALL%\bin\freetype.dll" (echo ERROR: FreeType DLL missing 1>&2 & exit /b 2)
REM JDK 7 assumes that freetype.dll and freetype.lib share one directory.
copy /Y "%FT_INSTALL%\bin\freetype.dll" "%FT_INSTALL%\lib\freetype.dll" >nul
if errorlevel 1 exit /b %ERRORLEVEL%
echo Built FreeType for native Windows x64: %FT_INSTALL%
exit /b 0
