local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pack = require(ReplicatedStorage:FindFirstChild("DataPack"))

local writer = Pack.NewStream()

writer:Write("Part1: Hello ")
writer:Write("Part2: World!")

local buf = writer:Finalize()
local pack = Pack.FromBuffer(buf, { Chunked = true })

local stream = pack:StreamRead(6)

while true do
	local chunk = stream()
	if not chunk then
		break
	end
	print("Chunk:", chunk)
end
