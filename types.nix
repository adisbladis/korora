{ lib }:
let
  inherit (builtins) typeOf isString isFunction isAttrs isList all attrValues concatStringsSep any isInt isFloat isBool attrNames;
  inherit (lib) findFirst nameValuePair listToAttrs;

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
lib.fix(self: let
  inherit (self) typedef;
in {
  typedef = name: verify: assert isString name; assert isFunction verify; {
    inherit name verify;
  };

  # Primitive types

  string = typedef "string" (wrapBoolVerify "string" isString);
  str = self.string;
  any = typedef "any" (_: null);
  int = typedef "int" (wrapBoolVerify "int" isInt);
  float = typedef "float" (wrapBoolVerify "float" isFloat);
  bool = typedef "bool" (wrapBoolVerify "bool" isBool);
  attrs = typedef "attrs" (wrapBoolVerify "attrs" isAttrs);
  list = typedef "list" (wrapBoolVerify "list" isList);

  # Composite types

  listOf = t: assert isTypeDef t; let
    name = "listOf<${t.name}>";
    inherit (t) verify;
  in typedef name (
    v:
    if ! isList v then typeError name v
    else addErrorContext "In ${name} element" (all' verify v));

  attrsOf = t: assert isTypeDef t; let
    name = "attrsOf<${t.name}>";
    inherit (t) verify;
  in typedef name (
    v:
    if ! isAttrs v then typeError name v
    else addErrorContext "In ${name} value" (all' verify (attrValues v)));

  union = types: assert isList types; assert all isTypeDef types; let
    name = "union<${concatStringsSep "," (map (t: t.name) types)}>";
    funcs = map (t: t.verify) types;
  in typedef name (wrapBoolVerify name (v: any (func: func v == null) funcs));

  struct = name: { ... }@members: assert all isTypeDef (attrValues members); let
    names = attrNames members;
    verifiers = listToAttrs (map (attr: nameValuePair attr members.${attr}.verify) names);
  in typedef name (
    v: addErrorContext "in struct '${name}'" (
      if ! isAttrs v then typeError name v
      else all' (
        attr:
        if ! v ? ${attr} then "missing member '${attr}'"
        else addErrorContext "in member '${attr}'" (verifiers.${attr} v.${attr})) names
    )
  );
})
