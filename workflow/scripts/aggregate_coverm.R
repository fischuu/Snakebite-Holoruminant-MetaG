#!/usr/bin/env Rscript
# Merge a folder of per-sample CoverM two-column TSVs (sequence_id, counts)
# into one wide table with one column per sample.

library(tidyverse)
library(argparse)

parser <- ArgumentParser()
parser$add_argument(
  "-i", "--input-folder",
  dest = "input_folder", help = "Folder containing the per-sample *.tsv files"
)
parser$add_argument(
  "-o", "--output-file",
  dest = "output_file", help = "Output wide TSV file"
)
args <- parser$parse_args()

dir.create(dirname(args$output_file), showWarnings = FALSE, recursive = TRUE)

tsv_files <- list.files(args$input_folder, pattern = "\\.tsv$", full.names = TRUE)
names(tsv_files) <- tools::file_path_sans_ext(basename(tsv_files))

read_one_sample <- function(path) {
  read_tsv(path, col_names = c("sequence_id", "counts"), col_types = cols(), skip = 1)
}

tsv_files %>%
  map(read_one_sample) %>%
  bind_rows(.id = "sample_id") %>%
  pivot_wider(names_from = sample_id, values_from = counts) %>%
  write_tsv(args$output_file)
