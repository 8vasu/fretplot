#!/bin/sh
## build.sh
## Copyright 2025-- Soumendra Ganguly
#
# This work may be distributed and/or modified under the
# conditions of the LaTeX Project Public License, either version 1.3
# of this license or (at your option) any later version.
# The latest version of this license is in
#   https://www.latex-project.org/lppl.txt
# and version 1.3c or later is part of all distributions of LaTeX
# version 2008 or later.
#
# This work has the LPPL maintenance status `author-maintained'.
# 
# The Current Maintainer of this work is Soumendra Ganguly.
#
# This work consists of the files fretplot.sty, fretplot.lua,
# doc_fretplot.tex, doc_fretplot.pdf, README.md, LICENSE,
# build.sh, cover.tex, and cover.svg.

# Generate documentation.
lualatex doc_fretplot.tex

# Generate the cover image.
lualatex cover.tex
pdf2svg cover.pdf cover.svg

# Prepare zip for CTAN.
mkdir fretplot
cp fretplot.lua fretplot.sty doc_fretplot.tex doc_fretplot.pdf README.md LICENSE fretplot/
zip -r fretplot.zip fretplot
