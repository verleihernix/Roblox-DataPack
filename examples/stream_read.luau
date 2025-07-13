local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pack = require(ReplicatedStorage:FindFirstChild("DataPack"))

-- simulate big data
local bigData = {
	Text = string.rep("xyz123", 1000),
}

local pack = Pack.New(bigData) -- will be compressed automatically

local reader = pack:StreamRead(512)
local part = reader()

while part do
	print("Read chunk:", #part, "bytes")
	part = reader()
end
