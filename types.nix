{ lib }:
let
  inherit (builtins) typeOf isString isFunction isAttrs isList all attrValues concatStringsSep any isInt isFloat isBool attrNames elem listToAttrs;
  inherit (lib) findFirst nameValuePair;

  isTypeDef = t: isAttrs t && t ? name && isString t.name && t ? verify && isFunction t.verify;

  toPretty = lib.generators.toPretty { indent = "    "; };

  typeError = name: v: "Expected type '${name}' but value '${toPretty v}' is of type '${typeOf v}'";

  # Builtin primitive checkers return a bool for indicating errors but we return option<str>
  wrapBoolVerify = name: verify: v: if verify v then null else typeError name v;

  # Wrap builtins.all to return option<str>, with string on error.
  all' = func: list: if all (v: func v == null) list then null else (
    # If an error was found, run the checks again to find the first error to return.
    func (findFirst (v: func v != null) (abort "This should never ever happen") list)
  );

  addErrorContext = context: error: if error == null then null else "${context}: ${error}";

in
lib.fix(self: {
  # Utility functions

  /*
  Declare a custom type.
  */
  typedef =
    # Name of the type as a string
    name:
    # Verification function returning a bool.
    verify:
    assert isString name; assert isFunction verify; self.typedef' name (wrapBoolVerify name verify);

  /*
  Declare a custom type.
  */
  typedef' =
    # Name of the type as a string
    name:
    # Verification function returning null on success & a string with error message on error.
    verify:
    assert isString name; assert isFunction verify; {
      inherit name verify;
      check = v: if verify v == null then v else throw (verify v);
    };

  # Primitive types

  /*
  String
  */
  string = self.typedef "string" isString;

  /*
  Type alias for string
  */
  str = self.string;

  /*
  Any
  */
  any = self.typedef' "any" (_: null);

  /*
  Int
  */
  int = self.typedef "int" isInt;

  /*
  Single precision floating point
  */
  float = self.typedef "float" isFloat;

  /*
  Bool
  */
  bool = self.typedef "bool" isBool;

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

  # Polymorphic types

  /*
  Option<t>
  */
  option =
    # Null or t
    t:
    assert isTypeDef t; let
      name = "option<${t.name}>";
      inherit (t) verify;
      errorContext = "in ${name}";
    in self.typedef' name (v: if v == null then null else addErrorContext errorContext (verify v));

  /*
  listOf<t>
  */
  listOf =
    # Element type
    t: assert isTypeDef t; let
      name = "listOf<${t.name}>";
      inherit (t) verify;
      errorContext = "in ${name} element";
    in self.typedef' name (v: if ! isList v then typeError name v else addErrorContext errorContext (all' verify v));

  /*
  listOf<t>
  */
  attrsOf =
    # Attribute type
    t: assert isTypeDef t; let
      name = "attrsOf<${t.name}>";
      inherit (t) verify;
      errorContext = "in ${name} value";
    in self.typedef' name (v: if ! isAttrs v then typeError name v else addErrorContext errorContext (all' verify (attrValues v)));

  /*
  union<types...>
  */
  union =
    # Any of list<t>
    types: assert isList types; assert all isTypeDef types; let
      name = "union<${concatStringsSep "," (map (t: t.name) types)}>";
      funcs = map (t: t.verify) types;
    in self.typedef name (v: any (func: func v == null) funcs);

  /*
  union<name, members...>
  */
  struct =
    # Name of struct type as a string
    name:
    # Member type definitions as an attribute set of types.
    members: assert isAttrs members; assert all isTypeDef (attrValues members); let
    names = attrNames members;
    verifiers = listToAttrs (map (attr: nameValuePair attr members.${attr}.verify) names);
    errorContext = "in struct '${name}'";
  in self.typedef' name (
    v: addErrorContext errorContext (
      if ! isAttrs v then typeError name v
      else all' (attr: if ! v ? ${attr} then "missing member '${attr}'" else addErrorContext "in member '${attr}'" (verifiers.${attr} v.${attr})) names
    )
  );

  /*
  enum<name, elems...>
  */
  enum =
    # Name of enum type as a string
    name:
    # Enum member can be any of elems
    elems:
    assert isList elems; self.typedef' name (v: if elem v elems then null else "'${toPretty v}' is not a member of enum '${name}'");
})
