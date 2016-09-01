{stdenv, buildFractalideContract, upkeepers, ...}:

buildFractalideContract rec {
  src = ./.;
  contract = ''
  @0x932e7ad13a9eb1bb;

  struct JsCreate {
    name @0 :Text;
    sender @1 :UInt64;
    append @2 :Text;
    attr @3 :List(Entry);
    class @4 :List(Classed);
    style @5 :List(Entry);
    property @6 :List(Entry);
    text @7 :Text;
    remove @8 :Bool;
    type @9 :Text;
  }

  struct Entry {
         key @0 :Text;
         val @1 :Text;
  }

  struct Classed {
         name @0 :Text;
         set @1 :Bool;
  }
  '';

  meta = with stdenv.lib; {
    description = "Contract: Describes a conrod UI";
    homepage = https://github.com/fractalide/fractalide/tree/master/contracts/path;
    license = with licenses; [ mpl20 ];
    maintainers = with upkeepers; [ dmichiels sjmackenzie];
  };
}
