#!/usr/bin/env Rscript
# One line per library with the summary of its Nonpareil curve. Libraries on which Nonpareil did not
# converge have an empty .npo file and are left out.
#
# Usage: nonpareil_summary.R <folder with the *.npo files> <output.tsv>

suppressPackageStartupMessages({
  library(tidyverse)
  library(Nonpareil)
})

arguments <- commandArgs(trailingOnly = TRUE)
curves <- list.files(arguments[1], pattern = "\\.npo$", full.names = TRUE)
curves <- curves[file.size(curves) > 0]

# If the coverage of a library is too low for a model, the summary of the set is a matrix of lists with
# empty cells, and as.data.frame() would lose all values, also those of the other libraries. So take the
# cells one by one. An empty cell becomes NA.
cells <- summary(Nonpareil.set(curves, plot = FALSE))
values <- matrix(
  sapply(cells, function(cell) if (length(cell) == 1) as.numeric(cell) else NA_real_),
  nrow = nrow(cells),
  dimnames = dimnames(cells)
)

summary_table <- as.data.frame(values)
write_tsv(rownames_to_column(summary_table, "sample_id"), arguments[2])
