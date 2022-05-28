local luau = {}

local inspect = require('debug/inspect')

local emitter = require('source/compiler/emitter')
local frog = require('source/lib/frog')

function luau:compile(ast)
    self.options = ast.options
    self.emitter = emitter:new(self.options)

    self:walk(ast.body)

    if ast['return'] then
        self.emitter:newline()
        self:return_statement(ast['return'])
    end

    return self.emitter.output
end

function luau:walk(body)
    for i, node in ipairs(body) do
        if node.type == 'assign' then
            self:assignment(node)
        elseif node.type == 'function' then
            self:function_declaration(node)
        elseif node.type == 'class' then
            self:class_declaration(node)
        elseif node.type == 'if' then
            self:if_declaration(node)
        elseif node.type == 'while' then
            self:while_declaration(node)
        elseif node.type == 'repeat' then
            self:repeat_declaration(node)
        elseif node.type == 'for' then
            self:for_declaration(node)
        elseif node.type == 'return' then
            self:return_statement(node)
        elseif node.type == 'break' then
            self.emitter:emit('break')
        elseif node.type == 'continue' then
            self.emitter:emit('continue')
        elseif node.call then
            self:name(node)
        elseif node.type == 'anonymous' then
            self:anonymous(node)
        elseif node.type == 'join_assign' then
            self:join_assignment(node)
        elseif node.type == 'access_assign' then
            self:quick_assignment(node)
        elseif node.type == 'add_assign' then
            self:add_assignment(node)
        else
            print(node.type)
        end
        
        if i ~= #body then
            self.emitter:newline()
        end
    end
end

function luau:join_assignment(node)
    for i, variable in ipairs(node.variables) do
        if variable.type == 'identifier' then
            for i, character in ipairs(variable.characters) do
                self.emitter:emit(character)
            end
        else
            self:name(variable)
        end

        self.emitter:whitespace()
        self.emitter:emit('=')
        self.emitter:whitespace()

        if variable.type == 'identifier' then
            for i, character in ipairs(variable.characters) do
                self.emitter:emit(character)
            end
        else
            self:name(variable)
        end

        self.emitter:optional()
        self.emitter:emit('..')
        self.emitter:optional()

        if #node.values == 1 then
            local value = node.values[1]
            self:expression(value)
        else
            self:expression(node.values[i])
        end
    end
end

function luau:add_assignment(node)
    for i, variable in ipairs(node.variables) do
        if variable.type == 'identifier' then
            for i, character in ipairs(variable.characters) do
                self.emitter:emit(character)
            end
        else
            self:name(variable)
        end

        self.emitter:whitespace()
        self.emitter:emit('=')
        self.emitter:whitespace()

        if variable.type == 'identifier' then
            for i, character in ipairs(variable.characters) do
                self.emitter:emit(character)
            end
        else
            self:name(variable)
        end

        self.emitter:optional()
        self.emitter:emit('+')
        self.emitter:optional()

        if #node.values == 1 then
            local value = node.values[1]
            self:expression(value)
        else
            self:expression(node.values[i])
        end
    end
end

function luau:quick_assignment(node)
    for i, variable in ipairs(node.variables) do
        variable.body.index = node.values[i].body or node.values[1].body
        self:name(variable)

        self.emitter:whitespace()
        self.emitter:emit('=')
        self.emitter:whitespace()

        if #node.values == 1 then
            local value = node.values[1]
            self:expression(value)
        else
            self:expression(node.values[i])
        end

        self.emitter:whitespace()
        self.emitter:emit('or')
        self.emitter:whitespace()

        self:name(variable)
    end
end

function luau:assignment(node)
    if node.isLocal then
        self.emitter:emit('local')
        self.emitter:whitespace()
    end

    if #node.variables > 1 then
        for i, variable in ipairs(node.variables) do
            if node.isGlobal then
                self.emitter:emit('_G')
                self.emitter:emit('.')
            end
            
            if variable.type == 'identifier' then
                for i, character in ipairs(variable.characters) do
                    self.emitter:emit(character)
                end
            else
                self:name(variable)
            end

            if i ~= #node.variables then
                self.emitter:emit(',')
                self.emitter:optional()
            end
        end
    else
        local variable = node.variables[1]
        if node.isGlobal then
            self.emitter:emit('_G')
            self.emitter:emit('.')
        end

        if variable.type == 'identifier' then
            for i, character in ipairs(variable.characters) do
                self.emitter:emit(character)
            end
        else
            self:name(variable)
        end
    end

    self.emitter:optional()

    if #node.values ~= 0 or node.isGlobal then
        self.emitter:emit('=')
        self.emitter:optional()

        if node.isGlobal and #node.values == 0 then
            for i = 1, #node.variables do
                self.emitter:emit('nil')

                if i ~= #node.variables then
                    self.emitter:emit(',')
                    self.emitter:optional()
                end
            end
        end
    end

    if #node.values == 1 and not node.values[1].call then
        local value = node.values[1]

        for i = 1, #node.variables do
            self:expression(value)

            if i ~= #node.variables then
                self.emitter:emit(',')
                self.emitter:optional()
            end
        end
    else
        for i, value in ipairs(node.values) do
            self:expression(value)

            if i ~= #node.values then
                self.emitter:emit(',')
                self.emitter:optional()
            end
        end
    end
end

function luau:function_declaration(node)
    if node.isLocal then
        self.emitter:emit('local')
        self.emitter:whitespace()
    end

    self.emitter:emit('function')
    self.emitter:whitespace()

    self:name(node.name)
    self.emitter:emit('(')

    for i, argument in ipairs(node.arguments) do
        self.emitter:emit(argument.characters)

        if i ~= #node.arguments then
            self.emitter:emit(',')
            self.emitter:emit(' ')
        end
    end

    if node.variable then
        if #node.arguments > 0 then
            self.emitter:emit(',')
            self.emitter:emit(' ')
        end

        self.emitter:emit('...')
    end

    self.emitter:emit(')')
    self.emitter:indent()

    if #node.body > 0 then
        self.emitter:newline()
    end

    self:walk(node.body)

    if node['return'] then
        self.emitter:newline()
        self:return_statement(node['return'])
    end

    self.emitter:unindent()
    self.emitter:newline()
    self.emitter:emit('end')
end

function luau:class_declaration(node)
    local name = node.name
    local constructor = node.constructor
    
    self:assignment({
        isLocal = true,
        variables = {
            name
        },
        values = {
            {
                type = 'table',
                body = {}
            }
        }
    })

    self.emitter:newline()

    self.emitter:emit('function')
    self.emitter:whitespace()

    name.index = {
        characters = { 'n', 'e', 'w' },
        type = 'identifier'
    }

    self:name(name)
    self.emitter:emit('(')

    if constructor then
        for i, argument in ipairs(constructor.arguments) do
            self.emitter:emit(argument.characters)

            if i ~= #constructor.arguments then
                self.emitter:emit(',')
                self.emitter:emit(' ')
            end
        end

        if constructor.variable then
            if #constructor.arguments > 0 then
                self.emitter:emit(',')
                self.emitter:emit(' ')
            end

            self.emitter:emit('...')
        end
    end

    self.emitter:emit(')')
    self.emitter:indent()
    self.emitter:newline()

    self:assignment({
        isLocal = true,
        variables = {
            {
                type = "name",
                body = {
                    characters = { 's', 'e', 'l', 'f' },
                    type = 'identifier'
                }
            }
        },
        values = {
            {
                type = 'table',
                body = {}
            }
        }
    })

    self.emitter:newline()

    name.index = nil
    self:name({
        type = 'name',
        body = {
            type = 'identifier',
            characters = { 's', 'e', 't', 'm', 'e', 't', 'a', 't', 'a', 'b', 'l', 'e' },
            call = {
                arguments = {
                    {
                        type = 'name',
                        body = {
                            type = 'identifier',
                            characters = { 's', 'e', 'l', 'f' }
                        }
                    },
                    {
                        type = 'table',
                        body = {
                            {
                                type = 'field',
                                key = {
                                    type = 'identifier',
                                    characters = { '_', '_', 'i', 'n', 'd', 'e', 'x' }
                                },
                                value = {
                                    type = 'name',
                                    body = name
                                }
                            }
                        }
                    }
                },
                type = 'call'
            }
        }
    })

    setmetatable(self, { __index = banana })

    local assignments = false
    for i, action in ipairs(node.body) do
        if action.type == 'assign' then
            if not assignments then
                assignments = true
                self.emitter:newline()
            end

            for i, name in ipairs(action.variables) do
                name.body = {
                    characters = { 's', 'e', 'l', 'f' },
                    type = 'identifier',
                    index = name.body
                }
            end

            self:assignment(action)
        end
    end

    if constructor then
        if #constructor.body > 0 then
            self.emitter:newline()
        end

        self:walk(constructor.body)
    end

    if constructor and constructor['return'] then
        self.emitter:newline()
        self:return_statement(constructor['return'])
    else
        self.emitter:newline()
        self:return_statement({
            {
                body = {
                    characters = { 's', 'e', 'l', 'f' },
                    type = 'identifier'
                },
                type = 'name'
            }
        })
    end

    self.emitter:unindent()
    self.emitter:newline()
    self.emitter:emit('end')

    local methods = false
    for i, action in ipairs(node.body) do
        if action.type == 'method' then
            if not methods then
                methods = true
                self.emitter:newline()
            end
            
            action.type = 'function'
            name.index = action.name
            name.index['method'] = true
            action.name = name
            
            self:function_declaration(action)
            self.emitter:newline()
        end
    end

    name.index = nil
    self.emitter:emit('setmetatable')
    self.emitter:emit('(')
    self:name({
        type = 'name', 
        body = name
    })
    self.emitter:emit(',')
    self.emitter:optional()

    name.index = {
        type = 'identifier',
        characters = { 'n', 'e', 'w' }
    }

    self:table({
        type = 'table',
        body = {
            {
                type = 'field',
                key = {
                    characters = { '_', '_', 'c', 'a', 'l', 'l' },
                    type = 'identifier'
                },
                value = {
                    type = 'name', 
                    body = name
                }
            }
        }
    })

    self.emitter:emit(')')
end

function luau:if_declaration(node)
    local clauses = node.clauses

    for i, clause in ipairs(node.clauses) do
        if clause.type == 'then' then
            self.emitter:emit('if')
            self.emitter:whitespace()

            self:expression(clause.condition)

            self.emitter:whitespace()
            self.emitter:emit('then')

            self.emitter:indent()
        elseif clause.type == 'elseif' then
            self.emitter:emit('elseif')
            self.emitter:whitespace()
    
            self:expression(clause.condition)
                
            self.emitter:whitespace()
            self.emitter:emit('then')
    
            self.emitter:indent()
        else
            self.emitter:emit('else')
            
            self.emitter:indent()
        end

        if #clause.body > 0 then
            self.emitter:newline()
        end

        self:walk(clause.body)

        if clause['return'] then
            self.emitter:newline()
            self:return_statement(clause['return'])
        end

        self.emitter:unindent()
        self.emitter:newline()
    end

    self.emitter:emit('end')
end

function luau:while_declaration(node)
    local condition = node.condition

    self.emitter:emit('while')
    self.emitter:whitespace()

    self:expression(condition)

    self.emitter:whitespace()
    self.emitter:emit('do')

    self.emitter:indent()
        
    if #node.body > 0 or node['return'] then
        self.emitter:newline()
    end

    self:walk(node.body)

    if node['return'] then
        self:return_statement(node['return'])
    end

    self.emitter:unindent()
    self.emitter:newline()

    self.emitter:emit('end')
end

function luau:repeat_declaration(node)
    local condition = node.condition

    self.emitter:emit('repeat')
    self.emitter:indent()
        
    if #node.body > 0 or node['return'] then
        self.emitter:newline()
    end

    self:walk(node.body)

    if node['return'] then
        self:return_statement(node['return'])
    end

    self.emitter:unindent()

    self.emitter:whitespace()
    self.emitter:emit('until')
    self.emitter:whitespace()

    self:expression(condition)
end

function luau:for_declaration(node)
    self.emitter:emit('for')
    self.emitter:whitespace()

    for i, variable in ipairs(node.variables) do
        if variable.type == 'identifier' then
            self.emitter:emit(variable.characters)
        end

        if i ~= #node.variables then
            self.emitter:emit(',')
            self.emitter:optional()
        end
    end


    if node.list then
        self.emitter:whitespace()
        self.emitter:emit('in')
        self.emitter:whitespace()

        self:expression(node.list)
    else
        self.emitter:optional()

        self.emitter:emit('=')
        self.emitter:optional()

        self:expression(node.initial)
        self.emitter:emit(',')
        self.emitter:optional()

        self:expression(node.limit)

        if node.step then
            self.emitter:emit(',')
            self.emitter:optional()

            self:expression(node.step)
        end
    end

    self.emitter:whitespace()
    self.emitter:emit('do')

    self.emitter:indent()
        
    if #node.body > 0 or node['return'] then
        self.emitter:newline()
    end

    self:walk(node.body)

    if node['return'] then
        self:return_statement(node['return'])
    end

    self.emitter:unindent()
    self.emitter:newline()

    self.emitter:emit('end')
end

function luau:return_statement(node)
    self.emitter:emit('return')
    self.emitter:whitespace()

    for i, value in ipairs(node) do
        self:expression(value)

        if i ~= #node then
            self.emitter:emit(',')
            self.emitter:optional()
        end
    end
end

function luau:string(node)
    -- Scan string for delimiters
    local double = 0
    local single = 0

    for i, character in ipairs(node.characters) do
        if character == '\'' or character == '\\\'' then
            single = single + 1
        elseif character == '"' or character == '\\"' then
            double = double + 1
        elseif character == '\\' then
            node.characters[i] = '\\\\'
        end
    end

    local choice = double >= single and '\'' or '"'
    self.emitter:emit(choice)

    for i, character in ipairs(node.characters) do
        if character == choice then
            self.emitter:emit('\\')
        end

        self.emitter:emit(character)
    end

    self.emitter:emit(choice)
end

function luau:number(node)
    for i, character in ipairs(node.characters) do
        if character == choice then
            self.emitter:emit('\\')
        end

        self.emitter:emit(character)
    end
end

function luau:anonymous(node)
    self.emitter:emit('function')
    self.emitter:emit('(')

    for i, argument in ipairs(node.arguments) do
        self.emitter:emit(argument.characters)
        
        if i ~= #node.arguments then
            self.emitter:emit(',')
            self.emitter:emit(' ')
        end
    end
        
    if node.variable then
        if #node.arguments > 0 then
            self.emitter:emit(',')
            self.emitter:emit(' ')
        end
        
        self.emitter:emit('...')
    end
        
    self.emitter:emit(')')

    self.emitter:indent()
    
    if #node.body > 0 or node['return'] then
        self.emitter:newline()
    end

    self:walk(node.body)

    if node['return'] then
        self:return_statement(node['return'])
    end
        
    self.emitter:unindent()
    self.emitter:newline()
    self.emitter:emit('end')
end

function luau:index(node, ignoreIndex)
    if node.yindex and not ignoreIndex then
        self.emitter:emit('[')

        self:index(node, true)
        self.emitter:emit(']')
    elseif node.type == 'name' then
        self:name(node)
    elseif node.type == 'identifier' then
        self.emitter:emit(node.characters)
    else
        self:expression(node)
    end

    if node.call and not ignoreIndex then
        self.emitter:emit('(')

        local arguments = node.call.arguments

        for i, argument in ipairs(arguments) do
            self:expression(argument)

            if i ~= #arguments then
                self.emitter:emit(',')
                self.emitter:optional()
            end
        end

        self.emitter:emit(')')

        local index = node.call.index

        if index and not ignoreIndex then
            if index.type == 'identifier' then
                if index['method'] then
                    self.emitter:emit(':')
                else
                    self.emitter:emit('.')
                end
            end

            self:index(index)
        end
    end

    local index = node.index

    if index and not ignoreIndex then
        if index.type == 'identifier' then
            if index['method'] then
                self.emitter:emit(':')
            else
                self.emitter:emit('.')
            end
        end

        self:index(node.index)
    end
end

function luau:name(node)
    if node.type == 'name' then
        local body = node.body

        if body.type == 'identifier' then
            self.emitter:emit(body.characters)
        else
            self:expression(body)
        end

        if body.call then
            self.emitter:emit('(')
    
            local arguments = body.call.arguments
    
            for i, argument in ipairs(arguments) do
                self:expression(argument)
    
                if i ~= #arguments then
                    self.emitter:emit(',')
                    self.emitter:optional()
                end
            end
    
            self.emitter:emit(')')

            local index = body.call.index

            if index then
                if index.type == 'identifier' then
                    if index['method'] then
                        self.emitter:emit(':')
                    else
                        self.emitter:emit('.')
                    end
                end

                self:index(index)
            end
        end

        if body.index then
            if body.index.type == 'identifier' then
                if body.index['method'] then
                    self.emitter:emit(':')
                else
                    self.emitter:emit('.')
                end
            end

            self:index(body.index)
        end
    elseif node.type == 'identifier' then
        self.emitter:emit(node.characters)

        local index = node.index

        if index then
            if index.type == 'identifier' then
                if index['method']then
                    self.emitter:emit(':')
                else
                    self.emitter:emit('.')
                end
            end

            self:index(index)
        end
    end
end

function luau:table(node)
    self.emitter:emit('{')

    if #node.body > 0 then
        self.emitter:indent()
        self.emitter:newline()

        for i, field in ipairs(node.body) do
            if field.key then
                if field.key.type == 'identifier' then
                    self.emitter:emit(field.key.characters)
                else
                    self.emitter:emit('[')
                    self:expression(field.key)
                    self.emitter:emit(']')
                end

                self.emitter:optional()
                self.emitter:emit('=')
                self.emitter:optional()
            end

            self:expression(field.value)

            if i ~= #node.body then
                self.emitter:emit(',')
                self.emitter:newline()
            end
        end

        self.emitter:unindent()
        self.emitter:newline()
    end

    self.emitter:emit('}')
end

function luau:expression(node)
    if node.type == 'string' then
        self:string(node)
    elseif node.type == 'boolean' then
        if node.value then
            self.emitter:emit('true')
        else
            self.emitter:emit('false')
        end
    elseif node.type == 'nil' then
        self.emitter:emit('nil')
    elseif node.type == 'number' then
        self:number(node)
    elseif node.type == 'unary' then
        if node.action == 'not' then
            self.emitter:emit('not')
            self.emitter:whitespace()

            self:expression(node.body)
        elseif node.action == 'length' then
            self.emitter:emit('#')

            self:expression(node.body)
        end
    elseif node.type == 'binary' then
        --[[
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
        ]]

        
        if node.action == 'add' then
            self:expression(node.left)

            self.emitter:optional()
            self.emitter:emit('+')
            self.emitter:optional()

            self:expression(node.right)
        elseif node.action == 'subtract' then
            self:expression(node.left)

            self.emitter:optional()
            self.emitter:emit('-')
            self.emitter:optional()

            self:expression(node.right)
        elseif node.action == 'multiply' then
            self:expression(node.left)

            self.emitter:optional()
            self.emitter:emit('*')
            self.emitter:optional()

            self:expression(node.right)
        elseif node.action == 'modulus' then
            self:expression(node.left)

            self.emitter:optional()
            self.emitter:emit('%')
            self.emitter:optional()

            self:expression(node.right)
        elseif node.action == 'power' then
            self:expression(node.left)

            self.emitter:optional()
            self.emitter:emit('^')
            self.emitter:optional()

            self:expression(node.right)
        elseif node.action == 'base' then
            self:base(node)
        elseif node.action == 'divide' then
            self:divide(node)
        elseif node.action == 'floor_division' then
            self:floor_division(node)
        elseif node.action == 'bitwise_and' then
            self:bitwise_and(node)
        elseif node.action == 'bitwise_or' then
            self:bitwise_or(node)
        elseif node.action == 'left_shift' then
            self:left_shift(node)
        elseif node.action == 'right_shift' then
            self:right_shift(node)
        elseif node.action == 'join' then
            self:expression(node.left)

            self.emitter:optional()
            self.emitter:emit('..')
            self.emitter:optional()

            self:expression(node.right)
        elseif node.action == 'equality' then
            self:expression(node.left)

            self.emitter:optional()
            self.emitter:emit('==')
            self.emitter:optional()

            self:expression(node.right)
        elseif node.action == 'exact_equality' then
            self:exact_equality(node)
        elseif node.action == 'inequality' then
            self:expression(node.left)

            self.emitter:optional()
            self.emitter:emit('~=')
            self.emitter:optional()

            self:expression(node.right)
        elseif node.action == 'exact_inequality' then
            self:exact_inequality(node)
        elseif node.action == 'less' then
            self:expression(node.left)

            self.emitter:optional()
            self.emitter:emit('<')
            self.emitter:optional()

            self:expression(node.right)
        elseif node.action == 'greater' then
            self:expression(node.left)

            self.emitter:optional()
            self.emitter:emit('>')
            self.emitter:optional()

            self:expression(node.right)
        elseif node.action == 'greater_equal' then
            self:expression(node.left)

            self.emitter:optional()
            self.emitter:emit('>=')
            self.emitter:optional()

            self:expression(node.right)
        elseif node.action == 'and' then
            self:expression(node.left)

            self.emitter:whitespace()
            self.emitter:emit('and')
            self.emitter:whitespace()

            self:expression(node.right)
        elseif node.action == 'or' then
            self:expression(node.left)

            self.emitter:whitespace()
            self.emitter:emit('or')
            self.emitter:whitespace()

            self:expression(node.right)
        end
    elseif node.type == 'name' or node.type == 'index' then
        self:name(node)
    elseif node.type == 'table' or node.type == 'array' then
        self:table(node)
    elseif node.type == 'anonymous' then
        self:anonymous(node)
    end
end

return luau