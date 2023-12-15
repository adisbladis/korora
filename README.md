# Kororā
A tiny & fast composable type system for Nix, in Nix.

# Features

- Types
  - Primitive types (`string`, `int`, etc)
  - Polymorphic types (`union`, `attrsOf`, etc)
  - Struct types

# Examples
For usage example see [tests.nix](./tests.nix).

# Reference

## `lib.types.typedef`

Declare a custom type using a bool function.

`name`

: Name of the type as a string


`verify`

: Verification function returning a bool.


## `lib.types.typedef'`

Declare a custom type using an option<str> function.

`name`

: Name of the type as a string


`verify`

: Verification function returning null on success & a string with error message on error.


## `lib.types.string`

String

## `lib.types.str`

Type alias for string

## `lib.types.any`

Any

## `lib.types.int`

Int

## `lib.types.float`

Single precision floating point

## `lib.types.number`

Either an int or a float

## `lib.types.bool`

Bool

## `lib.types.attrs`

Attribute with undefined attribute types

## `lib.types.list`

Attribute with undefined element types

## `lib.types.function`

Function

## `lib.types.option`

Option<t>

`t`

: Null or t


## `lib.types.listOf`

listOf<t>

`t`

: Element type


## `lib.types.attrsOf`

listOf<t>

`t`

: Attribute value type


## `lib.types.union`

union<types...>

`types`

: Any of listOf<t>


## `lib.types.struct`

union<name, members...>

`name`

: Name of struct type as a string


`members`

: Attribute set of type definitions.


## `lib.types.enum`

enum<name, elems...>

`name`

: Name of enum type as a string


`elems`

: List of allowable enum members

