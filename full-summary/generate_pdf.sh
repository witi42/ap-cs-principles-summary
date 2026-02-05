#!/bin/bash
pdflatex -output-directory=. -interaction=nonstopmode ap_csp_summary.tex && pdflatex -output-directory=. -interaction=nonstopmode ap_csp_summary.tex
