local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pack = require(ReplicatedStorage:FindFirstChild("DataPack"))

local data = {
	Name = "PlayerStats",
	Level = 12,
	Inventory = { "Sword", "Shield", "Potion" },
}

local pack = Pack.New(data)

local result = pack:Return()
print(result.Level) -- 12
