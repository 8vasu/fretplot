#!/bin/sh
## build.sh
## fretplot v0.0.3
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
for name in macro-demo amaj fretless custom-instrument
do
    cat include/start.tex include/${name}/body.tex include/end.tex > include/${name}/full.tex
done
latexmk -lualatex="lualatex --shell-escape" doc_fretplot.tex

# Generate the cover image.
latexmk -lualatex="lualatex --shell-escape" cover.tex
pdf2svg cover.pdf cover.svg

# Prepare zip for CTAN.
mkdir -p fretplot
cp fretplot.lua fretplot.sty doc_fretplot.tex doc_fretplot.pdf README.md LICENSE fretplot/
rm -f fretplot.zip
zip -r fretplot.zip fretplot
