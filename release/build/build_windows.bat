:: Compile LuaNext for Windows
:: Run this from the parent directory of release/build
@echo off

echo Building LuaNext
echo Target: Windows
echo ----------------

set output=release
set dir=./%output%/build/windows

echo Cleaning %output%
del /q %output%\\clamp.exe

set glue=%dir%/glue.exe
set srlua=%dir%/srlua.exe
set lua=%dir%/lua.exe
set squish=%dir%/../global/squish.lua
set build=%dir%/../global/build.lua

set gen=%lua% %build% main.lua -f
set collapse=%lua% %squish% -q
set command=%glue% %srlua% ./release/build/output.lua %output%/luanext.exe

echo Generating Squish file
powershell -Command %gen%

echo Renaming Squish file
rename squishy.new squishy

echo Specifying output
echo Output './%output%/build/output.lua'>>squishy

echo Squishing LuaNext
powershell -Command %collapse%

echo Compiling to .exe
powershell -Command %command%

echo Cleaning temporary files
del squishy
del %output%\\build\\output.lua

echo Finished!