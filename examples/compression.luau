local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pack = require(ReplicatedStorage:FindFirstChild("DataPack"))

-- simulate big data
local repeated = string.rep("attack_pattern_", 500)

local data = {
	Log = repeated,
}

local pack = Pack.New(data, { compress = true })

print("Is Compressed:", pack:IsCompressed())
print("Compression Ratio:", pack:GetCompressionRatio())

local unpacked = pack:Return()
print(unpacked.Log:sub(1, 20)) -- attack_pattern_att
