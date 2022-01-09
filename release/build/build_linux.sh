#!/bin/sh

# Compile LuaNext for Linux
# Run this from the parent directory of release/build

output="release"
dir="./$output/build/linux"

glue="$dir/glue"
srlua="$dir/srlua"

$($glue $srlua main.lua $output/LuaNext)