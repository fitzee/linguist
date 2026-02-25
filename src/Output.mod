IMPLEMENTATION MODULE Output;

FROM SYSTEM IMPORT ADR, ADDRESS;
IMPORT Util, Stats, Scan, Fmt;

VAR
  outBuf: ARRAY [0..16383] OF CHAR;
  fmtBuf: Fmt.Buf;

PROCEDURE Flush;
BEGIN
  outBuf[Fmt.BufLen(fmtBuf)] := 0C;
  Util.Out(outBuf);
  Fmt.BufClear(fmtBuf);
END Flush;

PROCEDURE RenderText(breakdown: BOOLEAN);
VAR
  i, n, bytes, files, lines, tot, langIdx: INTEGER;
  name: ARRAY [0..31] OF CHAR;
  pct: ARRAY [0..15] OF CHAR;
  bs: ARRAY [0..15] OF CHAR;
  fs: ARRAY [0..15] OF CHAR;
  ls: ARRAY [0..15] OF CHAR;
  path: ARRAY [0..255] OF CHAR;
  permille: INTEGER;
BEGIN
  n := Stats.LangCount();
  tot := Stats.TotalBytes();
  IF n = 0 THEN
    Util.OutLn("No source files found.");
    RETURN;
  END;
  Fmt.InitBuf(fmtBuf, ADR(outBuf), 16384);
  Fmt.TableSetColumns(5);
  Fmt.TableSetHeader(0, "Language");
  Fmt.TableSetHeader(1, "Lines");
  Fmt.TableSetHeader(2, "Bytes");
  Fmt.TableSetHeader(3, "Files");
  Fmt.TableSetHeader(4, "Percentage");
  FOR i := 0 TO n - 1 DO
    Stats.GetLang(i, name, bytes, files, lines);
    Util.IntToStr(lines, ls);
    Util.IntToStr(bytes, bs);
    Util.IntToStr(files, fs);
    IF tot > 0 THEN
      permille := (bytes DIV 100) * 1000 DIV (tot DIV 100);
    ELSE
      permille := 0;
    END;
    Util.FmtPercent(permille, pct);
    Util.StrAppend(pct, "%");
    langIdx := Fmt.TableAddRow();
    Fmt.TableSetCell(langIdx, 0, name);
    Fmt.TableSetCell(langIdx, 1, ls);
    Fmt.TableSetCell(langIdx, 2, bs);
    Fmt.TableSetCell(langIdx, 3, fs);
    Fmt.TableSetCell(langIdx, 4, pct);
  END;
  (* Totals row *)
  Util.IntToStr(Stats.TotalLines(), ls);
  Util.IntToStr(tot, bs);
  Util.IntToStr(Stats.TotalFiles(), fs);
  langIdx := Fmt.TableAddRow();
  Fmt.TableSetCell(langIdx, 0, "Total");
  Fmt.TableSetCell(langIdx, 1, ls);
  Fmt.TableSetCell(langIdx, 2, bs);
  Fmt.TableSetCell(langIdx, 3, fs);
  Fmt.TableSetCell(langIdx, 4, "100.0%");
  Fmt.TableRender(fmtBuf);
  Flush;
  Util.Out("");
  Util.OutLn("");
  IF breakdown THEN
    RenderBreakdownText;
  END;
END RenderText;

PROCEDURE RenderBreakdownText;
VAR
  i, j, n, bytes, files, lines: INTEGER;
  langName: ARRAY [0..31] OF CHAR;
  entryLang: ARRAY [0..31] OF CHAR;
  path: ARRAY [0..255] OF CHAR;
  shown: BOOLEAN;
BEGIN
  n := Stats.LangCount();
  FOR i := 0 TO n - 1 DO
    Stats.GetLang(i, langName, bytes, files, lines);
    shown := FALSE;
    FOR j := 0 TO Scan.EntryCount() - 1 DO
      Scan.GetEntryLang(j, entryLang);
      IF Util.StrEqual(entryLang, langName) THEN
        IF NOT shown THEN
          Util.OutLn(langName);
          shown := TRUE;
        END;
        Scan.GetEntryPath(j, path);
        Util.Out("  ");
        Util.OutLn(path);
      END;
    END;
  END;
END RenderBreakdownText;

PROCEDURE RenderJson(breakdown: BOOLEAN);
VAR
  i, j, n, bytes, files, lines, tot: INTEGER;
  name: ARRAY [0..31] OF CHAR;
  entryLang: ARRAY [0..31] OF CHAR;
  pct: ARRAY [0..15] OF CHAR;
  path: ARRAY [0..255] OF CHAR;
  permille: INTEGER;
BEGIN
  n := Stats.LangCount();
  tot := Stats.TotalBytes();
  Fmt.InitBuf(fmtBuf, ADR(outBuf), 16384);
  Fmt.JsonStart(fmtBuf);
  Fmt.JsonKey(fmtBuf, "languages");
  Fmt.JsonStart(fmtBuf);
  FOR i := 0 TO n - 1 DO
    Stats.GetLang(i, name, bytes, files, lines);
    IF tot > 0 THEN
      permille := (bytes DIV 100) * 1000 DIV (tot DIV 100);
    ELSE
      permille := 0;
    END;
    Util.FmtPercent(permille, pct);
    Fmt.JsonKey(fmtBuf, name);
    Fmt.JsonStart(fmtBuf);
    Fmt.JsonKey(fmtBuf, "bytes"); Fmt.JsonInt(fmtBuf, bytes);
    Fmt.JsonKey(fmtBuf, "files"); Fmt.JsonInt(fmtBuf, files);
    Fmt.JsonKey(fmtBuf, "lines"); Fmt.JsonInt(fmtBuf, lines);
    Fmt.JsonKey(fmtBuf, "percentage"); Fmt.JsonStr(fmtBuf, pct);
    IF breakdown THEN
      Fmt.JsonKey(fmtBuf, "file_list");
      Fmt.JsonArrayStart(fmtBuf);
      FOR j := 0 TO Scan.EntryCount() - 1 DO
        Scan.GetEntryLang(j, entryLang);
        IF Util.StrEqual(entryLang, name) THEN
          Scan.GetEntryPath(j, path);
          Fmt.JsonStr(fmtBuf, path);
        END;
      END;
      Fmt.JsonArrayEnd(fmtBuf);
    END;
    Fmt.JsonEnd(fmtBuf);
    (* Flush periodically for large repos *)
    IF Fmt.BufLen(fmtBuf) > 14000 THEN
      Flush;
    END;
  END;
  Fmt.JsonEnd(fmtBuf);
  Fmt.JsonKey(fmtBuf, "total_bytes"); Fmt.JsonInt(fmtBuf, tot);
  Fmt.JsonKey(fmtBuf, "total_files"); Fmt.JsonInt(fmtBuf, Stats.TotalFiles());
  Fmt.JsonKey(fmtBuf, "total_lines"); Fmt.JsonInt(fmtBuf, Stats.TotalLines());
  Fmt.JsonEnd(fmtBuf);
  Flush;
  Util.OutLn("");
END RenderJson;

END Output.
