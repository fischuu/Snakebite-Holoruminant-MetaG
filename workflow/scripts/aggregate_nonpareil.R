#!/usr/bin/env Rscript
# Summarize a folder of per-sample Nonpareil .npo curves into one TSV,
# skipping any empty .npo files (samples where Nonpareil produced no output).

library(tidyverse)
library(argparse)
library(Nonpareil)

parser <- ArgumentParser()
parser$add_argument(
  "-i", "--input-folder",
  dest = "input_folder", help = "Folder containing the *.npo files"
)
parser$add_argument(
  "-o", "--output-file",
  dest = "output_file", help = "Output TSV file"
)
args <- parser$parse_args()

dir.create(dirname(args$output_file), showWarnings = FALSE, recursive = TRUE)

npo_files <- list.files(args$input_folder, pattern = "\\.npo$", full.names = TRUE)
npo_files <- npo_files[file.size(npo_files) > 0]

npo_files %>%
  Nonpareil.set(plot = FALSE) %>%
  summary() %>%
  as.data.frame() %>%
  rownames_to_column("sample_id") %>%
  as_tibble() %>%
  write_tsv(args$output_file)
