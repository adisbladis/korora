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



