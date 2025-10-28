/*
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
*/
let
  inherit (builtins)
    typeOf
    isString
    isFunction
    isAttrs
    isList
    all
    attrValues
    isPath
    head
    split
    concatStringsSep
    any
    isInt
    isFloat
    isBool
    attrNames
    elem
    foldl'
    elemAt
    ;

  isDerivation = value: isAttrs value && (value.type or null == "derivation");

  optionalElem = cond: e: if cond then [ e ] else [ ];

  joinKeys = list: concatStringsSep ", " (map (e: "'${e}'") list);

  toPretty = (import ./lib.nix).toPretty { indent = "    "; };

  typeError = name: v: "Expected type '${name}' but value '${toPretty v}' is of type '${typeOf v}'";

  # Builtin primitive checkers return a bool for indicating errors but we return option<str>
  wrapBoolVerify =
    name: verify: v:
    if verify v then null else typeError name v;

  # Wrap builtins.all to return option<str>, with string on error.
  all' =
    func: list:
    if all (v: func v == null) list then
      null
    else
      # If an error was found, run the checks again to find the first error to return.
      (
        let
          recurse =
            i:
            let
              v = elemAt list i;
            in
            if func v != null then func v else recurse (i + 1);
        in
        recurse 0
      );

  addErrorContext = context: error: if error == null then null else "${context}: ${error}";

  fix =
    f:
    let
      x = f x;
    in
    x;

in
fix (self: {

  # Utility functions

  /**
    Declare a custom type using a bool function
  */
  typedef =
    # Name of the type as a string
    name:
    # Verification function returning a bool.
    verify:
    assert isFunction verify;
    self.typedef' name (wrapBoolVerify name verify);

  /**
    Declare a custom type using an option<str> function.
  */
  typedef' =
    # Name of the type as a string
    name:
    # Verification function returning null on success & a string with error message on error.
    verify:
    assert isFunction verify;
    {
      inherit name verify;
      check = v: v2: if verify v == null then v2 else throw (verify v);

      # The name of the type without polymorphic metadata
      __name = head (split "<" name);
    };

  # Primitive types

  /**
    String
  */
  string = self.typedef "string" isString;

  /**
    Type alias for string
  */
  str = self.string;

  /**
    Any
  */
  any = self.typedef' "any" (_: null);

  /**
    Never
  */
  never = self.typedef "never" (_: false);

  /**
    Int
  */
  int = self.typedef "int" isInt;

  /**
    Single precision floating point
  */
  float = self.typedef "float" isFloat;

  /**
    Either an int or a float
  */
  number = self.typedef "number" (v: isInt v || isFloat v);

  /**
    Bool
  */
  bool = self.typedef "bool" isBool;

  /**
    Attribute with undefined attribute types
  */
  attrs = self.typedef "attrs" isAttrs;

  /**
    Attribute with undefined element types
  */
  list = self.typedef "list" isList;

  /**
    Function
  */
  function = self.typedef "function" isFunction;

  /**
    Path
  */
  path = self.typedef "path" isPath;

  /**
    Derivation
  */
  derivation = self.typedef "derivation" isDerivation;

  /**
    Polymorphic types
  */

  /**
    Type
  */
  type = self.typedef "type" (
    v: isAttrs v && v ? name && isString v.name && v ? verify && isFunction v.verify
  );

  /**
    Option<t>
  */
  option =
    # Null or t
    t:
    let
      name = "option<${t.name}>";
      inherit (t) verify;
      withErrorContext = addErrorContext "in ${name}";
    in
    self.typedef' name (v: if v == null then null else withErrorContext (verify v));

  /**
    listOf<t>
  */
  listOf =
    # Element type
    t:
    let
      name = "listOf<${t.name}>";
      inherit (t) verify;
      withErrorContext = addErrorContext "in ${name} element";
    in
    self.typedef' name (v: if !isList v then typeError name v else withErrorContext (all' verify v));

  /**
    listOf<t>
  */
  attrsOf =
    # Attribute value type
    t:
    let
      name = "attrsOf<${t.name}>";
      inherit (t) verify;
      withErrorContext = addErrorContext "in ${name} value";
    in
    self.typedef' name (
      v: if !isAttrs v then typeError name v else withErrorContext (all' verify (attrValues v))
    );

  /**
    union<types...>
  */
  union =
    # Any of <t>
    types:
    assert isList types;
    let
      name = "union<${concatStringsSep "," (map (t: t.name) types)}>";
      funcs = map (t: t.verify) types;
    in
    self.typedef name (v: any (func: func v == null) funcs);

  /**
    intersection<types...>
  */
  intersection =
    # All of <t>
    types:
    assert isList types;
    let
      name = "intersection<${concatStringsSep "," (map (t: t.name) types)}>";
      funcs = map (t: t.verify) types;
    in
    self.typedef name (v: all (func: func v == null) funcs);

  /**
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
  */
  rename = name: type: self.typedef' name type.verify;

  /**
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
  */
  struct =
    # Name of struct type as a string
    name:
    # Attribute set of type definitions.
    members:
    assert isAttrs members;
    let
      names = attrNames members;
      withErrorContext = addErrorContext "in struct '${name}'";

      mkStruct' =
        {
          total ? true,
          unknown ? true,
          verify ? null,
        }:
        assert isBool total;
        assert isBool unknown;
        assert verify != null -> isFunction verify;
        let
          optionalFuncs =
            optionalElem (!unknown) (
              v:
              if removeAttrs v names == { } then
                null
              else
                "keys [${joinKeys (attrNames (removeAttrs v names))}] are unrecognized, expected keys are [${joinKeys names}]"
            )
            ++ optionalElem (verify != null) verify;

          # Turn member verifications into a list of verification functions with their verify functions
          # already looked up & with error contexts already computed.
          verifyAttrs =
            let
              funcs = map (
                attr:
                let
                  memberType = members.${attr};
                  inherit (memberType) verify;
                  withErrorContext = addErrorContext "in member '${attr}'";
                  missingMember = "missing member '${attr}'";
                  isOptionalAttr = memberType.__name == "optionalAttr";
                in
                v:
                (
                  if v ? ${attr} then
                    withErrorContext (verify v.${attr})
                  else if total && (!isOptionalAttr) then
                    missingMember
                  else
                    null
                )
              ) names;
            in
            v:
            if all (func: func v == null) funcs then
              null
            else
              (
                # If an error was found, run the checks again to find the first error to return.
                foldl' (
                  acc: func:
                  if acc != null then
                    acc
                  else if func v != null then
                    func v
                  else
                    null
                ) null funcs
              );

          verify' =
            if optionalFuncs == [ ] then
              verifyAttrs
            else
              let
                allFuncs = [ verifyAttrs ] ++ optionalFuncs;
              in
              v:
              foldl' (
                acc: func:
                if acc != null then
                  acc
                else if func v != null then
                  func v
                else
                  null
              ) null allFuncs;

        in
        (self.typedef' name (v: withErrorContext (if !isAttrs v then typeError name v else verify' v)))
        // {
          override = mkStruct';
        };
    in
    mkStruct' { };

  /**
    optionalAttr<t>
  */
  optionalAttr =
    t:
    let
      name = "optionalAttr<${t.name}>";
      inherit (t) verify;
      withErrorContext = addErrorContext "in ${name}";
    in
    self.typedef' name (v: withErrorContext (verify v));

  /**
    enum<name, elems...>
  */
  enum =
    # Name of enum type as a string
    name:
    # List of allowable enum members
    elems:
    assert isList elems;
    self.typedef' name (
      v: if elem v elems then null else "'${toPretty v}' is not a member of enum '${name}'"
    );
})
