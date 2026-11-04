#!/usr/bin/env bash
# Build the PDF of the book and put it next to the sources as book/Snakebite-MetaG-book.pdf.
#
# Needs Quarto and a LaTeX installation with xelatex. On a Mac with RStudio, Quarto comes with RStudio.
set -euo pipefail

cd "$(dirname "$0")"

if command -v quarto > /dev/null; then
    quarto_bin=quarto
else
    quarto_bin=/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto
fi

python3 tools/rule_reference.py
python3 tools/references.py
"$quarto_bin" render --to pdf
cp _build/*.pdf Snakebite-MetaG-book.pdf
echo "Book written to book/Snakebite-MetaG-book.pdf"
