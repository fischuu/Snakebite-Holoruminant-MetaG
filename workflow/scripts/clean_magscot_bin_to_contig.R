#!/usr/bin/env Rscript
# Convert MAGScoT's refined contig-to-bin table (columns: binnew, contig, ...)
# into the pipeline's own "{assembly_id}:bin_{bin_id}@{contig_id}" scheme.

library(tidyverse)
library(argparse)

parser <- ArgumentParser()
parser$add_argument(
  "-i", "--input-file",
  dest = "input_file", help = "Refined contig-to-bin file from MAGScoT"
)
parser$add_argument(
  "-o", "--output-file",
  dest = "output_file", help = "Cleaned-up contig-to-bin file"
)
args <- parser$parse_args()
print(args)

dir.create(dirname(args$output_file), showWarnings = FALSE, recursive = TRUE)

# MAGScoT prefixes its bin names with a variable-depth path, e.g.
# "some/path/magscot_cleanbin_3"; only the trailing "3" is the actual bin id.
last_path_segment <- function(x) map_chr(str_split(x, "/"), tail, n = 1)

read_tsv(args$input_file) %>%
  mutate(bin_id = str_remove(last_path_segment(binnew), "magscot_cleanbin_")) %>%
  separate(contig, into = c("assembly_bin", "contig_id"), sep = "@", remove = FALSE) %>%
  separate(assembly_bin, into = c("assembly_id", "orig_bin_id"), sep = ":", remove = TRUE) %>%
  mutate(seqname = str_glue("{assembly_id}:bin_{bin_id}@{contig_id}")) %>%
  select(-orig_bin_id) %>%
  write_tsv(args$output_file)
