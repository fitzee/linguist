MODULE Main;

FROM Args IMPORT ArgCount, GetArg;
FROM SYSTEM IMPORT ADR;
IMPORT CLI, Util, Stats, Scan, Output, Sys;

VAR
  dir: ARRAY [0..1023] OF CHAR;
  arg: ARRAY [0..255] OF CHAR;
  i: INTEGER;
  ac: CARDINAL;
  json, breakdown, noVendored, noGenerated: BOOLEAN;

PROCEDURE FetchArg(n: CARDINAL; VAR buf: ARRAY OF CHAR);
BEGIN
  GetArg(n, buf);
END FetchArg;

PROCEDURE FindPositionalArg;
(* Find first non-flag argument as the target directory. *)
VAR j: INTEGER;
    a: ARRAY [0..255] OF CHAR;
BEGIN
  dir[0] := '.'; dir[1] := 0C;
  j := 1;
  WHILE j < VAL(INTEGER, ac) DO
    GetArg(VAL(CARDINAL, j), a);
    IF a[0] # '-' THEN
      Util.StrCopy(a, dir);
      RETURN;
    END;
    INC(j);
  END;
END FindPositionalArg;

BEGIN
  CLI.AddFlag("h", "help", "Show this help message");
  CLI.AddFlag("j", "json", "Output as JSON");
  CLI.AddFlag("b", "breakdown", "Show per-language file list");
  CLI.AddFlag("", "no-vendored", "Exclude vendored files");
  CLI.AddFlag("", "no-generated", "Exclude generated files");
  ac := ArgCount();
  CLI.Parse(ac, FetchArg);

  IF CLI.HasFlag("help") = 1 THEN
    Util.OutLn("Usage: linguist [options] [directory]");
    Util.OutLn("");
    CLI.PrintHelp;
    HALT;
  END;

  json := CLI.HasFlag("json") = 1;
  breakdown := CLI.HasFlag("breakdown") = 1;
  noVendored := CLI.HasFlag("no-vendored") = 1;
  noGenerated := CLI.HasFlag("no-generated") = 1;

  FindPositionalArg;

  IF Sys.m2sys_is_dir(ADR(dir)) # 1 THEN
    Util.Err("Error: not a directory: ");
    Util.ErrLn(dir);
    HALT;
  END;

  Stats.Init;
  Scan.ScanDir(dir, noVendored, noGenerated, breakdown);
  Stats.Sort;

  IF json THEN
    Output.RenderJson(breakdown);
  ELSE
    Output.RenderText(breakdown);
  END;
END Main.
