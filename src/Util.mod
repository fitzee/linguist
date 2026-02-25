IMPLEMENTATION MODULE Util;

FROM SYSTEM IMPORT ADR;
IMPORT Sys;

PROCEDURE StrLen(s: ARRAY OF CHAR): INTEGER;
BEGIN
  RETURN Sys.m2sys_strlen(ADR(s));
END StrLen;

PROCEDURE StrCopy(src: ARRAY OF CHAR; VAR dst: ARRAY OF CHAR);
BEGIN
  dst[0] := 0C;
  Sys.m2sys_str_append(ADR(dst), HIGH(dst) + 1, ADR(src));
END StrCopy;

PROCEDURE StrEqual(a, b: ARRAY OF CHAR): BOOLEAN;
BEGIN
  RETURN Sys.m2sys_str_eq(ADR(a), ADR(b)) = 1;
END StrEqual;

PROCEDURE StrEqualCI(a, b: ARRAY OF CHAR): BOOLEAN;
BEGIN
  IF Sys.m2sys_strlen(ADR(a)) # Sys.m2sys_strlen(ADR(b)) THEN
    RETURN FALSE;
  END;
  RETURN Sys.m2sys_str_contains_ci(ADR(a), ADR(b)) = 1;
END StrEqualCI;

PROCEDURE StrAppend(VAR dst: ARRAY OF CHAR; src: ARRAY OF CHAR);
BEGIN
  Sys.m2sys_str_append(ADR(dst), HIGH(dst) + 1, ADR(src));
END StrAppend;

PROCEDURE StrStartsWith(s, prefix: ARRAY OF CHAR): BOOLEAN;
BEGIN
  RETURN Sys.m2sys_str_starts_with(ADR(s), ADR(prefix)) = 1;
END StrStartsWith;

PROCEDURE StrContainsCI(haystack, needle: ARRAY OF CHAR): BOOLEAN;
BEGIN
  RETURN Sys.m2sys_str_contains_ci(ADR(haystack), ADR(needle)) = 1;
END StrContainsCI;

PROCEDURE IntToStr(n: INTEGER; VAR buf: ARRAY OF CHAR);
VAR
  tmp: ARRAY [0..15] OF CHAR;
  i, j, d: INTEGER;
  neg: BOOLEAN;
BEGIN
  IF n = 0 THEN
    buf[0] := '0';
    IF 1 <= HIGH(buf) THEN buf[1] := 0C; END;
    RETURN;
  END;
  neg := n < 0;
  IF neg THEN n := -n; END;
  i := 0;
  WHILE n > 0 DO
    d := n MOD 10;
    tmp[i] := CHR(d + ORD('0'));
    n := n DIV 10;
    INC(i);
  END;
  j := 0;
  IF neg THEN
    buf[0] := '-';
    j := 1;
  END;
  WHILE i > 0 DO
    DEC(i);
    IF j <= HIGH(buf) THEN
      buf[j] := tmp[i];
      INC(j);
    END;
  END;
  IF j <= HIGH(buf) THEN
    buf[j] := 0C;
  END;
END IntToStr;

PROCEDURE FmtPercent(permille: INTEGER; VAR buf: ARRAY OF CHAR);
VAR
  whole, frac, i: INTEGER;
  ws: ARRAY [0..15] OF CHAR;
BEGIN
  whole := permille DIV 10;
  frac := permille MOD 10;
  IntToStr(whole, ws);
  StrCopy(ws, buf);
  i := StrLen(buf);
  IF i + 2 <= HIGH(buf) THEN
    buf[i] := '.';
    buf[i+1] := CHR(frac + ORD('0'));
    buf[i+2] := 0C;
  END;
END FmtPercent;

PROCEDURE CountFileLines(path: ARRAY OF CHAR): INTEGER;
VAR
  h, n, i, count: INTEGER;
  buf: ARRAY [0..4095] OF CHAR;
BEGIN
  h := Sys.m2sys_fopen(ADR(path), ADR("rb"));
  IF h < 0 THEN RETURN 0; END;
  count := 0;
  LOOP
    n := Sys.m2sys_fread_bytes(h, ADR(buf), 4096);
    IF n <= 0 THEN EXIT; END;
    i := 0;
    WHILE i < n DO
      IF buf[i] = 12C THEN INC(count); END;
      INC(i);
    END;
  END;
  Sys.m2sys_fclose(h);
  RETURN count;
END CountFileLines;

PROCEDURE Err(msg: ARRAY OF CHAR);
BEGIN
  Sys.m2_stderr_write(ADR(msg));
END Err;

PROCEDURE ErrLn(msg: ARRAY OF CHAR);
BEGIN
  Sys.m2_stderr_write(ADR(msg));
  Sys.m2_stderr_write(ADR(nl));
END ErrLn;

PROCEDURE Out(msg: ARRAY OF CHAR);
BEGIN
  Sys.m2_stdout_write(ADR(msg));
END Out;

PROCEDURE OutLn(msg: ARRAY OF CHAR);
BEGIN
  Sys.m2_stdout_write(ADR(msg));
  Sys.m2_stdout_write(ADR(nl));
END OutLn;

VAR nl: ARRAY [0..1] OF CHAR;
BEGIN
  nl[0] := 12C;
  nl[1] := 0C;
END Util.
