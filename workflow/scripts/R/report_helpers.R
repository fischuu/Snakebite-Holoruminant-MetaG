# Shared code of the module reports (workflow/scripts/R/<module>.Rmd).
#
# render_report.R defines project_folder, pipeline_folder, features_file, sample_file, rule_table and
# pipeline_version, renders the Rmd, and this file is sourced from its first chunk. All chunks run
# with results="asis", so the functions below write Markdown and LaTeX directly. Everything a report
# shows also goes to Rreports/<module>/tables and Rreports/<module>/figures for reuse in a paper.
#
# A tool's output can be missing (the tool wasn't part of the run) or have an unexpected format, and
# a report must not fail at the very end of a long run because of that. So each part of a report runs
# in section(), which turns an error into a sentence in the report and a line in the log, and a setup
# chunk reads the output of each tool through load_tool(), which does the same.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(readr)
  library(ggplot2)
  library(knitr)
})

ctx <- new.env()
ctx$unreadable <- list()

# Colourblind-safe colours (Okabe & Ito)
PALETTE <- c("#0072B2", "#E69F00", "#009E73", "#CC79A7", "#56B4E9", "#D55E00", "#F0E442", "#999999")

theme_report <- function() {
  theme_bw(base_size = 9) +
    theme(
      panel.grid.minor = element_blank(),
      legend.position = "bottom",
      legend.key.size = unit(0.35, "cm"),
      strip.background = element_rect(fill = "grey92", colour = NA)
    )
}

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

p <- function(...) file.path(project_folder, ...)

rel <- function(x) {
  prefix <- paste0(sub("/$", "", project_folder), "/")
  ifelse(startsWith(x, prefix), substring(x, nchar(prefix) + 1), x)
}

# ---- Start and end of a report --------------------------------------------------------------------

report_start <- function(module) {
  ctx$module <- module
  ctx$out <- p("Rreports", module)
  ctx$tables <- file.path(ctx$out, "tables")
  ctx$figures <- file.path(ctx$out, "figures")
  dir.create(ctx$tables, recursive = TRUE, showWarnings = FALSE)
  dir.create(ctx$figures, recursive = TRUE, showWarnings = FALSE)
  ctx$errors <- character(0)

  ctx$samples <- read.delim(p(sample_file), comment.char = "#", stringsAsFactors = FALSE)
  ctx$samples$library <- paste(ctx$samples$sample_id, ctx$samples$library_id, sep = ".")
  ctx$features <- yaml::read_yaml(p(features_file))
  ctx$config <- read_yaml_if_there(p("config", "config.yaml"))
  ctx$params <- read_yaml_if_there(p(ctx$config[["params-file"]] %||% "config/params.yaml"))
  ctx$docker <- read_yaml_if_there(p(ctx$config[["docker-file"]] %||% "config/.docker.yml"))
  ctx$assemblies <- unique(trimws(unlist(strsplit(ctx$samples$assembly_ids, ","))))
  invisible(NULL)
}

report_end <- function(folder_notes = character(0)) {
  section("How much data this module wrote, and where", data_section(folder_notes))
  section("Resources: requested, used, and what to change", resource_section())
  section("Tools, versions and references", tools_section())
  section("About this report", about_section())
  write_lines(ctx$errors, file.path(ctx$out, "section_errors.txt"))
}

read_yaml_if_there <- function(path) {
  if (file.exists(path)) yaml::read_yaml(path) else list()
}

libraries <- function() ctx$samples$library

assembly_members <- function() {
  ctx$samples %>%
    transmute(library, assembly_id = strsplit(assembly_ids, ",")) %>%
    unnest(assembly_id) %>%
    mutate(assembly_id = trimws(assembly_id))
}

assembly_fasta <- function(assembly_id) {
  assembler <- ctx$config$assembler %||% "metaspades"
  found <- p("results", "assemble", assembler, paste0(assembly_id, ".fa.gz"))
  if (file.exists(found)) return(found)
  # The configured assembler may have been changed after the run
  others <- Sys.glob(p("results", "assemble", "*", paste0(assembly_id, ".fa.gz")))
  others <- others[!grepl("/magscot/", others)]
  if (length(others) > 0) others[[1]] else found
}

# ---- Writing text ---------------------------------------------------------------------------------

# pdflatex stops at characters it has no glyph for, and a taxon or file name can contain anything
safe_text <- function(x) gsub("[^\\x01-\\x7F\\x{A0}-\\x{FF}]", "?", enc2utf8(as.character(x)), perl = TRUE)

para <- function(...) cat("\n\n", safe_text(paste0(...)), "\n\n", sep = "")

bullets <- function(items) {
  if (length(items) > 0) cat("\n\n", safe_text(paste0("- ", items, collapse = "\n")), "\n\n", sep = "")
}

heading <- function(text, level = 1) cat("\n\n", strrep("#", level), " ", text, "\n\n", sep = "")

section <- function(title, expr, level = 1) {
  heading(title, level)
  tryCatch(
    expr,
    error = function(e) {
      text <- gsub("[`\n]", " ", conditionMessage(e))
      para("**This section could not be produced.** The error was: `", text, "`")
      ctx$errors <- c(ctx$errors, paste0(title, ": ", text))
      message("ERROR in section '", title, "': ", text)
    }
  )
  invisible(NULL)
}

# Reads the output of one tool in a setup chunk, which runs outside section(). A file in an unexpected
# format then costs only the section of this tool, which says so through no_output(), and not the report.
load_tool <- function(tool, expr, otherwise = tibble()) {
  tryCatch(
    expr,
    error = function(e) {
      text <- gsub("[`\n]", " ", conditionMessage(e))
      ctx$unreadable[[tool]] <- text
      ctx$errors <- c(ctx$errors, paste0(tool, ": ", text))
      message("ERROR reading the output of '", tool, "': ", text)
      otherwise
    }
  )
}

no_output <- function(tool, where) {
  problem <- ctx$unreadable[[tool]]
  if (!is.null(problem)) {
    para("**The output of ", tool, " in `", where, "` could not be read.** The error was: `", problem, "`")
    return(invisible(NULL))
  }
  para("No output of ", tool, " was found in `", where, "`. The tool was either not part of this run, or it has ",
       "not finished.")
}

fmt_int <- function(x) {
  ifelse(is.na(x), "-", formatC(round(x), format = "f", digits = 0, big.mark = ","))
}

fmt_num <- function(x, digits = 1) {
  ifelse(is.na(x), "-", formatC(x, format = "f", digits = digits, big.mark = ","))
}

fmt_pct <- function(x, digits = 1) {
  ifelse(is.na(x), "-", paste0(formatC(x, format = "f", digits = digits), "%"))
}

plural <- function(n, word, words = paste0(word, "s")) {
  paste0(fmt_int(n), " ", ifelse(n == 1, word, words))
}

fmt_bytes <- function(x) {
  units <- c("B", "KiB", "MiB", "GiB", "TiB", "PiB")
  map_chr(x, function(v) {
    if (is.na(v)) return("-")
    i <- if (v <= 0) 1 else min(floor(log(v, 1024)) + 1, length(units))
    if (i == 1) return(paste0(round(v), " B"))
    sprintf("%.1f %s", v / 1024^(i - 1), units[[i]])
  })
}

fmt_bp <- function(x) {
  map_chr(x, function(v) {
    if (is.na(v)) return("-")
    if (v >= 1e9) return(sprintf("%.2f Gb", v / 1e9))
    if (v >= 1e6) return(sprintf("%.2f Mb", v / 1e6))
    if (v >= 1e3) return(sprintf("%.1f kb", v / 1e3))
    paste0(round(v), " bp")
  })
}

fmt_duration <- function(seconds) {
  map_chr(seconds, function(s) {
    if (is.na(s)) return("-")
    s <- round(s)
    sprintf("%d:%02d:%02d", s %/% 3600, (s %% 3600) %/% 60, s %% 60)
  })
}

latex_escape <- function(text) {
  text <- gsub("\\", "\\textbackslash{}", text, fixed = TRUE)
  text <- gsub("([&%$#_{}])", "\\\\\\1", text)
  text <- gsub("~", "\\textasciitilde{}", text, fixed = TRUE)
  gsub("^", "\\textasciicircum{}", text, fixed = TRUE)
}

# ---- Tables and figures ---------------------------------------------------------------------------

guess_align <- function(df) {
  paste(map_chr(df, function(col) {
    text <- as.character(col)
    text <- text[!is.na(text) & text != "" & text != "-"]
    numeric_like <- is.numeric(col) || (length(text) > 0 && all(grepl("^[<>]?-?[0-9][0-9,.]*( ?(%|B|KiB|MiB|GiB|TiB|bp|kb|Mb|Gb))?$", text)))
    if (numeric_like) "r" else "l"
  }), collapse = "")
}

# Show a table, and write `export` (by default the same table) to tables/<name>.tsv. Pass the raw
# numbers as `export` and rounded text as `df` where that makes the table easier to read.
show_table <- function(df, caption, name, export = df, max_rows = 30, note = NULL, max_chars = 70) {
  write_tsv(as_tibble(export), file.path(ctx$tables, paste0(name, ".tsv")), na = "")
  total <- nrow(df)
  shown <- as.data.frame(head(df, max_rows), check.names = FALSE, stringsAsFactors = FALSE)
  shown[] <- lapply(shown, function(col) {
    if (!is.character(col)) return(col)
    col <- safe_text(col)
    ifelse(!is.na(col) & nchar(col) > max_chars, paste0(substr(col, 1, max_chars - 3), "..."), col)
  })
  names(shown) <- safe_text(names(shown))
  width <- sum(map2_dbl(shown, names(shown), function(col, title) {
    max(nchar(title), nchar(as.character(col)), na.rm = TRUE)
  })) + 2 * ncol(shown)

  label <- latex_escape(safe_text(caption))
  align <- guess_align(shown)
  long <- nrow(shown) > 25 && width <= 115
  if (long) {
    body <- kable(shown, format = "latex", booktabs = TRUE, longtable = TRUE, escape = TRUE, linesep = "",
                  row.names = FALSE, align = strsplit(align, "")[[1]], caption = label)
    cat("\n\n\\begin{footnotesize}\n", body, "\n\\end{footnotesize}\n\n", sep = "")
  } else {
    body <- kable(shown, format = "latex", booktabs = TRUE, escape = TRUE, linesep = "", row.names = FALSE,
                  align = strsplit(align, "")[[1]])
    if (width > 105) body <- paste0("\\resizebox{\\linewidth}{!}{%\n", body, "\n}")
    cat("\n\n\\begin{center}\n\\begin{minipage}{\\linewidth}\n\\centering\n\\captionof{table}{", label,
        "}\n\\vspace{2pt}\n\\footnotesize\n", body, "\n\\end{minipage}\n\\end{center}\n\n", sep = "")
  }
  more <- if (total > max_rows) {
    paste0("The table shows the first ", max_rows, " of ", fmt_int(total), " rows. ")
  } else {
    ""
  }
  if (nzchar(more)) {
    para(more, "All rows are in `Rreports/", ctx$module, "/tables/", name, ".tsv`.")
  }
  if (!is.null(note)) para(note)
  invisible(NULL)
}

# Show a plot, and write it to figures/<name>.pdf (for the report and for a paper) and .png
show_figure <- function(plot, name, caption, width = 6.8, height = 3.8) {
  height <- min(height, 8.5)
  pdf_file <- file.path(ctx$figures, paste0(name, ".pdf"))
  ggsave(pdf_file, plot, width = width, height = height, device = "pdf", useDingbats = FALSE)
  try(ggsave(file.path(ctx$figures, paste0(name, ".png")), plot, width = width, height = height, dpi = 300),
      silent = TRUE)
  cat("\n\n\\begin{center}\n\\begin{minipage}{\\linewidth}\n\\centering\n\\includegraphics[width=", round(min(width, 6.8) / 6.8, 2),
      "\\linewidth]{", pdf_file, "}\n\\captionof{figure}{", latex_escape(safe_text(caption)), "}\n\\end{minipage}\n\\end{center}\n\n", sep = "")
  invisible(NULL)
}

# Height of a figure with one row per library, and whether there is still room for the names
rows_height <- function(n, per_row = 0.17, extra = 1.3) max(2.2, n * per_row + extra)

library_axis <- function(n) {
  if (n > 60) theme(axis.text.y = element_blank(), axis.ticks.y = element_blank()) else theme()
}

# Keep the n largest categories, and put the others together
top_n_other <- function(names, values, n = 10, other = "Other") {
  totals <- tapply(values, names, sum, na.rm = TRUE)
  keep <- names(sort(totals, decreasing = TRUE))[seq_len(min(n, length(totals)))]
  ifelse(names %in% keep, names, other)
}

category_colours <- function(levels) {
  colours <- rep_len(PALETTE[PALETTE != "#999999"], length(levels))
  names(colours) <- levels
  colours[names(colours) %in% c("Other", "Unclassified", "Removed", "unknown")] <- "#999999"
  colours
}

# ---- Reading common formats -----------------------------------------------------------------------

read_table_quiet <- function(path, ...) {
  read_tsv(path, show_col_types = FALSE, progress = FALSE, ...)
}

# Numbers of a samtools flagstats file
read_flagstat <- function(path) {
  lines <- readLines(path, warn = FALSE)
  value <- function(pattern) {
    hit <- grep(pattern, lines, value = TRUE)
    if (length(hit) == 0) return(NA_real_)
    as.numeric(sub(" .*", "", hit[[1]]))
  }
  tibble(
    total = value(" in total "),
    primary = value(" primary$"),
    mapped = value(" mapped \\("),
    primary_mapped = value(" primary mapped"),
    properly_paired = value(" properly paired")
  )
}

# The SN section of a samtools stats file, as a named vector
read_samstats <- function(path) {
  lines <- grep("^SN\t", readLines(path, warn = FALSE), value = TRUE)
  fields <- strsplit(lines, "\t")
  values <- suppressWarnings(as.numeric(map_chr(fields, 3)))
  names(values) <- sub(":$", "", map_chr(fields, 2))
  values
}

# Lengths and GC of all sequences of a (gzipped) FASTA file. This reads through the file with awk,
# so that a large assembly needs little memory.
fasta_table <- function(path) {
  program <- paste0(
    "/^>/{if(n)print name,l,g; name=substr($1,2); n=1; l=0; g=0; next} ",
    "{l+=length($0); g+=gsub(/[GCgc]/,\"\")} END{if(n)print name,l,g}"
  )
  command <- sprintf("gzip -dcf %s | awk %s", shQuote(path), shQuote(program))
  read.table(pipe(command), col.names = c("contig", "length", "gc"), stringsAsFactors = FALSE, comment.char = "",
             quote = "")
}

# N50 and the like, from a vector of contig lengths
length_stats <- function(lengths) {
  sorted <- sort(lengths, decreasing = TRUE)
  running <- cumsum(as.numeric(sorted))
  total <- sum(as.numeric(sorted))
  nx <- function(x) sorted[which(running >= total * x)[1]]
  tibble(
    contigs = length(sorted),
    total_bp = total,
    longest = if (length(sorted)) sorted[[1]] else NA_real_,
    N50 = if (length(sorted)) nx(0.5) else NA_real_,
    L50 = if (length(sorted)) which(running >= total * 0.5)[1] else NA_real_,
    N90 = if (length(sorted)) nx(0.9) else NA_real_,
    contigs_ge_5kb = sum(sorted >= 5000),
    contigs_ge_10kb = sum(sorted >= 10000),
    contigs_ge_50kb = sum(sorted >= 50000)
  )
}

# All modules of one FastQC zip file
read_fastqc <- function(zip_file) {
  inner <- grep("fastqc_data.txt$", unzip(zip_file, list = TRUE)$Name, value = TRUE)[[1]]
  con <- unz(zip_file, inner)
  on.exit(close(con))
  lines <- readLines(con, warn = FALSE)
  starts <- grep("^>>", lines)
  ends <- starts[lines[starts] == ">>END_MODULE"]
  starts <- setdiff(starts, ends)
  modules <- list()
  status <- list()
  for (start in starts) {
    fields <- strsplit(sub("^>>", "", lines[[start]]), "\t")[[1]]
    end <- min(ends[ends > start])
    body <- if (end > start + 1) lines[(start + 1):(end - 1)] else character(0)
    status[[fields[[1]]]] <- fields[[2]]
    modules[[fields[[1]]]] <- body
  }
  table_of <- function(name) {
    body <- modules[[name]]
    body <- body[!grepl("^#Total Deduplicated", body)]
    if (length(body) < 2) return(NULL)
    header <- strsplit(sub("^#", "", body[[1]]), "\t")[[1]]
    rows <- do.call(rbind, strsplit(body[-1], "\t"))
    colnames(rows) <- header
    as_tibble(rows)
  }
  basic <- table_of("Basic Statistics")
  dedup <- grep("^#Total Deduplicated Percentage", modules[["Sequence Duplication Levels"]], value = TRUE)
  list(
    basic = setNames(basic$Value, basic$Measure),
    status = tibble(module = names(status), status = unlist(status)),
    per_base = table_of("Per base sequence quality"),
    per_sequence = table_of("Per sequence quality scores"),
    gc = table_of("Per sequence GC content"),
    lengths = table_of("Sequence Length Distribution"),
    overrepresented = table_of("Overrepresented sequences"),
    adapter = table_of("Adapter Content"),
    deduplicated_pct = if (length(dedup)) as.numeric(strsplit(dedup, "\t")[[1]][[2]]) else NA_real_
  )
}

# One row per FastQC file: its numbers, for the reads and preprocess reports
fastqc_summary <- function(qc) {
  lengths <- qc$lengths
  midpoint <- map_dbl(strsplit(lengths$Length, "-"), function(x) mean(as.numeric(x)))
  counts <- as.numeric(lengths$Count)
  per_seq <- qc$per_sequence
  quality <- as.numeric(per_seq$Quality)
  n <- as.numeric(per_seq$Count)
  adapter <- qc$adapter
  max_adapter <- if (is.null(adapter)) NA_real_ else max(as.numeric(as.matrix(adapter[, -1])), na.rm = TRUE)
  tibble(
    reads = as.numeric(qc$basic[["Total Sequences"]]),
    bases = sum(midpoint * counts),
    read_length = qc$basic[["Sequence length"]],
    gc_pct = as.numeric(qc$basic[["%GC"]]),
    encoding = qc$basic[["Encoding"]],
    mean_quality = sum(quality * n) / sum(n),
    reads_q30_pct = 100 * sum(n[quality >= 30]) / sum(n),
    deduplicated_pct = qc$deduplicated_pct,
    max_adapter_pct = max_adapter
  )
}

fastqc_status_plot <- function(status, y_name = "File") {
  order <- unique(status$module)
  status$module <- factor(status$module, levels = order)
  ggplot(status, aes(module, file, fill = status)) +
    geom_tile(colour = "white", linewidth = 0.3) +
    scale_fill_manual(values = c(pass = "#009E73", warn = "#E69F00", fail = "#D55E00"), name = NULL) +
    labs(x = NULL, y = y_name) +
    theme_report() +
    theme(axis.text.x = element_text(angle = 40, hjust = 1)) +
    library_axis(n_distinct(status$file))
}

fastqc_notes <- function() {
  bullets(c(
    paste0("*Per sequence GC content* often gives a warning or a failure in a metagenome. FastQC compares the reads ",
           "with one normal curve, and a community of many genomes doesn't follow one curve. This isn't a problem ",
           "in itself."),
    paste0("*Sequence Duplication Levels* and *Overrepresented sequences* are worth a look: a high level can mean ",
           "a few very abundant genomes, or too little input material."),
    paste0("*Per base sequence quality*, *Adapter Content* and *Per base N content* point to technical problems, and ",
           "fastp should improve them. The preprocess report shows whether it did.")
  ))
}

# ---- How much data, and where ---------------------------------------------------------------------

module_files <- function() {
  root <- p("results", ctx$module)
  files <- list.files(root, recursive = TRUE, full.names = TRUE, all.files = TRUE, include.dirs = FALSE)
  if (length(files) == 0) {
    return(tibble(path = character(0), tool = character(0), size = numeric(0), link = logical(0), kind = character(0)))
  }
  tibble(
    path = files,
    relative = substring(files, nchar(root) + 2),
    size = file.info(files)$size,
    link = nzchar(Sys.readlink(files))
  ) %>%
    mutate(
      tool = ifelse(grepl("/", relative), sub("/.*", "", relative), "(this folder)"),
      kind = case_when(
        grepl("benchmark", relative) ~ "Benchmarks",
        grepl("\\.log(\\.try[0-9]+)?$", relative) ~ "Logs",
        TRUE ~ "Results"
      )
    )
}

data_section <- function(folder_notes) {
  files <- module_files()
  root <- paste0("results/", ctx$module)
  if (nrow(files) == 0) {
    para("Nothing has been written to `", root, "/` yet.")
    return(invisible(NULL))
  }
  own <- filter(files, !link)
  links <- filter(files, link)
  total <- sum(own$size, na.rm = TRUE)
  para("This module has written **", fmt_bytes(total), "** in ", fmt_int(nrow(own)), " files under `", root, "/`.",
       if (nrow(links) > 0) {
         paste0(" Another ", fmt_int(nrow(links)), " files are only links to data kept elsewhere (",
                fmt_bytes(sum(links$size, na.rm = TRUE)), "), and they are not counted here.")
       } else {
         ""
       },
       " Files that Snakemake deleted as temporary after their last use don't appear here, although they needed ",
       "disk space during the run.")

  by_folder <- own %>%
    group_by(tool) %>%
    summarise(
      files = n(),
      bytes = sum(size, na.rm = TRUE),
      logs_bytes = sum(size[kind != "Results"], na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(desc(bytes)) %>%
    mutate(
      folder = ifelse(tool == "(this folder)", paste0(root, "/"), paste0(root, "/", tool, "/")),
      share_pct = 100 * bytes / total,
      content = unname(folder_notes[tool]),
      content = ifelse(is.na(content), "", content)
    )
  show_table(
    by_folder %>% transmute(Folder = folder, Files = fmt_int(files), Size = fmt_bytes(bytes),
                            Share = fmt_pct(share_pct), Content = content),
    "Data written per folder of this module",
    "data_per_folder",
    export = by_folder %>% select(folder, files, bytes, share_pct, logs_bytes, content)
  )
  show_figure(
    by_folder %>% mutate(folder = reorder(tool, bytes)) %>%
      ggplot(aes(bytes / 1024^3, folder)) +
      geom_col(fill = PALETTE[[1]]) +
      labs(x = "Size (GiB)", y = NULL) +
      theme_report(),
    "data_per_folder",
    "Disk space per folder of this module.",
    height = rows_height(nrow(by_folder), 0.22, 1)
  )

  extension <- function(x) {
    name <- basename(x)
    ifelse(grepl(".", name, fixed = TRUE), sub("^.*?(\\.[A-Za-z0-9_]+(\\.(gz|bz2|xz))?)$", "\\1", name, perl = TRUE), "(none)")
  }
  by_type <- own %>%
    mutate(type = extension(path)) %>%
    group_by(type) %>%
    summarise(files = n(), bytes = sum(size, na.rm = TRUE), .groups = "drop") %>%
    arrange(desc(bytes))
  show_table(
    by_type %>% transmute(`File type` = type, Files = fmt_int(files), Size = fmt_bytes(bytes)),
    "Data written per file type",
    "data_per_type",
    export = by_type,
    max_rows = 12
  )

  largest <- own %>% arrange(desc(size)) %>% head(10) %>% transmute(file = rel(path), bytes = size)
  show_table(
    largest %>% transmute(File = file, Size = fmt_bytes(bytes)),
    "The largest files of this module",
    "largest_files",
    export = largest
  )
  para("The complete list of the module's files is in `Rreports/", ctx$module, "/tables/all_files.tsv`.")
  write_tsv(own %>% transmute(file = rel(path), bytes = size, kind), file.path(ctx$tables, "all_files.tsv"))
  invisible(NULL)
}

# ---- Resources: requested and used ----------------------------------------------------------------

# Rules of this module with a benchmark file, as Snakemake knows them (see __functions__.smk)
module_rule_table <- function() {
  if (!nzchar(rule_table)) {
    return(tibble(rule = character(0), pattern = character(0), uses_shm = logical(0)))
  }
  fields <- strsplit(strsplit(rule_table, ";", fixed = TRUE)[[1]], "|", fixed = TRUE)
  tibble(rule = map_chr(fields, 1), pattern = map_chr(fields, 2), uses_shm = map_chr(fields, 3) == "1")
}

# Every job in Snakemake's logs: rule, benchmark file, what it asked for and how it ended.
# The logs of all earlier runs of the project are read, in the order of their dates.
read_snakemake_logs <- function() {
  files <- sort(Sys.glob(p(".snakemake", "log", "*.snakemake.log")))
  jobs <- list()
  failures <- list()
  for (file in files) {
    lines <- readLines(file, warn = FALSE)
    starts <- grep("^(local)?(rule|checkpoint) [^ ]+:$", lines)
    finished <- regmatches(lines, regexpr("^Finished jobid: [0-9]+", lines))
    finished <- sub("Finished jobid: ", "", finished)
    finished_old <- regmatches(lines, regexpr("^Finished job [0-9]+", lines))
    finished <- c(finished, sub("Finished job ", "", finished_old))
    for (i in seq_along(starts)) {
      start <- starts[[i]]
      end <- start
      while (end < length(lines) && grepl("^    ", lines[[end + 1]])) end <- end + 1
      block <- lines[start:end]
      field <- function(name) {
        hit <- grep(paste0("^    ", name, ": "), block, value = TRUE)
        if (length(hit)) sub(paste0("^    ", name, ": "), "", hit[[1]]) else NA_character_
      }
      resources <- field("resources")
      value <- function(key) {
        found <- regmatches(resources, regexpr(paste0("(^|, )", key, "=[^,]*"), resources))
        if (length(found) == 0 || is.na(found)) return(NA_character_)
        sub("^.*=", "", found)
      }
      jobs[[length(jobs) + 1]] <- tibble(
        log = basename(file),
        rule = sub(":$", "", sub("^(local)?(rule|checkpoint) ", "", lines[[start]])),
        jobid = field("jobid"),
        benchmark = field("benchmark"),
        wildcards = field("wildcards"),
        threads = suppressWarnings(as.numeric(field("threads") %||% NA)),
        mem_mb = suppressWarnings(as.numeric(value("mem_mb"))),
        runtime_min = suppressWarnings(as.numeric(value("runtime"))),
        partition = value("slurm_partition"),
        gres = value("gres"),
        attempt = suppressWarnings(as.numeric(value("attempt"))),
        finished = field("jobid") %in% finished
      )
    }
    errors <- grep("^Error in rule [^ ]+:", lines, value = TRUE)
    if (length(errors)) {
      failures[[length(failures) + 1]] <- tibble(rule = sub(":.*$", "", sub("^Error in rule ", "", errors)))
    }
  }
  list(
    jobs = if (length(jobs)) bind_rows(jobs) else tibble(),
    failures = if (length(failures)) bind_rows(failures) else tibble(rule = character(0))
  )
}

read_resource_sets <- function() {
  sets <- ctx$config$resource_sets
  if (is.null(sets)) return(tibble())
  tibble(
    tier = names(sets),
    runtime_min = map_dbl(sets, ~ as.numeric(.x$runtime)),
    mem_mb = map_dbl(sets, ~ as.numeric(.x$mem_mb)),
    cpus = map_dbl(sets, ~ as.numeric(.x$cpus)),
    partition = map_chr(sets, ~ as.character(.x$partition %||% "")),
    nvme_gb = map_dbl(sets, ~ {
      found <- regmatches(as.character(.x$nvme %||% ""), regexpr("[0-9]+$", as.character(.x$nvme %||% "")))
      if (length(found)) as.numeric(found) else 0
    })
  )
}

read_escalation <- function() {
  raw <- read_yaml_if_there(p("config", "escalation.yaml"))
  map(raw, ~ trimws(strsplit(as.character(.x), ",")[[1]]))
}

escalation_order <- function(rule, escalation) {
  escalation[[rule]] %||% c("small", "medium", "large")
}

# One row per finished job with a benchmark file: requested (from the logs, or from the configuration
# if the logs are gone) and used (from the benchmark)
collect_jobs <- function() {
  rules <- module_rule_table()
  if (nrow(rules) == 0) return(tibble())
  literal <- nchar(gsub("\\{[^}]+\\}", "", rules$pattern)) + ifelse(grepl("\\{prefix\\}", rules$pattern), 0, 1000)
  rules <- rules[order(-literal), ]
  seen <- character(0)
  rows <- list()
  for (i in seq_len(nrow(rules))) {
    pattern <- rules$pattern[[i]]
    files <- if (grepl("\\{prefix\\}", pattern)) {
      # A helper rule can run anywhere, so look for its files in this module's folders
      suffix <- sub("^.*\\{prefix\\}", "", pattern)
      root <- p(sub("\\{prefix\\}.*$", "", pattern), "results", ctx$module)
      found <- list.files(root, recursive = TRUE, full.names = TRUE)
      found[endsWith(found, suffix)]
    } else {
      Sys.glob(p(gsub("\\{[^}]+\\}", "*", pattern)))
    }
    files <- setdiff(files, seen)
    seen <- c(seen, files)
    for (file in files) {
      bench <- tryCatch(
        read.delim(file, na.strings = c("-", "NA"), check.names = FALSE, stringsAsFactors = FALSE),
        error = function(e) NULL
      )
      if (is.null(bench) || nrow(bench) == 0) next
      rows[[length(rows) + 1]] <- tibble(
        rule = rules$rule[[i]],
        benchmark = rel(file),
        uses_shm = rules$uses_shm[[i]],
        wall_s = as.numeric(bench$s[[1]]),
        peak_mb = suppressWarnings(as.numeric(bench$max_rss[[1]])),
        cpu_s = suppressWarnings(as.numeric(bench$cpu_time[[1]])),
        io_in_mb = suppressWarnings(as.numeric(bench$io_in[[1]])),
        io_out_mb = suppressWarnings(as.numeric(bench$io_out[[1]]))
      )
    }
  }
  if (length(rows) == 0) return(tibble())
  jobs <- bind_rows(rows)

  logged <- read_snakemake_logs()$jobs
  last_try <- if (nrow(logged) > 0) {
    logged %>%
      filter(!is.na(benchmark)) %>%
      group_by(benchmark) %>%
      slice_tail(n = 1) %>%
      ungroup() %>%
      select(benchmark, threads, mem_mb, runtime_min, partition, gres, attempt)
  } else {
    tibble(benchmark = character(0), threads = numeric(0), mem_mb = numeric(0), runtime_min = numeric(0),
           partition = character(0), gres = character(0), attempt = numeric(0))
  }
  jobs <- left_join(jobs, last_try, by = "benchmark")

  # Without a log, the job is assumed to have run on the first resource set of its rule
  sets <- read_resource_sets()
  escalation <- read_escalation()
  jobs$source <- ifelse(is.na(jobs$mem_mb), "configuration", "log")
  jobs$attempt <- ifelse(is.na(jobs$attempt), 1, jobs$attempt)
  jobs$tier <- map2_chr(jobs$rule, jobs$attempt, function(rule, attempt) {
    order <- escalation_order(rule, escalation)
    order[[min(attempt, length(order))]]
  })
  fill <- match(jobs$tier, sets$tier)
  jobs$mem_mb <- ifelse(is.na(jobs$mem_mb), sets$mem_mb[fill], jobs$mem_mb)
  jobs$runtime_min <- ifelse(is.na(jobs$runtime_min), sets$runtime_min[fill], jobs$runtime_min)
  jobs$threads <- ifelse(is.na(jobs$threads), sets$cpus[fill], jobs$threads)
  jobs
}

summarise_rules <- function(jobs) {
  jobs %>%
    mutate(
      measured = !is.na(peak_mb) & peak_mb > 0,
      cores = ifelse(!is.na(cpu_s) & cpu_s > 0 & wall_s > 0, cpu_s / wall_s, NA_real_)
    ) %>%
    group_by(rule) %>%
    summarise(
      jobs = n(),
      uses_shm = any(uses_shm),
      first_tier = NA_character_,
      final_tier = names(sort(table(tier), decreasing = TRUE))[[1]],
      highest_attempt = max(attempt),
      retried_jobs = sum(attempt > 1),
      req_cpus = max(threads, na.rm = TRUE),
      req_mem_mb = max(mem_mb, na.rm = TRUE),
      req_runtime_min = max(runtime_min, na.rm = TRUE),
      wall_max_s = max(wall_s, na.rm = TRUE),
      wall_mean_s = mean(wall_s, na.rm = TRUE),
      wall_total_s = sum(wall_s, na.rm = TRUE),
      cores_mean = if (any(!is.na(cores))) sum(cpu_s[!is.na(cores)]) / sum(wall_s[!is.na(cores)]) else NA_real_,
      cores_peak = if (any(!is.na(cores))) max(cores, na.rm = TRUE) else NA_real_,
      mem_used_pct = if (any(measured)) 100 * max(peak_mb[measured] / mem_mb[measured]) else NA_real_,
      time_used_pct = 100 * max(wall_s / (runtime_min * 60), na.rm = TRUE),
      cpu_used_pct = if (any(!is.na(cores))) {
        100 * sum(cpu_s[!is.na(cores)]) / sum((wall_s * threads)[!is.na(cores)])
      } else {
        NA_real_
      },
      core_hours_reserved = sum(wall_s * threads, na.rm = TRUE) / 3600,
      core_hours_used = if (any(!is.na(cores))) sum(cpu_s[!is.na(cores)]) / 3600 else NA_real_,
      gb_hours_reserved = sum(wall_s * mem_mb, na.rm = TRUE) / 3600 / 1000,
      gb_hours_used = if (any(measured)) sum((wall_s * peak_mb)[measured]) / 3600 / 1000 else NA_real_,
      from_config = any(source == "configuration"),
      # Last, as later lines of summarise() would otherwise see these instead of the values per job
      mean_peak_mb = if (any(measured)) mean(peak_mb[measured]) else NA_real_,
      peak_mb = if (any(measured)) max(peak_mb[measured]) else NA_real_,
      .groups = "drop"
    )
}

# What to change for one rule. Safety margins: 30% on memory, 50% on run time. A rule that staged a
# database to /dev/shm keeps its memory, because the benchmark doesn't see the memory of those files
# and the cluster does count it. A rule on a set with local disk keeps that disk.
MEM_MARGIN <- 1.3
TIME_MARGIN <- 1.5
NEAR_LIMIT_PCT <- 85

suggest_rule <- function(row, sets, order) {
  result <- function(action, tier, why, custom = "") {
    list(action = action, tier = tier, why = why, custom = custom)
  }
  current_name <- row$first_tier
  current <- sets[sets$tier == current_name, ]
  final <- sets[sets$tier == row$final_tier, ]

  if (nrow(current) == 0) {
    return(result("check", current_name, paste0("The resource set `", current_name, "` isn't in config.yaml.")))
  }
  if (row$retried_jobs > 0 && nrow(final) > 0 && row$final_tier != current_name) {
    return(result(
      "start higher", row$final_tier,
      paste0(row$retried_jobs, " of ", plural(row$jobs, "job"), " failed on ", current_name, " and finished on ", row$final_tier)
    ))
  }
  if (is.na(row$peak_mb)) {
    near_time <- !is.na(row$time_used_pct) && row$time_used_pct >= NEAR_LIMIT_PCT
    if (near_time) {
      bigger <- sets %>% filter(runtime_min * 60 >= row$wall_max_s * TIME_MARGIN) %>% arrange(mem_mb, cpus)
      if (nrow(bigger) > 0) {
        return(result("raise", bigger$tier[[1]], paste0("Run time reached ", round(row$time_used_pct), "% of the limit")))
      }
    }
    return(result("not measured", current_name, "No memory measurement, so no suggestion"))
  }

  need_mem <- row$peak_mb * MEM_MARGIN
  need_time <- max(row$wall_max_s * TIME_MARGIN / 60, 10)
  need_cpus <- if (is.na(row$cores_peak)) row$req_cpus else max(1, ceiling(row$cores_peak * 0.9))
  floor_mem <- if (row$uses_shm) current$mem_mb else need_mem
  fits <- sets %>%
    filter(mem_mb >= max(need_mem, floor_mem), runtime_min >= need_time, cpus >= need_cpus, nvme_gb >= current$nvme_gb) %>%
    arrange(mem_mb, cpus, runtime_min, nvme_gb)
  measured <- paste0(
    "RAM ", fmt_num(row$peak_mb / 1000), "/", fmt_num(current$mem_mb / 1000), " GB, cores ",
    if (is.na(row$cores_peak)) "-" else fmt_num(row$cores_peak), "/", current$cpus,
    ", time ", fmt_duration(row$wall_max_s), "/", fmt_duration(current$runtime_min * 60)
  )
  custom <- ""
  best <- if (nrow(fits) > 0) fits[1, ] else current
  big_enough <- row$core_hours_reserved >= 5 || row$gb_hours_reserved >= 100
  if (big_enough && row$uses_shm && best$cpus >= 3 * need_cpus) {
    custom <- paste0("A set with the same memory and about ", plural(need_cpus, "CPU"), " would fit better.")
  } else if (big_enough && !row$uses_shm && (best$mem_mb >= 3 * need_mem || best$cpus >= 3 * need_cpus)) {
    custom <- paste0(
      "A set of about ", ceiling(need_mem / 1000), " GB, ", plural(need_cpus, "CPU"), " and ",
      ceiling(need_time / 60), " h would fit better."
    )
  }

  near <- row$mem_used_pct >= NEAR_LIMIT_PCT || row$time_used_pct >= NEAR_LIMIT_PCT
  if (near) {
    if (nrow(fits) > 0 && fits$tier[[1]] != current_name) {
      return(result("raise", fits$tier[[1]], paste0("Near the limit: ", measured)))
    }
    return(result("raise", current_name, paste0("Near the limit, no set is bigger: ", measured),
                  paste0("Add a set with at least ", ceiling(need_mem / 1000), " GB and ", ceiling(need_time / 60), " h.")))
  }
  if (nrow(fits) == 0 || fits$tier[[1]] == current_name) {
    return(result("keep", current_name, measured, custom))
  }
  smaller <- fits$mem_mb[[1]] <= current$mem_mb && fits$cpus[[1]] <= current$cpus
  if (!smaller) return(result("keep", current_name, measured, custom))
  note <- if (row$uses_shm) ". Memory stays: database in /dev/shm" else ""
  result("reduce", fits$tier[[1]], paste0(measured, note), custom)
}

# The new escalation of a rule: the suggestion first, the former sets after it as a fallback
new_chain <- function(tier, order, sets) {
  size <- function(name) {
    row <- sets[sets$tier == name, ]
    if (nrow(row)) row$mem_mb[[1]] else NA_real_
  }
  later <- order[!is.na(map_dbl(order, size)) & map_dbl(order, size) >= size(tier) & order != tier]
  unique(c(tier, later))
}

add_suggestions <- function(rules) {
  sets <- read_resource_sets()
  escalation <- read_escalation()
  rules$first_tier <- map_chr(rules$rule, ~ escalation_order(.x, escalation)[[1]])
  found <- map(seq_len(nrow(rules)), ~ suggest_rule(rules[.x, ], sets, escalation_order(rules$rule[[.x]], escalation)))
  rules$action <- map_chr(found, "action")
  rules$suggested_tier <- map_chr(found, "tier")
  rules$why <- map_chr(found, "why")
  rules$custom <- map_chr(found, "custom")
  rules$current_chain <- map_chr(rules$rule, ~ paste(escalation_order(.x, escalation), collapse = ", "))
  rules$new_chain <- map2_chr(rules$rule, rules$suggested_tier, function(rule, tier) {
    paste(new_chain(tier, escalation_order(rule, escalation), sets), collapse = ", ")
  })
  rules
}

resource_section <- function() {
  jobs <- collect_jobs()
  if (nrow(jobs) == 0) {
    para("No benchmark files of this module were found, so there is nothing to compare yet.")
    return(invisible(NULL))
  }
  rules <- add_suggestions(summarise_rules(jobs))
  write_tsv(jobs, file.path(ctx$tables, "resources_per_job.tsv"), na = "")
  write_tsv(select(rules, -custom), file.path(ctx$tables, "resources_per_rule.tsv"), na = "")

  measured <- any(!is.na(rules$peak_mb))
  para(
    "This module ran **", plural(nrow(jobs), "job"), "** of ", plural(nrow(rules), "rule"), ", for ",
    fmt_num(sum(jobs$wall_s, na.rm = TRUE) / 3600), " hours of job run time in total. They reserved ",
    fmt_num(sum(rules$core_hours_reserved), 1), " core-hours and ",
    fmt_num(sum(rules$gb_hours_reserved), 1), " GB-hours of memory.",
    if (measured) {
      paste0(" They used ", fmt_num(sum(rules$core_hours_used, na.rm = TRUE), 1), " core-hours (",
             fmt_pct(100 * sum(rules$core_hours_used, na.rm = TRUE) / sum(rules$core_hours_reserved)), ") and ",
             fmt_num(sum(rules$gb_hours_used, na.rm = TRUE), 1), " GB-hours (",
             fmt_pct(100 * sum(rules$gb_hours_used, na.rm = TRUE) / sum(rules$gb_hours_reserved)), ").")
    } else {
      ""
    }
  )
  para(
    "*Requested* comes from Snakemake's logs in `.snakemake/log/`, including the attempt that finished",
    if (any(jobs$source == "configuration")) {
      paste0(". The logs lacked ", plural(sum(jobs$source == "configuration"), "job"), ", and there it comes ",
             "from the first resource set in `config/escalation.yaml`")
    } else {
      ""
    },
    ". *Used* comes from each job's benchmark file: the highest memory of all its processes, its run time, and its ",
    "CPU time. Snakemake samples memory only every 30 seconds, so a short peak can be missed."
  )
  if (!measured) {
    para(
      "**Memory and CPU time weren't measured in this run.** All values are zero or missing in the benchmark files. ",
      "This happens when containers run through Docker, as Snakemake then sees only Docker's client process. ",
      "Apptainer on a cluster doesn't have this problem. So only run times can be compared here."
    )
  }

  usage <- rules %>%
    arrange(desc(wall_total_s)) %>%
    transmute(
      Rule = sub(paste0("^", ctx$module, "__"), "", rule),
      Jobs = fmt_int(jobs),
      `Set` = final_tier,
      `CPUs req.` = fmt_int(req_cpus),
      `Cores used` = fmt_num(cores_peak),
      `RAM req. (GB)` = fmt_num(req_mem_mb / 1000),
      `RAM used (GB)` = fmt_num(peak_mb / 1000),
      `RAM use` = fmt_pct(mem_used_pct, 0),
      `Time req.` = fmt_duration(req_runtime_min * 60),
      `Longest job` = fmt_duration(wall_max_s),
      `Time use` = fmt_pct(time_used_pct, 0),
      `All jobs` = fmt_duration(wall_total_s)
    )
  show_table(
    usage,
    "Requested and used resources per rule. Cores used is the highest of CPU time divided by run time; RAM used and Longest job are the highest values of any job of the rule",
    "resources_requested_used",
    export = rules %>% select(rule, jobs, final_tier, req_cpus, cores_peak, cores_mean, req_mem_mb, peak_mb, mem_used_pct,
                              req_runtime_min, wall_max_s, wall_mean_s, time_used_pct, wall_total_s, cpu_used_pct,
                              core_hours_reserved, core_hours_used, gb_hours_reserved, gb_hours_used, retried_jobs),
    max_rows = 45
  )

  panel <- bind_rows(
    rules %>% transmute(rule, metric = "Memory (GB)", requested = req_mem_mb / 1000, used = peak_mb / 1000),
    rules %>% transmute(rule, metric = "CPU cores", requested = req_cpus, used = cores_peak),
    rules %>% transmute(rule, metric = "Run time (h)", requested = req_runtime_min / 60, used = wall_max_s / 3600)
  ) %>%
    mutate(
      rule = factor(sub(paste0("^", ctx$module, "__"), "", rule),
                    levels = rev(sub(paste0("^", ctx$module, "__"), "", rules$rule[order(rules$wall_total_s, decreasing = TRUE)]))),
      metric = factor(metric, levels = c("Memory (GB)", "CPU cores", "Run time (h)"))
    )
  show_figure(
    ggplot(panel, aes(y = rule)) +
      geom_segment(aes(x = pmax(used, 1e-3), xend = requested, yend = rule), colour = "grey75", na.rm = TRUE) +
      geom_point(aes(x = requested, colour = "Requested"), size = 1.8, na.rm = TRUE) +
      geom_point(aes(x = pmax(used, 1e-3), colour = "Used"), size = 1.8, na.rm = TRUE) +
      scale_x_log10() +
      scale_colour_manual(values = c(Requested = PALETTE[[2]], Used = PALETTE[[1]]), name = NULL) +
      facet_wrap(~metric, scales = "free_x") +
      labs(x = "Logarithmic scale", y = NULL) +
      theme_report(),
    "resources_requested_used",
    "Requested and used resources per rule. A long line means a large unused reservation. Rules are sorted by their total run time.",
    height = rows_height(nrow(rules), 0.2, 1.4)
  )

  retried <- filter(rules, retried_jobs > 0)
  if (nrow(retried) > 0) {
    para("**Retries.** ", plural(sum(retried$retried_jobs), "job"), " needed more than one attempt, and each failed attempt also ",
         "used cluster time. The rules: ", paste0("`", retried$rule, "`", collapse = ", "), ".")
  }

  heading("Suggestions for the next run", 2)
  counts <- table(factor(rules$action, levels = c("start higher", "raise", "reduce", "keep", "not measured", "check")))
  para(
    "Each rule starts on the first resource set of its line in `config/escalation.yaml`, and moves to the next one if ",
    "it fails. The suggestions compare what a rule used with the sets in `config/config.yaml`, with a margin of ",
    round(100 * (MEM_MARGIN - 1)), "% on memory and ", round(100 * (TIME_MARGIN - 1)), "% on run time. ",
    "The former sets stay in the line as a fallback, so a suggestion that is too low costs one failed attempt, and not ",
    "the run. Rules that stage a database in `/dev/shm` keep their memory, because the cluster counts those files and ",
    "the benchmark doesn't. Rules on a set with local disk keep that disk."
  )
  para(
    "**These numbers hold for data like this run's.** The longest job and the highest memory of a rule decide. If the next ",
    "run has more reads or a larger co-assembly, memory and run time of assemblers, binners and mappers grow with it. ",
    "A test on a subset says little about the full data."
  )
  bullets(paste0("**", names(counts), "**: ", plural(as.integer(counts), "rule"))[counts > 0])

  changes <- rules %>%
    mutate(order = match(action, c("start higher", "raise", "reduce", "check", "not measured", "keep"))) %>%
    arrange(order, desc(core_hours_reserved))
  show_table(
    changes %>% transmute(
      Rule = sub(paste0("^", ctx$module, "__"), "", rule),
      Action = action,
      Now = current_chain,
      Suggested = ifelse(action %in% c("keep", "not measured"), "", new_chain),
      Why = why
    ),
    "Suggestion per rule",
    "resource_suggestions",
    export = changes %>% select(rule, action, current_chain, new_chain, why, custom),
    max_rows = 45,
    max_chars = 95
  )
  custom <- filter(rules, nzchar(custom))
  if (nrow(custom) > 0) {
    para("**Sets that don't exist yet.** These rules would fit a set that `config/config.yaml` doesn't have:")
    bullets(paste0("`", head(custom$rule, 12), "`: ", head(custom$custom, 12)))
  }

  to_apply <- filter(rules, action %in% c("start higher", "raise", "reduce"), current_chain != new_chain)
  yaml_file <- file.path(ctx$out, "escalation_suggestions.yaml")
  yaml_lines <- c(
    paste0("# Suggestions of the report for module ", ctx$module, ", ", format(Sys.time(), "%Y-%m-%d"), "."),
    "# Check them, and copy the lines you agree with to config/escalation.yaml.",
    if (nrow(to_apply)) paste0(to_apply$rule, ": ", to_apply$new_chain, "  # was: ", to_apply$current_chain) else "# Nothing to change."
  )
  write_lines(yaml_lines, yaml_file)
  if (nrow(to_apply) > 0) {
    saved <- rules %>%
      filter(action == "reduce") %>%
      mutate(new_cpus = read_resource_sets()$cpus[match(suggested_tier, read_resource_sets()$tier)]) %>%
      summarise(saving = sum(core_hours_reserved - core_hours_reserved * new_cpus / req_cpus, na.rm = TRUE)) %>%
      pull(saving)
    para("The lines to copy to `config/escalation.yaml` are in `Rreports/", ctx$module,
         "/escalation_suggestions.yaml`. With the same run times, the reductions would save about ",
         fmt_num(saved, 1), " reserved core-hours:")
    cat("\n\n```yaml\n", paste(head(paste0(to_apply$rule, ": ", to_apply$new_chain), 25), collapse = "\n"), "\n```\n\n", sep = "")
  } else {
    para("There are no lines to change in `config/escalation.yaml`.")
  }
  invisible(NULL)
}

# ---- Tools, versions, references ------------------------------------------------------------------

tools_table <- function() {
  folder <- file.path(pipeline_folder, "workflow", "scripts", "R")
  tools <- read.delim(file.path(folder, "report_tools.tsv"), stringsAsFactors = FALSE, quote = "") %>%
    filter(module == ctx$module | module == "all")
  versions <- read.delim(file.path(folder, "tool_versions.tsv"), stringsAsFactors = FALSE, quote = "")
  tools$image <- map_chr(tools$image_key, function(key) {
    image <- if (nzchar(key)) ctx$docker[[key]] else NULL
    if (is.null(image)) "" else sub("^docker://", "", image)
  })
  tools$version <- pmap_chr(list(tools$image, tools$version_name), function(image, name) {
    hit <- versions$version[versions$image == image & versions$tool == name]
    if (length(hit)) hit[[1]] else if (nzchar(image)) "see the image" else "-"
  })
  tools$version[tools$tool == "Snakemake"] <- snakemake_version
  tools
}

# "fastp (version 0.23.4)", for the methods text
tv <- function(tool) {
  tools <- tools_table()
  version <- tools$version[tools$tool == tool]
  if (length(version) == 0 || version[[1]] %in% c("-", "see the image")) tool else paste0(tool, " (version ", version[[1]], ")")
}

tools_section <- function() {
  tools <- tools_table()
  para(
    "Versions are those installed in the container images that the rules use, and the image names come from ",
    "`config/.docker.yml`. Use them for the methods section of a paper. If you change an image, check the version."
  )
  show_table(
    tools %>% transmute(Tool = tool, Version = version, Container = image, `Used for` = purpose),
    "Tools of this module",
    "tools",
    export = tools %>% select(tool, version, image, purpose, citation),
    max_rows = 40
  )
  heading("References", 2)
  bullets(sort(unique(tools$citation[nzchar(tools$citation)])))
  invisible(NULL)
}

about_section <- function() {
  para(
    "This report was made on ", format(Sys.time(), "%d %B %Y at %H:%M"), " by Snakebite-Holoruminant-MetaG version ",
    pipeline_version, ", with ", R.version.string, ". Project folder: `", project_folder, "`."
  )
  para("All tables of this report are in `Rreports/", ctx$module, "/tables/` as TSV files, with unrounded numbers. All ",
       "figures are in `Rreports/", ctx$module, "/figures/`, as PDF (vector) and PNG (300 dpi).")
  invisible(NULL)
}

config_value <- function(...) {
  value <- ctx$params
  for (key in c(...)) value <- value[[key]]
  value
}
