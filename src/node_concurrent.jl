#================================================

ConcurrentNode-specific code

=================================================#

using Base.Threads

#===========================
ConcurrentNode constructors
===========================#

function ConcurrentNode{T,M}(val, height; flags = 0x0, max_height = DEFAULT_MAX_HEIGHT) where {T,M}
    height = min(height, max_height)
    next = Vector{ConcurrentNode{T,M}}(undef, height)
    lock = ReentrantLock()
    prepared_lock = Threads.Condition()

    fully_linked = Atomic{Bool}(false)
    marked_for_deletion = Atomic{Bool}(false)

    ConcurrentNode{T,M}(val, next, fully_linked, marked_for_deletion, flags, lock, prepared_lock)
end

function ConcurrentLeftSentinel{T,M}(; max_height = DEFAULT_MAX_HEIGHT, kws...) where {T,M}
    node = ConcurrentNode{T,M}(zero(T), max_height; flags = FLAG_IS_LEFT_SENTINEL, kws...)
    mark_fully_linked!(node)
    node
end

function ConcurrentRightSentinel{T,M}(; max_height = DEFAULT_MAX_HEIGHT, kws...) where {T,M}
    node = ConcurrentNode{T,M}(zero(T), max_height; flags = FLAG_IS_RIGHT_SENTINEL, kws...)
    mark_fully_linked!(node)
    node
end

#===========================
ConcurrentNode external API
===========================#

function Base.string(node::ConcurrentNode)
    result = "key = $(key(node)), height = $(height(node)), "
    result *= "marked_for_deletion = $(is_marked_for_deletion(node)), "
    result *= "fully_linked = $(is_fully_linked(node))"
    "ConcurrentNode($result)"
end

Base.lock(node::ConcurrentNode) = lock(node.lock)
Base.unlock(node::ConcurrentNode) = unlock(node.lock)

key(node::ConcurrentNode) = node.val

is_marked_for_deletion(node) = node.marked_for_deletion[]
is_fully_linked(node) = node.fully_linked[]

unmark_for_deletion!(node) = atomic_xchg!(node.marked_for_deletion, false)

function mark_for_deletion!(node)
    if !is_sentinel(node)
        atomic_xchg!(node.marked_for_deletion, true)
    else
        # If the node is a sentinel, it can't be marked for deletion, so we
        # always return false
        false
    end
end

mark_fully_linked!(node) = atomic_or!(node.fully_linked, true)

"""
Check that a `ConcurrentNode` is okay to be deleted, meaning that
- it's fully linked,
- unmarked, and
- that it was found at its top layer.
"""
function ok_to_delete(node, level_found)
    height(node) == level_found &&
    is_fully_linked(node) &&
    !is_marked_for_deletion(node)
end


