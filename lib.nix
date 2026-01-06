# Utilities copied from nixpkgs lib https://github.com/NixOS/nixpkgs/tree/master/lib
# This is just enough to provide the feature set used by toPretty which is used to generate error messages.
# No other parts of nixpkgs lib are used in Korora.

let
  inherit (builtins)
    isInt
    isFloat
    isString
    filter
    isList
    split
    concatStringsSep
    replaceStrings
    addErrorContext
    length
    isFunction
    functionArgs
    elemAt
    isAttrs
    attrNames
    match
    isPath
    toJSON
    genList
    ;

  sublist =
    start: count: list:
    let
      len = length list;
    in
    genList (n: elemAt list (n + start)) (
      if start >= len then
        0
      else if start + count > len then
        len - start
      else
        count
    );

  take = count: sublist 0 count;

  last =
    list:
    if list == [ ] then
      (throw "lists.last: list must not be empty!")
    else
      elemAt list (length list - 1);

  init =
    list:
    if list == [ ] then (throw "lists.init: list must not be empty!") else take (length list - 1) list;

  mapAttrsToList = f: attrs: map (name: f name attrs.${name}) (attrNames attrs);

  concatMapStringsSep =
    sep: f: list:
    concatStringsSep sep (map f list);

  escape = list: replaceStrings list (map (c: "\\${c}") list);

  escapeNixString = s: escape [ "$" ] (toJSON s);

  escapeNixIdentifier =
    s:
    # Regex from https://github.com/NixOS/nix/blob/d048577909e383439c2549e849c5c2f2016c997e/src/libexpr/lexer.l#L91
    if match "[a-zA-Z_][a-zA-Z0-9_'-]*" s != null then s else escapeNixString s;

in

{

  /**
    Pretty print a value, akin to `builtins.trace`.

    Should probably be a builtin as well.

    The pretty-printed string should be suitable for rendering default values
    in the NixOS manual. In particular, it should be as close to a valid Nix expression
    as possible.

    # Inputs

    Structured function argument
    : allowPrettyValues
      : If this option is true, attrsets like { __pretty = fn; val = …; }
        will use fn to convert val to a pretty printed representation.
        (This means fn is type Val -> String.)
    : multiline
      : If this option is true, the output is indented with newlines for attribute sets and lists
    : recursivelyMultiline
      : If this option is true and multiline is also true, subattributes
        and sublists will be split onto multiple lines as well. This does
        nothing if multiline is false.
    : indent
      : Initial indentation level

    Value
    : The value to be pretty printed
  */
  toPretty =
    {
      allowPrettyValues ? false,
      multiline ? true,
      recursivelyMultiline ? true,
      indent ? "",
    }:
    let
      go =
        indent: multiline: v:
        let
          introSpace = if multiline then "\n${indent}  " else " ";
          outroSpace = if multiline then "\n${indent}" else " ";
        in
        if isInt v then
          toString v
        # toString loses precision on floats, so we use toJSON instead. This isn't perfect
        # as the resulting string may not parse back as a float (e.g. 42, 1e-06), but for
        # pretty-printing purposes this is acceptable.
        else if isFloat v then
          builtins.toJSON v
        else if isString v then
          let
            lines = filter (v: !isList v) (split "\n" v);
            escapeSingleline = escape [
              "\\"
              "\""
              "\${"
            ];
            escapeMultiline =
              replaceStrings
                [
                  "\${"
                  "''"
                ]
                [
                  "''\${"
                  "'''"
                ];
            singlelineResult = "\"" + concatStringsSep "\\n" (map escapeSingleline lines) + "\"";
            multilineResult =
              let
                escapedLines = map escapeMultiline lines;
                # The last line gets a special treatment: if it's empty, '' is on its own line at the "outer"
                # indentation level. Otherwise, '' is appended to the last line.
                lastLine = last escapedLines;
              in
              "''"
              + introSpace
              + concatStringsSep introSpace (init escapedLines)
              + (if lastLine == "" then outroSpace else introSpace + lastLine)
              + "''";
          in
          if multiline && length lines > 1 then multilineResult else singlelineResult
        else if true == v then
          "true"
        else if false == v then
          "false"
        else if null == v then
          "null"
        else if isPath v then
          toString v
        else if isList v then
          if v == [ ] then
            "[ ]"
          else
            "["
            + introSpace
            + concatMapStringsSep introSpace (go (indent + "  ") (multiline && recursivelyMultiline)) v
            + outroSpace
            + "]"
        else if isFunction v then
          let
            fna = functionArgs v;
            showFnas = concatStringsSep ", " (
              mapAttrsToList (name: hasDefVal: if hasDefVal then name + "?" else name) fna
            );
          in
          if fna == { } then "<function>" else "<function, args: {${showFnas}}>"
        else if isAttrs v then
          # apply pretty values if allowed
          if allowPrettyValues && v ? __pretty && v ? val then
            v.__pretty v.val
          else if v == { } then
            "{ }"
          else if v ? type && v.type == "derivation" then
            "<derivation ${v.name or "???"}>"
          else
            "{"
            + introSpace
            + concatStringsSep introSpace (
              mapAttrsToList (
                name: value:
                "${escapeNixIdentifier name} = ${
                  addErrorContext "while evaluating an attribute `${name}`" (
                    go (indent + "  ") (multiline && recursivelyMultiline) value
                  )
                };"
              ) v
            )
            + outroSpace
            + "}"
        else
          abort "generators.toPretty: should never happen (v = ${v})";
    in
    go indent multiline;

}
