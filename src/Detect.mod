IMPLEMENTATION MODULE Detect;

FROM SYSTEM IMPORT ADR, ADDRESS;
IMPORT Util, Text;

CONST
  MaxExts = 128;
  MaxNames = 16;

TYPE
  ExtRec = RECORD
    ext: ARRAY [0..15] OF CHAR;
    lang: ARRAY [0..31] OF CHAR;
  END;
  NameRec = RECORD
    name: ARRAY [0..31] OF CHAR;
    lang: ARRAY [0..31] OF CHAR;
  END;

VAR
  exts: ARRAY [0..MaxExts-1] OF ExtRec;
  extCount: INTEGER;
  names: ARRAY [0..MaxNames-1] OF NameRec;
  nameCount: INTEGER;

PROCEDURE AddExt(e, l: ARRAY OF CHAR);
BEGIN
  IF extCount < MaxExts THEN
    Util.StrCopy(e, exts[extCount].ext);
    Util.StrCopy(l, exts[extCount].lang);
    INC(extCount);
  END;
END AddExt;

PROCEDURE AddName(n, l: ARRAY OF CHAR);
BEGIN
  IF nameCount < MaxNames THEN
    Util.StrCopy(n, names[nameCount].name);
    Util.StrCopy(l, names[nameCount].lang);
    INC(nameCount);
  END;
END AddName;

PROCEDURE ByExtension(ext: ARRAY OF CHAR; VAR lang: ARRAY OF CHAR): BOOLEAN;
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE i < extCount DO
    IF Util.StrEqualCI(ext, exts[i].ext) THEN
      Util.StrCopy(exts[i].lang, lang);
      RETURN TRUE;
    END;
    INC(i);
  END;
  RETURN FALSE;
END ByExtension;

PROCEDURE ByFilename(name: ARRAY OF CHAR; VAR lang: ARRAY OF CHAR): BOOLEAN;
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE i < nameCount DO
    IF Util.StrEqual(name, names[i].name) THEN
      Util.StrCopy(names[i].lang, lang);
      RETURN TRUE;
    END;
    INC(i);
  END;
  RETURN FALSE;
END ByFilename;

PROCEDURE ByShebang(buf: ADDRESS; len: CARDINAL; VAR lang: ARRAY OF CHAR): BOOLEAN;
VAR
  interp: ARRAY [0..63] OF CHAR;
BEGIN
  Text.ParseShebang(buf, len, interp);
  IF interp[0] = 0C THEN RETURN FALSE; END;
  IF Util.StrEqual(interp, "sh") OR Util.StrEqual(interp, "bash") OR
     Util.StrEqual(interp, "zsh") OR Util.StrEqual(interp, "ksh") OR
     Util.StrEqual(interp, "dash") THEN
    Util.StrCopy("Shell", lang); RETURN TRUE;
  ELSIF Util.StrEqual(interp, "python") OR Util.StrEqual(interp, "python3") OR
        Util.StrEqual(interp, "python2") THEN
    Util.StrCopy("Python", lang); RETURN TRUE;
  ELSIF Util.StrEqual(interp, "ruby") THEN
    Util.StrCopy("Ruby", lang); RETURN TRUE;
  ELSIF Util.StrEqual(interp, "perl") OR Util.StrEqual(interp, "perl5") THEN
    Util.StrCopy("Perl", lang); RETURN TRUE;
  ELSIF Util.StrEqual(interp, "node") OR Util.StrEqual(interp, "nodejs") THEN
    Util.StrCopy("JavaScript", lang); RETURN TRUE;
  ELSIF Util.StrEqual(interp, "lua") THEN
    Util.StrCopy("Lua", lang); RETURN TRUE;
  ELSIF Util.StrEqual(interp, "php") THEN
    Util.StrCopy("PHP", lang); RETURN TRUE;
  ELSIF Util.StrEqual(interp, "Rscript") THEN
    Util.StrCopy("R", lang); RETURN TRUE;
  ELSIF Util.StrEqual(interp, "awk") OR Util.StrEqual(interp, "gawk") THEN
    Util.StrCopy("Awk", lang); RETURN TRUE;
  ELSIF Util.StrEqual(interp, "tclsh") OR Util.StrEqual(interp, "wish") THEN
    Util.StrCopy("Tcl", lang); RETURN TRUE;
  ELSIF Util.StrEqual(interp, "elixir") THEN
    Util.StrCopy("Elixir", lang); RETURN TRUE;
  END;
  RETURN FALSE;
END ByShebang;

PROCEDURE InitExts;
BEGIN
  extCount := 0;
  (* C family *)
  AddExt(".c", "C"); AddExt(".h", "C");
  AddExt(".cpp", "C++"); AddExt(".cxx", "C++"); AddExt(".cc", "C++");
  AddExt(".hpp", "C++"); AddExt(".hxx", "C++"); AddExt(".hh", "C++");
  AddExt(".cs", "C#");
  AddExt(".m", "Objective-C"); AddExt(".mm", "Objective-C++");
  (* JVM *)
  AddExt(".java", "Java");
  AddExt(".kt", "Kotlin"); AddExt(".kts", "Kotlin");
  AddExt(".scala", "Scala");
  AddExt(".groovy", "Groovy"); AddExt(".gradle", "Groovy");
  AddExt(".clj", "Clojure"); AddExt(".cljs", "Clojure");
  (* Scripting *)
  AddExt(".py", "Python"); AddExt(".pyi", "Python"); AddExt(".pyw", "Python");
  AddExt(".rb", "Ruby");
  AddExt(".pl", "Perl"); AddExt(".pm", "Perl");
  AddExt(".php", "PHP");
  AddExt(".lua", "Lua");
  AddExt(".r", "R"); AddExt(".R", "R");
  AddExt(".jl", "Julia");
  AddExt(".tcl", "Tcl");
  AddExt(".el", "Emacs Lisp");
  (* JavaScript / TypeScript *)
  AddExt(".js", "JavaScript"); AddExt(".mjs", "JavaScript");
  AddExt(".cjs", "JavaScript"); AddExt(".jsx", "JavaScript");
  AddExt(".ts", "TypeScript"); AddExt(".tsx", "TypeScript");
  AddExt(".mts", "TypeScript"); AddExt(".cts", "TypeScript");
  (* Systems *)
  AddExt(".go", "Go");
  AddExt(".rs", "Rust");
  AddExt(".swift", "Swift");
  AddExt(".zig", "Zig");
  AddExt(".nim", "Nim");
  AddExt(".d", "D");
  AddExt(".v", "V");
  AddExt(".dart", "Dart");
  (* Functional *)
  AddExt(".hs", "Haskell"); AddExt(".lhs", "Haskell");
  AddExt(".ml", "OCaml"); AddExt(".mli", "OCaml");
  AddExt(".fs", "F#"); AddExt(".fsi", "F#"); AddExt(".fsx", "F#");
  AddExt(".erl", "Erlang"); AddExt(".hrl", "Erlang");
  AddExt(".ex", "Elixir"); AddExt(".exs", "Elixir");
  AddExt(".lisp", "Common Lisp"); AddExt(".cl", "Common Lisp");
  AddExt(".rkt", "Racket"); AddExt(".scm", "Scheme");
  (* Classic *)
  AddExt(".ada", "Ada"); AddExt(".adb", "Ada"); AddExt(".ads", "Ada");
  AddExt(".pas", "Pascal"); AddExt(".pp", "Pascal");
  AddExt(".f90", "Fortran"); AddExt(".f95", "Fortran"); AddExt(".for", "Fortran");
  AddExt(".cob", "COBOL"); AddExt(".cbl", "COBOL");
  AddExt(".mod", "Modula-2"); AddExt(".def", "Modula-2");
  AddExt(".vb", "Visual Basic");
  (* Assembly *)
  AddExt(".asm", "Assembly"); AddExt(".s", "Assembly"); AddExt(".S", "Assembly");
  (* Shell *)
  AddExt(".sh", "Shell"); AddExt(".bash", "Shell");
  AddExt(".zsh", "Shell"); AddExt(".fish", "Shell");
  AddExt(".ps1", "PowerShell"); AddExt(".psm1", "PowerShell");
  AddExt(".bat", "Batch"); AddExt(".cmd", "Batch");
  (* Web *)
  AddExt(".html", "HTML"); AddExt(".htm", "HTML");
  AddExt(".css", "CSS"); AddExt(".scss", "SCSS");
  AddExt(".less", "Less"); AddExt(".sass", "Sass");
  (* Data / Markup *)
  AddExt(".xml", "XML"); AddExt(".xsl", "XML"); AddExt(".xsd", "XML");
  AddExt(".svg", "SVG");
  AddExt(".json", "JSON");
  AddExt(".yaml", "YAML"); AddExt(".yml", "YAML");
  AddExt(".toml", "TOML");
  AddExt(".ini", "INI");
  AddExt(".md", "Markdown"); AddExt(".markdown", "Markdown");
  AddExt(".rst", "reStructuredText");
  AddExt(".tex", "TeX");
  AddExt(".sql", "SQL");
  AddExt(".graphql", "GraphQL"); AddExt(".gql", "GraphQL");
  AddExt(".proto", "Protocol Buffers");
  (* Build / DevOps *)
  AddExt(".mk", "Makefile");
  AddExt(".cmake", "CMake");
  AddExt(".tf", "HCL"); AddExt(".hcl", "HCL");
  AddExt(".nix", "Nix");
  AddExt(".vim", "Vim Script");
  AddExt(".diff", "Diff"); AddExt(".patch", "Diff");
END InitExts;

PROCEDURE InitNames;
BEGIN
  nameCount := 0;
  AddName("Makefile", "Makefile");
  AddName("GNUmakefile", "Makefile");
  AddName("Dockerfile", "Dockerfile");
  AddName("CMakeLists.txt", "CMake");
  AddName("Rakefile", "Ruby");
  AddName("Gemfile", "Ruby");
  AddName("SConstruct", "Python");
  AddName("Vagrantfile", "Ruby");
  AddName("Justfile", "Just");
  AddName("Procfile", "Procfile");
END InitNames;

BEGIN
  InitExts;
  InitNames;
END Detect.
