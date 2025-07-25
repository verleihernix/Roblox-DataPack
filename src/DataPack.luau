--!strict
local HttpService = game:GetService("HttpService")

export type Metadata = { [string]: any }?
export type Stats = {
	Size: number,
	OriginalSize: number,
	Compressed: boolean,
	CompressionRatio: number,
	Efficiency: "Poor" | "Fair" | "Good" | "Excellent",
}

export type DataPack<T> = {
	Return: (self: DataPack<T>) -> T?,
	Clone: (self: DataPack<T>) -> DataPack<T>,
	Destroy: (self: DataPack<T>) -> (),
	StreamRead: (self: DataPack<T>, chunkSize: number?) -> () -> string?,
	SetMetadata: (self: DataPack<T>, metadata: Metadata) -> (),
	Validate: (self: DataPack<T>) -> boolean,

	-- Getters
	IsCompressed: (self: DataPack<T>) -> boolean,
	GetStats: (self: DataPack<T>) -> Stats,
	GetSize: (self: DataPack<T>) -> number,
	GetOriginalSize: (self: DataPack<T>) -> number,
	GetCompressionRatio: (self: DataPack<T>) -> number,
	GetMetadata: (self: DataPack<T>) -> Metadata,
	GetBuffer: (self: DataPack<T>) -> buffer?,
	GetId: (self: DataPack<T>) -> string,
}
type InternalDataPack<T> = DataPack<T> & {
	__index: any,
	_id: string,
	_buffer: buffer,
	_originalSize: number,
	_compressed: boolean,
	_chunkSize: number?,
	_metadata: Metadata,
}

export type StreamWriter = {
	Write: (self: StreamWriter, data: string) -> boolean,
	WriteAsync: (self: StreamWriter, data: string, callback: ((success: boolean) -> ())?) -> (),
	Finalize: (self: StreamWriter) -> buffer?,
	Close: (self: StreamWriter) -> (),

	-- Getters
	GetUsage: (self: StreamWriter) -> number,
	IsClosed: (self: StreamWriter) -> boolean,
	GetCapacity: (self: StreamWriter) -> number,
}
type InternalStreamWriter = StreamWriter & {
	__index: any,
	_buffer: buffer,
	_position: number,
	_capacity: number,
	_closed: boolean,
}

export type PackConstructor = {
	New: <T>(data: T, options: {
		compress: boolean,
		metadata: Metadata,
	}?) -> DataPack<T>,
	NewStream: (initialCapacity: number?) -> StreamWriter,
	FromBuffer: (buf: buffer, metadata: Metadata) -> DataPack<any>,

	-- Constants
	COMPRESSION_THRESHOLD: number,
	DEFAULT_CHUNK_SIZE: number,
	VERSION: string,
}
type InternalPackConstructor = PackConstructor & {
	__index: any,
	compress: (data: string) -> string,
	decompress: (data: string) -> string?,
	validateCompression: (original: string, compressed: string) -> boolean,
}

local PackConstructor = {} :: InternalPackConstructor
local DataPack = {} :: InternalDataPack<any>
local StreamWriter = {} :: InternalStreamWriter

-- Constants
PackConstructor.COMPRESSION_THRESHOLD = 1024 -- 1KB
PackConstructor.DEFAULT_CHUNK_SIZE = 4096 -- 4KB
PackConstructor.VERSION = "1" -- please change the version if you are contributing

-- optimized LZ77-like compression with simple hash map
function PackConstructor.compress(data)
	if #data < PackConstructor.COMPRESSION_THRESHOLD then
		return data
	end

	local windowSize = 255
	local hashMap = {} :: { [string]: { number } }
	local out = {} :: { string }
	local i = 1

	while i <= #data do
		local matchLen, matchDist = 0, 0
		local maxLook = math.min(windowSize, i - 1)
		for l = 3, math.min(255, #data - i + 1) do
			local substr = data:sub(i, i + l - 1)
			local positions = hashMap[substr]
			if not positions then
				break
			end

			matchLen = 1
			matchDist = i - positions[#positions]
		end

		if matchLen >= 3 then
			table.insert(out, string.char(255))
			table.insert(out, string.char(matchDist))
			table.insert(out, string.char(matchLen))

			for j = 0, matchLen - 1 do
				local s = data:sub(i + j, i + j)
				local key = s
				hashMap[key] = hashMap[key] or {}
				table.insert(hashMap[key], i + j)
			end
			i += matchLen
		else
			local c = data:sub(i, i)
			if c:byte() == 255 then
				table.insert(out, string.char(255))
				table.insert(out, string.char(0))
			end

			table.insert(out, c)
			hashMap[c] = hashMap[c] or {}
			table.insert(hashMap[c], i)

			i += 1
		end
	end

	return table.concat(out)
end

function PackConstructor.decompress(data)
	local res = {}
	local i = 1

	while i <= #data do
		local b = data:byte(i)
		if b == 255 then
			local nb = data:byte(i + 1) or 0

			if nb == 0 then
				table.insert(res, string.char(255))
				i += 2
			else
				local dist = nb
				local length = data:byte(i + 2) or 0
				local start = #res - dist + 1

				if start < 1 then
					warn("Invalid reference")
					return nil
				end

				for k = 0, length - 1 do
					table.insert(res, res[start + k])
				end

				i += 3
			end
		else
			table.insert(res, string.char(b))
			i += 1
		end
	end
	return table.concat(res)
end

function PackConstructor.validateCompression(original, compressed)
	local decompressed = PackConstructor.decompress(compressed)
	return decompressed == original
end

function PackConstructor.NewStream(initialCapacity): StreamWriter
	local capacity = initialCapacity or 8192
	local newStream = (setmetatable({}, StreamWriter) :: any) :: InternalStreamWriter

	newStream._buffer = buffer.create(capacity)
	newStream._position = 0
	newStream._capacity = capacity
	newStream._closed = false

	return newStream :: StreamWriter
end
StreamWriter["__index"] = StreamWriter

function StreamWriter:Write(data)
	if (self :: InternalStreamWriter)._closed then
		warn("Cannot write to closed stream")
		return false
	end

	local dataLen = #data
	if dataLen == 0 then
		return true
	end

	-- expand buffer if needed
	if (self :: InternalStreamWriter)._position + dataLen > (self :: InternalStreamWriter)._capacity then
		local newCapacity =
			math.max((self :: InternalStreamWriter)._capacity * 2, (self :: InternalStreamWriter)._position + dataLen)
		local newBuffer = buffer.create(newCapacity)

		if (self :: InternalStreamWriter)._position > 0 then
			buffer.copy(
				newBuffer,
				0,
				(self :: InternalStreamWriter)._buffer,
				0,
				(self :: InternalStreamWriter)._position
			)
		end

		(self :: InternalStreamWriter)._buffer = newBuffer;
		(self :: InternalStreamWriter)._capacity = newCapacity
	end

	-- write data
	buffer.writestring((self :: InternalStreamWriter)._buffer, (self :: InternalStreamWriter)._position, data);
	(self :: InternalStreamWriter)._position = (self :: InternalStreamWriter)._position + dataLen

	return true
end

function StreamWriter:WriteAsync(data, callback)
	task.spawn(function()
		local success = self:Write(data)
		if callback then
			callback(success)
		end
	end)
end

function StreamWriter:Finalize()
	if (self :: InternalStreamWriter)._closed then
		warn("Stream already closed")
		return nil
	end

	local finalBuffer = buffer.create((self :: InternalStreamWriter)._position)
	if (self :: InternalStreamWriter)._position > 0 then
		buffer.copy(finalBuffer, 0, (self :: InternalStreamWriter)._buffer, 0, (self :: InternalStreamWriter)._position)
	end

	self:Close()
	return finalBuffer
end

function StreamWriter:GetUsage()
	return if (self :: InternalStreamWriter)._capacity > 0
		then (self :: InternalStreamWriter)._position / (self :: InternalStreamWriter)._capacity
		else 0
end

function StreamWriter:Close()
	(self :: InternalStreamWriter)._closed = true
	(self :: InternalStreamWriter)._buffer = nil :: any
end

function StreamWriter:IsClosed()
	return (self :: InternalStreamWriter)._closed
end

function StreamWriter:GetCapacity()
	return (self :: InternalStreamWriter)._capacity
end

function PackConstructor.New<T>(data: T, options): DataPack<T>
	local opts = options or {}
	local json = HttpService:JSONEncode(data)
	local origSize = #json
	local finalData = json
	local isCompressed = false

	-- auto compress for big data
	local shouldCompress = (opts :: { compress: boolean? }).compress
	if shouldCompress == nil then
		shouldCompress = origSize >= PackConstructor.COMPRESSION_THRESHOLD
	end

	if shouldCompress then
		local compressed = PackConstructor.compress(json)
		-- only compress if we save at least 10%
		if #compressed < origSize * 0.9 then
			finalData = compressed
			isCompressed = true
		end
	end

	local buff = buffer.create(#finalData)
	buffer.writestring(buff, 0, finalData)

	local newPack = (setmetatable({}, DataPack) :: any) :: InternalDataPack<T>
	newPack._id = HttpService:GenerateGUID(false)
	newPack._buffer = buff
	newPack._originalSize = origSize
	newPack._compressed = isCompressed
	newPack._metadata = (opts :: { metadata: Metadata }).metadata

	return newPack :: DataPack<T>
end

function PackConstructor.FromBuffer<T>(buf, metadata): DataPack<T>
	local newPack = (setmetatable({}, DataPack) :: any) :: InternalDataPack<T>
	newPack._id = HttpService:GenerateGUID(false)
	newPack._buffer = buf
	newPack._originalSize = buffer.len(buf)
	newPack._compressed = false
	newPack._metadata = metadata

	return newPack
end

DataPack["__index"] = DataPack

function DataPack:Return()
	if not (self :: InternalDataPack<any>)._buffer then
		warn("DataPack buffer is nil")
		return nil
	end

	local data = buffer.readstring(
		(self :: InternalDataPack<any>)._buffer,
		0,
		buffer.len((self :: InternalDataPack<any>)._buffer)
	)

	-- decompression if needed
	if (self :: InternalDataPack<any>)._compressed then
		local decompressed = PackConstructor.decompress(data)
		if not decompressed then
			warn("Failed to decompress DataPack data")
			return nil
		end
		data = decompressed
	end

	local success, result = pcall(function()
		return HttpService:JSONDecode(data)
	end)

	if success then
		return result
	else
		warn(`Deserialization failed: {tostring(result)}`)
		return nil
	end
end

function DataPack:StreamRead(chunkSize)
	local size = chunkSize or PackConstructor.DEFAULT_CHUNK_SIZE
	local position = 0
	local bufferSize = buffer.len((self :: InternalDataPack<any>)._buffer)

	return function(): string?
		if position >= bufferSize then
			return nil
		end

		local remainingBytes = bufferSize - position
		local readSize = math.min(size, remainingBytes)

		local chunk = buffer.readstring((self :: InternalDataPack<any>)._buffer, position, readSize)
		position = position + readSize

		return chunk
	end
end

function DataPack:GetSize()
	return buffer.len((self :: InternalDataPack<any>)._buffer)
end

function DataPack:GetOriginalSize()
	return (self :: InternalDataPack<any>)._originalSize
end

function DataPack:IsCompressed()
	return (self :: InternalDataPack<any>)._compressed
end

function DataPack:GetCompressionRatio()
	if not (self :: InternalDataPack<any>)._compressed then
		return 1.0
	end

	return buffer.len((self :: InternalDataPack<any>)._buffer) / (self :: InternalDataPack<any>)._originalSize
end

function DataPack:GetMetadata()
	return (self :: InternalDataPack<any>)._metadata
end

function DataPack:SetMetadata(metadata)
	(self :: InternalDataPack<any>)._metadata = metadata
end

function DataPack:Validate()
	if not (self :: InternalDataPack<any>)._buffer then
		return false
	end

	-- try to read and parse the data
	local success = pcall(function()
		self:Return()
	end)

	return success
end

function DataPack:GetStats()
	local size = self:GetSize()
	local originalSize = self:GetOriginalSize()
	local ratio = self:GetCompressionRatio()

	local efficiency = "Poor"
	if ratio < 0.5 then
		efficiency = "Excellent"
	elseif ratio < 0.7 then
		efficiency = "Good"
	elseif ratio < 0.9 then
		efficiency = "Fair"
	end

	return (
		{
			Size = size,
			OriginalSize = originalSize,
			Compressed = (self :: InternalDataPack<any>)._compressed,
			CompressionRatio = ratio,
			Efficiency = efficiency,
		} :: any
	) :: Stats
end

function DataPack:GetId()
	return (self :: InternalDataPack<any>)._id
end

function DataPack:Clone()
	local originalData = buffer.readstring(
		(self :: InternalDataPack<any>)._buffer,
		0,
		buffer.len((self :: InternalDataPack<any>)._buffer)
	)
	local newBuf = buffer.create(#originalData)
	buffer.writestring(newBuf, 0, originalData)

	local newPack = (setmetatable({}, DataPack) :: any) :: InternalDataPack<any>
	newPack._id = HttpService:GenerateGUID(false)
	newPack._buffer = newBuf
	newPack._originalSize = (self :: InternalDataPack<any>)._originalSize
	newPack._compressed = (self :: InternalDataPack<any>)._compressed
	newPack._metadata = if (self :: InternalDataPack<any>)._metadata
		then table.clone((((self :: any) :: { _metadata: Metadata })._metadata) :: any) :: Metadata
		else nil

	return newPack :: DataPack<any>
end

function DataPack:GetBuffer()
	if not (self :: InternalDataPack<any>)._buffer then
		warn("DataPack buffer is nil")
		return nil
	end

	return (self :: InternalDataPack<any>)._buffer
end

function DataPack:Destroy()
	(self :: InternalDataPack<any>)._buffer = nil :: any
	(self :: InternalDataPack<any>)._originalSize = 0
	(self :: InternalDataPack<any>)._compressed = false
	(self :: InternalDataPack<any>)._metadata = nil
end

return PackConstructor :: PackConstructor
