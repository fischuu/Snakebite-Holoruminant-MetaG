#!/usr/bin/env Rscript
# Join the CoverM tables of all libraries (one method) into one table: a row per sequence,
# a column per library, named after the input file.
#
# Usage: coverm_wide_table.R <folder with one <library>.tsv per library> <output.tsv>

suppressPackageStartupMessages(library(tidyverse))

arguments <- commandArgs(trailingOnly = TRUE)
library_tables <- list.files(arguments[1], pattern = "\\.tsv$", full.names = TRUE)

read_library <- function(path) {
  library_name <- tools::file_path_sans_ext(basename(path))
  read_tsv(path, skip = 1, col_names = c("sequence_id", library_name), col_types = cols())
}

library_tables %>%
  map(read_library) %>%
  reduce(full_join, by = "sequence_id") %>%
  write_tsv(arguments[2])
