# Note: Functions surrounded by a comment blocks are there because `Vararg` is still allocating.
# When Vararg is fast enough, they can simply be removed.


#######################
# UndefBlocksInitializer #
#######################

"""
    UndefBlocksInitializer

Singleton type used in block array initialization, indicating the
array-constructor-caller would like an uninitialized block array. See also
undef_blocks (@ref), an alias for UndefBlocksInitializer().

Examples

≡≡≡≡≡≡≡≡≡≡
```julia
julia> BlockArray(undef_blocks, Matrix{Float32}, [1,2], [3,2])
2×2-blocked 3×5 BlockArrays.BlockArray{Float32,2,Array{Float32,2}}:
 #undef  #undef  #undef  │  #undef  #undef
 ------------------------┼----------------
 #undef  #undef  #undef  │  #undef  #undef
 #undef  #undef  #undef  │  #undef  #undef
 ```
"""
struct UndefBlocksInitializer end

"""
    undef_blocks

Alias for UndefBlocksInitializer(), which constructs an instance of the singleton
type UndefBlocksInitializer (@ref), used in block array initialization to indicate the
array-constructor-caller would like an uninitialized block array.

Examples

≡≡≡≡≡≡≡≡≡≡
```julia
julia> BlockArray(undef_blocks, Matrix{Float32}, [1,2], [3,2])
2×2-blocked 3×5 BlockArrays.BlockArray{Float32,2,Array{Float32,2}}:
 #undef  #undef  #undef  │  #undef  #undef
 ------------------------┼----------------
 #undef  #undef  #undef  │  #undef  #undef
 #undef  #undef  #undef  │  #undef  #undef
 ```
"""
const undef_blocks = UndefBlocksInitializer()

##############
# BlockArray #
##############

function _BlockArray end

"""
    BlockArray{T, N, R <: AbstractArray{T, N}} <: AbstractBlockArray{T, N}

A `BlockArray` is an array where each block is stored contiguously. This means that insertions and retrieval of blocks
can be very fast and non allocating since no copying of data is needed.

In the type definition, `R` defines the array type that each block has, for example `Matrix{Float64}`.
"""
struct BlockArray{T, N, R <: AbstractArray{T, N}} <: AbstractBlockArray{T, N}
    blocks::Array{R, N}
    block_sizes::BlockSizes{N}

    global function _BlockArray(blocks::Array{R, N}, block_sizes::BlockSizes{N}) where {T, N, R <: AbstractArray{T, N}}
        new{T, N, R}(blocks, block_sizes)
    end
end

# Auxilary outer constructors
function _BlockArray(blocks::Array{R, N}, block_sizes::Vararg{AbstractVector{Int}, N}) where {T, N, R <: AbstractArray{T, N}}
    return _BlockArray(blocks, BlockSizes(block_sizes...))
end

const BlockMatrix{T, R <: AbstractMatrix{T}} = BlockArray{T, 2, R}
const BlockVector{T, R <: AbstractVector{T}} = BlockArray{T, 1, R}
const BlockVecOrMat{T, R} = Union{BlockMatrix{T, R}, BlockVector{T, R}}

################
# Constructors #
################

@inline function _BlockArray(::Type{R}, block_sizes::Vararg{AbstractVector{Int}, N}) where {T, N, R <: AbstractArray{T, N}}
    _BlockArray(R, BlockSizes(block_sizes...))
end

function _BlockArray(::Type{R}, block_sizes::BlockSizes{N}) where {T, N, R <: AbstractArray{T, N}}
    n_blocks = nblocks(block_sizes)
    blocks = Array{R, N}(undef, n_blocks)
    _BlockArray(blocks, block_sizes)
end

@inline function undef_blocks_BlockArray(::Type{R}, block_sizes::Vararg{AbstractVector{Int}, N}) where {T, N, R <: AbstractArray{T, N}}
    _BlockArray(R, block_sizes...)
end

"""
Constructs a `BlockArray` with uninitialized blocks from a block type `R` with sizes defind by `block_sizes`.

```jldoctest
julia> BlockArray(undef_blocks, Matrix{Float64}, [1,3], [2,2])
2×2-blocked 4×4 BlockArrays.BlockArray{Float64,2,Array{Float64,2}}:
 #undef  │  #undef  #undef  #undef  │
 --------┼--------------------------┼
 #undef  │  #undef  #undef  #undef  │
 #undef  │  #undef  #undef  #undef  │
 --------┼--------------------------┼
 #undef  │  #undef  #undef  #undef  │
```
"""
@inline function BlockArray(::UndefBlocksInitializer, ::Type{R}, block_sizes::Vararg{AbstractVector{Int}, N}) where {T, N, R <: AbstractArray{T, N}}
    undef_blocks_BlockArray(R, block_sizes...)
end

@inline function BlockArray{T}(::UndefBlocksInitializer, block_sizes::Vararg{AbstractVector{Int}, N}) where {T, N}
    BlockArray(undef_blocks, Array{T,N}, block_sizes...)
end

@inline function BlockArray{T,N}(::UndefBlocksInitializer, block_sizes::Vararg{AbstractVector{Int}, N}) where {T, N}
    BlockArray(undef_blocks, Array{T,N}, block_sizes...)
end

@inline function BlockArray{T,N,R}(::UndefBlocksInitializer, block_sizes::Vararg{AbstractVector{Int}, N}) where {T, N, R <: AbstractArray{T, N}}
    BlockArray(undef_blocks, R, block_sizes...)
end



@generated function initialized_blocks_BlockArray(::Type{R}, block_sizes::BlockSizes{N}) where {T, N, R <: AbstractArray{T, N}}
    return quote
        block_arr = _BlockArray(R, block_sizes)
        @nloops $N i i->(1:nblocks(block_sizes, i)) begin
            block_index = @ntuple $N i
            setblock!(block_arr, similar(R, blocksize(block_sizes, block_index)), block_index...)
        end

        return block_arr
    end
end


function initialized_blocks_BlockArray(::Type{R}, block_sizes::Vararg{AbstractVector{Int}, N}) where {T, N, R <: AbstractArray{T, N}}
    initialized_blocks_BlockArray(R, BlockSizes(block_sizes...))
end

@inline function BlockArray{T}(::UndefInitializer, block_sizes::BlockSizes{N}) where {T, N}
    initialized_blocks_BlockArray(Array{T, N}, block_sizes)
end

@inline function BlockArray{T, N}(::UndefInitializer, block_sizes::BlockSizes{N}) where {T, N}
    initialized_blocks_BlockArray(Array{T, N}, block_sizes)
end

@inline function BlockArray{T, N, R}(::UndefInitializer, block_sizes::BlockSizes{N}) where {T, N, R <: AbstractArray{T, N}}
    initialized_blocks_BlockArray(R, block_sizes)
end

@inline function BlockArray{T}(::UndefInitializer, block_sizes::Vararg{AbstractVector{Int}, N}) where {T, N}
    initialized_blocks_BlockArray(Array{T, N}, block_sizes...)
end

@inline function BlockArray{T, N}(::UndefInitializer, block_sizes::Vararg{AbstractVector{Int}, N}) where {T, N}
    initialized_blocks_BlockArray(Array{T, N}, block_sizes...)
end

@inline function BlockArray{T, N, R}(::UndefInitializer, block_sizes::Vararg{AbstractVector{Int}, N}) where {T, N, R <: AbstractArray{T, N}}
    initialized_blocks_BlockArray(R, block_sizes...)
end

function BlockArray(arr::AbstractArray{T, N}, block_sizes::Vararg{AbstractVector{Int}, N}) where {T,N}
    for i in 1:N
        if sum(block_sizes[i]) != size(arr, i)
            throw(DimensionMismatch("block size for dimension $i: $(block_sizes[i]) does not sum to the array size: $(size(arr, i))"))
        end
    end
    BlockArray(arr, BlockSizes(block_sizes...))
end

@generated function BlockArray(arr::AbstractArray{T, N}, block_sizes::BlockSizes{N}) where {T,N}
    return quote
        block_arr = _BlockArray(typeof(arr), block_sizes)
        @nloops $N i i->(1:nblocks(block_sizes, i)) begin
            block_index = @ntuple $N i
            indices = globalrange(block_sizes, block_index)
            setblock!(block_arr, arr[indices...], block_index...)
        end

        return block_arr
    end
end

# Convert AbstractArrays that conform to block array interface
convert(::Type{BlockArray{T,N,R}}, A::BlockArray{T,N,R}) where {T,N,R} = A
convert(::Type{BlockArray{T,N}}, A::BlockArray{T,N}) where {T,N} = A
convert(::Type{BlockArray{T}}, A::BlockArray{T}) where {T} = A
convert(::Type{BlockArray}, A::BlockArray) = A

BlockArray{T, N}(A::AbstractArray{T2, N}) where {T,T2,N} =
    BlockArray(Array{T, N}(A), blocksizes(A))
BlockArray{T1}(A::AbstractArray{T2, N}) where {T1,T2,N} = BlockArray{T1, N}(A)
BlockArray(A::AbstractArray{T, N}) where {T,N} = BlockArray{T, N}(A)

convert(::Type{BlockArray{T, N}}, A::AbstractArray{T2, N}) where {T,T2,N} =
    BlockArray(convert(Array{T, N}, A), blocksizes(A))
convert(::Type{BlockArray{T1}}, A::AbstractArray{T2, N}) where {T1,T2,N} =
    convert(BlockArray{T1, N}, A)
convert(::Type{BlockArray}, A::AbstractArray{T, N}) where {T,N} =
    convert(BlockArray{T, N}, A)

copy(A::BlockArray) = _BlockArray(copy.(A.blocks), copy(A.block_sizes))

################################
# AbstractBlockArray Interface #
################################
@inline blocksizes(block_array::BlockArray) = block_array.block_sizes

@inline function getblock(block_arr::BlockArray{T,N}, block::Vararg{Int, N}) where {T,N}
    @boundscheck blockcheckbounds(block_arr, block...)
    block_arr.blocks[block...]
end

@inline function Base.getindex(block_arr::BlockArray{T,N}, blockindex::BlockIndex{N}) where {T,N}
    @boundscheck checkbounds(block_arr.blocks, blockindex.I...)
    @inbounds block = block_arr.blocks[blockindex.I...]
    @boundscheck checkbounds(block, blockindex.α...)
    @inbounds v = block[blockindex.α...]
    return v
end


###########################
# AbstractArray Interface #
###########################

@inline function Base.similar(block_array::BlockArray{T,N}, ::Type{T2}) where {T,N,T2}
    _BlockArray(similar(block_array.blocks, Array{T2, N}), copy(blocksizes(block_array)))
end

@inline function Base.getindex(block_arr::BlockArray{T, N}, i::Vararg{Int, N}) where {T,N}
    @boundscheck checkbounds(block_arr, i...)
    @inbounds v = block_arr[global2blockindex(blocksizes(block_arr), i)]
    return v
end

@inline function Base.setindex!(block_arr::BlockArray{T, N}, v, i::Vararg{Int, N}) where {T,N}
    @boundscheck checkbounds(block_arr, i...)
    @inbounds block_arr[global2blockindex(blocksizes(block_arr), i)] = v
    return block_arr
end

############
# Indexing #
############

function _check_setblock!(block_arr::BlockArray{T, N}, v, block::NTuple{N, Int}) where {T,N}
    for i in 1:N
        if size(v, i) != blocksize(block_arr, i, block[i])
            throw(DimensionMismatch(string("tried to assign $(size(v)) array to ", blocksize(block_arr, block), " block")))
        end
    end
end


@inline function setblock!(block_arr::BlockArray{T, N}, v, block::Vararg{Int, N}) where {T,N}
    @boundscheck blockcheckbounds(block_arr, block...)
    @boundscheck _check_setblock!(block_arr, v, block)
    @inbounds block_arr.blocks[block...] = v
    return block_arr
end

@propagate_inbounds function Base.setindex!(block_array::BlockArray{T, N}, v, block_index::BlockIndex{N}) where {T,N}
    getblock(block_array, block_index.I...)[block_index.α...] = v
end

########
# Misc #
########

@generated function Base.Array(block_array::BlockArray{T, N, R}) where {T,N,R}
    # TODO: This will fail for empty block array
    return quote
        block_sizes = blocksizes(block_array)
        arr = similar(block_array.blocks[1], size(block_array)...)
        @nloops $N i i->(1:nblocks(block_sizes, i)) begin
            block_index = @ntuple $N i
            indices = globalrange(block_sizes, block_index)
            arr[indices...] = getblock(block_array, block_index...)
        end

        return arr
    end
end

@generated function copyto!(block_array::BlockArray{T, N, R}, arr::R) where {T,N,R <: AbstractArray}
    return quote
        block_sizes = blocksizes(block_array)

        @nloops $N i i->(1:nblocks(block_sizes, i)) begin
            block_index = @ntuple $N i
            indices = globalrange(block_sizes, block_index)
            copyto!(getblock(block_array, block_index...), arr[indices...])
        end

        return block_array
    end
end

function Base.fill!(block_array::BlockArray, v)
    for block in block_array.blocks
        fill!(block, v)
    end
    block_array
end

function lmul!(α::Number, block_array::BlockArray)
    for block in block_array.blocks
        lmul!(α, block)
    end
    block_array
end

function rmul!(block_array::BlockArray, α::Number)
    for block in block_array.blocks
        rmul!(block, α)
    end
    block_array
end
