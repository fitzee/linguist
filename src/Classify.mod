IMPLEMENTATION MODULE Classify;

FROM SYSTEM IMPORT ADR, ADDRESS;
IMPORT HashMap, Tokenizer, Util;

CONST
  MaxLangs = 32;
  MaxKeys  = 32;
  MaxCandidates = 4;
  MinGap   = 200;
  DefaultWeight = -2;
  BagCap   = 256;

TYPE
  KeyWeight = RECORD
    key: ARRAY [0..31] OF CHAR;
    weight: INTEGER;
  END;
  LangProfile = RECORD
    name: ARRAY [0..31] OF CHAR;
    keys: ARRAY [0..MaxKeys-1] OF KeyWeight;
    keyCount: INTEGER;
  END;
  AmbigGroup = RECORD
    ext: ARRAY [0..15] OF CHAR;
    langs: ARRAY [0..MaxCandidates-1] OF INTEGER;
    langCount: INTEGER;
  END;

VAR
  profiles: ARRAY [0..MaxLangs-1] OF LangProfile;
  profileCount: INTEGER;
  ambigs: ARRAY [0..7] OF AmbigGroup;
  ambigCount: INTEGER;

(* --- Profile building helpers --- *)

PROCEDURE AddKey(VAR p: LangProfile; k: ARRAY OF CHAR; w: INTEGER);
BEGIN
  IF p.keyCount < MaxKeys THEN
    Util.StrCopy(k, p.keys[p.keyCount].key);
    p.keys[p.keyCount].weight := w;
    INC(p.keyCount);
  END;
END AddKey;

PROCEDURE StartProfile(name: ARRAY OF CHAR): INTEGER;
VAR idx: INTEGER;
BEGIN
  idx := profileCount;
  IF idx < MaxLangs THEN
    Util.StrCopy(name, profiles[idx].name);
    profiles[idx].keyCount := 0;
    INC(profileCount);
  END;
  RETURN idx;
END StartProfile;

(* --- Scoring --- *)

PROCEDURE ScoreLang(VAR profile: LangProfile; VAR bag: HashMap.Map): INTEGER;
VAR
  i, score, cnt: INTEGER;
BEGIN
  score := 0;
  i := 0;
  WHILE i < profile.keyCount DO
    IF HashMap.Get(bag, profile.keys[i].key, cnt) THEN
      score := score + profile.keys[i].weight * cnt;
    END;
    INC(i);
  END;
  RETURN score;
END ScoreLang;

PROCEDURE ClassifyAgainst(buf: ADDRESS; len: CARDINAL;
                          VAR candidates: ARRAY OF INTEGER;
                          candCount: INTEGER;
                          VAR lang: ARRAY OF CHAR): BOOLEAN;
VAR
  bag: HashMap.Map;
  buckets: ARRAY [0..BagCap-1] OF HashMap.Bucket;
  ts: Tokenizer.State;
  tok: Tokenizer.Token;
  word: ARRAY [0..63] OF CHAR;
  cnt, i, score, best, second, bestIdx: INTEGER;
BEGIN
  (* Build token bag *)
  HashMap.Init(bag, ADR(buckets), BagCap);
  Tokenizer.Init(ts, buf, len);
  WHILE Tokenizer.Next(ts, tok) DO
    IF tok.kind = Tokenizer.Ident THEN
      Tokenizer.CopyToken(ts, tok, word);
      IF HashMap.Get(bag, word, cnt) THEN
        IF NOT HashMap.Put(bag, word, cnt + 1) THEN END;
      ELSE
        IF NOT HashMap.Put(bag, word, 1) THEN END;
      END;
    END;
  END;
  (* Score each candidate *)
  best := -10000;
  second := -10000;
  bestIdx := -1;
  i := 0;
  WHILE i < candCount DO
    IF (candidates[i] >= 0) AND (candidates[i] < profileCount) THEN
      score := ScoreLang(profiles[candidates[i]], bag);
      IF score > best THEN
        second := best;
        best := score;
        bestIdx := candidates[i];
      ELSIF score > second THEN
        second := score;
      END;
    END;
    INC(i);
  END;
  (* Winner must exceed minimum gap *)
  IF (bestIdx >= 0) AND (best - second >= MinGap) AND (best > 0) THEN
    Util.StrCopy(profiles[bestIdx].name, lang);
    RETURN TRUE;
  END;
  RETURN FALSE;
END ClassifyAgainst;

(* --- Public API --- *)

PROCEDURE IsAmbiguous(ext: ARRAY OF CHAR): BOOLEAN;
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE i < ambigCount DO
    IF Util.StrEqualCI(ext, ambigs[i].ext) THEN
      RETURN TRUE;
    END;
    INC(i);
  END;
  RETURN FALSE;
END IsAmbiguous;

PROCEDURE ByContent(buf: ADDRESS; len: CARDINAL;
                    ext: ARRAY OF CHAR;
                    VAR lang: ARRAY OF CHAR): BOOLEAN;
VAR
  i, j: INTEGER;
  allCands: ARRAY [0..MaxLangs-1] OF INTEGER;
BEGIN
  (* Check ambiguity groups first *)
  IF ext[0] # 0C THEN
    i := 0;
    WHILE i < ambigCount DO
      IF Util.StrEqualCI(ext, ambigs[i].ext) THEN
        RETURN ClassifyAgainst(buf, len,
                 ambigs[i].langs, ambigs[i].langCount, lang);
      END;
      INC(i);
    END;
  END;
  (* No ambiguity match -- classify against all profiled languages *)
  i := 0;
  WHILE i < profileCount DO
    allCands[i] := i;
    INC(i);
  END;
  RETURN ClassifyAgainst(buf, len, allCands, profileCount, lang);
END ByContent;

(* --- Profile initialization --- *)

PROCEDURE InitProfiles;
VAR p: INTEGER;
BEGIN
  profileCount := 0;

  (* 0: C *)
  p := StartProfile("C");
  AddKey(profiles[p], "int", 80);
  AddKey(profiles[p], "void", 80);
  AddKey(profiles[p], "char", 70);
  AddKey(profiles[p], "struct", 80);
  AddKey(profiles[p], "typedef", 90);
  AddKey(profiles[p], "printf", 90);
  AddKey(profiles[p], "include", 50);
  AddKey(profiles[p], "define", 60);
  AddKey(profiles[p], "ifdef", 80);
  AddKey(profiles[p], "ifndef", 80);
  AddKey(profiles[p], "return", 30);
  AddKey(profiles[p], "static", 40);
  AddKey(profiles[p], "extern", 70);
  AddKey(profiles[p], "unsigned", 90);
  AddKey(profiles[p], "sizeof", 70);
  AddKey(profiles[p], "malloc", 100);
  AddKey(profiles[p], "free", 60);
  AddKey(profiles[p], "NULL", 80);
  AddKey(profiles[p], "enum", 50);
  AddKey(profiles[p], "union", 90);

  (* 1: C++ *)
  p := StartProfile("C++");
  AddKey(profiles[p], "class", 70);
  AddKey(profiles[p], "namespace", 100);
  AddKey(profiles[p], "template", 100);
  AddKey(profiles[p], "public", 60);
  AddKey(profiles[p], "private", 60);
  AddKey(profiles[p], "protected", 70);
  AddKey(profiles[p], "virtual", 100);
  AddKey(profiles[p], "override", 90);
  AddKey(profiles[p], "std", 90);
  AddKey(profiles[p], "cout", 100);
  AddKey(profiles[p], "cin", 100);
  AddKey(profiles[p], "endl", 100);
  AddKey(profiles[p], "vector", 90);
  AddKey(profiles[p], "string", 50);
  AddKey(profiles[p], "auto", 50);
  AddKey(profiles[p], "nullptr", 100);
  AddKey(profiles[p], "constexpr", 100);
  AddKey(profiles[p], "noexcept", 100);
  AddKey(profiles[p], "include", 30);
  AddKey(profiles[p], "const_cast", 100);

  (* 2: Objective-C *)
  p := StartProfile("Objective-C");
  AddKey(profiles[p], "interface", 90);
  AddKey(profiles[p], "implementation", 100);
  AddKey(profiles[p], "end", 40);
  AddKey(profiles[p], "property", 90);
  AddKey(profiles[p], "synthesize", 100);
  AddKey(profiles[p], "selector", 100);
  AddKey(profiles[p], "protocol", 90);
  AddKey(profiles[p], "NSObject", 100);
  AddKey(profiles[p], "NSString", 100);
  AddKey(profiles[p], "NSArray", 100);
  AddKey(profiles[p], "NSDictionary", 100);
  AddKey(profiles[p], "alloc", 90);
  AddKey(profiles[p], "init", 50);
  AddKey(profiles[p], "self", 50);
  AddKey(profiles[p], "nil", 60);
  AddKey(profiles[p], "BOOL", 80);
  AddKey(profiles[p], "YES", 70);
  AddKey(profiles[p], "NO", 40);
  AddKey(profiles[p], "IBOutlet", 100);
  AddKey(profiles[p], "IBAction", 100);

  (* 3: Java *)
  p := StartProfile("Java");
  AddKey(profiles[p], "class", 50);
  AddKey(profiles[p], "public", 40);
  AddKey(profiles[p], "private", 40);
  AddKey(profiles[p], "protected", 40);
  AddKey(profiles[p], "static", 30);
  AddKey(profiles[p], "void", 30);
  AddKey(profiles[p], "import", 30);
  AddKey(profiles[p], "package", 80);
  AddKey(profiles[p], "extends", 80);
  AddKey(profiles[p], "implements", 100);
  AddKey(profiles[p], "interface", 50);
  AddKey(profiles[p], "abstract", 80);
  AddKey(profiles[p], "final", 60);
  AddKey(profiles[p], "throws", 100);
  AddKey(profiles[p], "synchronized", 100);
  AddKey(profiles[p], "instanceof", 80);
  AddKey(profiles[p], "System", 70);
  AddKey(profiles[p], "String", 40);
  AddKey(profiles[p], "ArrayList", 100);
  AddKey(profiles[p], "HashMap", 90);

  (* 4: Python *)
  p := StartProfile("Python");
  AddKey(profiles[p], "def", 80);
  AddKey(profiles[p], "class", 40);
  AddKey(profiles[p], "import", 40);
  AddKey(profiles[p], "self", 80);
  AddKey(profiles[p], "None", 90);
  AddKey(profiles[p], "True", 60);
  AddKey(profiles[p], "False", 60);
  AddKey(profiles[p], "elif", 100);
  AddKey(profiles[p], "except", 70);
  AddKey(profiles[p], "lambda", 90);
  AddKey(profiles[p], "yield", 80);
  AddKey(profiles[p], "pass", 90);
  AddKey(profiles[p], "raise", 80);
  AddKey(profiles[p], "finally", 50);
  AddKey(profiles[p], "__init__", 100);
  AddKey(profiles[p], "__name__", 100);
  AddKey(profiles[p], "__main__", 100);
  AddKey(profiles[p], "print", 50);
  AddKey(profiles[p], "range", 60);
  AddKey(profiles[p], "len", 50);

  (* 5: Ruby *)
  p := StartProfile("Ruby");
  AddKey(profiles[p], "def", 60);
  AddKey(profiles[p], "end", 40);
  AddKey(profiles[p], "class", 40);
  AddKey(profiles[p], "module", 60);
  AddKey(profiles[p], "require", 80);
  AddKey(profiles[p], "attr_accessor", 100);
  AddKey(profiles[p], "attr_reader", 100);
  AddKey(profiles[p], "puts", 90);
  AddKey(profiles[p], "nil", 70);
  AddKey(profiles[p], "do", 50);
  AddKey(profiles[p], "unless", 90);
  AddKey(profiles[p], "elsif", 100);
  AddKey(profiles[p], "yield", 60);
  AddKey(profiles[p], "each", 70);
  AddKey(profiles[p], "rescue", 100);
  AddKey(profiles[p], "ensure", 80);
  AddKey(profiles[p], "initialize", 90);
  AddKey(profiles[p], "frozen_string_literal", 100);
  AddKey(profiles[p], "include", 40);
  AddKey(profiles[p], "extend", 70);

  (* 6: JavaScript *)
  p := StartProfile("JavaScript");
  AddKey(profiles[p], "function", 60);
  AddKey(profiles[p], "var", 70);
  AddKey(profiles[p], "let", 60);
  AddKey(profiles[p], "const", 50);
  AddKey(profiles[p], "undefined", 90);
  AddKey(profiles[p], "null", 40);
  AddKey(profiles[p], "typeof", 80);
  AddKey(profiles[p], "instanceof", 50);
  AddKey(profiles[p], "prototype", 100);
  AddKey(profiles[p], "require", 60);
  AddKey(profiles[p], "module", 40);
  AddKey(profiles[p], "exports", 90);
  AddKey(profiles[p], "console", 80);
  AddKey(profiles[p], "async", 50);
  AddKey(profiles[p], "await", 50);
  AddKey(profiles[p], "Promise", 80);
  AddKey(profiles[p], "document", 80);
  AddKey(profiles[p], "window", 80);
  AddKey(profiles[p], "addEventListener", 100);
  AddKey(profiles[p], "querySelector", 100);

  (* 7: TypeScript *)
  p := StartProfile("TypeScript");
  AddKey(profiles[p], "interface", 60);
  AddKey(profiles[p], "type", 40);
  AddKey(profiles[p], "enum", 40);
  AddKey(profiles[p], "namespace", 50);
  AddKey(profiles[p], "declare", 90);
  AddKey(profiles[p], "readonly", 80);
  AddKey(profiles[p], "implements", 60);
  AddKey(profiles[p], "abstract", 50);
  AddKey(profiles[p], "as", 40);
  AddKey(profiles[p], "keyof", 100);
  AddKey(profiles[p], "typeof", 50);
  AddKey(profiles[p], "async", 40);
  AddKey(profiles[p], "await", 40);
  AddKey(profiles[p], "Promise", 50);
  AddKey(profiles[p], "string", 40);
  AddKey(profiles[p], "number", 60);
  AddKey(profiles[p], "boolean", 70);
  AddKey(profiles[p], "undefined", 50);
  AddKey(profiles[p], "any", 60);
  AddKey(profiles[p], "never", 80);

  (* 8: Go *)
  p := StartProfile("Go");
  AddKey(profiles[p], "func", 90);
  AddKey(profiles[p], "package", 80);
  AddKey(profiles[p], "import", 40);
  AddKey(profiles[p], "defer", 100);
  AddKey(profiles[p], "goroutine", 100);
  AddKey(profiles[p], "chan", 100);
  AddKey(profiles[p], "select", 50);
  AddKey(profiles[p], "interface", 40);
  AddKey(profiles[p], "struct", 50);
  AddKey(profiles[p], "range", 60);
  AddKey(profiles[p], "nil", 50);
  AddKey(profiles[p], "fmt", 90);
  AddKey(profiles[p], "Println", 80);
  AddKey(profiles[p], "Sprintf", 80);
  AddKey(profiles[p], "err", 50);
  AddKey(profiles[p], "error", 40);
  AddKey(profiles[p], "go", 50);
  AddKey(profiles[p], "make", 60);
  AddKey(profiles[p], "append", 60);
  AddKey(profiles[p], "len", 40);

  (* 9: Rust *)
  p := StartProfile("Rust");
  AddKey(profiles[p], "fn", 90);
  AddKey(profiles[p], "let", 50);
  AddKey(profiles[p], "mut", 100);
  AddKey(profiles[p], "impl", 100);
  AddKey(profiles[p], "trait", 100);
  AddKey(profiles[p], "enum", 50);
  AddKey(profiles[p], "match", 60);
  AddKey(profiles[p], "pub", 80);
  AddKey(profiles[p], "mod", 50);
  AddKey(profiles[p], "crate", 100);
  AddKey(profiles[p], "Option", 80);
  AddKey(profiles[p], "Result", 70);
  AddKey(profiles[p], "Some", 80);
  AddKey(profiles[p], "None", 50);
  AddKey(profiles[p], "Ok", 50);
  AddKey(profiles[p], "Err", 60);
  AddKey(profiles[p], "Vec", 80);
  AddKey(profiles[p], "println", 70);
  AddKey(profiles[p], "unwrap", 90);
  AddKey(profiles[p], "use", 40);

  (* 10: Shell *)
  p := StartProfile("Shell");
  AddKey(profiles[p], "echo", 70);
  AddKey(profiles[p], "fi", 100);
  AddKey(profiles[p], "then", 80);
  AddKey(profiles[p], "else", 30);
  AddKey(profiles[p], "elif", 50);
  AddKey(profiles[p], "done", 100);
  AddKey(profiles[p], "do", 50);
  AddKey(profiles[p], "esac", 100);
  AddKey(profiles[p], "case", 40);
  AddKey(profiles[p], "in", 30);
  AddKey(profiles[p], "export", 80);
  AddKey(profiles[p], "local", 60);
  AddKey(profiles[p], "function", 30);
  AddKey(profiles[p], "set", 40);
  AddKey(profiles[p], "unset", 70);
  AddKey(profiles[p], "shift", 80);
  AddKey(profiles[p], "exit", 50);
  AddKey(profiles[p], "trap", 90);
  AddKey(profiles[p], "source", 70);
  AddKey(profiles[p], "readonly", 70);

  (* 11: Perl *)
  p := StartProfile("Perl");
  AddKey(profiles[p], "sub", 80);
  AddKey(profiles[p], "my", 90);
  AddKey(profiles[p], "use", 50);
  AddKey(profiles[p], "strict", 90);
  AddKey(profiles[p], "warnings", 90);
  AddKey(profiles[p], "package", 60);
  AddKey(profiles[p], "chomp", 100);
  AddKey(profiles[p], "foreach", 60);
  AddKey(profiles[p], "unless", 60);
  AddKey(profiles[p], "elsif", 50);
  AddKey(profiles[p], "die", 90);
  AddKey(profiles[p], "print", 40);
  AddKey(profiles[p], "shift", 50);
  AddKey(profiles[p], "push", 50);
  AddKey(profiles[p], "pop", 40);
  AddKey(profiles[p], "qw", 100);
  AddKey(profiles[p], "BEGIN", 60);
  AddKey(profiles[p], "END", 40);
  AddKey(profiles[p], "STDIN", 80);
  AddKey(profiles[p], "STDOUT", 80);

  (* 12: Prolog *)
  p := StartProfile("Prolog");
  AddKey(profiles[p], "module", 40);
  AddKey(profiles[p], "use_module", 100);
  AddKey(profiles[p], "dynamic", 80);
  AddKey(profiles[p], "is", 40);
  AddKey(profiles[p], "not", 30);
  AddKey(profiles[p], "write", 50);
  AddKey(profiles[p], "writeln", 80);
  AddKey(profiles[p], "read", 40);
  AddKey(profiles[p], "nl", 80);
  AddKey(profiles[p], "assert", 70);
  AddKey(profiles[p], "retract", 100);
  AddKey(profiles[p], "findall", 100);
  AddKey(profiles[p], "member", 80);
  AddKey(profiles[p], "append", 50);
  AddKey(profiles[p], "length", 40);
  AddKey(profiles[p], "atom", 80);
  AddKey(profiles[p], "functor", 100);
  AddKey(profiles[p], "clause", 100);
  AddKey(profiles[p], "halt", 60);
  AddKey(profiles[p], "discontiguous", 100);

  (* 13: PHP *)
  p := StartProfile("PHP");
  AddKey(profiles[p], "php", 60);
  AddKey(profiles[p], "echo", 50);
  AddKey(profiles[p], "function", 30);
  AddKey(profiles[p], "class", 30);
  AddKey(profiles[p], "public", 30);
  AddKey(profiles[p], "private", 30);
  AddKey(profiles[p], "protected", 30);
  AddKey(profiles[p], "namespace", 40);
  AddKey(profiles[p], "use", 30);
  AddKey(profiles[p], "require_once", 100);
  AddKey(profiles[p], "include_once", 100);
  AddKey(profiles[p], "isset", 100);
  AddKey(profiles[p], "unset", 50);
  AddKey(profiles[p], "array", 70);
  AddKey(profiles[p], "foreach", 40);
  AddKey(profiles[p], "endif", 100);
  AddKey(profiles[p], "endforeach", 100);
  AddKey(profiles[p], "endwhile", 100);
  AddKey(profiles[p], "elseif", 50);
  AddKey(profiles[p], "die", 50);

  (* 14: Haskell *)
  p := StartProfile("Haskell");
  AddKey(profiles[p], "module", 40);
  AddKey(profiles[p], "where", 80);
  AddKey(profiles[p], "import", 40);
  AddKey(profiles[p], "data", 70);
  AddKey(profiles[p], "type", 40);
  AddKey(profiles[p], "newtype", 100);
  AddKey(profiles[p], "class", 40);
  AddKey(profiles[p], "instance", 100);
  AddKey(profiles[p], "deriving", 100);
  AddKey(profiles[p], "do", 30);
  AddKey(profiles[p], "let", 30);
  AddKey(profiles[p], "in", 20);
  AddKey(profiles[p], "case", 30);
  AddKey(profiles[p], "of", 20);
  AddKey(profiles[p], "otherwise", 100);
  AddKey(profiles[p], "qualified", 100);
  AddKey(profiles[p], "IO", 80);
  AddKey(profiles[p], "Maybe", 90);
  AddKey(profiles[p], "Just", 80);
  AddKey(profiles[p], "Nothing", 90);

  (* 15: MATLAB *)
  p := StartProfile("MATLAB");
  AddKey(profiles[p], "function", 40);
  AddKey(profiles[p], "end", 30);
  AddKey(profiles[p], "elseif", 60);
  AddKey(profiles[p], "fprintf", 100);
  AddKey(profiles[p], "disp", 90);
  AddKey(profiles[p], "zeros", 100);
  AddKey(profiles[p], "ones", 90);
  AddKey(profiles[p], "linspace", 100);
  AddKey(profiles[p], "plot", 80);
  AddKey(profiles[p], "xlabel", 100);
  AddKey(profiles[p], "ylabel", 100);
  AddKey(profiles[p], "title", 40);
  AddKey(profiles[p], "hold", 60);
  AddKey(profiles[p], "subplot", 100);
  AddKey(profiles[p], "figure", 80);
  AddKey(profiles[p], "nargin", 100);
  AddKey(profiles[p], "nargout", 100);
  AddKey(profiles[p], "classdef", 100);
  AddKey(profiles[p], "properties", 80);
  AddKey(profiles[p], "methods", 60);

  (* 16: Swift *)
  p := StartProfile("Swift");
  AddKey(profiles[p], "func", 60);
  AddKey(profiles[p], "let", 50);
  AddKey(profiles[p], "var", 50);
  AddKey(profiles[p], "guard", 100);
  AddKey(profiles[p], "struct", 40);
  AddKey(profiles[p], "class", 30);
  AddKey(profiles[p], "protocol", 60);
  AddKey(profiles[p], "extension", 80);
  AddKey(profiles[p], "import", 30);
  AddKey(profiles[p], "nil", 50);
  AddKey(profiles[p], "self", 40);
  AddKey(profiles[p], "optional", 60);
  AddKey(profiles[p], "unwrap", 50);
  AddKey(profiles[p], "deinit", 100);
  AddKey(profiles[p], "fallthrough", 100);
  AddKey(profiles[p], "typealias", 100);
  AddKey(profiles[p], "associatedtype", 100);
  AddKey(profiles[p], "weak", 80);
  AddKey(profiles[p], "unowned", 100);
  AddKey(profiles[p], "didSet", 100);

  (* 17: Kotlin *)
  p := StartProfile("Kotlin");
  AddKey(profiles[p], "fun", 90);
  AddKey(profiles[p], "val", 80);
  AddKey(profiles[p], "var", 50);
  AddKey(profiles[p], "class", 30);
  AddKey(profiles[p], "object", 60);
  AddKey(profiles[p], "when", 60);
  AddKey(profiles[p], "is", 30);
  AddKey(profiles[p], "companion", 100);
  AddKey(profiles[p], "data", 50);
  AddKey(profiles[p], "sealed", 100);
  AddKey(profiles[p], "lateinit", 100);
  AddKey(profiles[p], "suspend", 100);
  AddKey(profiles[p], "coroutine", 100);
  AddKey(profiles[p], "launch", 70);
  AddKey(profiles[p], "override", 50);
  AddKey(profiles[p], "internal", 80);
  AddKey(profiles[p], "inline", 50);
  AddKey(profiles[p], "reified", 100);
  AddKey(profiles[p], "init", 40);
  AddKey(profiles[p], "println", 50);

  (* 18: Scala *)
  p := StartProfile("Scala");
  AddKey(profiles[p], "def", 60);
  AddKey(profiles[p], "val", 60);
  AddKey(profiles[p], "var", 40);
  AddKey(profiles[p], "object", 60);
  AddKey(profiles[p], "trait", 80);
  AddKey(profiles[p], "class", 30);
  AddKey(profiles[p], "case", 40);
  AddKey(profiles[p], "match", 50);
  AddKey(profiles[p], "sealed", 70);
  AddKey(profiles[p], "implicit", 100);
  AddKey(profiles[p], "lazy", 70);
  AddKey(profiles[p], "override", 40);
  AddKey(profiles[p], "extends", 50);
  AddKey(profiles[p], "with", 40);
  AddKey(profiles[p], "yield", 40);
  AddKey(profiles[p], "forSome", 100);
  AddKey(profiles[p], "println", 40);
  AddKey(profiles[p], "Seq", 80);
  AddKey(profiles[p], "Map", 40);
  AddKey(profiles[p], "Option", 50);

  (* 19: C# *)
  p := StartProfile("C#");
  AddKey(profiles[p], "using", 70);
  AddKey(profiles[p], "namespace", 60);
  AddKey(profiles[p], "class", 30);
  AddKey(profiles[p], "public", 30);
  AddKey(profiles[p], "private", 30);
  AddKey(profiles[p], "protected", 30);
  AddKey(profiles[p], "static", 20);
  AddKey(profiles[p], "void", 20);
  AddKey(profiles[p], "string", 30);
  AddKey(profiles[p], "var", 30);
  AddKey(profiles[p], "async", 40);
  AddKey(profiles[p], "await", 40);
  AddKey(profiles[p], "foreach", 50);
  AddKey(profiles[p], "readonly", 50);
  AddKey(profiles[p], "sealed", 50);
  AddKey(profiles[p], "delegate", 100);
  AddKey(profiles[p], "event", 80);
  AddKey(profiles[p], "partial", 100);
  AddKey(profiles[p], "LINQ", 100);
  AddKey(profiles[p], "Console", 80);

  (* 20: Lua *)
  p := StartProfile("Lua");
  AddKey(profiles[p], "function", 40);
  AddKey(profiles[p], "local", 70);
  AddKey(profiles[p], "end", 40);
  AddKey(profiles[p], "then", 40);
  AddKey(profiles[p], "elseif", 50);
  AddKey(profiles[p], "nil", 60);
  AddKey(profiles[p], "require", 50);
  AddKey(profiles[p], "pairs", 100);
  AddKey(profiles[p], "ipairs", 100);
  AddKey(profiles[p], "table", 60);
  AddKey(profiles[p], "string", 30);
  AddKey(profiles[p], "tonumber", 100);
  AddKey(profiles[p], "tostring", 100);
  AddKey(profiles[p], "setmetatable", 100);
  AddKey(profiles[p], "getmetatable", 100);
  AddKey(profiles[p], "pcall", 100);
  AddKey(profiles[p], "xpcall", 100);
  AddKey(profiles[p], "rawget", 100);
  AddKey(profiles[p], "rawset", 100);
  AddKey(profiles[p], "unpack", 80);

  (* 21: R *)
  p := StartProfile("R");
  AddKey(profiles[p], "function", 40);
  AddKey(profiles[p], "library", 90);
  AddKey(profiles[p], "require", 40);
  AddKey(profiles[p], "data", 40);
  AddKey(profiles[p], "frame", 50);
  AddKey(profiles[p], "TRUE", 60);
  AddKey(profiles[p], "FALSE", 60);
  AddKey(profiles[p], "NULL", 50);
  AddKey(profiles[p], "NA", 80);
  AddKey(profiles[p], "if", 20);
  AddKey(profiles[p], "else", 20);
  AddKey(profiles[p], "for", 20);
  AddKey(profiles[p], "while", 20);
  AddKey(profiles[p], "ggplot", 100);
  AddKey(profiles[p], "aes", 90);
  AddKey(profiles[p], "geom_point", 100);
  AddKey(profiles[p], "dplyr", 100);
  AddKey(profiles[p], "mutate", 80);
  AddKey(profiles[p], "filter", 40);
  AddKey(profiles[p], "summarise", 100);

  (* 22: Elixir *)
  p := StartProfile("Elixir");
  AddKey(profiles[p], "defmodule", 100);
  AddKey(profiles[p], "def", 60);
  AddKey(profiles[p], "defp", 100);
  AddKey(profiles[p], "do", 40);
  AddKey(profiles[p], "end", 30);
  AddKey(profiles[p], "case", 30);
  AddKey(profiles[p], "cond", 60);
  AddKey(profiles[p], "when", 40);
  AddKey(profiles[p], "with", 40);
  AddKey(profiles[p], "fn", 40);
  AddKey(profiles[p], "pipe_through", 100);
  AddKey(profiles[p], "defstruct", 100);
  AddKey(profiles[p], "use", 40);
  AddKey(profiles[p], "alias", 70);
  AddKey(profiles[p], "import", 30);
  AddKey(profiles[p], "require", 40);
  AddKey(profiles[p], "GenServer", 100);
  AddKey(profiles[p], "Supervisor", 100);
  AddKey(profiles[p], "Agent", 70);
  AddKey(profiles[p], "Enum", 80);

  (* 23: Erlang *)
  p := StartProfile("Erlang");
  AddKey(profiles[p], "module", 60);
  AddKey(profiles[p], "export", 70);
  AddKey(profiles[p], "import", 30);
  AddKey(profiles[p], "receive", 100);
  AddKey(profiles[p], "after", 50);
  AddKey(profiles[p], "case", 30);
  AddKey(profiles[p], "of", 20);
  AddKey(profiles[p], "end", 30);
  AddKey(profiles[p], "when", 40);
  AddKey(profiles[p], "fun", 50);
  AddKey(profiles[p], "spawn", 90);
  AddKey(profiles[p], "register", 70);
  AddKey(profiles[p], "gen_server", 100);
  AddKey(profiles[p], "supervisor", 90);
  AddKey(profiles[p], "behaviour", 100);
  AddKey(profiles[p], "init", 30);
  AddKey(profiles[p], "handle_call", 100);
  AddKey(profiles[p], "handle_cast", 100);
  AddKey(profiles[p], "handle_info", 100);
  AddKey(profiles[p], "terminate", 70);

  (* 24: Dart *)
  p := StartProfile("Dart");
  AddKey(profiles[p], "import", 30);
  AddKey(profiles[p], "class", 30);
  AddKey(profiles[p], "extends", 40);
  AddKey(profiles[p], "implements", 40);
  AddKey(profiles[p], "with", 30);
  AddKey(profiles[p], "mixin", 100);
  AddKey(profiles[p], "void", 20);
  AddKey(profiles[p], "var", 30);
  AddKey(profiles[p], "final", 40);
  AddKey(profiles[p], "const", 30);
  AddKey(profiles[p], "late", 80);
  AddKey(profiles[p], "required", 60);
  AddKey(profiles[p], "async", 40);
  AddKey(profiles[p], "await", 40);
  AddKey(profiles[p], "Future", 80);
  AddKey(profiles[p], "Stream", 50);
  AddKey(profiles[p], "Widget", 90);
  AddKey(profiles[p], "BuildContext", 100);
  AddKey(profiles[p], "StatelessWidget", 100);
  AddKey(profiles[p], "StatefulWidget", 100);

  (* 25: OCaml *)
  p := StartProfile("OCaml");
  AddKey(profiles[p], "let", 50);
  AddKey(profiles[p], "in", 20);
  AddKey(profiles[p], "val", 40);
  AddKey(profiles[p], "fun", 50);
  AddKey(profiles[p], "function", 30);
  AddKey(profiles[p], "match", 50);
  AddKey(profiles[p], "with", 30);
  AddKey(profiles[p], "type", 40);
  AddKey(profiles[p], "module", 50);
  AddKey(profiles[p], "struct", 40);
  AddKey(profiles[p], "sig", 100);
  AddKey(profiles[p], "end", 30);
  AddKey(profiles[p], "open", 80);
  AddKey(profiles[p], "rec", 100);
  AddKey(profiles[p], "mutable", 70);
  AddKey(profiles[p], "begin", 50);
  AddKey(profiles[p], "failwith", 100);
  AddKey(profiles[p], "Printf", 70);
  AddKey(profiles[p], "List", 40);
  AddKey(profiles[p], "Array", 40);

  (* 26: SQL *)
  p := StartProfile("SQL");
  AddKey(profiles[p], "SELECT", 90);
  AddKey(profiles[p], "FROM", 60);
  AddKey(profiles[p], "WHERE", 80);
  AddKey(profiles[p], "INSERT", 90);
  AddKey(profiles[p], "UPDATE", 80);
  AddKey(profiles[p], "DELETE", 70);
  AddKey(profiles[p], "CREATE", 70);
  AddKey(profiles[p], "TABLE", 80);
  AddKey(profiles[p], "ALTER", 80);
  AddKey(profiles[p], "DROP", 70);
  AddKey(profiles[p], "INDEX", 60);
  AddKey(profiles[p], "JOIN", 90);
  AddKey(profiles[p], "LEFT", 40);
  AddKey(profiles[p], "INNER", 80);
  AddKey(profiles[p], "GROUP", 60);
  AddKey(profiles[p], "ORDER", 50);
  AddKey(profiles[p], "HAVING", 90);
  AddKey(profiles[p], "DISTINCT", 80);
  AddKey(profiles[p], "VARCHAR", 100);
  AddKey(profiles[p], "INTEGER", 50);
END InitProfiles;

PROCEDURE InitAmbig;
BEGIN
  ambigCount := 0;

  (* .h -> C, C++, Objective-C *)
  Util.StrCopy(".h", ambigs[0].ext);
  ambigs[0].langs[0] := 0;   (* C *)
  ambigs[0].langs[1] := 1;   (* C++ *)
  ambigs[0].langs[2] := 2;   (* Objective-C *)
  ambigs[0].langCount := 3;
  INC(ambigCount);

  (* .pl -> Perl, Prolog *)
  Util.StrCopy(".pl", ambigs[1].ext);
  ambigs[1].langs[0] := 11;  (* Perl *)
  ambigs[1].langs[1] := 12;  (* Prolog *)
  ambigs[1].langCount := 2;
  INC(ambigCount);

  (* .m -> Objective-C, MATLAB *)
  Util.StrCopy(".m", ambigs[2].ext);
  ambigs[2].langs[0] := 2;   (* Objective-C *)
  ambigs[2].langs[1] := 15;  (* MATLAB *)
  ambigs[2].langCount := 2;
  INC(ambigCount);
END InitAmbig;

BEGIN
  InitProfiles;
  InitAmbig;
END Classify.
