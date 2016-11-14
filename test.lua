local tracedoc = require "tracedoc"

local doc = tracedoc.new {
	a = 1,
	b = { 1,2,3 },
	c = { d = 4 , e = 5 },
	d = {},
}

local function dump(doc)
	local changes = tracedoc.commit(doc, {})
	print("Dump:")
	for k,v in pairs(doc) do
		print(k,v)
		if type(v) == "table" then
			for k, v in pairs(v) do
				print("\t",k,v)
			end
		end
	end
	print("changes:")
	for k,v in pairs(changes) do
		print(k,v)
	end
end

dump(doc)

tracedoc.opaque(doc.d, true)
doc.d.x = 1	-- d change ( d is opaque)
doc.d.y = 2	-- d change ( d is opaque)

assert(doc.b[1] == 1)
assert(doc.b[2] == 2)
assert(doc.b[3] == 3)
assert(doc.c.d == 4)

doc.b[1] = 0	-- change
doc.b[2] = 2	-- not change

local tmp = doc.c

dump(doc)

doc.a = nil	-- clear doc.a
assert(doc.a == nil)

doc.b[3] = nil	-- remove 3
table.remove(doc.b)	-- remove 2
table.insert(doc.b , 5)	-- doc.b[2] = 5
table.insert(doc.b , 6)	-- doc.b[3] = 6
table.insert(doc.b , 7)	-- doc.b[4] = 7

for k,v in ipairs(doc.b) do
	print("doc.b[" .. k .. "]",v)
end

doc.e = "e"	-- add doc.e

for k,v in pairs(doc) do
	print("doc."..k , v)
end

dump(doc)

doc.a = 2	-- change
assert(doc.a == 2)
doc.b = 2	-- change and delete table
assert(doc.b == 2)
local doc_c = { e = 5 }
doc.c = doc_c -- change table
assert(doc.c.d == nil)
doc.b = nil
doc.d = setmetatable({}, { __tostring = function() return "userobject" end })	-- table with metatable is an userobject
doc.e = { x = 1, y = 2 }

assert(tmp ~= doc.c)
tmp = doc.c	-- update c
assert(tmp ~= doc_c)

dump(doc)

assert(tmp.e == 5)


