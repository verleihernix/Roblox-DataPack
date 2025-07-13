# DataPack Class
Represents a packaged, serialized and optionally compressed blob of data.

#### Return(): T?
Returns the data contained in the DataPack.

#### Clone(): DataPack<T>
Returns a new instance of the DataPack with the same data and metadata.

#### Destroy(): ()
Destroys the DataPack, freeing up resources.

#### StreamRead(chunkSize: number?): () -> string?
Returns a function that yields string chunks of the serialized data.

Use for: incremental reading (e.g. large strings, streamed buffers)

#### SetMetadata(metadata: Metadata): ()
Sets the metadata for the DataPack.

#### Validate(): boolean
Returns true if the pack is structurally valid and can be unpacked.

## Getters
#### IsCompressed(): boolean
Returns true if the DataPack is compressed.

#### GetStats(): Stats
Returns statistics about the DataPack, including size, original size, compression ratio, and efficiency.

#### GetSize(): number
Returns the size of the DataPack in bytes.

#### GetOriginalSize(): number
Returns the original size of the data before compression.

#### GetCompressionRatio(): number 
Returns the compression ratio of the DataPack. (0-1)

#### GetMetadata(): Metadata
Returns the metadata associated with the DataPack.

#### GetBuffer(): buffer?
Returns the raw buffer of the DataPack, if available. Returns nil if the buffer is not set.

# StreamWriter Class
Used to incrementally build a pack from multiple parts.

#### Write(data: string): boolean
Writes a string to the buffer. Returns true if the write was successful.

#### WriteAsync(data: string, callback: (boolean) -> ()?): ()
Writes a string asynchronously to the buffer. Calls the callback with true if successful, false otherwise.

#### Finalize(): buffer?
Returns the final serialized buffer (ready for FromBuffer).

## Getters
#### GetUsage(): number
Returns the current usage of the StreamWriter buffer in bytes.

#### IsClosed(): boolean
Returns true if the StreamWriter is closed and no more data can be written.

#### GetCapacity(): number
Returns the current capacity of the StreamWriter buffer in bytes.