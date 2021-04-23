---
author: Joe Kachmar
title: Levity Polymorphism in Haskell
subtitle: ...and other things that aren't discussed very often
date: 16 June 2020
institute: Berlin Functional Programming Group

theme: metropolis

mainfont: Open Sans
mainfontoptions: Scale=1
sansfont: Open Sans
sansfontoptions: Scale=1
monofont: 'Fira Code'
monofontoptions: Scale=0.85

header-includes:
  - '\hypersetup{colorlinks=true}'
  - '\usetheme{metropolis}'
  - '\makeatletter'
  - '\def\verbatim@nolig@list{}'
  - '\beamer@ignorenonframefalse'
  - '\makeatother'
---

## Preamble

* The Glasgow Haskell Compiler (GHC) is _very advanced_
  * It can (and will) aggressively optimize high-level code
  * Assume _all_ code that follows is subject to optimization
  * What's true for `-O0` is not necessarily true for `-O2`

. . .

* Much of what follows is being actively researched
  * Things may change subtly between releases of GHC

. . .

* I'm **not** an active user of all of these features
  * Trust, but verify; I'll likely have gotten some of this wrong

# Haskell, what is it good for?

## Haskell, what is it good for?

Haskell is known for being:

* pure
* functional
* statically typed

. . .

* **lazy**
* **high-level**
* **higher-kinded**

## Haskell, what is it good for?

Haskell is **not** known for:

* "obvious" space/time complexity
  * consequence of lazy evaluation

* precise control over memory allocation
  * not uncommon in "high-level"[^high-level] languages

[^high-level]: "High-level" and "low-level" are fairly squishy terms; for the
sake of example consider Python to be high-level and C to be low-level

# Laziness, Lifted Types, and Levity Polymorphism

## Laziness

```haskell
data Boolean = False | True
```

. . .

`False` is a _value_ whose _type_ is `Boolean`

```
λ> :type False
False :: Boolean
```

. . .

`Boolean` is a _type_ whose _kind_ is `Type`

```
λ> :kind Boolean
Boolean :: Type
```

. . .

Kinds are like "types of types"

## Laziness

```haskell
example :: [Boolean]
example = [True, error "boom!"]
```

. . .


```
λ> head example
True
```

`example` is a lazy value

* `error` isn't evaluated on definition
* `head` doesn't touch `error`

. . .

```
λ> head (tail example)
*** Exception: boom!
```

## Laziness and Lifted Types

What we wrote:

```haskell
data Boolean = True | False
```

What we believed:

`Boolean` values may to be one of...

* `True`
* `False`

## Laziness and Lifted Types

What we actually got:

```haskell
data Boolean = True | False | ⊥
```

`Boolean` values may _actually_ be one of...

* `True`
* `False`
* `⊥` or "bottom"
  * Computations which never complete successfully [^bottom]
  * Frequently a result of `undefined` or `error`

[^bottom]: https://wiki.haskell.org/Bottom

## Laziness, Lifted Types, and Levity Polymorphism

What _is_ a `Type`, anyway?

. . .

```haskell
data TYPE (a :: RuntimeRep)
data RuntimeRep = LiftedRep | UnliftedRep | Int8Rep | ...
type Type = (TYPE 'LiftedRep)
```

* `TYPE` is the abstract "kind" of valid Haskell types
  * Parameterized by runtime representation
* `TYPE LiftedRep` is a "lifted type"
  * **Lazy** types
  * "Normal" Haskell `Type`s
* `TYPE UnliftedRep` is an "unlifted type"
  * **Strict** types
* `TYPE IntRep` is a "primitive type"
  * Strict 8-bit signed integer types

## Levity Polymorphism

What we think Haskell gives us:
```haskell
($) :: (a -> b) -> a -> b
f $ x = f x
```
. . .

What Haskell _actually_ gives us:
```haskell
($) :: forall r a (b :: TYPE r). (a -> b) -> a -> b
f $ x = f x
```

* `f :: (a :: Type) -> (b :: TYPE r)`
  * Accepts a lifted type
  * Returns a type that is _levity-polymorphic_
    * i.e. polymorphic over its "liftedness"
    * More precisely it is polymorphic over its _representation_

## Levity Polymorphism

Levity polymorphism and unlifted types have restrictions...

* Levity-polymorphic values cannot be _bound_
  * `fn0 x = ...` or `let x = ...` are illegal when `x :: TYPE r`

* Unlifted types cannot be bound at the _top-level_
  * `fn1 :: (a :: TYPE 'UnliftedRep)` is illegal

* Error messages and type signatures can be confusing

## Laziness, Lifted Types, and Levity Polymorphism

Recap

* Haskell is a lazy language
* Lazy values are "lifted"
* Strict values are "unlifted"
* Levity polymorphism abstracts over this distinction

## {.standout}

Questions?

# Runtime Representation and Memory Allocation

## Runtime Representation

_[...] calling convention is an implementation-level scheme for how subroutines receive parameters from their caller and how they return a result._ [^calling]

. . .

```haskell
data RuntimeRep 
  = LiftedRep | UnliftedRep | Int8Rep
  | TupleRep [RuntimeRep] | SumRep [RuntimeRep]
  ...
```

`RuntimeRep` abstracts over _calling convention_


[^calling]: https://en.wikipedia.org/wiki/Calling_convention

## Memory Allocation

Lifted types _must be_ boxed [^optimization]

* Boxed values are represented by pointers to heap-allocated objects

. . .

Unboxed values _must_ be unlifted

* `Int#`: unboxed, unlifted machine-sized integer

. . .

Unlifted structures _may_ contain lifted values

* `Array# Int`: boxed, unlifted array of lifted integers

[^optimization]: GHC can (and will) optimize this away in many cases


## Memory Allocation

Why care about this?

. . .

Unboxed values come with some guarantees:

* Memory representation is _static_ and stack-allocated
* Can be stored directly in register memory
* Can be _deterministically_ made to be _very_ efficient

## Runtime Representation and Memory Allocation

```haskell
add_int :: Int# -> Int# -> Int#
add_int i1 i2 = i2 +# i3
```

* `i1`, `i2`, `i3` are **stack**-allocated machine-sized signed integers
* `+#` is a primop wrapper for native integer addition[^primops]

[^primops]: https://gitlab.haskell.org/ghc/ghc/-/wikis/commentary/prim-ops

## Runtime Representation and Memory Allocation

![`add_int` Function Definition](images/add_int_fn.png)

![`add_int` Assembly](images/add_int_asm.png)

## Unboxed Tuples

```haskell
(Int, Int)
```

* Pointer to a heap object also pointing to heap objects[^optimization]

. . .


```haskell
(# Int, Int #)
```

* Unboxed tuple of lifted `Int`s
* Contiguously spaced pointers to heap-allocated `Int`s

. . .

```haskell
(# Int#, Int# #)
```

* Unboxed tuple of unboxed `Int#`s
* Two machine-sized integers in contiguous memory

[^optimization]: Again, all of this may be completely optimized away

## Unboxed Sums

```haskell
data IntOrFloat = Int64 | Double | Word64
```

* All pointer-indirected, as with the tuples

. . .

```haskell
type IntOrFloat# = (# Int64# | Double# | Word64# #)
```

* Three words on 64-bit architectures
  * Tag word identifying the constructor
  * Info table pointer[^info_table]
  * Data word (containing the actual data)

[^info_table]: https://gitlab.haskell.org/ghc/ghc/-/wikis/commentary/rts/storage/heap-objects#info-tables

. . .

GHC _should_ optimize the former down to the latter[^unpacked_sum]

[^unpacked_sum]: https://gitlab.haskell.org/ghc/ghc/-/wikis/unpacked-sum-types

## Low-Overhead Abstractions in Haskell

```haskell
type Maybe# a = (# a | (##) #)

pattern Just# :: a -> Maybe# a
pattern Just# a = (# a | #)

pattern Nothing# :: Maybe# a
pattern Nothing# = (# | (##) #)
```

* `(##)`: empty, unboxed tuple
* Pattern synonyms to aid construction
* GHC 8.10's `UnliftedNewtype`s makes this easier

## Miscellany

```haskell
{-# language MagicHash, UnboxedSums, UnboxedTuples #-}
```

`MagicHash`: `#` may be used postfix in names

* `Int64#`: type constructor for unboxed 64-bit integers
* `I64#`: data constructor for 64-bit integers
  * Has the type `Int# -> Int64` 

```haskell
import GHC.Exts
```

`GHC.Exts`: provides primitive functionality

* "Approved" re-exports from `GHC.Prim` module[^prim]

[^prim]: https://hackage.haskell.org/package/ghc-prim-0.6.1/docs/GHC-Prim.html

## Related Reading

[`url-bytes`: URL parser](https://github.com/goolord/url-bytes/blob/1a97c9194574672243a843d70b07218d7cb58c62/src/Url/Rebind.hs#L88-L129)

* Demonstrates some of the present ergonomic issues

[`parsnip`: ANSI string parser combinators](https://github.com/ekmett/codex/blob/d16edaff0e1fe111426c492b6ff19f497c6265d1/parsnip/src/Text/Parsnip/Internal/Parser.hs)

[Unlifted Data Types Wiki Entry](https://gitlab.haskell.org/ghc/ghc/-/wikis/unlifted-data-types)

* [Unlifted Data Types GHC Proposal](https://github.com/ghc-proposals/ghc-proposals/blob/56c4b7f900e772135dc0ec098a7e2fcc3e7e82be/proposals/0265-unlifted-datatypes.rst)

[Unarisation GHC Source Code](https://gitlab.haskell.org/ghc/ghc/-/blob/master/compiler/GHC/Stg/Unarise.hs)

* [Explanation of Unarisation (by chessai)](https://github.com/mckeankylej/unpacked-maybe/issues/3#issuecomment-567167058)

## {.standout}

Questions?

