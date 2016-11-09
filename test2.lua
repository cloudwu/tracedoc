local tracedoc = require "tracedoc"

local doc = tracedoc.new {}

doc.a = 0
doc.b = { x = 1, y = 2 }

local function map(str)
	return function (doc, v)
		print(str, v)
	end
end

local function add_b(doc, x, y)
	print("b.x+b.y=", x+y)
end

local mapping = tracedoc.changeset {
	{ map "A1" , "a" },
	{ map "A2" , "a" },
	{ map "BX" , "b.x" },
	{ map "BY" , "b.y" },
	{ add_b, "b.x", "b.y" },
}

tracedoc.mapset(doc, mapping)

doc.b.y = 3

tracedoc.mapset(doc, mapping)

