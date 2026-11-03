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

summary_table <- as.data.frame(summary(Nonpareil.set(curves, plot = FALSE)))
write_tsv(rownames_to_column(summary_table, "sample_id"), arguments[2])
