IMPLEMENTATION MODULE Scan;

FROM SYSTEM IMPORT ADR, ADDRESS;
IMPORT Sys, Util, Path, Text, Detect, Ignore, Attrs, Stats;

CONST
  MaxEntries = 4096;
  HeadSize = 8192;
  ListSize = 65536;

TYPE
  EntryRec = RECORD
    path: ARRAY [0..255] OF CHAR;
    lang: ARRAY [0..31] OF CHAR;
  END;

VAR
  entries: ARRAY [0..MaxEntries-1] OF EntryRec;
  entryCnt: INTEGER;
  storeEntries: BOOLEAN;
  skipVendored, skipGenerated: BOOLEAN;

PROCEDURE EntryCount(): INTEGER;
BEGIN
  RETURN entryCnt;
END EntryCount;

PROCEDURE GetEntryLang(i: INTEGER; VAR lang: ARRAY OF CHAR);
BEGIN
  IF (i >= 0) AND (i < entryCnt) THEN
    Util.StrCopy(entries[i].lang, lang);
  ELSE
    lang[0] := 0C;
  END;
END GetEntryLang;

PROCEDURE GetEntryPath(i: INTEGER; VAR path: ARRAY OF CHAR);
BEGIN
  IF (i >= 0) AND (i < entryCnt) THEN
    Util.StrCopy(entries[i].path, path);
  ELSE
    path[0] := 0C;
  END;
END GetEntryPath;

PROCEDURE IsSkipName(name: ARRAY OF CHAR): BOOLEAN;
BEGIN
  RETURN Util.StrEqual(name, ".git") OR
         Util.StrEqual(name, ".DS_Store") OR
         Util.StrEqual(name, ".hg") OR
         Util.StrEqual(name, ".svn") OR
         Util.StrEqual(name, "node_modules");
END IsSkipName;

PROCEDURE ProcessFile(fullPath: ARRAY OF CHAR; relPath: ARRAY OF CHAR);
VAR
  headBuf: ARRAY [0..HeadSize-1] OF CHAR;
  ext: ARRAY [0..31] OF CHAR;
  lang: ARRAY [0..63] OF CHAR;
  bn: ARRAY [0..255] OF CHAR;
  dmy: ARRAY [0..1] OF CHAR;
  h, headLen, sz, lns: INTEGER;
BEGIN
  (* Skip symlinks *)
  IF Sys.m2sys_is_symlink(ADR(fullPath)) = 1 THEN RETURN; END;
  sz := Sys.m2sys_file_size(ADR(fullPath));
  IF sz < 0 THEN RETURN; END;
  (* Read file head for binary/shebang detection *)
  h := Sys.m2sys_fopen(ADR(fullPath), ADR("rb"));
  IF h < 0 THEN RETURN; END;
  headLen := Sys.m2sys_fread_bytes(h, ADR(headBuf), HeadSize);
  Sys.m2sys_fclose(h);
  IF headLen < 0 THEN headLen := 0; END;
  (* Skip binary files *)
  IF (headLen > 0) AND Text.IsBinary(ADR(headBuf), VAL(CARDINAL, headLen)) THEN
    RETURN;
  END;
  (* Check .gitattributes overrides *)
  IF skipVendored AND Attrs.IsVendored(relPath) THEN RETURN; END;
  IF skipGenerated AND Attrs.IsGenerated(relPath) THEN RETURN; END;
  IF Attrs.IsDocumentation(relPath) THEN RETURN; END;
  (* Check for language override from .gitattributes *)
  lang[0] := 0C;
  IF NOT Attrs.GetLanguageOverride(relPath, lang) THEN
    (* Detect by extension *)
    Path.Extension(fullPath, ext);
    IF ext[0] # 0C THEN
      IF NOT Detect.ByExtension(ext, lang) THEN
        lang[0] := 0C;
      END;
    END;
    (* Try by well-known filename *)
    IF lang[0] = 0C THEN
      Path.Split(fullPath, dmy, bn);
      IF NOT Detect.ByFilename(bn, lang) THEN
        lang[0] := 0C;
      END;
    END;
    (* Try shebang for extensionless or unrecognized *)
    IF (lang[0] = 0C) AND (headLen > 0) THEN
      IF NOT Detect.ByShebang(ADR(headBuf), VAL(CARDINAL, headLen), lang) THEN
        lang[0] := 0C;
      END;
    END;
  END;
  IF lang[0] = 0C THEN RETURN; END;
  (* Count lines *)
  lns := Util.CountFileLines(fullPath);
  (* Add to stats *)
  Stats.AddFile(lang, sz, lns);
  (* Store for breakdown if enabled *)
  IF storeEntries AND (entryCnt < MaxEntries) THEN
    Util.StrCopy(relPath, entries[entryCnt].path);
    Util.StrCopy(lang, entries[entryCnt].lang);
    INC(entryCnt);
  END;
END ProcessFile;

PROCEDURE ScanRecurse(dir: ARRAY OF CHAR; relDir: ARRAY OF CHAR;
                      depth: INTEGER);
VAR
  listBuf: ARRAY [0..ListSize-1] OF CHAR;
  entry: ARRAY [0..255] OF CHAR;
  fullPath: ARRAY [0..1023] OF CHAR;
  relPath: ARRAY [0..1023] OF CHAR;
  giPath: ARRAY [0..1023] OF CHAR;
  listLen, i, j: INTEGER;
  isDir: BOOLEAN;
BEGIN
  (* Check for .gitignore in this directory *)
  Path.Join(dir, ".gitignore", giPath);
  IF Sys.m2sys_file_exists(ADR(giPath)) = 1 THEN
    Ignore.LoadFile(giPath, relDir, depth);
  END;
  (* Check for .gitattributes in this directory *)
  Path.Join(dir, ".gitattributes", giPath);
  IF Sys.m2sys_file_exists(ADR(giPath)) = 1 THEN
    Attrs.LoadFile(giPath);
  END;
  (* List directory entries *)
  listLen := Sys.m2sys_list_dir(ADR(dir), ADR(listBuf), ListSize);
  IF listLen <= 0 THEN RETURN; END;
  (* Parse newline-separated entries *)
  i := 0;
  WHILE i < listLen DO
    j := 0;
    WHILE (i < listLen) AND (listBuf[i] # 12C) AND (j < HIGH(entry)) DO
      entry[j] := listBuf[i];
      INC(i); INC(j);
    END;
    entry[j] := 0C;
    IF (i < listLen) AND (listBuf[i] = 12C) THEN INC(i); END;
    IF (entry[0] = 0C) OR (entry[0] = '.') THEN
      (* Skip empty, hidden files, and . / .. *)
    ELSIF IsSkipName(entry) THEN
      (* Skip well-known non-source dirs *)
    ELSE
      (* Build full and relative paths *)
      Path.Join(dir, entry, fullPath);
      IF relDir[0] = 0C THEN
        Util.StrCopy(entry, relPath);
      ELSE
        Util.StrCopy(relDir, relPath);
        Util.StrAppend(relPath, "/");
        Util.StrAppend(relPath, entry);
      END;
      isDir := Sys.m2sys_is_dir(ADR(fullPath)) = 1;
      IF NOT Ignore.IsIgnored(relPath, isDir) THEN
        IF isDir THEN
          ScanRecurse(fullPath, relPath, depth + 1);
        ELSE
          ProcessFile(fullPath, relPath);
        END;
      END;
    END;
  END;
  (* Pop ignore patterns for this depth *)
  Ignore.PopDepth(depth);
END ScanRecurse;

PROCEDURE ScanDir(root: ARRAY OF CHAR;
                  noVendored, noGenerated, breakdown: BOOLEAN);
VAR
  emptyRel: ARRAY [0..0] OF CHAR;
BEGIN
  entryCnt := 0;
  storeEntries := breakdown;
  skipVendored := noVendored;
  skipGenerated := noGenerated;
  emptyRel[0] := 0C;
  Ignore.Init;
  Attrs.Init;
  ScanRecurse(root, emptyRel, 0);
END ScanDir;

END Scan.
