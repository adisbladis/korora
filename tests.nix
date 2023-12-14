let
  pkgs = import <nixpkgs> { };
  inherit (pkgs) lib;

  inherit (lib) toUpper substring stringLength;

  types = import ./types.nix { inherit lib; };

  capitalise = s: toUpper (substring 0 1 s) + (substring 1 (stringLength s) s);

  addCoverage = public: tests: (
    assert ! tests ? coverage;
    tests // {
      coverage = lib.mapAttrs' (n: v: {
        name = "test" + (capitalise n);
        value = {
          expr = tests ? ${n};
          expected = true;
        };
      }) tests;
    }
  );

in
addCoverage types {
  string = {
    testInvalid = {
      expr = types.str.verify 1;
      expected = "Expected type 'string' but value '1' is of type 'int'";
    };

    testValid = {
      expr = types.str.verify "Hello";
      expected = null;
    };
  };

  function = {
    testInvalid = {
      expr = types.function.verify 1;
      expected = "Expected type 'function' but value '1' is of type 'int'";
    };

    testValid = {
      expr = types.function.verify (_: null);
      expected = null;
    };
  };

  any = {
    testValid = {
      expr = types.any.verify (throw "NO U"); # Note: Value not checked
      expected = null;
    };
  };

  int = {
    testInvalid = {
      expr = types.int.verify "x";
      expected = "Expected type 'int' but value '\"x\"' is of type 'string'";
    };

    testValid = {
      expr = types.int.verify 1;
      expected = null;
    };
  };

  float = {
    testInvalid = {
      expr = types.float.verify "x";
      expected = "Expected type 'float' but value '\"x\"' is of type 'string'";
    };

    testValid = {
      expr = types.float.verify 1.0;
      expected = null;
    };
  };

  bool = {
    testInvalid = {
      expr = types.bool.verify "x";
      expected = "Expected type 'bool' but value '\"x\"' is of type 'string'";
    };

    testValid = {
      expr = types.bool.verify true;
      expected = null;
    };
  };

  attrs = {
    testInvalid = {
      expr = types.attrs.verify "x";
      expected = "Expected type 'attrs' but value '\"x\"' is of type 'string'";
    };

    testValid = {
      expr = types.attrs.verify { };
      expected = null;
    };
  };

  list = {
    testInvalid = {
      expr = types.list.verify "x";
      expected = "Expected type 'list' but value '\"x\"' is of type 'string'";
    };

    testValid = {
      expr = types.list.verify [ ];
      expected = null;
    };
  };

  listOf = let
    testListOf = types.listOf types.str;
  in {
    testValid = {
      expr = testListOf.verify [ "hello" ];
      expected = null;
    };

    testInvalidElem = {
      expr = testListOf.verify [ 1 ];
      expected = "in listOf<string> element: Expected type 'string' but value '1' is of type 'int'";
    };

    testInvalidType = {
      expr = testListOf.verify 1;
      expected = "Expected type 'listOf<string>' but value '1' is of type 'int'";
    };
  };

  atrsOf = let
    testAttrsOf = types.attrsOf types.str;
  in {
    testValid = {
      expr = testAttrsOf.verify {
        x = "hello";
      };
      expected = null;
    };

    testInvalidElem = {
      expr = testAttrsOf.verify {
        x = 1;
      };
      expected = "in attrsOf<string> value: Expected type 'string' but value '1' is of type 'int'";
    };

    testInvalidType = {
      expr = testAttrsOf.verify 1;
      expected = "Expected type 'attrsOf<string>' but value '1' is of type 'int'";
    };
  };

  union = let
    testUnion = (types.union [ types.str ]);
  in {
    testValid = {
      expr = testUnion.verify "hello";
      expected = null;
    };

    testInvalid = {
      expr = testUnion.verify 1;
      expected = "Expected type 'union<string>' but value '1' is of type 'int'";
    };
  };

  option = let
    testOption = types.option types.str;
  in {
    testValidString = {
      expr = testOption.verify "hello";
      expected = null;
    };

    testNull = {
      expr = testOption.verify null;
      expected = null;
    };

    testInvalid = {
      expr = testOption.verify 3;
      expected = "in option<string>: Expected type 'string' but value '3' is of type 'int'";
    };
  };

  struct = let
    testStruct = types.struct "testStruct" {
      foo = types.string;
    };
  in {
    testValid = {
      expr = testStruct.verify {
        foo = "bar";
      };
      expected = null;
    };

    testMissingAttr = {
      expr = testStruct.verify { };
      expected = "in struct 'testStruct': missing member 'foo'";
    };

    testInvalidType = {
      expr = testStruct.verify "bar";
      expected = "in struct 'testStruct': Expected type 'testStruct' but value '\"bar\"' is of type 'string'";
    };

    testInvalidMember = {
      expr = testStruct.verify {
        foo = 1;
      };
      expected = "in struct 'testStruct': in member 'foo': Expected type 'string' but value '1' is of type 'int'";
    };
  };

  enum = let
    testEnum = types.enum "testEnum" [ "A" "B" "C" ];
  in {
    testHasElem = {
      expr = testEnum.verify "B";
      expected = null;
    };

    testNotHasElem = {
      expr = testEnum.verify "nope";
      expected = "'\"nope\"' is not a member of enum 'testEnum'";
    };
  };
}
