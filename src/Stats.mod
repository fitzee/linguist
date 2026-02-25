IMPLEMENTATION MODULE Stats;

IMPORT Util;

CONST
  MaxLangs = 128;

TYPE
  LangStat = RECORD
    name: ARRAY [0..31] OF CHAR;
    bytes: INTEGER;
    files: INTEGER;
    lines: INTEGER;
  END;

VAR
  langs: ARRAY [0..MaxLangs-1] OF LangStat;
  langCnt: INTEGER;
  totBytes, totFiles, totLines: INTEGER;

PROCEDURE Init;
BEGIN
  langCnt := 0;
  totBytes := 0;
  totFiles := 0;
  totLines := 0;
END Init;

PROCEDURE FindLang(name: ARRAY OF CHAR): INTEGER;
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE i < langCnt DO
    IF Util.StrEqual(name, langs[i].name) THEN RETURN i; END;
    INC(i);
  END;
  RETURN -1;
END FindLang;

PROCEDURE AddFile(lang: ARRAY OF CHAR; bytes: INTEGER; lines: INTEGER);
VAR idx: INTEGER;
BEGIN
  idx := FindLang(lang);
  IF idx < 0 THEN
    IF langCnt >= MaxLangs THEN RETURN; END;
    idx := langCnt;
    Util.StrCopy(lang, langs[idx].name);
    langs[idx].bytes := 0;
    langs[idx].files := 0;
    langs[idx].lines := 0;
    INC(langCnt);
  END;
  INC(langs[idx].bytes, bytes);
  INC(langs[idx].files, 1);
  INC(langs[idx].lines, lines);
  INC(totBytes, bytes);
  INC(totFiles, 1);
  INC(totLines, lines);
END AddFile;

PROCEDURE LangCount(): INTEGER;
BEGIN
  RETURN langCnt;
END LangCount;

PROCEDURE GetLang(i: INTEGER; VAR name: ARRAY OF CHAR;
                  VAR bytes, files, lines: INTEGER);
BEGIN
  IF (i >= 0) AND (i < langCnt) THEN
    Util.StrCopy(langs[i].name, name);
    bytes := langs[i].bytes;
    files := langs[i].files;
    lines := langs[i].lines;
  END;
END GetLang;

PROCEDURE TotalBytes(): INTEGER;
BEGIN
  RETURN totBytes;
END TotalBytes;

PROCEDURE TotalFiles(): INTEGER;
BEGIN
  RETURN totFiles;
END TotalFiles;

PROCEDURE TotalLines(): INTEGER;
BEGIN
  RETURN totLines;
END TotalLines;

PROCEDURE Sort;
VAR
  i, j: INTEGER;
  tmp: LangStat;
BEGIN
  i := 0;
  WHILE i < langCnt - 1 DO
    j := i + 1;
    WHILE j < langCnt DO
      IF langs[j].bytes > langs[i].bytes THEN
        tmp := langs[i];
        langs[i] := langs[j];
        langs[j] := tmp;
      END;
      INC(j);
    END;
    INC(i);
  END;
END Sort;

END Stats.
