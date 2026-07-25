# shape-measure.awk — the MEASUREMENT half of the code-shape gate (#120). It reads tracked shell
# scripts and prints one TAB-delimited row per measured fact; it enforces NOTHING. shape-check.sh
# is the enforcing half and the only intended caller. DEV infrastructure: never ships to a user
# estate (#43), and no PRODUCT script references it.
#
# WHY A SEPARATE FILE, AND WHY awk: the four metrics need a shell TOKENISER (quotes, comments,
# heredocs, command substitution) and that is a scanner, not a grep. Keeping it here keeps
# shape-check.sh small enough to pass its own limits. This file is deliberately OUTSIDE the
# measured surface — the surface is tracked *.sh, and awk is not shell. That is a stated boundary,
# not an oversight: the four limits are defined for shell code and mean nothing applied to awk.
#
# OUTPUT ROWS — "<file>\t<key>\t<value...>":
#   longlines  <n>                       lines longer than the character limit
#   longfirst  <lineno>                  first such line (0 if none)
#   outside    <n>                       lines of code outside every function
#   depth      <n>                       deepest nesting of compound commands
#   depthline  <lineno>                  where that depth is reached
#   funclen    <n>                       longest function, in physical lines (0 if none)
#   census     <name> <start> <end> <lines> <single>   one row per function definition found
#   balance    <n>                       nesting depth left over at end of file; MUST be 0
#   error      <message>                 the scanner could not account for something
#
# THE FOUR MEASUREMENTS, stated exactly (a metric nobody can restate is a metric nobody can check):
#
# 1. LINE LENGTH — CHARACTERS, not bytes. This repository's prose is full of em dashes, which cost
#    three bytes each, so a byte rule would measure something no author can see in their editor.
#    awk's own length() cannot be used for it: gawk counts characters in a UTF-8 locale but BYTES
#    under the LC_ALL=C that shape-check.sh sets for determinism, and mawk counts bytes in either.
#    So length() alone makes the verdict depend on the locale and the implementation that happened
#    to run. nchars() subtracts UTF-8 continuation bytes from the byte length instead, which
#    returns the character count under every combination of the two. A BEGIN probe proves the
#    counter on a known string and emits a fatal row if it is wrong, so a miscounting awk reds
#    loudly instead of quietly reporting smaller numbers.
#
# 2. LINES OF CODE OUTSIDE ANY FUNCTION — non-blank, non-comment-only lines, minus every line from
#    a column-zero definition through its matched close (so a single-line definition contributes
#    exactly one line inside). A line is comment-only when the scanner is in clean code state at
#    the start of it and its first non-blank character is "#": that state test is what stops a "#"
#    inside a heredoc body or a multi-line string being read as a comment. HEREDOC BODIES ARE NOT
#    CODE and are excluded — they are data the script writes out, and counting them would measure
#    the size of a fixture as if it were logic.
#
# 3. NESTING DEPTH — the deepest nesting of COMPOUND COMMANDS: if / for / while / until / select /
#    case and brace groups (a function body is one). DO NOT count "then" and "do" as levels of
#    their own: they are the same compound command as the "if" or "for" that opened them, and
#    counting both doubles every measurement — an if inside a for reads as depth 4 rather than 2,
#    which is the whole budget spent on two levels of ordinary shell. Parentheses (subshells,
#    command substitution, process substitution) are NOT counted as depth: they cannot be told
#    apart from a case pattern's ")" or a definition's "()" without a full parser, and a miscount
#    there is worse than the level it would add.
#
# 4. FUNCTION LENGTH — physical lines from the definition line through the line carrying its
#    matched close, both counted. A single-line definition is therefore 1.
#
# THE SCANNER'S OWN HONESTY CHECK: depth must return to exactly 0 at the end of every file, every
# heredoc must terminate, every quote must close, and no function may be left open. Shell that
# parses has all four properties, so a non-zero balance means the SCANNER is wrong, not the file.
# shape-check.sh treats any such row as a hard failure rather than reporting numbers it cannot
# stand behind — the measurement half never guesses.
#
# KNOWN LIMITS, stated rather than discovered later: backtick command substitution is not parsed
# (this repository uses none); a case pattern's ")" inside a command substitution would close the
# substitution early; and only the first heredoc-per-line family is fully exercised here. Each of
# these would show up as a non-zero balance rather than as a wrong number quietly passing.

# nchars — characters in s, counted the same way by every awk under every locale (see note 1).
function nchars(s,   t) { t = s; return length(t) - gsub(CONT, "", t) }

# is_delim — the characters that can precede an unquoted "#" and still leave it starting a comment.
function is_delim(c) { return (c == " " || c == "\t" || c == ";" || c == "&" || c == "|") }

# push_heredoc — s[i] begins "<<" or "<<-": read the delimiter word (quoted or not) and queue it,
# returning the position just after it so the rest of the line keeps scanning. The delimiter's own
# quotes must never toggle quote state, which is why it is consumed here rather than by scan().
function push_heredoc(s, i,   j, n, c, q, d, dash) {
  n = length(s); j = i + 2; dash = 0
  if (substr(s, j, 1) == "-") { dash = 1; j++ }
  while (j <= n && (substr(s, j, 1) == " " || substr(s, j, 1) == "\t")) j++
  d = ""
  while (j <= n) {
    c = substr(s, j, 1)
    if (c == "'" || c == "\"") {
      q = c; j++
      while (j <= n && substr(s, j, 1) != q) { d = d substr(s, j, 1); j++ }
      j++
      continue
    }
    if (c == " " || c == "\t" || c == ";" || c == "&" || c == "|" || c == ")" || c == "<" || c == ">") break
    if (c == "\\") { j++; continue }
    d = d c; j++
  }
  if (d == "") return j
  hqn++; hq[hqn] = d; hqdash[hqn] = dash
  return j
}

# scan — return the line's CODE text with comments and quoted data removed, carrying quote state
# across lines (a shell string may span lines, and this repository has several that do).
# COMMAND SUBSTITUTION OPENS A FRESH QUOTING CONTEXT, which is why there is a stack rather than a
# single state: inside "$(...)" the quotes start over, so a flat scanner reads the apostrophe in a
# word like "don't" — legal inside the substitution's own double quotes — as opening a string, and
# then silently swallows every line until the next apostrophe, guards and braces included.
function scan(s,   i, n, c, out) {
  out = ""; i = 1; n = length(s)
  while (i <= n) {
    c = substr(s, i, 1)
    if (qs == "S") { if (c == "'") qs = ""; i++; continue }
    if (qs == "D") {
      if (c == "\\") { i += 2; continue }
      if (c == "\"") { qs = ""; i++; continue }
      if (substr(s, i, 2) == "$(") { sn++; sq[sn] = "D"; sp[sn] = pd; qs = ""; pd = 0; i += 2; continue }
      i++; continue
    }
    if (c == "\\") { i += 2; continue }
    if (c == "'") { qs = "S"; i++; continue }
    if (c == "\"") { qs = "D"; i++; continue }
    if (c == "#" && (i == 1 || is_delim(substr(s, i - 1, 1)))) break
    if (substr(s, i, 2) == "$(") { sn++; sq[sn] = ""; sp[sn] = pd; qs = ""; pd = 0; out = out " "; i += 2; continue }
    if (c == "(") { pd++; out = out " "; i++; continue }
    if (c == ")") {
      if (pd > 0) pd--
      else if (sn > 0) { qs = sq[sn]; pd = sp[sn]; sn-- }
      out = out " "; i++; continue
    }
    # "<<<" is a here-STRING and queues nothing; only "<<" and "<<-" open a heredoc.
    if (c == "<") {
      if (substr(s, i, 3) == "<<<") { i += 3; continue }
      if (substr(s, i, 2) == "<<") { i = push_heredoc(s, i); continue }
    }
    out = out c
    i++
  }
  return out
}

function reset_file() {
  qs = ""; sn = 0; pd = 0; hqn = 0; hd = 0; depth = 0; maxdepth = 0; maxdline = 0
  loc = 0; inloc = 0; longl = 0; longf = 0; maxfl = 0
  infunc = 0; fbase = 0; fname = ""; fstart = 0
}

function flush() {
  if (fn == "") return
  print fn "\tlonglines\t" longl
  print fn "\tlongfirst\t" longf
  print fn "\toutside\t" (loc - inloc)
  print fn "\tdepth\t" maxdepth
  print fn "\tdepthline\t" maxdline
  print fn "\tfunclen\t" maxfl
  print fn "\tbalance\t" depth
  if (infunc) print fn "\terror\tfunction " fname " opened at line " fstart " never closes"
  if (hd) print fn "\terror\theredoc " hq[1] " never terminates"
  if (qs != "") print fn "\terror\ta quoted string is still open at end of file"
  if (sn != 0) print fn "\terror\ta command substitution is still open at end of file"
}

BEGIN {
  # LIMIT is passed in by shape-check.sh so the number has ONE home (see that script's table).
  if (LIMIT == 0) LIMIT = 100
  CONT = "[" sprintf("%c", 128) "-" sprintf("%c", 191) "]"
  # The probe: "a", an em dash, "b" — three characters, five bytes. If this awk cannot tell those
  # apart, every line-length number it would print is wrong, so say so and let the caller stop.
  if (nchars("a" sprintf("%c%c%c", 226, 128, 148) "b") != 3)
    print "-\tfatal\tthis awk cannot count UTF-8 characters; line-length numbers would be wrong"
}

FNR == 1 { flush(); fn = FILENAME; reset_file() }

{
  raw = $0
  if (nchars(raw) > LIMIT) { longl++; if (longf == 0) longf = FNR }
  trimmed = raw
  sub(/^[ \t]*/, "", trimmed)
  sub(/[ \t]*$/, "", trimmed)

  # --- heredoc body: data, not code. Consumed here so nothing inside it is read as shell.
  if (hd) {
    term = raw
    if (hqdash[1]) sub(/^\t*/, "", term)
    if (term == hq[1]) {
      for (k = 1; k < hqn; k++) { hq[k] = hq[k + 1]; hqdash[k] = hqdash[k + 1] }
      hqn--
      if (hqn == 0) hd = 0
    }
    next
  }

  # clean_start: this line begins in code state, so "#" here really is a comment and a definition
  # here really is a definition (rather than text inside a string that began on an earlier line).
  clean_start = (qs == "" && sn == 0)

  isdef = 0
  if (clean_start && raw ~ /^[A-Za-z_][A-Za-z0-9_-]*[ \t]*\(\)[ \t]*\{/) {
    isdef = 1; dname = raw; sub(/[ \t]*\(\).*/, "", dname)
  } else if (clean_start && raw ~ /^[A-Za-z_][A-Za-z0-9_-]*[ \t]*\(\)/) {
    # A definition whose brace is on the NEXT line: the census would silently lose it, so red.
    print fn "\terror\tline " FNR " defines a function without an opening brace on the same line"
  }

  isloc = 1
  if (trimmed == "") isloc = 0
  else if (clean_start && substr(trimmed, 1, 1) == "#") isloc = 0
  if (isloc) loc++

  code = scan(raw)

  if (isdef) {
    if (infunc) print fn "\terror\tline " FNR " defines a function inside another function"
    infunc = 1; fbase = depth; fname = dname; fstart = FNR
  }
  if (isloc && infunc) inloc++

  # Parameter expansions are blanked BEFORE tokenising: "${x#*<tab>}" ends in a "}" that would
  # otherwise be read as a brace group closing, and this repository splits fields on tabs like that.
  while (match(code, /\$\{[^{}]*\}/)) code = substr(code, 1, RSTART - 1) " " substr(code, RSTART + RLENGTH)
  gsub(/[;&|<>]/, " ", code)
  ntok = split(code, T, /[ \t]+/)
  for (k = 1; k <= ntok; k++) {
    t = T[k]
    if (t == "if" || t == "for" || t == "while" || t == "until" || t == "select" || t == "case" || t == "{") {
      depth++
      if (depth > maxdepth) { maxdepth = depth; maxdline = FNR }
    } else if (t == "fi" || t == "done" || t == "esac" || t == "}") {
      depth--
      if (depth < 0) { print fn "\terror\tline " FNR " closes a block that was never opened"; depth = 0 }
      if (infunc && depth == fbase) {
        infunc = 0
        flen = FNR - fstart + 1
        if (flen > maxfl) maxfl = flen
        print fn "\tcensus\t" fname "\t" fstart "\t" FNR "\t" flen "\t" (fstart == FNR ? 1 : 0)
      }
    }
  }
  if (hqn > 0) hd = 1
}

END { flush() }
