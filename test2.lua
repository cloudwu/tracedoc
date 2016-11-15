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
	{ "B" , map "B", "b" },
	{ "B" , map "BX" , "b.x" },
	{ add_b, "b.x", "b.y" },
	{ "C", add_c, "c" },
}

local function map(info)
	print("====", info, "====")
	tracedoc.mapchange(doc, mapping)
	print("------------------")
end

map(1)

doc.a = 0

doc.b.y = 3
doc.c.b = 5

map(2)

doc.a = 1

doc.b.y = 4

map(3)

print("Filter A")
tracedoc.mapupdate(doc, mapping, "A")
print("Filter B")
tracedoc.mapupdate(doc, mapping, "B")
print("Filter null")
tracedoc.mapupdate(doc, mapping, "")
print("Filter All")
tracedoc.mapupdate(doc, mapping)
