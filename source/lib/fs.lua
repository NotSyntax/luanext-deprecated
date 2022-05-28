class fs
    directory = '.'

    constructor(directory)
        self .= directory
    end

    method mkdir(directory)
        os.execute('mkdir ' .. self.directory .. directory)
    end

    method resolvedir(directory)
        local construction = self.directory .. '/'
        local match = string.gmatch(line, "[^/]+")
        local i = 0

        for token in match do
            construction ..= token
            i += 1

            if i == #match then
                break
            end

            self:mkdir(construction)
        end
    end
end

return fs