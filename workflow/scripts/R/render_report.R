# Render the report of one module. Usage, all as name=value:
#   Rscript render_report.R module=reads project=<folder> pipeline=<folder> features=config/features.yaml \
#       samples=config/samples.tsv output=Rreports/reads.pdf version=0.4.71 rules='<rule|benchmark|shm;...>'
#
# The report is built in its own temporary folder inside the project, because the pipeline folder may
# be read-only, and reports of different modules can run at the same time. The caches of LaTeX go
# there too, since the home folder may be unavailable or full on a compute node.
#
# LaTeX is pdflatex, not xelatex: the LaTeX in the container lacks packages that xelatex needs, and it
# would try to download them, which fails on a compute node without network.

args <- commandArgs(trailingOnly = TRUE)
opt <- setNames(sub("^[^=]+=", "", args), sub("=.*$", "", args))

module <- opt[["module"]]
project_folder <- normalizePath(opt[["project"]])
pipeline_folder <- normalizePath(opt[["pipeline"]])
output <- file.path(project_folder, opt[["output"]])

report_env <- new.env(parent = globalenv())
report_env$project_folder <- project_folder
report_env$pipeline_folder <- pipeline_folder
report_env$features_file <- opt[["features"]]
report_env$sample_file <- opt[["samples"]]
report_env$rule_table <- if ("rules" %in% names(opt)) opt[["rules"]] else ""
report_env$pipeline_version <- if ("version" %in% names(opt)) opt[["version"]] else "unknown"
report_env$snakemake_version <- if ("snakemake" %in% names(opt)) opt[["snakemake"]] else "unknown"

build <- tempfile(paste0(".build_", module, "_"), tmpdir = dirname(output))
dir.create(build, recursive = TRUE)
Sys.setenv(
  TEXMFVAR = file.path(build, "texmf-var"),
  TEXMFCONFIG = file.path(build, "texmf-config"),
  XDG_CACHE_HOME = file.path(build, "cache")
)

script <- file.path(build, paste0(module, ".Rmd"))
file.copy(file.path(pipeline_folder, "workflow", "scripts", "R", paste0(module, ".Rmd")), script)

header <- file.path(build, "header.tex")
# Only packages that the container has. Tables and figures are placed where they stand, and not as
# floats, so that they stay in the order of the text. For that, \captionof gives them their numbers.
writeLines(c(
  "\\usepackage{longtable}",
  "\\usepackage{graphicx}",
  "\\makeatletter",
  "\\def\\captionof#1{\\def\\@captype{#1}\\caption}",
  "\\makeatother",
  "\\providecommand{\\toprule}{\\hline}",
  "\\providecommand{\\midrule}{\\hline}",
  "\\providecommand{\\bottomrule}{\\hline}",
  "\\sloppy"
), header)

tryCatch(
  rmarkdown::render(
    script,
    output_format = rmarkdown::pdf_document(
      latex_engine = "pdflatex",
      toc = TRUE,
      toc_depth = 2,
      number_sections = TRUE,
      fig_caption = TRUE,
      includes = rmarkdown::includes(in_header = header)
    ),
    output_file = output,
    intermediates_dir = build,
    knit_root_dir = build,
    envir = report_env,
    quiet = TRUE
  ),
  finally = unlink(build, recursive = TRUE)
)
