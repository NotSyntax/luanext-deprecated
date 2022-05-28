local parser = {}

local scanner = require('source/parser/scanner')
local frog = require('source/lib/frog')
local options = require('source/lib/options')
local config = require('config')

--[[

comment <- '--' (!\n)* '\n'? | '--[' <'='*> '[' (!)* ']' <'='*> ']'
number <- digit* '.'? digit+ | '0x' digit+
string <- <('"`)> (!\n)* <('"`)> | '[' <'='*> '[' (!)* ']' <'='*> ']'
identifier <- non_digit ascii*

chunk {
    version
    length

    type = 'chunk'

    options .= string ';'?
    comments .= { !!comment* }
    body .= { statement* }

    imports .= { !!import* }
    exports .= { !!export* }

    return .= return?
}

statements {
    statement*
}

block .= statements

statement {
    ';' |             ✔️
    if |              ✔️
    while |           ✔️
    do |              ✔️
    for |             ✔️
    repeat |          ✔️
    function |        ✔️
    method |          ✔️
    class |           ✔️
    switch |          ✔️
    enum |            ✔️
    localfunction |   ✔️
    localstatement |  ✔️
    label |           ✔️
    break |           ✔️
    goto |            ✔️
    return |          ✔️
    exprstat |        ✔️
    define            ✔️
}

return {
    'return'
    type = 'return'
    body .= { expression, (',' expression)* }?
}

localfunction {
    'local'
    'function'
    type = 'localfunction'
    name .= identifier
    body .= body
}

localstatement {
    'local'
    type = 'localstatement'
    names .= { identifier, (',' identifier)* }
    (equal
    values .= { expression, (',' expression)* }
    )?
}

define {
    'define'
    type = 'define'
    name .= identifier
    (
        '='
        type = 'definition'
        value .= expression
    ) | (
        type = 'function'
        body .= body
    )?
}

equal {
    '=' | '..=' | '+=' | '-=' | '*=' | '.=' | '/=' | '&=' | '|=' | '#=' | '^='
}

expression .= ternary | subexpression

simple {
    number | string | 'nil' | 'true' | 'false' | '...' | table | 'function' body | suffixed
}

unary {
    'not'|
    '!'|
    '#'|
    '~'
}

binary {
    '+' |
    '-' |
    '*' |
    '%' |
    '^' |
    '/' |
    '&' |
    '|' |
    '_' |
    '//'|
    '=='|
    '~='|
    '!='|
    '!=='|
    '==='|
    '=|='|
    'and'|
    'or'|
    '&&'|
    '||'|
    '>>'|
    '<<'|
    '<'|
    '>'|
    '<='|
    '>='|
    '|>'|
    '=>'|
    '->'|
}

ternary {
    type = 'ternary'
    condition .= expression
    '?'
    truthy .= expression
    ':'
    falsey .= expression
}

subexpression {
    type = 'expression'
    value .= { (simple | unary, subexpression), (binary, subexpression)? }
}

primary {
    (
        identifier 
    ) | (
        '('
        expression
        ')'
    )
}

suffixed {
    type = 'suffixed'
    name .= { primary, (('.', identifier) | ('[', expression, ']') | (':', identifier, funcargs) | funcargs)? }
}

funcargs {
    (
        '('
        expression, (',', expression)*
        ')'
    ) | (
        table
    ) | string
}

rest {
    (
        ',',
        suffixed,
        rest
    ) | (
        '=',
        expression, 
        (',', expression)*
    )
}

exprstat {
    type = 'exprstat'
    index .= suffixed
    assign .= rest?
}

if {
    'if'

    type = 'if'
    clauses .= {
        then
        elseif*
        else?
    }

    'end'
}

switch {
    'switch'
    type = 'switch'
    condition .= expression

    'do'

    cases .= {
        case*
    }

    'end'
}

case {
    'case'
    type = 'case'
    value .= expression
    body .= block
    'end'
}

then {
    type = 'then'
    condition .= expression

    'then'

    body .= block
}

elseif {
    'else 'if' | 'elseif'
    then
    type = 'elseif'
}

else {
    'else'
    type = 'else'
    body .= block
}

condition .= expression

while {
    type = 'while'
    'while'
    condition .= condition
    'do'
    body .= block
    'end'
}

do {
    type = 'do'
    'do'
    body .= block
    'end'
}

repeat {
    'repeat'
    type = 'repeat'
    body .= statements
    'until'
    condition .= condition
}

fornum {
    type = 'number'
    variable .= identifier
    '='
    value .= expression
    ','
    limit .= expression
    (','
    step .= expression)?
    body .= do
}

forlist {
    type = 'list'
    variables .= { ((identifier ',')* identifier)+ }
    'in'
    body .= do
}

for {
    'for'
    type = 'for'
    body .= forlist | fornum
}

single .= identifier

function {
    'function'
    type = 'function'
    name .= { single, ('.', identifier)*, (':', identifier)? }?
    method = name[-2] == ':'
    body .= body
}

body {
    '('
    type = 'body'
    parameters .= [ identifier*, '...'? ]
    ')'
    body .= statements
    'end'
}

method {
    'method'
    type = 'method'
    name .= single
    body .= body
}

metamethod {
    'meta'
    type = 'metamethod'
    name .= single

    (body .= body) |
    ('='
    body .= expression)
}

classmethod {
    type .= 'get' | 'set'
    name .= single
    body .= body
}

classbody {
    (method |
    classmethod |
    metamethod |
    exprstat |
    define |
    enum
    )*
}

constructor {
    type .= 'constructor'
    'constructor'
    body .= body
}

class {
    'class'
    type = 'class'
    name .= identifier
    ('extends'
    extends .= identifier)?
    constructor .= <constructor>?
    body .= classbody

    'end'
}

label {
    'label' | <'::'>
    type = 'label'
    name .= identifier
    <'::'>
}

goto {
    'goto'
    type = 'goto'
    target .= identifier
}

break {
    'break'
    type .= 'break'
}

enum {
    'enum'
    type = 'enum'
    name .= { single, ('.', identifier)*, (':', identifier)? }
    ('{'

    body .= { enumvalue, (',', enumvalue)*, ','? }?

    '}')?
}

enumvalue {
    type = 'enumvalue'
    name .= identifier
    ('='
    value .= expression
    )?
}



]]--

function parser:new(tokens, raw, options)
    if not tokens then return end

    local _class = {}
    local cleaned = {}
    local comments = {}

    for i, token in ipairs(tokens) do
        if token.type ~= 'whitespace' and token.type ~= 'comment' then
            table.insert(cleaned, token)
        elseif token.type == 'comment' then
            table.insert(comments, self:clean(token))
        end
    end

    setmetatable(_class, self)
    self.__index = self

    _class.spaced = tokens
    _class.tokens = cleaned
    _class.index = 1
    _class.token = _class.tokens[_class.index]

    _class.lexed = scanner:new(raw)
    _class.options = options

    _class.raw = raw
    _class.tree = {
        version = config.version,
        
        type = 'chunk',
        length = #raw,

        comments = comments,
        body = {},
        options = '',
        variable = true
    }

    _class.ancestory = {}
    _class.node = _class.tree

    return _class
end

function parser:skip()
    if not self.token then return end

    self.index = self.index + 1
    self.token = self.tokens[self.index]

    return self.tokens[self.index - 1]
end

function parser:accept(typed, characters)
    if not self.token then return end

    if characters then
        if self.token.type == typed and table.concat(self.token.characters, '') == characters then
            return self:skip()
        end
    else
        if self.token.type == typed then
            return self:skip()
        end
    end

    return nil
end

function parser:test(typed, characters)
    if not self.token then return end

    if characters then
        if self.token.type == typed and table.concat(self.token.characters, '') == characters then
            return self.token
        end
    else
        if self.token.type == typed then
            return self.token
        end
    end

    return nil
end

function parser:peek(typed, characters)
    if not self.token then return end

    if characters then
        if self.tokens[self.index + 1].type == typed and table.concat(self.tokens[self.index + 1].characters, '') == characters then
            return self.tokens[self.index + 1]
        end
    else
        if self.tokens[self.index + 1].type == typed then
            return self.tokens[self.index + 1]
        end
    end

    return nil
end

function parser:expect(typed, characters)
    if not self.token then
        frog:parse(self.lexed.lines, #self.lexed.lines, 1, 2, 'Unexpected EOF, expected type "' .. typed .. '"')

        os.exit()
    end

    if self:test(typed, characters) then
        return self:accept(typed, characters)
    end

    if characters then
        frog:parse(self.lexed.lines, self.token.line, self.token.range[1], self.token.range[2],'Expected "' .. typed .. '" with value "' .. characters .. '"')
    else
        frog:parse(self.lexed.lines, self.token.line, self.token.range[1], self.token.range[2],'Expected "' .. typed .. '", got "' .. self.token.type .. '".')
    end

    os.exit()

    return nil
end

function parser:enter(node, body)
    table.insert(self.ancestory, { self.tree, self.node })
    self.tree = body
    self.node = node
end

function parser:exit()
    local index = table.remove(self.ancestory)

    self.tree = index[1]
    self.node = index[2]
end

function parser:name(token)
    return table.concat(token.characters, '')
end

-- Precedence

local priority = {
    ['add'] = { 10, 10 }, ['subtract'] = { 10, 10 },
    ['multiply'] = { 11, 11 }, ['modulus'] = { 11, 11 },
    ['power'] = { 14, 13 }, ['base'] = { 14, 13 },
    ['divide'] = { 11, 11 }, ['floor_division'] = { 11, 11 },
    ['bitwise_and'] = { 6, 6 }, ['bitwise_or'] = { 4, 4 }, ['bitwise_xor'] = { 5, 5 },
    ['left_shift'] = { 7, 7 }, ['right_shift'] = { 7, 7 },
    ['join'] = { 9, 8 },
    ['equality'] = { 3, 3 }, ['exact_equality'] = { 3, 3 },
    ['inequality'] = { 3, 3 }, ['exact_inequality'] = { 3, 3 },
    ['less'] = { 3, 3 }, ['greater'] = { 3, 3 },
    ['greater_equal'] = { 3, 3 }, ['less_equal'] = { 3, 3 },
    ['and'] = { 2, 2 }, ['or'] = { 1, 1 },
    ['ternary'] = { 0, 0 }
}

-- Nodes

function parser:labelstat()
    local name = ""
    if self:accept('label') then
        name = self:name(self:expect('identifier'))
    else
        self:expect('double_colon')
        name = self:name(self:expect('identifier'))
        self:expect('double_colon')
    end

    return {
        type = 'label',
        name = name
    }
end

function parser:gotostat()
    self:expect('goto')
    local name = self:name(self:expect('identifier'))

    return {
        type = 'goto',
        name = name
    }
end

function parser:block(node)
    local body = {}
    self:enter(node, body)
    self:statements()

    return body
end

function parser:unary()
    if self:test('not')
       or self:test('tilde')
       or self:test('bang') then
        return 'not'
    elseif self:test('hashtag') then
        return 'length'
    end

    return false
end

function parser:clean(token)
    if not token then return end
    if token.type == 'string' then
        token.counting = nil
        token.escaped = nil
        token.inbetweens = nil
        token.delimiter = nil
    elseif token.type == 'comment' then
        token.counting = nil
        token.inbetweens = nil
    end

    if not token.multiline then
        token.multiline = nil
    end

    if not token.hex then
        token.hex = nil
    end

    if not token.radix then
        token.radix = nil
    end

    return token
end

function parser:binary()
    if self:test('or') then
        return 'or'
    elseif self:test('and') then
        return 'and'
    elseif self:test('less') then
        return 'less'
    elseif self:test('greater') then
        return 'greater'
    elseif self:test('greater_equal') then
        return 'greater_equal'
    elseif self:test('less_equal') then
        return 'less_equal'
    elseif self:test('inequality') then
        return 'inequality'
    elseif self:test('equality') then
        return 'equality'
    elseif self:test('exact_equality') and not self.options:has('no-operators') then
        return 'exact_equality'
    elseif self:test('pipe') then
        return 'bitwise_or'
    elseif self:test('tilde') then
        return 'bitwise_xor'
    elseif self:test('ampersand') then
        return 'bitwise_and'
    elseif self:test('left_shift') then
        return 'left_shift'
    elseif self:test('right_shift') then
        return 'right_shift'
    elseif self:test('join') then
        return 'join'
    elseif self:test('plus') then
        return 'add'
    elseif self:test('arrow') and not self.options:has('no-operators') then
        return 'pipe'
    elseif self:test('minus') then
        return 'subtract'
    elseif self:test('star') then
        return 'multiply'
    elseif self:test('slash') then
        return 'divide'
    elseif self:test('floor_division') then
        return 'floor_division'
    elseif self:test('percent') then
        return 'modulus'
    elseif self:test('caret') then
        return 'power'
    elseif self:test('base') and not self.options:has('no-operators') then
        return 'base'
    end

    return false
end

function parser:arguments()
    local variable = false
    if not self:test('close_parenthesis') then
        if self:test('identifier') then
            table.insert(self.node.arguments, self:clean(self:accept('identifier')))
        elseif self:accept('dots') then
            self.node.variable = true
            variable = true
        else
            frog:parse(self.lexed.lines, self.token.line, self.token.range[1], self.token.range[2], 'Expected variable arguments or identifier in arguments.')
        end

        while not variable and self:accept('comma') do
            if self:test('identifier') then
                table.insert(self.node.arguments, self:clean(self:accept('identifier')))
            elseif self:accept('dots') then
                self.node.variable = true
                variable = true
            end
        end
    end
end

function parser:body()
    self:expect('open_parenthesis')
    self:arguments()
    self:expect('close_parenthesis')
    self:statements()
    self:expect('end')
end

function parser:primary()
    local expression
    if self:accept('open_parenthesis') then
        expression = self:expression()
        self:expect('close_parenthesis')
    elseif self:test('identifier') then
        return self:clean(self:accept('identifier'))
    elseif self.token then
        frog:parse(self.lexed.lines, self.token.line, self.token.range[1], self.token.range[2], 'Unexpected token "' .. self.token.type .. '" in expression.')
    else
        frog:parse(self.lexed.lines, #self.lexed.lines, 1, 2, 'Unexpected EOF')
    end

    return expression
end

function parser:tablefield()
    local node = {
        type = 'field',
    }

    if self:test('identifier') then
        if self:peek('equal') then
            node.key = self:clean(self:accept('identifier'))
            self:expect('equal')
            node.value = self:expression()
        else
            node.value = self:expression()
        end
    elseif self:accept('open_bracket') then
        node.key = self:expression()
        self:expect('close_bracket')
        self:expect('equal')
        node.value = self:expression()
    else
        node.value = self:expression()
    end

    return node
end

function parser:arrayfield()
    return {
        type = 'field',
        value = self:expression()
    }
end

function parser:array()
    local node = {
        type = 'array',
        body = {}
    }

    self:expect('open_bracket')

    if not self:test('close_bracket') then
        table.insert(node.body, self:arrayfield())

        while self:accept('comma') or self:accept('semicolon') do
            if self:test('close_bracket') then break end

            table.insert(node.body, self:arrayfield())
        end
    end

    self:expect('close_bracket')
    return node
end

function parser:table()
    local node = {
        type = 'table',
        body = {}
    }

    self:expect('open_brace')

    if not self:test('close_brace') then
        table.insert(node.body, self:tablefield())

        while self:accept('comma') or self:accept('semicolon') do
            if self:test('close_brace') then break end

            table.insert(node.body, self:tablefield())
        end
    end

    self:expect('close_brace')
    return node
end

function parser:call()
    local node = {
        type = 'call',
        arguments = {}
    }

    if self:accept('open_parenthesis') then
        if not self:test('close_parenthesis') then
            table.insert(node.arguments, self:expression())
            while self:accept('comma') do
                table.insert(node.arguments, self:expression())
            end
        end

        self:expect('close_parenthesis')
    elseif self:test('open_brace') then
        node.arguments = { self:table() }
    elseif self:test('open_bracket') then
        return self:table()
    elseif self:test('string') then
        node.arguments = { self:clean(self:accept('string')) }
    else
        if self.ternary then
            return nil
        else
            frog:parse(self.lexed.lines, self.token and self.token.line or #self.lexed.lines, self.token and self.token.range[1] or 1, self.token and self.token.range[2] or 2, 'Expected call when referencing method.')
        end
    end

    return node
end

function parser:suffixed()
    local node = {
        type = 'name',
        body = self:primary()
    }

    local level = node.body

    while true do
        if self:accept('period') then
            level.index = self:clean(self:expect('identifier'))
            level = level.index
            node['call'] = nil
        elseif self:accept('open_bracket') then
            level.index = self:expression()
            level = level.index
            level['yindex'] = true

            self:expect('close_bracket')
            node['call'] = nil
        elseif self:accept('colon') then
            local base = level

            level.index = self:clean(self:accept('identifier'))

            if not level.index then
                if self:test('colon') then
                    -- Skip possible method
                    self.index = self.index - 1
                    self.token = self.tokens[self.index]
                end

                while not self:test('colon') do
                    self.index = self.index - 1
                    self.token = self.tokens[self.index]
                end

                base.index = nil
                base['method'] = nil

                break
            end

            level = level.index
            level['method'] = true

            level.call = self:call()
            node.call = true

            if level.call then
                level = level.call
                node.arguments = level.arguments
            else
                if self:test('colon') then
                    -- Skip possible method
                    self.index = self.index - 1
                    self.token = self.tokens[self.index]
                end

                while not self:test('colon') do
                    self.index = self.index - 1
                    self.token = self.tokens[self.index]
                end

                base.index = nil
                base['method'] = nil

                break
            end
        elseif self:test('open_parenthesis') or self:test('open_brace') or self:test('string') then
            level.call = self:call()
            level = level.call
            node.arguments = level.arguments
            node.call = true
        else
            break
        end
    end

    return node
end

function parser:simple()
    if self:test('number') then
        return self:clean(self:accept('number'))
    elseif self:test('string') then
        return self:clean(self:accept('string'))
    elseif self:test('identifier', 'new') and self:peek('identifier') then
        return self:initialize()
    elseif self:accept('nil') then
        return {
            type = 'nil'
        }
    elseif self:accept('true') then
        return {
            type = 'boolean',
            value = true
        }
    elseif self:accept('false') then
        return {
            type = 'boolean',
            value = false
        }
    elseif self:test('dots') then
        if not self.node.variable then
            frog:parse(self.lexed.lines, self.token.line, self.token.range[1], self.token.range[2], 'Current block does not have a variable number of arguments.')
        end

        self:accept('dots')

        return {
            type = 'dots'
        }
    elseif self:test('open_brace') then
        return self:table()
    elseif self:test('open_bracket') and not self.options:has('no-arrays') then
        return self:array()
    elseif self:accept('function') then
        local node = {
            type = 'anonymous',
            body = {},
            arguments = {}
        }

        self:enter(node, node.body)
        self:body()
        return node
    else
        return self:suffixed()
    end

    self:skip()
end

function parser:subexpression(limit, bin)
    local expression = {}
    local unary = self:unary()

    if unary then
        self:skip()
        expression = {
            type = 'unary',
            action = unary,
            body = self:subexpression(12)
        }
    else
        expression = self:simple()
    end

    local binary = self:binary()
    while binary do
        if not priority[binary] then break end
        if priority[binary][1] < limit then break end

        self:skip()

        local operand, value = self:subexpression(priority[binary][2], true)

        expression = {
            type = 'binary',
            action = binary,
            left = expression,
            right = value
        }

        binary = operand
    end

    if bin then
        return binary, expression
    end

    local ternary = self:accept('question_mark')
    if ternary then
        self.ternary = true

        expression = {
            type = 'ternary',
            condition = expression,
            truthy = self:expression()
        }

        
        self.ternary = nil

        if not self:test('colon') and expression.truthy.type == 'call' then
            local index = expression.truthy.body
            local last = nil

            while index do
                if type(index) ~= 'table' then
                    break
                end

                if index['method'] then
                    last = index
                end

                index = index.call or index.index
            end

            if last then
                -- Backtrack and prune misread values
                last.call = nil
                last['method'] = nil
                last.index = nil

                while not self:test('colon') do
                    self.index = self.index - 1
                    self.token = self.tokens[self.index]
                end
            end
        end

        self:expect('colon')
        expression.falsey = self:expression()
    end

    return expression
end

function parser:expression()
    return self:subexpression(0)
end

function parser:thenblock()
    local node = {
        type = 'then',
        body = {}
    }

    local isThen = not not self:test('if')
    if not self:accept('if') and not self:accept('elseif') then
        self:expect('if')
    end

    local condition = self:expression()
    self:expect('then')

    node.type = isThen and 'then' or 'elseif'
    node.body = self:block(node)
    node.condition = condition
    return node
end

function parser:elseblock()
    local node = {
        type = 'else',
        body = {}
    }

    self:expect('else')

    node.body = self:block(node)
    return node
end

function parser:ifstat()
    local clauses = {
        self:thenblock()
    }

    while self:test('elseif') do
        table.insert(clauses, self:thenblock())
    end

    if self:test('else') then
        table.insert(clauses, self:elseblock())
    end

    self:expect('end')

    return {
        type = 'if',
        clauses = clauses
    }
end

function parser:whilestat()
    local node = {
        type = 'while',
        body = {},
        condition = {}
    }
    self:expect('while')
    node.condition = self:expression()
    self:expect('do')
    node.body = self:block(node)
    self:expect('end')

    return node
end

function parser:forstat()
    local node = {
        type = 'for',
        body = {},
        variables = {}
    }

    self:expect('for')

    table.insert(node.variables, self:clean(self:expect('identifier')))
    if self:accept('equal') then
        node.initial = self:expression()
        self:expect('comma')
        node.limit = self:expression()
        
        if self:accept('comma') then
            node.step = self:expression()
        end
    elseif self:test('comma') or self:test('in') then
        while self:accept('comma') do
            table.insert(node.variables, self:clean(self:expect('identifier')))
        end

        self:expect('in')

        node.list = self:expression()
    else
        frog:parse(self.lexed.lines, self.token.line, self.token.range[1], self.token.range[2], 'Expected "=" or "in" in for statement.')
    end

    self:expect('do')

    node.body = self:block(node)

    self:expect('end')
    return node
end

function parser:repeatstat()
    local node = {
        type = 'repeat',
        body = {},
        condition = {}
    }

    self:expect('repeat')
    node.body = self:block(node)
    self:expect('until')
    node.condition = self:expression()

    return node
end

function parser:functionstat()
    local node = {
        type = 'function',
        name = {},
        body = {},
        arguments = {}
    }

    self:expect('function')

    node.name = self:clean(self:expect('identifier'))
    local level = node.name

    while self:accept('period') do
        level.index = self:clean(self:expect('identifier'))
        level = level.index
    end

    if self:accept('colon') then
        level.index = self:clean(self:expect('identifier'))
        level = level.index
        level['method'] = true
    end

    self:enter(node, node.body)
    self:body()

    return node
end

function parser:casestat()
    self:expect('case')

    local node = {
        type = 'case',
        value = self:expression(),
        body = {}
    }

    self:expect('do')
    node.body = self:block(node)

    return node
end

function parser:switchstat()
    self:expect('switch')

    local node = {
        type = 'switch',
        condition = {},
        cases = {}
    }

    node.condition = self:expression()
    self:expect('do')

    local hasCase = false

    while self:test('case') do
        hasCase = true
        table.insert(node.cases, self:casestat())
    end

    if self:accept('default') then
        hasCase = true
        local _default = {
            type = 'default',
            body = {}
        }

        self:expect('do')
        _default.body = self:block(_default)

        node['default'] = _default
    end

    local target = self.token
    if hasCase and not self.options:has('no-close-case') then
        self:expect('end')
    end

    if not self:test('end') and hasCase then
        frog:parse(self.lexed.lines, target.line, target.range[1], target.range[2], 'Expected "end" to close case statements.')
    else
        self:expect('end')
    end

    return node
end

function parser:methodstat()
    self:expect('method')

    local node = {
        type = 'method',
        body = {},
        arguments = {},
        name = self:clean(self:expect('identifier'))
    }

    self:enter(node, node.body)
    self:body()

    return node
end

function parser:enumvalue()
    local node = {
        type = 'enumvalue',
        name = self:clean(self:expect('identifier')),
    }

    if self:accept('equal') then
        node.value = self:expression()
    end

    return node
end

function parser:enumstat()
    self:expect('enum')
    local node = {
        type = 'enum',
        values = {}
    }

    node.name = self:clean(self:expect('identifier'))
    local level = node.name

    while self:accept('period') do
        level.index = self:clean(self:expect('identifier'))
        level = level.index
    end

    self:expect('open_brace')

    if self:test('identifier') then
        table.insert(node.values, self:enumvalue())

        while self:accept('comma') do
            if self:test('close_brace') then break end
            table.insert(node.values, self:enumvalue())
        end
    end

    self:expect('close_brace')
    return node
end

function parser:classmethod()
    local methodType = 'getter'
    if self:accept('identifier', 'get') then
        methodType = 'getter'
    elseif self:accept('identifier', 'set') then
        methodType = 'setter'
    else
        self:expect('identifier', 'get')
    end

    local node = {
        type = methodType,
        body = {},
        arguments = {},
        name = self:clean(self:expect('identifier')),
    }

    self:enter(node, node.body)
    self:body()
    
    return node
end

function parser:metamethod()
    self:expect('meta')

    local node = {
        type = 'meta',
        body = {},
        name = self:clean(self:expect('identifier')),
    }

    if self:accept('equal') then
        node.value = self:expression()
        node.body = nil
    else
        node.arguments = {}
        self:enter(node, node.body)
        self:body()
    end
    
    return node
end

function parser:constructorstat()
    local fallback = self.token
    self:expect('identifier', 'constructor')

    local node = {
        type = 'constructor',
        body = {},
        arguments = {}
    }

    self:enter(node, node.body)
    self:body()

    if self.node.constructor then
        frog:parse(self.lexed.lines, fallback.line, fallback.range[1], fallback.range[2], 'Multiple constructors in same class.')
    end

    self.node.constructor = node

    return node
end

function parser:definestat()
    self:expect('define')

    local fallback = self.token
    local node = {
        type = 'define',
        name = self:clean(self:expect('identifier'))
    }

    if self:test('equal') or self:test('comma') then
        node.variables = { node.name }
        node.name = nil
        node.values = {}
        node.type = 'assign'

        local count = 0
        local values = 0

        while self:accept('comma') do
            table.insert(node.variables, self:clean(self:expect('identifier')))
            count = count + 1
        end
    
        self:expect('equal')
        table.insert(node.values, self:expression())

        while self:accept('comma') do
            table.insert(node.values, self:expression())
            count = count - 1
            values = values + 1
        end

        if count ~= 0 and values ~= 0 then
            frog:parse(self.lexed.lines, fallback.line, fallback.range[1], fallback.range[2] + 1, 'Mismatch between variables and values.')
        end
    else
        node.body = {}
        node.arguments = {}
        node.type = 'function'
        
        local level = node.name
        while self:accept('period') do
            level.index = self:clean(self:expect('identifier'))
            level = level.index
        end

        if self:accept('colon') then
            node['method'] = true
            level.index = self:clean(self:expect('identifier'))
            level = level.index
        end

        self:enter(node, node.body)
        self:body()
    end

    return node
end

function parser:classbody()
    if self:test('method') and not self.options:has('no-method') then
        return self:methodstat()
    elseif self:test('identifier', 'constructor') then
        return self:constructorstat()
    elseif self:test('identifier', 'get') or self:test('identifier', 'set') then
        return self:classmethod()
    elseif self:test('meta') then
        return self:metamethod()
    elseif self:test('define') and not self.options:has('no-define') then
        return self:definestat()
    elseif self:test('enum') and not self.options:has('no-enum') then
        return self:enumstat()
    else
        local fallback = self.token
        local node = {
            type = 'assign',
            name = self:suffixed()
        }
    
        if self:test('equal') or self:test('comma') then
            node.variables = { node.name }
            node.name = nil
            node.values = {}
        
            local count = 0
            local values = 0

            while self:accept('comma') do
                table.insert(node.variables, self:suffixed())
                count = count + 1
            end
        
            self:expect('equal')
            table.insert(node.values, self:expression())
    
            while self:accept('comma') do
                table.insert(node.values, self:expression())
                count = count - 1
                values = values + 1
            end
    
            if count ~= 0 and values ~= 0 then
                frog:parse(self.lexed.lines, fallback.line, fallback.range[1], fallback.range[2] + 1, 'Mismatch between variables and values.')
            end
        else
            frog:parse(self.lexed.lines, fallback.line, fallback.range[1], fallback.range[2], 'Unexpected token in class structure.')
        end
    
        return node
    end
end

function parser:classstat()
    self:expect('class')

    local node = {
        type = 'class',
        body = {},
        name = self:clean(self:expect('identifier'))
    }

    if self:accept('extends') and not self.options:has('no-extends') then
        node['extends'] = self:clean(self:expect('identifier'))
    end

    self:enter(node, node.body)

    while not self:conclude(true) do
        table.insert(node.body, self:classbody())
    end

    self:exit()

    self:expect('end')
    return node
end

function parser:localfunction()
    self:expect('function')

    local node = {
        type = 'function',
        name = self:clean(self:expect('identifier')),
        body = {},
        arguments = {},
        isLocal = true
    }

    self:enter(node, node.body)
    self:body()

    return node
end

function parser:returnstat()
    local returns = {}

    if self:conclude(1) or self:test('semicolon') then
        returns = {}
    else
        table.insert(returns, self:expression())

        while self:accept('comma') do
            table.insert(returns, self:expression())
        end
    end

    self:accept('semicolon')

    return returns
end

function parser:localstat()
    local fallback = self.token
    local node = {
        type = 'assign',
        variables = { self:clean(self:expect('identifier')) },
        values = {},
        isLocal = true
    }

    local count = 0
    local values = 0
    local error = self.token

    while self:accept('comma') do
        table.insert(node.variables, self:clean(self:expect('identifier')))
        count = count + 1
    end

    if self:accept('equal') then
        table.insert(node.values, self:expression())

        while self:accept('comma') do
            table.insert(node.values, self:expression())
            count = count - 1
            values = values + 1
        end
    end

    if count ~= 0 and values ~= 0 then
        frog:parse(self.lexed.lines, fallback.line, fallback.range[1], fallback.range[2] + 1, 'Mismatch between variables and values.')
    end

    return node
end

function parser:globalstat()
    local fallback = self.token
    local node = {
        type = 'assign',
        variables = { self:clean(self:expect('identifier')) },
        values = {},
        isGlobal = true
    }

    local count = 0
    local values = 0
    local error = self.token

    while self:accept('comma') do
        table.insert(node.variables, self:clean(self:expect('identifier')))
        count = count + 1
    end

    if self:accept('equal') then
        table.insert(node.values, self:expression())

        while self:accept('comma') do
            table.insert(node.values, self:expression())
            count = count - 1
            values = values + 1
        end
    end

    if count ~= 0 and values ~= 0 then
        frog:parse(self.lexed.lines, fallback.line, fallback.range[1], fallback.range[2] + 1, 'Mismatch between variables and values.')
    end

    return node
end

function parser:specialequal()
    --[[
        ['..='] = 'join_equal',
        ['+='] = 'plus_equal',
        ['-='] = 'minus_equal',
        ['*='] = 'star_equal',
        ['/='] = 'slash_equal',
        ['|='] = 'pipe_equal',
        ['&='] = 'and_equal',
        ['%='] = 'mod_equal',
        ['^='] = 'power_equal',
        ['.='] = 'access_equal',
        ['_='] = 'base_equal',
    ]]

    if self:accept('join_equal') then
        return 'join_assign'
    elseif self:accept('plus_equal') then
        return 'add_assign'
    elseif self:accept('minus_equal') then
        return 'subtract_assign'
    elseif self:accept('star_equal') then
        return 'multiply_assign'
    elseif self:accept('slash_equal') then
        return 'divide_assign'
    elseif self:accept('pipe_equal') then
        return 'or_assign'
    elseif self:accept('and_equal') then
        return 'and_assign'
    elseif self:accept('mod_equal') then
        return 'mod_assign'
    elseif self:accept('power_equal') then
        return 'power_assign'
    elseif self:accept('access_equal') then
        return 'access_assign'
    elseif self:accept('base_equal') then
        return 'base_assign'
    else
        self:expect('equal')
        return 'assign'
    end
end

function parser:hasequal()
    --[[
        ['..='] = 'join_equal',
        ['+='] = 'plus_equal',
        ['-='] = 'minus_equal',
        ['*='] = 'star_equal',
        ['/='] = 'slash_equal',
        ['|='] = 'pipe_equal',
        ['&='] = 'and_equal',
        ['%='] = 'mod_equal',
        ['^='] = 'power_equal',
        ['.='] = 'access_equal',
        ['_='] = 'base_equal',
    ]]

    if self.options:has('no-special-equality') then
        if self:test('equal') then
            return 'assign'
        else
            return false
        end
    end

    if self:test('join_equal') then
        return 'join_assign'
    elseif self:test('plus_equal') then
        return 'add_assign'
    elseif self:test('minus_equal') then
        return 'subtract_assign'
    elseif self:test('star_equal') then
        return 'multiply_assign'
    elseif self:test('slash_equal') then
        return 'divide_assign'
    elseif self:test('pipe_equal') then
        return 'or_assign'
    elseif self:test('and_equal') then
        return 'and_assign'
    elseif self:test('mod_equal') then
        return 'mod_assign'
    elseif self:test('power_equal') then
        return 'power_assign'
    elseif self:test('access_equal') then
        return 'access_assign'
    elseif self:test('base_equal') then
        return 'base_assign'
    elseif self:test('equal') then
        return 'assign'
    else
        return false
    end
end

function parser:expressionstat()
    local fallback = self.token

    if self.token.type ~= 'identifier' and self.token.type ~= 'open_parenthesis' then
        local node = {
            type = 'ternary',
        }

        node = self:expression()
        if node.type ~= 'ternary' then
            frog:parse(self.lexed.lines, fallback.line, fallback.range[1], fallback.range[2], 'Unexpected token "' .. fallback.type .. '" in expression.')
        end

        return node
    end

    local node = {
        type = 'exprstat',
        name = self:suffixed()
    }

    if self:hasequal() or self:test('comma') then
        node.variables = { node.name }
        node.name = nil
        node.values = {}
        
        local count = 0
        local variables = 1
        local values = 1

        while self:accept('comma') do
            table.insert(node.variables, self:suffixed())
            count = count + 1
            variables = variables + 1
        end
    
        node.type = self:specialequal()
        table.insert(node.values, self:expression())

        while self:accept('comma') do
            table.insert(node.values, self:expression())
            count = count - 1
            values = values + 1
        end

        if node.type ~= 'assign' then
            if count ~= 0 and values ~= 0 then
                frog:parse(self.lexed.lines, fallback.line, fallback.range[1], fallback.range[2] + 1, 'Mismatch between variables and values.')
            end
        else
            if values ~= variables and values ~= 1 then
                frog:parse(self.lexed.lines, fallback.line, fallback.range[1], fallback.range[2] + 1, 'Mismatch between variables and values.')
            end
        end
    else
        node = node.name

        if not node.call then
            local node = {
                type = 'ternary',
                condition = node
            }

            self.index = self.index - 1
            self.token = self.tokens[self.index]

            local fallback = self.token
            node = self:expression()
    
            if node.type ~= 'ternary' then
                self.token = fallback
                frog:parse(self.lexed.lines, fallback.line, fallback.range[1], fallback.range[2], 'Unexpected expression of type "' .. fallback.type .. '" in statement.')
            end

            return node
        end
    end

    return node
end

function parser:initialize()
    local fallback = self.token
    self:expect('identifier', 'new')
    local node = self:suffixed()

    if not node.call then
        self.token = self.token or fallback
        frog:parse(self.lexed.lines, self.token.line, self.token.range[1], self.token.range[2], 'Expected function call when instantiating class.')
    end

    return {
        type = 'initialize',
        call = node
    }
end

function parser:statement()
    if self:test('semicolon') and not self.options:has('no-semicolons') then
        self:accept('semicolon')
        return 'semicolon'
    elseif self:test('if') then
        table.insert(self.tree, self:ifstat())
        return 'if'
    elseif self:test('while') then
        table.insert(self.tree, self:whilestat())
        return 'while'
    elseif self:test('repeat') then
        table.insert(self.tree, self:repeatstat())
        return 'repeat'
    elseif self:test('function') then
        table.insert(self.tree, self:functionstat())
        return 'function'
    elseif self:test('define') and not self.options:has('no-define') then
        table.insert(self.tree, self:definestat())
        return 'define'
    elseif self:test('method') and not self.options:has('no-method') then
        table.insert(self.tree, self:methodstat())
        return 'method'
    elseif self:test('enum') and not self.options:has('no-enum') then
        table.insert(self.tree, self:enumstat())
        return 'enum'
    elseif self:test('switch') and not self.options:has('no-switch') then
        table.insert(self.tree, self:switchstat())
        return 'switch'
    elseif self:test('identifier', 'new') and not self.options:has('no-new') then
        table.insert(self.tree, self:initialize())
        return 'initialize'
    elseif self:accept('do') then
        local node = {
            type = 'do',
            body = {}
        }

        node.body = self:block(node)

        table.insert(self.tree, node)
        return 'do'
    elseif self:accept('local') then
        if self:test('function') then
            table.insert(self.tree, self:localfunction())
        else
            table.insert(self.tree, self:localstat())
        end

        return 'local'
    elseif self:accept('global') and not self.options:has('no-global') then
        table.insert(self.tree, self:globalstat())

        return 'global'
    elseif self:accept('return') then
        if self.node['return'] then
            frog:parse(self.lexed.lines, self.token.line, self.token.range[1], self.token.range[2], 'Multiple return values in current block.')
        end

        self.node['return'] = self:returnstat()
        return 'return'
    elseif self:test('for') then
        table.insert(self.tree, self:forstat())
        return 'for'
    elseif ((self:test('label') and not self.options:has('no-label')) or self:test('double_colon')) and not self.options:has('no-jumping') then
        table.insert(self.tree, self:labelstat())
        return 'label'
    elseif self:test('goto') and not self.options:has('no-jumping') then
        table.insert(self.tree, self:gotostat())
        return 'goto'
    elseif self:test('class') and not self.options:has('no-class') then
        table.insert(self.tree, self:classstat())
        return 'class'
    elseif self:accept('break') then
        table.insert(self.tree, {
            type = 'break'
        })
        return 'break'
    else
        table.insert(self.tree, self:expressionstat())
        return 'expression'
    end

    if not self.token then return end
    frog:parse(self.lexed.lines, self.token.line, self.token.range[1], self.token.range[2], 'Unexpected token of type "' .. self.token.type .. '" in statement.')
end

function parser:conclude(withuntil)
    if self:test('else')
       or self:test('elseif')
       or self:test('end')
       or self:test('case')
       or self:test('default')
       or not self.token then
        return true
    elseif self:test('until') then
        return withuntil
    else
        return false
    end
end

function parser:statements()
    while not self:conclude(true) do
        if self:test('return') then
            self:statement()
            break
        end

        self:statement()
    end

    self:exit()
end

function parser:chunk()
    if self:test('string') and not self.options:has('no-options') then
        self.tree.options = table.concat(self:accept('string').characters, '')
        if not self.options:has('no-semicolons') then
            self:accept('semicolon')
        end
    end

    self.tree.options = options:parse(self.tree.options or '', self.options or {})

    self:enter(self.tree, self.tree.body)

    while self.token do
        if self:test('return') then
            self:statement()
            break
        end

        self:statement()
    end

    self:exit()

    if self.token then
        frog:parse(self.lexed.lines, self.token.line, self.token.range[1], self.token.range[2], 'Expected EOF following file body.')
    end
end

-- Main

function parser:parse(safe)
    self.safe = safe

    self:chunk()
    self.tree.options.has = nil
    
    return self.tree
end

return parser