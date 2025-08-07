# Kororā
A tiny & fast composable type system for Nix, in Nix.

Named after the [little penguin](https://www.doc.govt.nz/nature/native-animals/birds/birds-a-z/penguins/little-penguin-korora/).

# Features

- Types
  - Primitive types (`string`, `int`, etc)
  - Polymorphic types (`union`, `attrsOf`, etc)
  - Struct types

# Basic usage

- Verification

Basic verification is done with the type function `verify`:
``` nix
{ korora }:
let
  t = korora.string;

  value = 1;

  # Error contains the string "Expected type 'string' but value '1' is of type 'int'"
  error = t.verify 1;

in if error != null then throw error else value
```
Errors are returned as a string.
On success `null` is returned.

- Checking (assertions)

For convenience you can also check a value on-the-fly:
``` nix
{ korora }:
let
  t = korora.string;

  value = 1;

  # Same error as previous example, but `check` throws.
  value = t.check value value;

in value
```

On error `check` throws. On success it returns the value that was passed in.

# Examples
For usage example see [tests.nix](./tests.nix).

# Reference

## `lib.types.typedef`

Declare a custom type using a bool function

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

## `lib.types.never`

Never

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

## `lib.types.path`

Path

## `lib.types.derivation`

Derivation

## `lib.types.type`

Type

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

: Any of <t>


## `lib.types.intersection`

intersection<types...>

`types`

: All of <t>


## `lib.types.rename`

rename<name, type>

Because some polymorphic types such as attrsOf inherits names from it's
sub-types we need to erase the name to not cause infinite recursion.

#### Example:
``` nix
myType = types.attrsOf (
  types.rename "eitherType" (types.union [
    types.string
    myType
  ])
);
```

`name`

: Function argument


`type`

: Function argument


## `lib.types.struct`

struct<name, members...>

#### Example
``` nix
korora.struct "myStruct" {
  foo = types.string;
}
```

#### Features

- Totality

By default, all attribute names must be present in a struct. It is possible to override this by specifying _totality_. Here is how to do this:
``` nix
(korora.struct "myStruct" {
  foo = types.string;
}).override { total = false; }
```

This means that a `myStruct` struct can have any of the keys omitted. Thus these are valid:
``` nix
let
  s1 = { };
  s2 = { foo = "bar"; }
in ...
```

- Unknown attribute names

By default, unknown attribute names are allowed.

It is possible to override this by specifying `unknown`.
``` nix
(korora.struct "myStruct" {
  foo = types.string;
}).override { unknown = false; }
```

This means that
``` nix
{
  foo = "bar";
  baz = "hello";
}
```
is normally valid, but not when `unknown` is set to `false`.

Because Nix lacks primitive operations to iterate over attribute sets dynamically without
allocation this function allocates one intermediate attribute set per struct verification.

- Custom invariants

Custom struct verification functions can be added as such:
``` nix
(types.struct "testStruct2" {
  x = types.int;
  y = types.int;
}).override {
  verify = v: if v.x + v.y == 2 then "VERBOTEN" else null;
};
```

#### Function signature

`name`

: Name of struct type as a string


`members`

: Attribute set of type definitions.


## `lib.types.optionalAttr`

optionalAttr<t>

`t`

: Function argument


## `lib.types.enum`

enum<name, elems...>

`name`

: Name of enum type as a string


`elems`

: List of allowable enum members



