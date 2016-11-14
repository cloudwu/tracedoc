local tracedoc = require "tracedoc"

local doc = tracedoc.new {}

doc.a = false
doc.b = { x = 1, y = 2 }
doc.c = { a = 3, b = 4 }

tracedoc.opaque(doc.c, true)

local function map(str)
	return function (doc, v)
		print(str, v)
	end
end

local function add_b(doc, x, y)
	print("b.x+b.y=", x+y)
end

local function add_c(doc, c)
	print("c.a+c.b=", c.a + c.b)
end

local mapping = tracedoc.changeset {
	{ "A" , map "A1" , "a" },
	{ "A" , map "A2" , "a" },
	{ "B" , map "BX" , "b.x" },
	{ "B" , map "BY" , "b.y" },
	{ add_b, "b.x", "b.y" },
	{ "C", add_c, "c" },
}

tracedoc.mapchange(doc, mapping)

doc.a = 0

doc.b.y = 3
doc.c.b = 5

tracedoc.mapchange(doc, mapping)

print("Filter A")
tracedoc.mapupdate(doc, mapping, "A")
print("Filter B")
tracedoc.mapupdate(doc, mapping, "B")
print("Filter null")
tracedoc.mapupdate(doc, mapping, "")
print("Filter All")
tracedoc.mapupdate(doc, mapping)
