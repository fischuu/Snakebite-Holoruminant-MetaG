# The Snakebite-Holoruminant-MetaG book

A handbook of the pipeline: Linux and SLURM, Snakemake from the first rule, every tool, every module and a tutorial with real
data. The finished book is [Snakebite-MetaG-book.pdf](Snakebite-MetaG-book.pdf), and its sources are the Markdown files here.

## Status

| Part | State |
|------|-------|
| Part I: Foundations (Linux, SLURM, containers, Snakemake) | Written, and its examples run on a test cluster |
| Part II: The tools | Written. The versions are read from the images |
| Part III: The modules | Written. Appendix A lists all rules, generated from the code |
| Part IV: Tutorial with real data | Written from a small run with the real tools. The tools with large databases wait for a complete run on a cluster, which its section "What's still waiting" lists |

## What is where

| Path | Content |
|------|---------|
| `index.md`, `part1/`, `part2/`, `part3/`, `part4/`, `appendix/` | The chapters, listed in `_quarto.yml` |
| `examples/snakemake/` | The examples of Part I. Each folder has a Snakefile and a `commands.sh` |
| `examples/transcripts/` | What those commands really printed, which is what the chapters quote |
| `examples/minicluster/` | A one-node SLURM cluster in a container, where the examples run |
| `examples/real_tools/` | Runs the pipeline's rules with the real tools on a computer with only Docker. Part IV quotes the results |
| `examples/container_versions.tsv` | The tool versions in each image |
| `tools/container_versions.sh` | Reads those versions out of the images |
| `tools/versions_table.py` | Writes the table of versions into Part II from them |
| `tools/rule_reference.py` | Writes `appendix/rule-reference.md` from the rule files |
| `tools/references.py` | Writes `appendix/references.md` from the tool chapters |
| `tools/check_sync.py` | Fails when the book doesn't cover the pipeline as it is now |
| `tools/check_transcripts.py` | Fails when a chapter quotes output that isn't in a transcript |

## Keeping the book up to date

The book is a living document, and it has to change together with the pipeline. When you change anything in `workflow/` or `config/`:

1. Update the chapters of the tools and modules you touched.
2. Regenerate the rule reference and run the checks:

   ```bash
   python3 book/tools/rule_reference.py
   python3 book/tools/references.py
   python3 book/tools/versions_table.py --check
   python3 book/tools/check_sync.py
   python3 book/tools/check_transcripts.py
   ```

3. If you changed an example, run it again. This needs Docker:

   ```bash
   bash book/examples/run_all.sh
   ```

4. Rebuild the PDF, which needs Quarto and a LaTeX installation with xelatex. RStudio comes with Quarto:

   ```bash
   bash book/build.sh
   ```

## Writing conventions

- A ```` ```text ```` block is terminal output. It has to come from a real run, and `check_transcripts.py` compares it with the recorded transcripts. `[...]` marks a shortening.
- Anything else that is shown as plain text, such as a file listing you typed yourself, uses a fence without a language.
- If something couldn't be run, the text says so.
- Refer to other chapters with `@sec-name`, so that the numbers stay right.
