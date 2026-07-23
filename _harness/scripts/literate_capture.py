#!/usr/bin/env python3
"""literate_capture.py — transport delimited SQL/python blocks into notebook cells.

WHAT THIS IS: a dumb TRANSPORT. It reads working files, finds comment-native
delimiter blocks, and appends each as a (markdown why-note + code) cell pair to a
notebook through the existing append_notebook_cell.py plumbing. It NEVER executes
a block and NEVER judges one — results enter the notebook by hand or by the
format's own result section, never from here.

THE DELIMITER GRAMMAR (all markers are host-language COMMENTS, so a captured file
stays natively executable in its own tool):
  - A DELIMITER line marks the start of a code block. It is a comment whose body
    is `%%`, optionally followed by a bracketed label:
        SQL:     -- %% [label]
        python:  # %% [label]        (Jupytext-style)
    The label may also be given bare (no brackets); it may be omitted entirely.
  - The MARKDOWN CELL for a block is the contiguous run of comment lines
    IMMEDIATELY ABOVE its delimiter (the "why" the author wrote next to the work).
    A blank line or a code line ends that run.
  - The CODE CELL is every line AFTER the delimiter, up to the next block's
    markdown run (or end-of-file for the last block).

RE-RUNNABLE BY DESIGN: every block is content-hashed (label + note + code) and the
hash is recorded in its markdown cell. On a re-run — over one file or a whole
folder — a block whose hash already sits in the target notebook is skipped, so
only genuinely new blocks land.

PROVENANCE: each markdown cell records the source path, block label, capture
timestamp, and content hash.

MALFORMED INPUT: a source file with content but no delimiter is a clean no-op —
one prescriptive line naming the fix, nothing written, no stack trace.

SOURCE FILES ARE NEVER MODIFIED: sources are opened read-only, always.

GENERIC ONLY: the parser knows two comment tokens (`#`, `--`) and `%%`. It carries
no SQL/python dialect awareness — dialect-specific sugar is fork-layer material and
does not belong in the shared product.

Usage: literate_capture.py <notebook.ipynb> <source-file-or-dir>...
"""
import sys, os, re, subprocess, hashlib
from datetime import datetime, timezone

import nbformat  # READ-ONLY here (for dedupe); the WRITER stays append_notebook_cell.py

# A delimiter line: a `#` or `--` comment whose body is `%%` plus an optional label.
DELIM_RE = re.compile(r'^\s*(?:#|--)\s*%%\s*(.*?)\s*$')
# Any comment line (used to gather the note run that precedes a delimiter).
COMMENT_RE = re.compile(r'^\s*(?:#|--)')
# Pull a recorded hash back out of an existing markdown cell, for dedupe.
HASH_RE = re.compile(r'hash:\s*`([0-9a-f]+)`')
# Source file kinds we capture (generic: SQL and python working files).
SOURCE_EXTS = ('.sql', '.py')


def strip_comment(line):
    # Turn a comment line into its plain prose: drop leading space, the comment
    # token, and one following space so "-- why" reads as "why" in the markdown.
    s = line.lstrip()
    if s.startswith('--'):
        s = s[2:]
    elif s.startswith('#'):
        s = s[1:]
    if s.startswith(' '):
        s = s[1:]
    return s


def label_of(raw):
    # A bracketed label wins ([foo] -> foo); otherwise take the bare text as-is.
    m = re.match(r'^\[(.*)\]$', raw)
    return (m.group(1) if m else raw).strip()


def parse_file(path):
    """Return this file's blocks as (label, note, code) tuples.
    Returns [] when the file has no delimiter (the caller treats that as the
    prescriptive malformed no-op), or None when the file can't be read as text.
    """
    try:
        with open(path, 'r', encoding='utf-8') as fh:
            text = fh.read()
    except (OSError, UnicodeDecodeError):
        # Never a stack trace: name the file and move on. Sources are read-only.
        print(f"literate_capture: cannot read '{path}' as UTF-8 text — skipping "
              f"(only text SQL/python sources are captured).")
        return None

    lines = text.split('\n')
    delims = [i for i, l in enumerate(lines) if DELIM_RE.match(l)]
    if not delims:
        return []

    def note_start(d):
        # Walk up from just above a delimiter over its contiguous comment run;
        # return the index of the run's first line (or d itself if there is none).
        j = d - 1
        while j >= 0 and COMMENT_RE.match(lines[j]) and not DELIM_RE.match(lines[j]):
            j -= 1
        return j + 1

    blocks = []
    for k, d in enumerate(delims):
        label = label_of(DELIM_RE.match(lines[d]).group(1))
        # The note is the comment run directly above this delimiter.
        note = '\n'.join(strip_comment(lines[i]) for i in range(note_start(d), d)).strip()
        # The code runs until the NEXT block's note begins (or EOF for the last).
        end = note_start(delims[k + 1]) if k + 1 < len(delims) else len(lines)
        code = '\n'.join(lines[d + 1:end]).strip()
        blocks.append((label, note, code))
    return blocks


def block_hash(label, note, code):
    # Content identity for dedupe: label + note + code, NUL-separated so the parts
    # can't run together. The timestamp and source path are provenance, NOT hashed,
    # so the same block re-captured (even from another path) dedupes correctly.
    h = hashlib.sha256()
    for part in (label, note, code):
        h.update(part.encode('utf-8'))
        h.update(b'\0')
    return h.hexdigest()[:12]


def provenance_markdown(source, label, note, digest):
    # The markdown cell: the author's why-note, then a provenance block carrying the
    # source path, label, capture time, and the dedupe hash.
    ts = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    prov = (f"- source: `{source}`\n"
            f"- label: `{label}`\n"
            f"- captured: `{ts}`\n"
            f"- hash: `{digest}`")
    return f"{note}\n\n{prov}" if note else prov


def existing_hashes(nb_path):
    # Collect the hashes already recorded in the notebook's markdown cells, so a
    # re-run only appends blocks that aren't present yet. Read-only.
    nb = nbformat.read(nb_path, as_version=4)
    found = set()
    for cell in nb.cells:
        if cell.cell_type == 'markdown':
            found.update(HASH_RE.findall(cell.source))
    return found


def append_pair(nb_path, note_md, code):
    # Delegate the actual notebook write to the one deterministic writer — never
    # hand-edit .ipynb JSON. Invoke it with THIS interpreter so the same python
    # (and its nbformat) is used.
    helper = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'append_notebook_cell.py')
    r = subprocess.run([sys.executable, helper, nb_path, note_md, code],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(f"literate_capture: append helper failed for the notebook — {r.stdout}{r.stderr}".rstrip())
        sys.exit(1)


def collect_sources(paths):
    # Expand each argument: a directory contributes its .sql/.py files (sorted for
    # a deterministic capture order); a file is taken as-is; a missing path is named.
    files = []
    for p in paths:
        if os.path.isdir(p):
            for root, _dirs, names in sorted(os.walk(p)):
                for n in sorted(names):
                    if n.endswith(SOURCE_EXTS):
                        files.append(os.path.join(root, n))
        elif os.path.isfile(p):
            files.append(p)
        else:
            print(f"literate_capture: source '{p}' not found — nothing captured for it.")
    return files


def main():
    args = sys.argv[1:]
    if len(args) < 2:
        print("literate_capture: usage: literate_capture.py <notebook.ipynb> <source-file-or-dir>...")
        sys.exit(2)
    nb_path, sources = args[0], args[1:]
    if not os.path.isfile(nb_path):
        # This script only APPENDS; the notebook must already exist.
        print(f"literate_capture: notebook '{nb_path}' not found — create it first "
              f"(an empty .ipynb) or point at an existing one; this script only appends.")
        sys.exit(2)

    seen = existing_hashes(nb_path)   # dedupe set: hashes already in the notebook
    appended = 0
    for f in collect_sources(sources):
        blocks = parse_file(f)
        if blocks is None:
            continue                  # unreadable — already reported, nothing written
        if not blocks:
            # Content but no delimiter: the prescriptive malformed no-op.
            print(f"literate_capture: no delimiter in '{f}' — add a '-- %% [label]' "
                  f"(SQL) or '# %% [label]' (python) line above the block to capture it; "
                  f"nothing written.")
            continue
        for label, note, code in blocks:
            digest = block_hash(label, note, code)
            if digest in seen:
                continue              # already captured on an earlier run — skip
            seen.add(digest)          # also dedupe identical blocks within THIS run
            append_pair(nb_path, provenance_markdown(f, label, note, digest), code)
            appended += 1

    print(f"literate_capture: appended {appended} new block(s) to {nb_path}.")


if __name__ == '__main__':
    main()
