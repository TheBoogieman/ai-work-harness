#!/usr/bin/env python3
"""append_notebook_cell.py — deterministic notebook writer for check-scribe.
Agents must NEVER hand-edit .ipynb JSON; they call this instead.
Usage: append_notebook_cell.py <notebook.ipynb> "<why-note markdown>" "<code>"
"""
import sys, nbformat
def main():
    # Exactly three args (notebook, why-note, code); anything else is a usage error, not a silent no-op.
    if len(sys.argv) != 4:
        print("FAIL: usage: append_notebook_cell.py <nb.ipynb> <note> <code>"); sys.exit(2)
    path, note, code = sys.argv[1:4]
    # Read the existing notebook and APPEND — this helper is the only writer, so each check adds to
    # the running audit trail instead of replacing it (agents never hand-edit the .ipynb JSON).
    nb = nbformat.read(path, as_version=4)
    nb.cells.append(nbformat.v4.new_markdown_cell(note))   # the why-note (markdown) precedes its code
    nb.cells.append(nbformat.v4.new_code_cell(code))       # the check itself (any language the kernel runs)
    # Validate BEFORE writing so a malformed cell never reaches disk and corrupts the notebook.
    nbformat.validate(nb)
    nbformat.write(nb, path)
    print(f"OK: appended note+code cells to {path} ({len(nb.cells)} cells total).")
if __name__ == "__main__":
    main()
