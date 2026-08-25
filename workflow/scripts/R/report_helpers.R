# Shared helpers for the per-module PDF reports (workflow/scripts/R/*.Rmd).
# Sourced from every module report; keeps benchmark-aggregation and common
# file parsers in one place instead of duplicated across eight Rmd files.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(readr)
  library(ggplot2)
  library(knitr)
  library(kableExtra)
})

# ---- Runtime / resource statistics (from Snakemake `benchmark:` files) ----

#' Recursively find every benchmark TSV under one module's results folder and
#' combine them into one data frame, with a "rule" column derived from the
#' file's position in the folder tree.
discover_benchmarks <- function(project_folder, module) {
  root <- file.path(project_folder, "results", module)
  if (!dir.exists(root)) {
    return(empty_benchmark_table())
  }

  paths <- list.files(
    root,
    pattern = "\\.tsv$",
    recursive = TRUE,
    full.names = TRUE
  )
  paths <- paths[grepl("benchmark", paths, ignore.case = TRUE)]

  if (length(paths) == 0) {
    return(empty_benchmark_table())
  }

  rows <- map(paths, function(p) {
    df <- tryCatch(read_tsv(p, show_col_types = FALSE), error = function(e) NULL)
    if (is.null(df) || nrow(df) == 0) {
      return(NULL)
    }
    df$rule <- benchmark_label(root, p)
    df
  })
  rows <- compact(rows)
  if (length(rows) == 0) {
    return(empty_benchmark_table())
  }
  bind_rows(rows)
}

empty_benchmark_table <- function() {
  tibble(
    s = numeric(0), `h:m:s` = character(0), max_rss = numeric(0),
    max_vms = numeric(0), max_uss = numeric(0), max_pss = numeric(0),
    io_in = numeric(0), io_out = numeric(0), mean_load = numeric(0),
    cpu_time = numeric(0), rule = character(0)
  )
}

#' Derive a readable rule label from a benchmark file's path relative to the
#' module's results root. Two naming conventions are used across the
#' pipeline's rules, and both need to collapse to a sensible label:
#'   - "<tool>/benchmark/<wildcard>.tsv"        -> group by <tool>
#'     (e.g. results/assemble/megahit/benchmark/assembly1.tsv -> "megahit")
#'   - "<tool>/<wildcard>/benchmark_<step>.tsv" -> distinguish sub-steps
#'     (e.g. results/assemble/magscot/assembly1/benchmark_prodigal.tsv
#'      -> "magscot: prodigal", keeping magscot's 8 sub-rules separate)
benchmark_label <- function(root, path) {
  rel <- sub(paste0("^", root, "/?"), "", path)
  parts <- strsplit(rel, "/", fixed = TRUE)[[1]]
  if (tolower(parts[1]) == "benchmark") {
    # No intermediate tool subfolder at all (e.g. results/reads/benchmark/*.tsv)
    # -- fall back to the module's own name as the label.
    return(basename(root))
  }
  tool <- parts[1]
  if (length(parts) <= 1) {
    return(tool)
  }
  parent <- parts[length(parts) - 1]
  if (tolower(parent) == "benchmark") {
    return(tool)
  }
  base <- sub("\\.tsv$", "", parts[length(parts)])
  base <- sub("^benchmark_?", "", base)
  if (nchar(base) == 0 || base == tool) tool else paste0(tool, ": ", base)
}

#' One row per rule: number of jobs, total/mean/max runtime, peak memory.
summarise_runtime <- function(bench_df) {
  if (nrow(bench_df) == 0) {
    return(tibble(
      rule = character(0), n_jobs = integer(0), total_runtime = character(0),
      mean_runtime = character(0), max_runtime = character(0), peak_mem_gb = numeric(0)
    ))
  }
  bench_df %>%
    group_by(rule) %>%
    summarise(
      n_jobs = n(),
      total_s = sum(s, na.rm = TRUE),
      mean_s = mean(s, na.rm = TRUE),
      max_s = max(s, na.rm = TRUE),
      peak_mem_gb = round(max(max_rss, na.rm = TRUE) / 1024, 2),
      .groups = "drop"
    ) %>%
    mutate(
      total_runtime = format_hms(total_s),
      mean_runtime = format_hms(mean_s),
      max_runtime = format_hms(max_s)
    ) %>%
    select(rule, n_jobs, total_runtime, mean_runtime, max_runtime, peak_mem_gb) %>%
    arrange(desc(total_runtime))
}

format_hms <- function(seconds) {
  seconds[is.na(seconds)] <- 0
  h <- floor(seconds / 3600)
  m <- floor((seconds %% 3600) / 60)
  s <- round(seconds %% 60)
  sprintf("%02d:%02d:%02d", h, m, s)
}

#' kableExtra escapes table *cell* content for LaTeX automatically, but not
#' the `caption=` string itself -- a literal "_" there (e.g. a module or file
#' name like "read_annotate") crashes LaTeX with "Missing $ inserted". Every
#' caption in this file is routed through here rather than escaped by hand.
escape_latex <- function(text) {
  gsub("([_%&#{}])", "\\\\\\1", text)
}

#' Nicely formatted runtime/resource table for the report.
runtime_table <- function(bench_df, caption = "Runtime and peak memory per rule") {
  tbl <- summarise_runtime(bench_df)
  if (nrow(tbl) == 0) {
    return(cat("_No benchmark data recorded for this module yet._\n"))
  }
  colnames(tbl) <- c("Rule", "Jobs", "Total runtime", "Mean runtime", "Max runtime", "Peak RAM (GB)")
  kable(tbl, caption = escape_latex(caption), booktabs = TRUE) %>%
    kable_styling(latex_options = c("striped", "hold_position"), font_size = 9)
}

#' Horizontal bar chart of total runtime per rule, longest first.
runtime_plot <- function(bench_df, title = "Total runtime per rule") {
  tbl <- bench_df %>%
    group_by(rule) %>%
    summarise(total_s = sum(s, na.rm = TRUE), .groups = "drop")
  if (nrow(tbl) == 0) {
    return(invisible(NULL))
  }
  tbl <- tbl %>% mutate(rule = reorder(rule, total_s))
  ggplot(tbl, aes(x = rule, y = total_s / 3600)) +
    geom_col(fill = "#00B5E2") +
    coord_flip() +
    labs(title = title, x = NULL, y = "Total runtime (hours)") +
    theme_minimal(base_size = 11)
}

# ---- Allocated vs. actual resource usage (for calibrating escalation.yaml) ----

#' Load the pipeline's resource tiers (config.yaml's resource_sets) and the
#' per-rule escalation order (escalation.yaml). Both live at a fixed,
#' project-relative path regardless of which config files were passed to
#' this particular report (same convention the Snakefile itself uses for
#' escalation.yaml).
load_resource_config <- function(project_folder) {
  list(
    resource_sets = yaml::read_yaml(file.path(project_folder, "config", "config.yaml"))$resource_sets,
    escalation = yaml::read_yaml(file.path(project_folder, "config", "escalation.yaml"))
  )
}

#' Best-effort match from a `discover_benchmarks()` display label (e.g.
#' "megahit", "magscot: prodigal") back to its real escalation.yaml key
#' (e.g. "assemble__megahit__run", "assemble__magscot__prodigal"), so its
#' configured resource tier can be looked up. The label is a *display* name
#' derived from a benchmark file's path, not the literal rule name, so this
#' is approximate: every word in the label must appear in the candidate key.
#' Ambiguous or unmatched rules return NA and the caller falls back to the
#' pipeline's default 3-tier escalation, rather than guessing wrong.
match_escalation_key <- function(rule_label, module, escalation) {
  words <- tolower(strsplit(gsub("[:_]", " ", rule_label), "\\s+")[[1]])
  words <- words[nchar(words) > 0]
  candidates <- names(escalation)[startsWith(names(escalation), paste0(module, "__"))]
  if (length(candidates) == 0) {
    return(NA_character_)
  }
  hits <- vapply(candidates, function(k) all(vapply(words, grepl, logical(1), x = tolower(k), fixed = TRUE)), logical(1))
  matched <- candidates[hits]
  if (length(matched) == 1) matched else NA_character_
}

#' For each rule with benchmark data, compare its actual peak memory/runtime
#' against what its first-attempt resource tier allocates. This is the
#' escalation.yaml/config.yaml "small/medium/large" tier a rule starts on
#' before any retry-escalation -- a rule sitting near 100% utilization here
#' is a candidate for a bigger starting tier; one sitting well under is a
#' candidate for a smaller (cheaper, faster-scheduled) one.
resource_allocation_table <- function(bench_df, module, project_folder,
                                      caption = "Allocated vs. actual resource usage") {
  if (nrow(bench_df) == 0) {
    return(cat("_No benchmark data recorded for this module yet._\n"))
  }
  cfg <- load_resource_config(project_folder)
  default_tiers <- c("small", "medium", "large")

  actual <- bench_df %>%
    group_by(rule) %>%
    summarise(actual_mem_gb = max(max_rss, na.rm = TRUE) / 1024,
              actual_runtime_s = max(s, na.rm = TRUE), .groups = "drop")

  rows <- pmap_dfr(actual, function(rule, actual_mem_gb, actual_runtime_s) {
    key <- match_escalation_key(rule, module, cfg$escalation)
    tiers <- if (!is.na(key)) cfg$escalation[[key]] else default_tiers
    tier1 <- trimws(tiers[[1]])
    alloc <- cfg$resource_sets[[tier1]]
    if (is.null(alloc)) {
      return(NULL)
    }
    alloc_mem_gb <- alloc$mem_mb / 1024
    alloc_runtime_s <- alloc$runtime * 60
    mem_pct <- round(100 * actual_mem_gb / alloc_mem_gb, 1)
    runtime_pct <- round(100 * actual_runtime_s / alloc_runtime_s, 1)
    tibble(
      rule = rule,
      tier = tier1,
      allocated_mem_gb = round(alloc_mem_gb, 1),
      actual_mem_gb = round(actual_mem_gb, 1),
      mem_used_pct = mem_pct,
      allocated_runtime = format_hms(alloc_runtime_s),
      actual_runtime = format_hms(actual_runtime_s),
      runtime_used_pct = runtime_pct,
      flag = case_when(
        pmax(mem_pct, runtime_pct) >= 90 ~ "near limit -- consider a bigger starting tier",
        pmax(mem_pct, runtime_pct) <= 15 ~ "over-provisioned -- consider a smaller tier",
        TRUE ~ ""
      )
    )
  })

  if (is.null(rows) || nrow(rows) == 0) {
    return(cat("_Could not match any rule in this module to a configured resource tier._\n"))
  }

  colnames(rows) <- c("Rule", "Starting tier", "Allocated RAM (GB)", "Actual RAM (GB)", "RAM used (%)",
                       "Allocated runtime", "Actual runtime", "Runtime used (%)", "Note")
  kable(rows, caption = escape_latex(caption), booktabs = TRUE) %>%
    kable_styling(latex_options = c("striped", "hold_position", "scale_down"), font_size = 7)
}

# ---- Generic table helpers ----

#' Read a TSV if it exists, else return an empty (zero-row) tibble so
#' downstream code can render "no data yet" instead of erroring.
safe_read_tsv <- function(path, ...) {
  if (is.na(path) || !file.exists(path)) {
    return(tibble())
  }
  tryCatch(read_tsv(path, show_col_types = FALSE, ...), error = function(e) tibble())
}

#' Preview the first n rows of a (possibly large) table.
preview_table <- function(df, n = 10, caption = NULL) {
  if (nrow(df) == 0) {
    return(cat("_No data available yet._\n"))
  }
  if (!is.null(caption)) caption <- escape_latex(caption)
  kable(head(df, n), caption = caption, booktabs = TRUE) %>%
    kable_styling(latex_options = c("striped", "hold_position", "scale_down"), font_size = 8)
}

#' For tools without a custom parser: show a preview of the first
#' table-shaped output found under its results folder (tsv, tsv.gz, or a
#' delimited txt), so every tool gets at least minimal, automatic coverage.
generic_tool_section <- function(project_folder, module, tool_glob, title) {
  cat(paste0("\n### ", title, "\n\n"))
  files <- Sys.glob(file.path(project_folder, "results", module, tool_glob))
  files <- files[grepl("\\.(tsv|tsv\\.gz|txt)$", files)]
  if (length(files) == 0) {
    cat("_No output found yet._\n\n")
    return(invisible(NULL))
  }
  preview_table(safe_read_tsv(files[[1]]), caption = basename(files[[1]]))
}

# ---- Tool-specific parsers ----

#' FastQC's fastqc_data.txt lives inside each *_fastqc.zip; extract the
#' ">>Basic Statistics" block as a one-row data frame.
parse_fastqc_zip <- function(zip_path) {
  if (!file.exists(zip_path)) {
    return(tibble())
  }
  inner <- grep("fastqc_data.txt$", unzip(zip_path, list = TRUE)$Name, value = TRUE)
  if (length(inner) == 0) {
    return(tibble())
  }
  con <- unz(zip_path, inner[[1]])
  lines <- readLines(con, warn = FALSE)
  close(con)
  start <- grep("^>>Basic Statistics", lines)
  end <- grep("^>>END_MODULE", lines)
  end <- end[end > start][1]
  block <- lines[(start + 2):(end - 1)]
  kv <- strsplit(block, "\t")
  df <- as_tibble(setNames(
    as.list(map_chr(kv, 2)),
    map_chr(kv, 1)
  ))
  df$sample <- basename(zip_path)
  df
}

#' fastp's per-library JSON report: read counts, Q20/Q30 rate, adapter trimming.
parse_fastp_json <- function(json_path) {
  if (!file.exists(json_path)) {
    return(tibble())
  }
  j <- tryCatch(jsonlite::fromJSON(json_path), error = function(e) NULL)
  if (is.null(j)) {
    return(tibble())
  }
  tibble(
    reads_before = j$summary$before_filtering$total_reads,
    reads_after = j$summary$after_filtering$total_reads,
    pct_reads_passed = round(100 * j$summary$after_filtering$total_reads /
      j$summary$before_filtering$total_reads, 2),
    q30_rate_after = round(100 * j$summary$after_filtering$q30_rate, 2),
    duplication_pct = round(100 * (j$duplication$rate %||% NA), 2)
  )
}

`%||%` <- function(a, b) if (is.null(a)) b else a

#' Kraken2's tab-separated report format: pct, reads_clade, reads_direct,
#' rank_code, taxid, name. Returns the top-N taxa by clade percentage.
parse_kraken2_report <- function(report_path, top_n = 15) {
  df <- safe_read_tsv(report_path,
    col_names = c("pct", "reads_clade", "reads_direct", "rank", "taxid", "name")
  )
  if (nrow(df) == 0) {
    return(df)
  }
  df %>%
    mutate(name = trimws(name)) %>%
    arrange(desc(pct)) %>%
    head(top_n)
}

#' MetaPhlAn's merged abundance table: first column is a pipe-delimited
#' taxonomy string (k__|p__|...|s__), one column per sample thereafter.
#' Returns the top-N species by mean relative abundance across samples.
parse_metaphlan_top_taxa <- function(profile_path, top_n = 15) {
  df <- safe_read_tsv(profile_path, comment = "#")
  if (nrow(df) == 0) {
    return(tibble())
  }
  clade_col <- grep("clade_name|taxonomy|#", colnames(df), ignore.case = TRUE, value = TRUE)
  clade_col <- if (length(clade_col) > 0) clade_col[[1]] else colnames(df)[[1]]
  sample_cols <- setdiff(colnames(df), clade_col)
  if (length(sample_cols) == 0) {
    return(tibble())
  }
  df %>%
    filter(grepl("s__", .data[[!!clade_col]])) %>%
    mutate(species = sub(".*s__", "s__", .data[[!!clade_col]]),
           mean_abundance = rowMeans(across(all_of(sample_cols)), na.rm = TRUE)) %>%
    select(species, mean_abundance, all_of(sample_cols)) %>%
    arrange(desc(mean_abundance)) %>%
    head(top_n)
}

#' HUMAnN's merged gene-family/pathway table: first column is the
#' feature name, one column per sample thereafter. UNMAPPED/UNGROUPED are
#' bookkeeping rows, not real gene families, and are excluded from the
#' top-N ranking. Returns the top-N features by total abundance.
parse_humann_top_features <- function(table_path, top_n = 15) {
  df <- safe_read_tsv(table_path)
  if (nrow(df) == 0) {
    return(tibble())
  }
  feature_col <- colnames(df)[[1]]
  sample_cols <- setdiff(colnames(df), feature_col)
  if (length(sample_cols) == 0) {
    return(tibble())
  }
  df %>%
    rename(feature = 1) %>%
    filter(!feature %in% c("UNMAPPED", "UNGROUPED"), !grepl("\\|", feature)) %>%
    mutate(total_abundance = rowSums(across(all_of(sample_cols)), na.rm = TRUE)) %>%
    select(feature, total_abundance, all_of(sample_cols)) %>%
    arrange(desc(total_abundance)) %>%
    head(top_n)
}
