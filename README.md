# DataPack

A lightweight, high-efficiency serialization and compression module for Roblox using custom buffer-based data handling and simplified LZ77 compression. **Use this to handle large data sets efficiently.**

## Features

- Serialize any Lua table or value using JSON
- Optional automatic compression with threshold-based logic
- Custom lightweight LZ77-like compression and decompression
- Stream-based writing and reading support
- Chunked reading for large data sets
- Metadata attachment
- Cloneable and destructible data packs
- Stats and validation methods included

---

## Usage
###### Basic Example
```lua
local DataPack = require(path.to:FindFirstChild("DataPack"))

local largeData = {}
for i = 1, 100 do
    largeData[i] = {
        Name = "Item" .. i,
        Value = math.random(1, 1000),
        Attributes = {
            Color = "Color" .. math.random(1, 10),
            Size = math.random(1, 100)
        }
    }
end

local myPack = DataPack.new(largeData, { -- optional
    compress = true, -- we dont need to do this here, since it will be done automatically, as the data is very large
    metadata = {} -- optional metadata
})

print(`From {myPack:GetOriginalSize()} bytes to {myPack:GetSize()} bytes`)
```