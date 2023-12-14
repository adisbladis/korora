let
  pkgs = import <nixpkgs> { };
  inherit (pkgs) lib;

  types = import ./types.nix { inherit lib; };

in
{
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

  listOf = {
    testValid = {
      expr = (types.listOf types.str).verify [ "hello" ];
      expected = null;
    };

    testInvalidElem = {
      expr = (types.listOf types.str).verify [ 1 ];
      expected = "in listOf<string> element: Expected type 'string' but value '1' is of type 'int'";
    };

    testInvalidType = {
      expr = (types.listOf types.str).verify 1;
      expected = "Expected type 'listOf<string>' but value '1' is of type 'int'";
    };
  };

  atrsOf = {
    testValid = {
      expr = (types.attrsOf types.str).verify {
        x = "hello";
      };
      expected = null;
    };

    testInvalidElem = {
      expr = (types.attrsOf types.str).verify {
        x = 1;
      };
      expected = "in attrsOf<string> value: Expected type 'string' but value '1' is of type 'int'";
    };

    testInvalidType = {
      expr = (types.attrsOf types.str).verify 1;
      expected = "Expected type 'attrsOf<string>' but value '1' is of type 'int'";
    };
  };

  union = {
    testValid = {
      expr = (types.union [ types.str ]).verify "hello";
      expected = null;
    };

    testInvalid = {
      expr = (types.union [ types.str ]).verify 1;
      expected = "Expected type 'union<string>' but value '1' is of type 'int'";
    };
  };

  struct = {
    testValid = {
      expr = (types.struct "testStruct" {
        foo = types.string;
      }).verify {
        foo = "bar";
      };
      expected = null;
    };

    testMissingAttr = {
      expr = (types.struct "testStruct" {
        foo = types.string;
      }).verify { };
      expected = "in struct 'testStruct': missing member 'foo'";
    };

    testInvalidType = {
      expr = (types.struct "testStruct" {
        foo = types.string;
      }).verify "bar";
      expected = "in struct 'testStruct': Expected type 'testStruct' but value '\"bar\"' is of type 'string'";
    };

    testInvalidMember = {
      expr = (types.struct "testStruct" {
        foo = types.string;
      }).verify {
        foo = 1;
      };
      expected = "in struct 'testStruct': in member 'foo': Expected type 'string' but value '1' is of type 'int'";
    };
  };
}
