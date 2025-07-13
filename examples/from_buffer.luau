local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pack = require(ReplicatedStorage:FindFirstChild("DataPack"))

local original = { Score = 420, Valid = true }

local pack = Pack.New(original)
local buffer = pack:GetBuffer()

-- reuse later
local reused = Pack.FromBuffer(buffer)
print(reused:Return().Score) -- 420
