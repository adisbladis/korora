{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
}:

let
  inherit (lib) toUpper substring stringLength;

  types = import ./default.nix { inherit lib; };

  capitalise = s: toUpper (substring 0 1 s) + (substring 1 (stringLength s) s);

  addCoverage =
    public: tests:
    (
      assert !tests ? coverage;
      tests
      // {
        coverage = lib.mapAttrs' (n: v: {
          name = "test" + (capitalise n);
          value = {
            expr = tests ? ${n};
            expected = true;
          };
        }) public;
      }
    );

in
lib.fix (
  self:
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
    str = self.string;

    # Dummy out for coverage
    typedef = {
      testValid = {
        expr = (types.typedef "testDef" (_: true)).name;
        expected = "testDef";
      };
      testInvalidName = {
        expr = types.typedef 1 null;
        expectedError.type = "AssertionError";
      };
      testInvalidFunc = {
        expr = types.typedef "testDef" "x";
        expectedError.type = "AssertionError";
      };
    };
    typedef' = {
      testValid = {
        expr = (types.typedef' "testDef" (_: true)).name;
        expected = "testDef";
      };
      testInvalidName = {
        expr = types.typedef' 1 null;
        expectedError.type = "AssertionError";
      };
      testInvalidFunc = {
        expr = types.typedef' "testDef" "x";
        expectedError.type = "AssertionError";
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

    path = {
      testInvalid = {
        expr = types.path.verify 1;
        expected = "Expected type 'path' but value '1' is of type 'int'";
      };

      testValid = {
        expr = types.path.verify ./.;
        expected = null;
      };
    };

    derivation = {
      testInvalid = {
        expr = types.derivation.verify { };
        expected = "Expected type 'derivation' but value '{ }' is of type 'set'";
      };

      testValid = {
        expr = types.derivation.verify (
          builtins.derivation {
            name = "test";
            builder = ":";
            system = "fake";
          }
        );
        expected = null;
      };
    };

    any = {
      testValid = {
        expr = types.any.verify (throw "NO U"); # Note: Value not checked
        expected = null;
      };
    };

    never = {
      testInvalid = {
        expr = types.never.verify 1234;
        expected = "Expected type 'never' but value '1234' is of type 'int'";
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

    number = {
      testInvalid = {
        expr = types.number.verify "x";
        expected = "Expected type 'number' but value '\"x\"' is of type 'string'";
      };

      testValidInt = {
        expr = types.number.verify 1;
        expected = null;
      };

      testValidFloat = {
        expr = types.number.verify 1.0;
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

    listOf =
      let
        testListOf = types.listOf types.str;
      in
      {
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

    attrsOf =
      let
        testAttrsOf = types.attrsOf types.str;
      in
      {
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

    union =
      let
        testUnion = (types.union [ types.str ]);
      in
      {
        testValid = {
          expr = testUnion.verify "hello";
          expected = null;
        };

        testInvalid = {
          expr = testUnion.verify 1;
          expected = "Expected type 'union<string>' but value '1' is of type 'int'";
        };
      };

    intersection =
      let
        struct1 = (
          types.struct "struct1" {
            a = types.str;
          }
        );

        struct2 = (
          types.struct "struct2" {
            b = types.str;
          }
        );

        testIntersection = (
          types.intersection [
            struct1
            struct2
          ]
        );
      in
      {
        testValid = {
          expr = testIntersection.verify {
            a = "foo";
            b = "bar";
          };
          expected = null;
        };

        testInvalid = {
          expr = testIntersection.verify 1;
          expected = "Expected type 'intersection<struct1,struct2>' but value '1' is of type 'int'";
        };
      };

    type = {
      testValid = {
        expr = types.type.verify types.string;
        expected = null;
      };

      testInvalid = {
        expr = types.type.verify { };
        expected = "Expected type 'type' but value '{ }' is of type 'set'";
      };
    };

    option =
      let
        testOption = types.option types.str;
      in
      {
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

    struct =
      let
        testStruct = types.struct "testStruct" {
          foo = types.string;
        };

        testStruct2 =
          (types.struct "testStruct2" {
            x = types.int;
            y = types.int;
          }).override
            {
              verify = v: if v.x + v.y == 2 then "VERBOTEN" else null;
            };

        testStructNonTotal = testStruct.override { total = false; };
        testStructWithoutUnknown = testStruct.override { unknown = false; };

      in
      {
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

        testNonTotal = {
          expr = testStructNonTotal.verify {
            foo = "bar";
            unknown = "is allowed";
          };
          expected = null;
        };

        testExtraInvariantCheck = {
          expr = testStruct2.verify {
            x = 1;
            y = 1;
          };
          expected = "in struct 'testStruct2': VERBOTEN";
        };

        testUnknownAttrNotAllowed = {
          expr = testStructWithoutUnknown.verify {
            foo = "bar";
            bar = "foo";
          };
          expected = "in struct 'testStruct': keys ['bar'] are unrecognized, expected keys are ['foo']";
        };

        testUnknownAttr = {
          expr = testStruct.verify {
            foo = "bar";
            bar = "foo";
          };
          expected = null;
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

    optionalAttr =
      let
        testStruct = types.struct "testOptionalAttrStruct" {
          foo = types.string;
          optionalFoo = types.optionalAttr types.string;
        };

      in
      {
        testWithOptional = {
          expr = testStruct.verify {
            foo = "hello";
            optionalFoo = "goodbye";
          };
          expected = null;
        };

        testWithoutOptional = {
          expr = testStruct.verify {
            foo = "hello";
          };
          expected = null;
        };

        testWithInvalidOptional = {
          expr = testStruct.verify {
            foo = "hello";
            optionalFoo = 1234;
          };
          expected = "in struct 'testOptionalAttrStruct': in member 'optionalFoo': in optionalAttr<string>: Expected type 'string' but value '1234' is of type 'int'";
        };
      };

    enum =
      let
        testEnum = types.enum "testEnum" [
          "A"
          "B"
          "C"
        ];
      in
      {
        testHasElem = {
          expr = testEnum.verify "B";
          expected = null;
        };

        testNotHasElem = {
          expr = testEnum.verify "nope";
          expected = "'\"nope\"' is not a member of enum 'testEnum'";
        };
      };

    rename = {
      testRename = {
        expr = let
          t = types.rename "florp" types.string;
        in {
          inherit (t) name;
          isFunction = builtins.isFunction t.verify;
        };
        expected = {
          name = "florp";
          isFunction = true;
        };
      };
    };

    recursiveTypes = {
      struct =
        let
          recursive = types.struct "recursive" {
            children = types.optionalAttr (types.attrsOf (recursive));
          };
        in
        {
          testOK = {
            expr = recursive.verify {
              children = {
                x = { };
              };
            };
            expected = null;
          };

          testNotOK = {
            expr = recursive.check {
              children = {
                x = "hello";
              };
            } null;
            expectedError.type = "ThrownError";
          };
        };

      attrsOf =
        let
          # Because attrsOf inherits names from it's sub-types we need to erase the name to not cause infinite recursion.
          # This should have it's own exposed function.
          type = types.attrsOf (
            types.rename "eitherType"
              (types.union [
                types.string
                type
              ])
          );
        in
        {
          testOK = {
            expr = type.verify {
              foo = "bar";
              baz = {
                foo = "bar";
                baz = {
                  foo = "bar";
                };
              };
            };
            expected = null;
          };

          testNotOK = {
            expr = type.check {
              foo = "bar";
              baz = {
                foo = "bar";
                baz = {
                  foo = "bar";
                  int = 1;
                };
              };
            } null;
            expectedError.type = "ThrownError";
          };
        };
    };
  }
)
