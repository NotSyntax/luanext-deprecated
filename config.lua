return {
    version = '1.0.0',
    name = 'LuaNext',

    description = '🌑 The LuaNext compiler, written in Lua for Lua.',
    author = 'LuaUp',

    output = 'release',
    scripts = {
        build = function()
            if os then
                if package.cpath:match("%p[\\|/]?%p(%a+)") == 'dll' then
                    os.execute(io.popen("cd"):read('*l') .. '/release/build/build_windows.bat')
                elseif package.cpath:match("%p[\\|/]?%p(%a+)") == 'so' then
                    os.execute(string.gsub(debug.getinfo(1).source, "^@(.+/)[^/]+$", "%1") .. '/release/build/build_linux.sh')
                end
            else
                
            end
        end
    }
}