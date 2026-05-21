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
    length
    mapAttrs
    stringLength
    match
    ;

  isDerivation = value: isAttrs value && (value.type or null == "derivation");

  optionalElem = cond: e: if cond then [ e ] else [ ];

  joinKeys = list: concatStringsSep ", " (map (e: "'${e}'") list);

  lib = import ./lib.nix;
  toPretty = lib.toPretty {indent = "  ";};

  concatMapAttrsStringSep =
    sep: f: attrs:
    concatStringsSep sep (attrValues (mapAttrs f attrs));

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

  scalarName = {
    int = toString;
    bool = v: if v then "true" else "false";
    string = toString;
    path = toString;
    null = toString;
    float = toString;
  };

  fix =
    f:
    let
      x = f x;
    in
    x;


  isType = t: t ? __name && isString t;
in
fix (self: {

  # Utility functions

  /*
    Declare a custom type using a bool function
  */
  typedef =
    # Name of the type as a string
    name:
    # Verification function returning a bool.
    verify:
    assert isFunction verify;
    self.typedef' name (wrapBoolVerify name verify);

  /*
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

  /*
    String
  */
  string = self.typedef "string" isString // {
    match = regex: self.refine "/${regex}/" self.string (s: match regex s != null);
    size = {
      nonEmpty = self.refine "non-empty" self.string (s: s != "");
      lt = len: self.refine "length<${toString len}" self.string (s: stringLength s < len);
      gt = len: self.refine "length>${toString len}" self.string (s: stringLength s > len);
      lte = len: self.refine "length<${toString len}" self.string (s: stringLength s < len);
      gte = len: self.refine "length>${toString len}" self.string (s: stringLength s > len);
      between = a: b: self.refine "${toString a}<=length<=${toString b}" self.string (s: a <= stringLength s && stringLength s <= b);
    };
  };

  /*
    Type alias for string
  */
  str = self.string;

  /*
    Any
  */
  any = self.typedef' "any" (_: null);

  /*
    Never
  */
  never = self.typedef "never" (_: false);

  /*
    Int
  */
  int = self.typedef "int" isInt // {
    lt = len: self.refine "int<${toString len}" self.int (s: s < len);
    gt = len: self.refine "int>${toString len}" self.int (s: s > len);
    lte = len: self.refine "int<${toString len}" self.int (s: s < len);
    gte = len: self.refine "int>${toString len}" self.int (s: s > len);
    between = a: b: self.refine "${toString a}<=int<=${toString b}" self.int (s: a <= s && s <= b);
    even = self.refine "even" self.int (n: n == (n / 2) * 2);
    odd = self.refine "odd" self.int (n: n != (n / 2) * 2);
    positive = self.refine "positive" self.int (n: n > 0);
    nonNegative = self.refine "nonNegative" self.int (n: n >= 0);
    negative = self.refine "positive" self.int (n: n < 0);
  };

  /*
    Single precision floating point
  */
  float = self.typedef "float" isFloat // {
    lt = len: self.refine "float<${toString len}" self.float (s: s < len);
    gt = len: self.refine "float>${toString len}" self.float (s: s > len);
    lte = len: self.refine "float<${toString len}" self.float (s: s < len);
    gte = len: self.refine "float>${toString len}" self.float (s: s > len);
    between = a: b: self.refine "${toString a}<=float<=${toString b}" self.float (s: a <= s && s <= b);
    positive = self.refine "positive" self.float (n: n > 0.0);
    nonNegative = self.refine "nonNegative" self.float (n: n >= 0.0);
    negative = self.refine "positive" self.float (n: n < 0.0);
  };

  /*
    Either an int or a float
  */
  number = self.typedef "number" (v: isInt v || isFloat v) // {
    lt = len: self.refine "number<${toString len}" self.number (s: s < len);
    gt = len: self.refine "number>${toString len}" self.number (s: s > len);
    lte = len: self.refine "number<${toString len}" self.number (s: s < len);
    gte = len: self.refine "number>${toString len}" self.number (s: s > len);
    between = a: b: self.refine "${toString a}<=number<=${toString b}" self.number (s: a <= s && s <= b);
    positive = self.refine "positive" self.number (n: n > 0);
    nonNegative = self.refine "nonNegative" self.number (n: n >= 0);
    negative = self.refine "positive" self.number (n: n < 0);
  };

  /*
    Bool
  */
  bool = self.typedef "bool" isBool;

  /*
    Null
  */
  null = self.typedef "null" isNull;

  /*
    Attribute with undefined attribute types
  */
  attrs = self.typedef "attrs" isAttrs;

  /*
    Attribute with undefined element types
  */
  list = self.typedef "list" isList;

  /*
    Function
  */
  function = self.typedef "function" isFunction;

  /*
    Path
  */
  path = self.typedef "path" isPath;

  /*
    Value that may not technically be a path, but has path-like properties
    Either an actual path `./foo`, a derivation, or a string
  */
  pathLike = self.typedef "pathLike" (v: isPath v || isDerivation v || isString v);

  /*
    Derivation
  */
  derivation = self.typedef "derivation" isDerivation;

  # Polymorphic types

  /*
    Type
  */
  type = self.typedef "type" (
    v: isAttrs v && v ? name && isString v.name && v ? verify && isFunction v.verify
  );

  /*
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

  /*
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

  /*
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

  /*
    map<k, t>
  */
  map =
    # Attribute value type
    k: v:
    let
      name = "map<${k.name}, ${v.name}>";
      withErrorContext = addErrorContext "in ${name} value";
    in
    self.typedef' name (v:
      if !isAttrs v then
        typeError name v
      else
        withErrorContext (all' k.verify (attrNames v) && all' v.verify (attrValues v))
    );
  /*
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

  /*
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

  /*
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

  /*
    struct<name, members...>

    #### Example
    ``` nix
    korora.struct {
      name = "myStruct";
      types = {
        foo = types.string;
      };
    }
    ```

    #### Features

    - Totality

    By default, all attribute names must be present in a struct. It is possible to override this by specifying _totality_. Here is how to do this:
    ``` nix
    korora.struct {
      name = "myStruct";
      types = {
        foo = types.string;
      };
    }
    ```

    This means that a `myStruct` struct can have any of the keys omitted. Thus these are valid:
    ``` nix
    let
      s1 = { };
      s2 = { foo = "bar"; }
    in ...
    ```

    - Unknown attribute names

    By default, unknown attribute names are not allowed.

    It is possible to override this by specifying `unknown` on struct creation:
    ```nix
    korora.struct {
      name = "myStruct";
      unknown = true;
      types = {
        foo = types.string;
      };
    }
    ```

    This means that
    ``` nix
    {
      foo = "bar";
      baz = "hello";
    }
    ```
    is normally invalid, but works when `unknown` is set to `true`.

    Because Nix lacks primitive operations to iterate over attribute sets dynamically without
    allocation this function allocates one intermediate attribute set per struct verification.

    - Custom invariants

    Custom struct verification functions can be added as such:
    ``` nix
    korora.struct {
      name = "testStruct2";
      verify = v: if v.x + v.y == 2 then "VERBOTEN" else null;
      types = {
        x = types.int;
        y = types.int;
      };
    }
    ```

    - Overridability

    An existing struct can have its behavior changed, by using `.override` like so:
    ```nix
    let
      # total is true by default
      myStruct = korora.struct {
        name = "myStruct";
        types = {
          foo = types.string;
        };
      };
    in
      myStruct.override { total = false; }
    ```

    This allows overriding `total`, `unknown`, and `verify` after the fact.

    #### Function signature
  */

  struct =
    args:
    let
      name = args.name;
      types = args.types;
      total = args.total or true;
      unknown = args.unknown or false;
      verify = args.verify or null;

      names = attrNames types;
      withErrorContext = addErrorContext "in struct '${name}'";
    in
    # Old version of the function took two args, for name and type. To give a
    # custom error, allow the function to take another arg if the first arg is a
    # string (since they're passing a name)
    if isString args then
      types:
      abort ''

        Struct wth name '${args}' uses the old struct API, and needs to be rewritten.
        Given the old format:

        types.struct "example" {
          foo = types.int;
        }

        This should be rewritten to:

        types.struct {
          name = "example";
          types = {
            foo = types.int;
          };
        }
      ''
    else
      let
        mkStruct' =
          {
            total ? true,
            unknown ? false,
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
                    memberType = types.${attr};
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
      mkStruct' { inherit total unknown verify; };


  /*
    Another interface for defining records

    record<name, types> - strict record; no unknown elements
    record.partial<name, types> - record which allows missing keys
    record.extensible<name, types> - record which allows unknown keys
    record.loose<name, types> - record which allows missing keys and unknown keys
  */
  record = {
    __functor = _: name: types: self.struct {
      inherit name types;
      total = true;
      unknown = false;
    };
    partial = name: types: self.struct {
      inherit name types;
      total = false;
      unknown = false;
    };
    extensible = name: types: self.struct {
      inherit name types;
      total = true;
      unknown = true;
    };
    loose = name: types: self.struct {
      inherit name types;
      total = false;
      unknown = false;
    };
  };
  /*
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

  /*
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

  /*
    tuple<elems...>
  */
  tuple =
    # List of tuple memeber types
    members:
    assert isList members;
    let
      name = "tuple<${concatStringsSep ", " (map (t: t.name) members)}>";
      withErrorContext = addErrorContext "in ${name}";
      len = length members;
      funcs = map (t: t.verify) members;
      verifyValue =
        v: i:
        if i == len then
          null
        else if (elemAt funcs i) (elemAt v i) != null then
          ("in element ${toString i}: ${(elemAt funcs i) (elemAt v i)}")
        else
          verifyValue v (i + 1);
    in
    self.typedef' name (
      v:
      if !isList v then
        typeError name v
      else if (length v) != len then
        "Expected tuple to have length ${toString len} but value '${toPretty v}' has length ${toString (length v)}"
      else
        withErrorContext (verifyValue v 0)
    );

  /*
    scalar.int
    scalar.bool
    scalar.string
    scalar.path
    scalar.null
    scalar.float

    Attrset of types to check functions (returns bool for success) that a scalar
    literal matches for that type
   */
  scalar = mapAttrs (k: checkFn: type:
    self.typedef'
      (scalarName.${k} type)
      (v: if checkFn type v then null else "Expected ${k} '${toPretty type}' but got ${typeOf v} '${toPretty v}'")
  ) {
    int = type: value: type == value;
    bool = type: value: type == value;
    string = type: value: type == value;
    path = type: value: type == value;
    null = type: value: type == value;
    float = type: value: type == value;
  };

  /*
    from<value>

    Build a type from a literal input
  */
  from = value:
    if value ? name then
      value
    else
      let t = typeOf value; in
      if self.scalar ? ${t} then
        self.scalar.${t} value
      else if t == "lambda" then
        self.typedef' "lambda" (v: (self.from (value v)).verify)
      else if t == "set" then
        let
          value_ = mapAttrs (_: self.from) value;
        in
          self.struct {
            name = "{${concatMapAttrsStringSep ";" (k: v: "${k}=${v.name}}") value_}";
            total = true;
            unknown = false;
            types = value_;
          }
      else if t == "list" then
        self.tuple (map self.from value)
      else
        throw "check: cannot handle ${value} :: ${t}";

  /*
    refine'<name, T, refinement>

    Create a refinement over a given verify function
  */
  refine' =
    name: T: refinement:
    self.typedef' name (v: let err1 = T.verify v; in if err1 == null then refinement v else err1);

  /*
    Create a refinement over a given check function
  */
  refine = name: T: predicate:
    self.refine' name T (v: if predicate v then null else "failed predicate ${name}");

  /*
    Refuse to accept the given type
  */
  omit = T:
    self.typedef' "omit<${T.name}>" (v: let err = T.verify v; in if err == null then "${T.name} forbidden" else null);

  /*
    Create a wrapped type checked function.
  */
  defun =
    name: args: T: f:
    let
      errorPrefix = "while calling '${name}'";
      len = length args;
      run = idx: partial:
        if idx < len then
          arg:
          let err = (elemAt args idx).verify arg; in
          if err != null then
            throw "${errorPrefix}: while checking argument ${toString idx}: ${err}"
          else
            run (idx + 1) (partial arg)
        else
          let err = T.verify partial; in
          if err != null then
            throw "${errorPrefix}: while checking return type: ${err}"
          else
            partial;
    in
      run 0 f;
})
