IMPLEMENTATION MODULE Attrs;

FROM SYSTEM IMPORT ADR;
IMPORT Sys, Util, Glob, Path;

CONST
  MaxAttrs = 128;

TYPE
  AttrRec = RECORD
    pattern: ARRAY [0..127] OF CHAR;
    vendored: BOOLEAN;
    generated: BOOLEAN;
    documentation: BOOLEAN;
    language: ARRAY [0..31] OF CHAR;
    hasLanguage: BOOLEAN;
    matchBase: BOOLEAN;
  END;

VAR
  attrs: ARRAY [0..MaxAttrs-1] OF AttrRec;
  attrCount: INTEGER;

PROCEDURE Init;
BEGIN
  attrCount := 0;
END Init;

PROCEDURE TrimLine(VAR s: ARRAY OF CHAR);
VAR i: INTEGER;
BEGIN
  i := Util.StrLen(s);
  WHILE (i > 0) AND ((s[i-1] = ' ') OR (s[i-1] = 11C) OR
                      (s[i-1] = 15C) OR (s[i-1] = 12C)) DO
    DEC(i);
  END;
  IF i <= HIGH(s) THEN s[i] := 0C; END;
END TrimLine;

PROCEDURE HasSlash(s: ARRAY OF CHAR): BOOLEAN;
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE (i <= HIGH(s)) AND (s[i] # 0C) DO
    IF s[i] = '/' THEN RETURN TRUE; END;
    INC(i);
  END;
  RETURN FALSE;
END HasSlash;

PROCEDURE SkipSpaces(line: ARRAY OF CHAR; start: INTEGER): INTEGER;
BEGIN
  WHILE (start <= HIGH(line)) AND
        ((line[start] = ' ') OR (line[start] = 11C)) DO
    INC(start);
  END;
  RETURN start;
END SkipSpaces;

PROCEDURE ExtractToken(line: ARRAY OF CHAR; start: INTEGER;
                       VAR tok: ARRAY OF CHAR; VAR next: INTEGER);
VAR j: INTEGER;
BEGIN
  j := 0;
  WHILE (start <= HIGH(line)) AND (line[start] # 0C) AND
        (line[start] # ' ') AND (line[start] # 11C) AND
        (j <= HIGH(tok)) DO
    tok[j] := line[start];
    INC(start); INC(j);
  END;
  IF j <= HIGH(tok) THEN tok[j] := 0C; END;
  next := start;
END ExtractToken;

PROCEDURE ParseLine(line: ARRAY OF CHAR);
VAR
  p: INTEGER;
  pattern, token, val: ARRAY [0..127] OF CHAR;
  idx: INTEGER;
  eqPos, k: INTEGER;
BEGIN
  TrimLine(line);
  IF (line[0] = 0C) OR (line[0] = '#') THEN RETURN; END;
  IF attrCount >= MaxAttrs THEN RETURN; END;
  p := 0;
  ExtractToken(line, p, pattern, p);
  IF pattern[0] = 0C THEN RETURN; END;
  idx := attrCount;
  Util.StrCopy(pattern, attrs[idx].pattern);
  attrs[idx].vendored := FALSE;
  attrs[idx].generated := FALSE;
  attrs[idx].documentation := FALSE;
  attrs[idx].hasLanguage := FALSE;
  attrs[idx].language[0] := 0C;
  attrs[idx].matchBase := NOT HasSlash(pattern);
  (* Parse attribute tokens *)
  LOOP
    p := SkipSpaces(line, p);
    IF (p > HIGH(line)) OR (line[p] = 0C) THEN EXIT; END;
    ExtractToken(line, p, token, p);
    IF token[0] = 0C THEN EXIT; END;
    (* Check for key=value *)
    eqPos := -1;
    k := 0;
    WHILE (k <= HIGH(token)) AND (token[k] # 0C) DO
      IF token[k] = '=' THEN eqPos := k; END;
      INC(k);
    END;
    IF eqPos > 0 THEN
      (* key=value *)
      val[0] := 0C;
      k := eqPos + 1;
      IF (k <= HIGH(token)) AND (token[k] # 0C) THEN
        Util.StrCopy(token, val);
        (* Shift val to start after '=' *)
        k := 0;
        WHILE val[k + VAL(INTEGER, eqPos) + 1] # 0C DO
          val[k] := val[k + VAL(INTEGER, eqPos) + 1];
          INC(k);
        END;
        val[k] := 0C;
      END;
      token[eqPos] := 0C;
      IF Util.StrEqual(token, "linguist-language") THEN
        attrs[idx].hasLanguage := TRUE;
        Util.StrCopy(val, attrs[idx].language);
      ELSIF Util.StrEqual(token, "linguist-vendored") THEN
        attrs[idx].vendored := Util.StrEqual(val, "true") OR
                               Util.StrEqual(val, "");
      ELSIF Util.StrEqual(token, "linguist-generated") THEN
        attrs[idx].generated := Util.StrEqual(val, "true") OR
                                Util.StrEqual(val, "");
      ELSIF Util.StrEqual(token, "linguist-documentation") THEN
        attrs[idx].documentation := Util.StrEqual(val, "true") OR
                                    Util.StrEqual(val, "");
      END;
    ELSE
      (* bare attribute *)
      IF Util.StrEqual(token, "linguist-vendored") THEN
        attrs[idx].vendored := TRUE;
      ELSIF Util.StrEqual(token, "linguist-generated") THEN
        attrs[idx].generated := TRUE;
      ELSIF Util.StrEqual(token, "linguist-documentation") THEN
        attrs[idx].documentation := TRUE;
      END;
    END;
  END;
  INC(attrCount);
END ParseLine;

PROCEDURE LoadFile(path: ARRAY OF CHAR);
VAR
  h, n: INTEGER;
  line: ARRAY [0..511] OF CHAR;
BEGIN
  h := Sys.m2sys_fopen(ADR(path), ADR("r"));
  IF h < 0 THEN RETURN; END;
  LOOP
    n := Sys.m2sys_fread_line(h, ADR(line), 512);
    IF n < 0 THEN EXIT; END;
    ParseLine(line);
  END;
  Sys.m2sys_fclose(h);
END LoadFile;

PROCEDURE MatchAttr(idx: INTEGER; relPath: ARRAY OF CHAR): BOOLEAN;
VAR
  bn: ARRAY [0..255] OF CHAR;
  d: ARRAY [0..1] OF CHAR;
BEGIN
  IF attrs[idx].matchBase THEN
    Path.Split(relPath, d, bn);
    RETURN Glob.Match(attrs[idx].pattern, bn);
  ELSE
    RETURN Glob.Match(attrs[idx].pattern, relPath);
  END;
END MatchAttr;

PROCEDURE IsVendored(relPath: ARRAY OF CHAR): BOOLEAN;
VAR i: INTEGER; result: BOOLEAN;
BEGIN
  result := FALSE;
  FOR i := 0 TO attrCount - 1 DO
    IF attrs[i].vendored AND MatchAttr(i, relPath) THEN
      result := TRUE;
    END;
  END;
  RETURN result;
END IsVendored;

PROCEDURE IsGenerated(relPath: ARRAY OF CHAR): BOOLEAN;
VAR i: INTEGER; result: BOOLEAN;
BEGIN
  result := FALSE;
  FOR i := 0 TO attrCount - 1 DO
    IF attrs[i].generated AND MatchAttr(i, relPath) THEN
      result := TRUE;
    END;
  END;
  RETURN result;
END IsGenerated;

PROCEDURE IsDocumentation(relPath: ARRAY OF CHAR): BOOLEAN;
VAR i: INTEGER; result: BOOLEAN;
BEGIN
  result := FALSE;
  FOR i := 0 TO attrCount - 1 DO
    IF attrs[i].documentation AND MatchAttr(i, relPath) THEN
      result := TRUE;
    END;
  END;
  RETURN result;
END IsDocumentation;

PROCEDURE GetLanguageOverride(relPath: ARRAY OF CHAR;
                              VAR lang: ARRAY OF CHAR): BOOLEAN;
VAR i: INTEGER;
BEGIN
  FOR i := 0 TO attrCount - 1 DO
    IF attrs[i].hasLanguage AND MatchAttr(i, relPath) THEN
      Util.StrCopy(attrs[i].language, lang);
      RETURN TRUE;
    END;
  END;
  RETURN FALSE;
END GetLanguageOverride;

END Attrs.
