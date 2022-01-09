return {
    version = '1.0.0',
    name = 'LuaNext',

    description = '🌑 The LuaNext compiler, written in Lua for Lua.',
    author = 'LuaUp',

    output = 'release',
    scripts = {
        build = function()
            if os then
                os.execute(io.popen("cd"):read('*l') .. '/release/build/build.bat')  
            else
                
            end
        end
    }
}