#================================================

Basic typedefs, function / macro defintions, etc. for the module

=================================================#

using Base.Threads

#===========================
Constants
===========================#

const DEFAULT_P = 0.5
const DEFAULT_MAX_HEIGHT = 64
const DEFAULT_NODE_CAPACITY = 32

const FLAG_IS_LEFT_SENTINEL = 0x80
const FLAG_IS_RIGHT_SENTINEL = 0x40
const IS_SENTINEL = FLAG_IS_LEFT_SENTINEL | FLAG_IS_RIGHT_SENTINEL

const NODE_NOT_FOUND = -1

#===========================
Typedefs
===========================#

abstract type AbstractNode{T,M} end
abstract type AbstractSkipList{T,M} end

