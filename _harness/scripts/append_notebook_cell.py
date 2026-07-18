#!/usr/bin/env python3
"""append_notebook_cell.py — deterministic notebook writer for check-scribe.
Agents must NEVER hand-edit .ipynb JSON; they call this instead.
Usage: append_notebook_cell.py <notebook.ipynb> "<why-note markdown>" "<code>"
"""
import sys, nbformat
def main():
    if len(sys.argv) != 4:
        print("FAIL: usage: append_notebook_cell.py <nb.ipynb> <note> <code>"); sys.exit(2)
    path, note, code = sys.argv[1:4]
    nb = nbformat.read(path, as_version=4)
    nb.cells.append(nbformat.v4.new_markdown_cell(note))
    nb.cells.append(nbformat.v4.new_code_cell(code))
    nbformat.validate(nb)
    nbformat.write(nb, path)
    print(f"OK: appended note+code cells to {path} ({len(nb.cells)} cells total).")
if __name__ == "__main__":
    main()
