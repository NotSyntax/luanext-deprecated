#!/bin/sh

# Compile LuaNext for Linux
# Run this from the parent directory of release/build

echo "Building LuaNext"
echo "Target: Ubuntu"
echo "----------------"

output="release"
dir="./$output/build/linux"

echo "Cleaning $output"
rm -rf "$output/LuaNext"

glue="$dir/glue"
srlua="$dir/srlua"
lua="$dir/lua"
squish="$dir/../global/squish.lua"
build="$dir/../global/build.lua"

echo "Generating Squish file"
$($lua $build main.lua -f)

echo "Renaming Squish file"
mv "squishy.new" "squishy"

echo "Specifying output"
$(echo "Output './$output/build/output.lua'">>squishy)

echo "Squishing LuaNext"
$($lua $squish -q)

echo "Compiling to executable"
$($glue $srlua ./$output/build/output.lua $output/LuaNext)

echo "Cleaning temporary files"
rm -rf "squishy"
rm -rf "./$output/build/output.lua"

echo "Finished!"