# Testing a workflow {#sec-testing}

A pipeline that is changed for years needs tests, or small changes break things unnoticed. Workflows have a problem here: a real run takes days and needs terabytes of databases. So you test on several levels, from checks that take seconds to complete runs. The example is in `book/examples/snakemake/15_tests/`.

## Level 1: the dry run

The cheapest test is `snakemake -n`. It parses all rule files, builds the whole plan, and finds most kinds of mistakes in the plan without running anything. It needs the input files to exist, but they may be empty, which makes it easy to test a pipeline without any data:

```bash
mkdir -p reads resources/reference
touch reads/sample1_R1.fastq.gz reads/sample1_R2.fastq.gz resources/reference/host.fa.gz
snakemake -n --cores 1 all
```

Add `-p`, and each command gets built as well, which also finds problems like single braces in a command.

## Level 2: the linter

`--lint` looks for known bad habits in a workflow:

```text
$ snakemake --lint text | head -n 12
Lints for rule count_reads (line 10, /scratch/project_demo/examples/15_tests/Snakefile):
    * No log directive defined:
      Without a log directive, all output will be printed to the terminal. In
      distributed environments, this means that errors are harder to discover.
      In local environments, output of concurrent jobs will be mixed and become
      unreadable.
      Also see:
      https://snakemake.readthedocs.io/en/stable/snakefiles/rules.html#log-files
    * Specify a conda environment or container for each rule.:
      This way, the used software for each specific step is documented, and the
      workflow can be executed on any machine without prerequisites.
      Also see:
```

A separate tool called `snakefmt` formats Snakefiles consistently, and the pipeline's GitHub workflow uses a linter on each pull request.

## Level 3: unit tests for rules

Snakemake can write unit tests for you. After a successful run, `--generate-unit-tests` copies the input and output of one job per rule, and writes a test that runs the rule again and compares the result:

```text
$ snakemake --cores 2 --quiet rules
[...]
8 of 8 steps (100%) done

$ snakemake --generate-unit-tests --cores 1 2>&1 | tail -n 1
Generating unit test for rule count_reads: .tests/unit/test_count_reads.py.

$ find .tests -type f | sort | head -n 12
.tests/unit/common.py
.tests/unit/conftest.py
.tests/unit/count_reads/config/.gitempty
.tests/unit/count_reads/data/data/sampleA_R1.fastq.gz
.tests/unit/count_reads/expected/results/counts/sampleA_R1.txt
.tests/unit/summary/config/.gitempty
.tests/unit/summary/data/results/counts/sampleA_R1.txt
.tests/unit/summary/data/results/counts/sampleA_R2.txt
.tests/unit/summary/data/results/counts/sampleB_R1.txt
.tests/unit/summary/data/results/counts/sampleB_R2.txt
.tests/unit/summary/data/results/counts/sampleC_R1.txt
.tests/unit/summary/data/results/counts/sampleC_R2.txt
```

Each rule gets a folder with `data` (its inputs) and `expected` (its outputs). A test framework called pytest runs them:

```text
$ pytest -q .tests/unit 2>&1 | tail -n 3
..                                                                       [100%]
2 passed in 2.76s
```

This is a neat idea, and has limits for a pipeline like this one:

- It stores real inputs and outputs. With tools that take gigabytes of input, this doesn't fit in a repository, so it needs a small dataset.
- It compares bytes by default. Many bioinformatics tools produce different files on each run, with dates in them, or a different order when they use several threads. You then need your own comparison.
- It needs the rule's software available when the tests run.

## Level 4: running with stand-in tools

This level answers a question the others don't: does the shell code of the rules work, with its loops, renames and clean-up steps? You put small programs on the `PATH` named like the real tools, which only create the expected files. Then you run the real Snakefile for real, without containers.

It takes seconds, needs no databases, and checks everything except the tools themselves. If you run the old and the new version of the pipeline this way, and compare all results, you learn whether a rewrite changed anything. This is how the rule rewrite described in the README was verified.

A stand-in can also fail on purpose, which tests how the pipeline handles failures. `tests/escalation/run_test.sh` does this on a real SLURM cluster in a container (@sec-tests-in-repo). A stand-in `bgzip` fails when a job has too little memory, and the test checks that the rule fails and that a bigger SLURM job follows. This test found two serious bugs that no dry run could have found: rules that ignored failing commands (@sec-strict-mode), and retries that stayed inside the same job (@sec-retries-trap).

Its limit is clear: a stand-in accepts any option you give it. It can't tell you that a real tool doesn't understand a flag.

## Level 5: real runs with real data

Only this level proves that the pipeline works, and it's the most expensive. A small but real dataset keeps it possible, and the real tools then run in their containers. Part IV of this book does this, and its results are stored as tests for later changes.

## What you should run when

| Change | Check |
|--------|-------|
| Any change to a rule | Dry run in several setups |
| Changing shell code | Stand-in run |
| Changing a tool's options or container | A real run of that rule |
| Before a release | A complete real run on the small dataset |
| Any change at all | The book's sync check (`book/tools/check_sync.py`) |

## Summary

Test on several levels, because each finds different mistakes:

- A dry run finds problems in the plan.
- A linter finds bad habits.
- Unit tests keep single rules from changing their results.
- Stand-in runs check the shell code around the tools.
- Real runs check the tools themselves.
