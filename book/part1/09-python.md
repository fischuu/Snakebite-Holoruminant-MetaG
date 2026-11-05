# Just enough Python {#sec-python}

A Snakefile is a Python file with extra keywords. You can read and write simple workflows without knowing Python, but this
pipeline uses it in many places: to read the sample sheet, to build file lists and to choose inputs per sample. This chapter
teaches exactly that part of Python and nothing more. If you know Python, skim the last two sections, which are about how
Snakemake uses it. The example is in `book/examples/snakemake/05_python/`.

## Python in one page

Here is the whole file `python_basics.py`. You can run it with `python python_basics.py`:

```python
from pathlib import Path

# A list, and a loop over it
samples = ["sampleA", "sampleB"]
for sample in samples:
    print("Sample:", sample)

# An f-string puts values into a text
sample = "sampleA"
print(f"results/{sample}.txt")

# A list comprehension builds a list from another list
print([f"results/{sample}.txt" for sample in samples])

# A dictionary maps names to values
hosts = {"cow": "cow.fa.gz", "sheep": "sheep.fa.gz"}
print(hosts["cow"], list(hosts))

# A function takes values and returns a result
def result_file(sample, mate):
    return f"results/{sample}_R{mate}.txt"
print(result_file("sampleA", 1))

# A lambda is a function without a name, written in one line
double = lambda x: x * 2
print(double(21))

# Path objects join folders with "/"
RESULTS = Path("results")
print(RESULTS / "fastp" / "sampleA.fq.gz")
```

This prints:

```text
Sample: sampleA
Sample: sampleB
results/sampleA.txt
['results/sampleA.txt', 'results/sampleB.txt']
cow.fa.gz ['cow', 'sheep']
results/sampleA_R1.txt
42
results/fastp/sampleA.fq.gz
```

Now let us look at each idea and where you will meet it.

### Lists and loops

A list is written in square brackets. In Python, indentation shows what belongs to a loop or a function, which is why the
line after `for` is indented. A `#` starts a comment.

### f-strings

An f-string has an `f` in front of the quotes, and replaces each `{name}` with the value of the variable. Be careful about the
similarity to Snakemake's patterns, because they do different things:

```python
"results/{sample}.txt"    # A pattern: {sample} is a wildcard, filled in later by Snakemake
f"results/{sample}.txt"   # An f-string: {sample} is a Python variable, filled in right now
```

If you need both in one text, double the braces of the wildcard: `f"{RESULTS}/{{sample}}.txt"`. You will see that in this
pipeline's `folders.smk`.

### List comprehensions

A list comprehension is a loop squeezed into one expression: "make this, for each of these". The pipeline uses them instead
of `expand()` when the combinations aren't all possible. In this rule, not every library belongs to every assembly, so a
plain `expand()` would ask for files that shouldn't exist:

```python
[
    ASSEMBLY_MAPPING / f"{assembly_id}.{sample_id}.{library_id}.cram"
    for assembly_id, sample_id, library_id in ASSEMBLY_LIBRARIES
]
```

`ASSEMBLY_LIBRARIES` is a list of triples, and each round of the loop unpacks one into three variables. This is the most common
kind of Python in this pipeline.

### Dictionaries

A dictionary maps a name to a value, and you look values up in square brackets. Configuration files turn into dictionaries
in Python, which is why you will see lookups like `config["assembler"]` or `params["assemble"]["drep"]["P_ani"]`.

### Functions and lambdas

`def` defines a function, and `return` hands back its result. A `lambda` is a small function without a name, and it fits on one
line. These two are the same:

```python
def double(x):
    return x * 2

double = lambda x: x * 2
```

### Paths

`Path` from Python's standard library represents a file path, and `/` joins its parts. The pipeline defines one constant per
results folder in `workflow/rules/folders.smk`, and uses them everywhere:

```python
ASSEMBLE = Path("results/assemble")
MEGAHIT = ASSEMBLE / "megahit"
```

Then a rule can write its output as `MEGAHIT / "{assembly_id}.fa.gz"`. If the folder ever moves, one line changes.

## Reading a sample sheet with pandas

The sample sheet of this example has one line per library:

```
sample_id	library_id	forward	reverse	assembly_ids
sampleA	L001	data/sampleA_R1.fastq.gz	data/sampleA_R2.fastq.gz	asm1, combined
sampleB	L001	data/sampleB_R1.fastq.gz	data/sampleB_R2.fastq.gz	asm2, combined
sampleC	L001	data/sampleC_R1.fastq.gz	data/sampleC_R2.fastq.gz	asm3
```

The last column says which assemblies a library goes into, and a library can be in several. This is a small model of the
pipeline's `samples.tsv`, where several libraries that share an `assembly_id` make up a co-assembly.

**pandas** is a Python library for tables. Let's follow what the workflow does with this sheet, step by step:

```python
import pandas as pd

samples = pd.read_table("samples.tsv")
print(samples[["sample_id", "assembly_ids"]])
```

```text
  sample_id    assembly_ids
0   sampleA  asm1, combined
1   sampleB  asm2, combined
2   sampleC            asm3
```

`read_table` loads the file as a table called a **data frame**, and `samples[[...]]` selects columns. Now we split the text in
the last column into a real list, using a lambda on each cell:

```python
samples["assembly_id"] = samples["assembly_ids"].map(lambda cell: cell.replace(" ", "").split(","))
print(samples[["sample_id", "assembly_id"]])
```

```text
  sample_id       assembly_id
0   sampleA  [asm1, combined]
1   sampleB  [asm2, combined]
2   sampleC            [asm3]
```

`explode` then gives each list element a row of its own:

```python
samples = samples.explode("assembly_id")
print(samples[["sample_id", "assembly_id"]])
```

```text
  sample_id assembly_id
0   sampleA        asm1
0   sampleA    combined
1   sampleB        asm2
1   sampleB    combined
2   sampleC        asm3
```

Now it is easy to ask which libraries belong to an assembly. A condition in square brackets keeps the matching rows:

```python
members = samples[samples["assembly_id"] == "combined"]
print(list(zip(members["sample_id"], members["library_id"])))
```

```text
[('sampleA', 'L001'), ('sampleB', 'L001')]
```

`zip` pairs up two columns. The pipeline's `workflow/Snakefile` and its function `libraries_of_assembly` work just like this.

## Input functions: an input that depends on the wildcards

Now everything comes together. Pooling reads for an assembly has a problem: how many input files there are depends on the
assembly, so no fixed pattern can describe them. For this you can write a function as the input:

```python
import pandas as pd
from pathlib import Path

RESULTS = Path("results")

samples = pd.read_table("samples.tsv")
samples["assembly_id"] = samples["assembly_ids"].map(lambda cell: cell.replace(" ", "").split(","))
samples = samples.explode("assembly_id")
ASSEMBLIES = samples["assembly_id"].unique().tolist()


def forward_reads(wildcards):
    """The forward read files of all samples in one assembly"""
    return samples.loc[samples["assembly_id"] == wildcards.assembly_id, "forward"].tolist()


rule all:
    input:
        [RESULTS / f"{assembly_id}.fastq.gz" for assembly_id in ASSEMBLIES],


rule pool_reads:
    """Pool the reads of all samples that belong to one assembly"""
    input:
        forward_reads,
    output:
        RESULTS / "{assembly_id}.fastq.gz",
    params:
        n_files=lambda wildcards, input: len(input),
    shell:
        """
        echo "{wildcards.assembly_id}: pooling {params.n_files} file(s)"
        cat {input} > {output}
        """
```

The line `forward_reads,` has no parentheses. This hands Snakemake the function itself, instead of calling it. Once Snakemake
knows the wildcards of a job, it calls the function with them, and the function returns the list of input files. This is called
an **input function**. The job for the assembly `combined` gets two files, and the others one each:

```text
$ snakemake --cores 1
combined: pooling 2 file(s)
asm1: pooling 1 file(s)
asm2: pooling 1 file(s)
asm3: pooling 1 file(s)
[...]
localrule pool_reads:
    input: data/sampleA_R1.fastq.gz, data/sampleB_R1.fastq.gz
    output: results/combined.fastq.gz
    jobid: 2
    reason: Missing output files: results/combined.fastq.gz
    wildcards: assembly_id=combined
    resources: tmpdir=/tmp
[...]

$ for file in results/*.fastq.gz; do echo "$file: $(zcat "$file" | wc -l | awk '{print $1 / 4}') reads"; done
results/asm1.fastq.gz: 40 reads
results/asm2.fastq.gz: 60 reads
results/asm3.fastq.gz: 25 reads
results/combined.fastq.gz: 100 reads
```

Pooled gzip files stay valid, which is a useful property of the gzip format: `cat a.gz b.gz > c.gz` gives a file that decompresses to
both contents. The metaSPAdes rule pools reads this way.

The example has another new thing: `params:` lists values for the command that aren't files. A lambda here can ask for
`wildcards`, `input`, `output`, `threads` or `resources`, by naming them as its arguments. `params` plays a big role in the next
chapter.

Two details make input functions easier to debug:

- A function can be tested on its own in Python, and it isn't Snakemake that has to fail first.
- If a function raises a Python error, Snakemake can report the confusing message "No rule to produce" that you saw in the
  previous chapter. That's why that message mentions input functions.

### Functions that return a function

The pipeline uses one more step here. Many rules need the same function, once for mate 1 and once for mate 2. So
`assembly_reads` in `workflow/rules/assemble/__functions__.smk` takes the mate as a value, and *returns a new function*:

```python
def assembly_reads(end, separator=None):
    read_folder = CLEAN_READS if HOST_NAMES else FASTP

    def reads(wildcards):
        paths = [
            str(read_folder / f"{sample_id}.{library_id}_{end}.fq.gz")
            for sample_id, library_id in libraries_of_assembly(wildcards.assembly_id)
        ]
        return separator.join(paths) if separator else paths

    return reads
```

In a rule, this reads almost like a sentence, and note the parentheses this time, since the outer function does get called:

```python
    input:
        forwards=assembly_reads(1),
        reverses=assembly_reads(2),
```

## Python that runs at parse time

One thing confuses people about Python in a Snakefile: **when** it runs. Snakemake reads the Snakefile and runs all top-level
Python code first, to learn what the rules are. It does this before it looks at any job:

- Code at the top level, such as reading the sample sheet, runs each time Snakemake starts. It runs many times on a cluster:
  once in the main process, and again in each SLURM job. So keep it fast, and don't make it print much or change files.
- Input functions run later, once per job, when Snakemake builds the DAG.
- The `shell:` block runs when the job runs.

The fact that a Snakefile is read again inside each SLURM job has a consequence that @sec-cluster describes, and which affects this
pipeline.

## Summary

- A Snakefile is Python, and the pipeline uses lists, f-strings, comprehensions, dictionaries, functions and `Path`.
- pandas reads the sample sheet, and `explode` handles libraries in several assemblies.
- An input function chooses a job's inputs from its wildcards.
- Top-level code runs every time Snakemake starts, also inside each cluster job.
