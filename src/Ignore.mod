IMPLEMENTATION MODULE Ignore;

FROM SYSTEM IMPORT ADR;
IMPORT Sys, Util, Glob, Path;

CONST
  MaxPatterns = 512;

TYPE
  PatRec = RECORD
    pat: ARRAY [0..127] OF CHAR;
    base: ARRAY [0..127] OF CHAR;
    depth: INTEGER;
    negated: BOOLEAN;
    dirOnly: BOOLEAN;
    matchBase: BOOLEAN;
  END;

VAR
  pats: ARRAY [0..MaxPatterns-1] OF PatRec;
  patCount: INTEGER;

PROCEDURE Init;
BEGIN
  patCount := 0;
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

PROCEDURE AddPattern(line: ARRAY OF CHAR; baseDir: ARRAY OF CHAR;
                     depth: INTEGER);
VAR
  p: INTEGER;
  neg, dOnly, mBase: BOOLEAN;
  pat: ARRAY [0..127] OF CHAR;
  i, j: INTEGER;
BEGIN
  TrimLine(line);
  IF (line[0] = 0C) OR (line[0] = '#') THEN RETURN; END;
  IF patCount >= MaxPatterns THEN RETURN; END;
  neg := FALSE;
  p := 0;
  IF line[0] = '!' THEN
    neg := TRUE;
    p := 1;
  END;
  (* Check trailing / for directory-only *)
  i := Util.StrLen(line);
  dOnly := FALSE;
  IF (i > 0) AND (line[i-1] = '/') THEN
    dOnly := TRUE;
    line[i-1] := 0C;
    DEC(i);
  END;
  (* Strip leading / (anchored to base dir) *)
  IF line[p] = '/' THEN INC(p); END;
  (* Copy from position p *)
  j := 0;
  WHILE (line[p] # 0C) AND (j < HIGH(pat)) DO
    pat[j] := line[p];
    INC(p); INC(j);
  END;
  pat[j] := 0C;
  IF pat[0] = 0C THEN RETURN; END;
  (* Determine if pattern matches basename only (no slash in pattern) *)
  mBase := NOT HasSlash(pat);
  Util.StrCopy(pat, pats[patCount].pat);
  Util.StrCopy(baseDir, pats[patCount].base);
  pats[patCount].depth := depth;
  pats[patCount].negated := neg;
  pats[patCount].dirOnly := dOnly;
  pats[patCount].matchBase := mBase;
  INC(patCount);
END AddPattern;

PROCEDURE LoadFile(path: ARRAY OF CHAR; baseDir: ARRAY OF CHAR;
                   depth: INTEGER);
VAR
  h, n: INTEGER;
  line: ARRAY [0..255] OF CHAR;
BEGIN
  h := Sys.m2sys_fopen(ADR(path), ADR("r"));
  IF h < 0 THEN RETURN; END;
  LOOP
    n := Sys.m2sys_fread_line(h, ADR(line), 256);
    IF n < 0 THEN EXIT; END;
    AddPattern(line, baseDir, depth);
  END;
  Sys.m2sys_fclose(h);
END LoadFile;

PROCEDURE PopDepth(depth: INTEGER);
BEGIN
  WHILE (patCount > 0) AND (pats[patCount-1].depth >= depth) DO
    DEC(patCount);
  END;
END PopDepth;

PROCEDURE GetBasename(path: ARRAY OF CHAR; VAR bn: ARRAY OF CHAR);
VAR d: ARRAY [0..1] OF CHAR;
BEGIN
  Path.Split(path, d, bn);
END GetBasename;

PROCEDURE StripPrefix(path: ARRAY OF CHAR; prefix: ARRAY OF CHAR;
                      VAR out: ARRAY OF CHAR): BOOLEAN;
VAR
  pLen, i, j: INTEGER;
BEGIN
  pLen := Util.StrLen(prefix);
  IF pLen = 0 THEN
    Util.StrCopy(path, out);
    RETURN TRUE;
  END;
  IF NOT Util.StrStartsWith(path, prefix) THEN RETURN FALSE; END;
  i := pLen;
  IF (i <= HIGH(path)) AND (path[i] = '/') THEN INC(i); END;
  j := 0;
  WHILE (i <= HIGH(path)) AND (path[i] # 0C) AND (j <= HIGH(out)) DO
    out[j] := path[i];
    INC(i); INC(j);
  END;
  IF j <= HIGH(out) THEN out[j] := 0C; END;
  RETURN TRUE;
END StripPrefix;

PROCEDURE IsIgnored(relPath: ARRAY OF CHAR; isDir: BOOLEAN): BOOLEAN;
VAR
  i: INTEGER;
  result: BOOLEAN;
  bn: ARRAY [0..255] OF CHAR;
  sub: ARRAY [0..511] OF CHAR;
BEGIN
  result := FALSE;
  GetBasename(relPath, bn);
  FOR i := 0 TO patCount - 1 DO
    IF pats[i].dirOnly AND (NOT isDir) THEN
      (* directory-only pattern, skip for files *)
    ELSIF pats[i].matchBase THEN
      IF Glob.Match(pats[i].pat, bn) THEN
        IF pats[i].negated THEN
          result := FALSE;
        ELSE
          result := TRUE;
        END;
      END;
    ELSE
      IF StripPrefix(relPath, pats[i].base, sub) THEN
        IF Glob.Match(pats[i].pat, sub) THEN
          IF pats[i].negated THEN
            result := FALSE;
          ELSE
            result := TRUE;
          END;
        END;
      END;
    END;
  END;
  RETURN result;
END IsIgnored;

END Ignore.
