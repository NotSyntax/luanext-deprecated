return {
    delimiters = {
        ['"'] = true,
        ['\''] = true,
        ['`'] = true,
    },

    multiline = {
        start = '[',
        close = ']'
    },

    token = {
        type = 'string',
        characters = {},
        multiline = false,
        delimiter = nil,
        escaped = false,
        inbetweens = 0,
        counting = false
    }
}