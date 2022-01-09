:: Compile LuaNext for Windows
:: Run this from the parent directory of release/build

set output=release
set dir=./%output%/build/windows

set glue=%dir%/glue.exe
set srlua=%dir%/srlua.exe

set command=%glue% %srlua% main.lua %output%/LuaNext.exe

mkdir %output%

powershell -Command %command%