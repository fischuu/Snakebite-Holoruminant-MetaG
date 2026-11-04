# Welcome {.unnumbered}

This book explains Snakebite-Holoruminant-MetaG from the ground up: the Linux and cluster knowledge
you need, the workflow system Snakemake, every tool the pipeline runs, every module and rule, and a
tutorial with real data. You don't need any programming background to start, and you can stop reading
at the point where you know enough for your work.

## Who this book is for

- **Newcomers to metagenomics or to clusters** should read from the beginning. Part I assumes that you
  have never written a workflow, and explains the Linux commands it uses.
- **Users of the pipeline** who already know Snakemake can start at Part II for the tools, or Part III
  for what a module does.
- **Developers of the pipeline** will mostly use Part III and the rule reference in the appendix.

## How the book is organised

| Part | Content |
|------|---------|
| Part I: Foundations | Linux on a cluster, SLURM, containers and a thorough introduction to Snakemake |
| Part II: The tools | Every tool in the pipeline: what it does, its input and output, when to use it and why we do |
| Part III: The modules | Every module, rule by rule, and how the rules work together |
| Part IV: Tutorial | A run with real data, stage by stage, with the results and how to read them |
| Appendices | The generated reference of all rules |

## What you can trust in this book

Everything printed as terminal output comes from a real run, and each chapter says where it was run.
The examples of Part I are in `book/examples/`, so you can run them yourself and compare. When
something could not be run, for example a real SLURM submission from a laptop, the text says so.

This book changes together with the pipeline. @sec-rule-reference is generated from the rule files, and
the check `book/tools/check_sync.py` fails when a rule, tool or configuration file is not covered in the
text. If you find a place where the book and the pipeline disagree, trust the pipeline and please open an
issue.

## How this book was written

This book was drafted with AI assistance (Claude Code) and checked against the pipeline's code and real
runs. Where the pipeline comes from is described in "Provenance and acknowledgements" in the repository's
`README.md`.
