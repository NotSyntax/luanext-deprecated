<div align="center">
	<img src="../../assets/logo/standard.svg" style="margin: 0;" width="128" align="center" valign="middle">
	<a href="/#gh-dark-mode-only">
		<img src="../../assets/name/standardlight.svg" style="margin: 0;" width="200" align="center" valign="middle">
	</a>
</div>

## [LuaNext Standard](../standard.md): Targeting Luau

# Statements

<table align="center">
<tr>
<th style="text-align: center;">Keyword</ths>
<th style="text-align: center;">Docs</th>
<th style="text-align: center;">Support</th>
</tr>
<tr>
<td align="center">

`if`

</td>
<td align="center">

[If Statement](#If)

</td>
<td align="center">❌</td>
</tr>

<tr>
<td align="center">

`while`

</td>
<td align="center">

[While Statement](#While)

</td>
<td align="center">❌</td>
</tr>

<tr>
<td align="center">

`repeat`

</td>
<td align="center">

[Repeat Statement](#Repeat)

</td>
<td align="center">❌</td>
</tr>

<tr>
<td align="center">

`function`

</td>
<td align="center">

[Function Statement](#Functions)

</td>
<td align="center">❌</td>
</tr>

</table>
<table align="center">
<tr>
<td>✔️</td>
<td align="center">Currently supported in<br>the Luau target.</td>
</tr>
<tr>
<td>⚠️</td>
<td align="center">Experimental/preview support in<br>the Luau target.</td>
</tr>
<tr>
<td>❌</td>
<td align="center">No support in<br>the Luau target.</td>
</tr>
</table>

## Classes

<table align="center">
<tr>
<th style="text-align: center;">LuaNext</ths>
<th style="text-align: center;">Lua</th>
</tr>
<tr>
<td>

```lua
class Vector
    x, y, z = 0
    
    constructor(x, y, z)
        return {
            x = x || self.x,
            y = y || self.y,
            z = z || self.z,
        }
    end
end

local myVector = new Vector(5, 5, 5)
```

</td>
<td>

```lua
local Vector = {}

function Vector.new(x, y, z)
    self = self or {}

    self.x = 0
    self.y = 0
    self.z = 0

    setmetatable(self, {
        __index = Vector
    })

    return {
        x = x or self.x,
        y = y or self.y,
        z = z or self.z
    }
end

-- disable with `no-class-call`
setmetatable(Vector, {
    __call = Vector.new
})

local myVector = Vector.new(5, 5, 5)
```

</td>
</tr>
</table>

<table align="center">
<tr>
<th style="text-align: center;">LuaNext</ths>
<th style="text-align: center;">Lua</th>
</tr>
<tr>
<td>

```lua
class Vector2
    x, y = 0

    constructor(x, y)
        self .= x, y
    end
end

class Vector3 extends Vector2
    z = 0

    constructor(x, y, z)
        super(x, y)
        
        self .= z
    end
end
```

</td>
<td>

```lua
local Vector2 = {}

function Vector2.new(x, y)
    self = self or {}

    self.x = 0
    self.y = 0

    self.x = x or self.x
    self.y = y or self.y

    return setmetatable(self, {
        __index = Vector2
    })
end

-- disable with `no-class-call`
setmetatable(Vector2, {
    __call = Vector2.new
})

local Vector3 = {}

function Vector3.new(x, y, z)
    self = Vector2.new(x, y)

    self.z = 0

    self.z = z or self.z

    return setmetatable(self, {
        __index = Vector3
    })
end

-- disable with `no-class-call`
setmetatable(Vector3, {
    __call = Vector3.new
})
```

</td>
</tr>
</table>

<table align="center">
<tr>
<th style="text-align: center;">LuaNext</ths>
<th style="text-align: center;">Lua</th>
</tr>
<tr>
<td>

```lua
'closures'

class Fruit
    edible = true
    fruit = 'apple'
    color = 'red'
    age = 0

    method sit(days)
        self.age += days

        if self.age > 10 then
            self.edible = false
        end
    end

    constructor(fruit, color)
        self .= fruit, color
    end
end

local Apple = new Fruit()
```

</td>
<td>

```lua
function Fruit(fruit, color)
    self = {}

    self.edible = true
    self.fruit = 'apple'
    self.color = 'red'
    self.age = 0

    function self:sit(days)
        -- disable with `no-luau-equalities`
        self.age += days

        if self.age > 10 then
            self.edible = false
        end
    end

    self.fruit = fruit or self.fruit
    self.color = color or self.color

    return self
end

local Apple = Fruit()
```

</td>
</tr>
</table>