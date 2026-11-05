# Linux on a cluster {#sec-linux}

This pipeline runs on a high-performance computing cluster (HPC), and clusters run Linux. Before we can
talk about workflows, we need the small part of Linux that you will use every day. This chapter assumes
nothing. If you already work on a cluster each day, skim the section on pipes and exit codes, because
Snakemake depends on those details, and then move on.

Every command in this chapter was run on a small test cluster, and the output you see is real. You can
repeat them yourself with the files in `book/examples/`, as @sec-running-the-examples explains.

## What a cluster is

A laptop has one computer in it. A cluster has hundreds or thousands of them, called **nodes**, connected
by a fast network and sharing the same disks. You don't sit in front of any of them. You connect over the
network, and you ask a piece of software called the **scheduler** to run your work on nodes that are free.

Three ideas explain most of how a cluster behaves.

### Login nodes and compute nodes

When you connect, you arrive on a **login node**. Everybody on the system shares it, and it is meant for
small tasks: editing files, moving data, starting workflows. Real work happens on **compute nodes**, which
you can't normally log in to directly. You ask for them through the scheduler, and @sec-slurm explains how.

Running a heavy program on a login node slows the system down for everyone, and administrators may stop it.
A rough rule is that anything needing more than a few minutes or more than a gigabyte of memory doesn't
belong there.

Snakemake itself is the exception that surprises people. It does little work: it mostly waits and submits
jobs, so it is normal to leave it running on a login node while it sends the real work to compute nodes.
This pipeline works that way.

### Shared disks, with different purposes

All nodes see the same files, because the disks are shared over the network. A typical cluster has several
of these areas, and using the right one matters. The names differ between systems, and here are the ones
used at CSC's Puhti system, where this pipeline was developed:

| Area | Example path | Meant for | Typical limits |
|------|--------------|-----------|----------------|
| Home | `/users/fischerd` | Settings, small scripts | Small and backed up |
| Project application folder | `/projappl/project_2009831` | Installed software, containers | Moderate |
| Scratch | `/scratch/project_2009831` | Data and results of running projects | Large, old files may be removed |
| Local disk on a compute node | `$LOCAL_SCRATCH` | Temporary files during a job | Fast, gone after the job |
| Memory disk | `/dev/shm` | Very fast temporary files, such as databases | Counts as memory, gone after the job |

For this pipeline, the most common mistake is to leave results or caches in the home folder, which fills up
quickly. Your project folder belongs on scratch. You will meet the local disk and the memory disk again in
@sec-module-read-annotate, because copying a large database there can speed up a tool a lot.

A shared network disk also has a behaviour worth remembering: a file written on one node can take a few
seconds to appear on another. That is why the pipeline's run script sets `--latency-wait 60`, which tells
Snakemake to wait up to a minute for a file before calling it missing.

### You ask for resources, and you get exactly those

On your laptop, a program can use whatever is free. On a cluster, you say up front how many CPU cores, how
much memory and how much time a job needs. The scheduler finds a place for it and then usually holds it to
that request: a job that exceeds its memory or time gets killed. Asking for too much isn't free either,
because large requests wait longer in the queue and use up your project's allocation.

Much of the pipeline's design deals with this fact. @sec-pipeline-patterns explains how it starts each rule
on a small resource set and moves up to a bigger one when a job fails.

## Connecting

You connect with `ssh`, which gives you a terminal on the login node:

```bash
ssh yourname@puhti.csc.fi
```

Everything you type then happens on the cluster. Most clusters today require an SSH key instead of a password,
and your computing centre's documentation describes how to set one up. This command wasn't run for this book,
because the examples run on a small test cluster.

### Keeping things running after you disconnect

If your connection drops, programs started in that terminal normally stop too. Since a workflow can run for
days, you need a way around this. The usual tool is `tmux`, which keeps a terminal alive on the login node:

```bash
tmux new -s metag        # start a session named "metag"
# ... start your workflow, then press Ctrl-b and then d to detach ...
tmux attach -t metag     # come back later, even from another computer
```

Some systems have several login nodes, so remember which one you were on (the command `hostname` tells you).
Your tmux session exists only on that node.

## Moving around

The shell is the program that reads your commands. It always has a **current folder**, and `pwd` prints it:

```text
$ pwd
/scratch/project_demo/examples/00_linux
```

`ls` lists what is in a folder:

```text
$ ls data
sampleA_R1.fastq.gz
sampleA_R2.fastq.gz
sampleB_R1.fastq.gz
sampleB_R2.fastq.gz
sampleC_R1.fastq.gz
sampleC_R2.fastq.gz
```

With `-l` you get details, and `-h` makes sizes readable:

```text
$ ls -lh data | head -n 4
total 24K
-rw-r--r-- 1 root root 1.3K Nov  3 17:12 sampleA_R1.fastq.gz
-rw-r--r-- 1 root root 1.2K Nov  3 17:12 sampleA_R2.fastq.gz
-rw-r--r-- 1 root root 1.9K Nov  3 17:12 sampleB_R1.fastq.gz
```

The columns are the permissions, the number of links, the owner, the group, the size, the date of the last
change and the name. Snakemake uses that date to decide what is out of date, so it will matter later.

A few commands cover almost all of your file handling:

| Command | What it does | Example |
|---------|--------------|---------|
| `cd` | Change the current folder | `cd /scratch/project_2009831` |
| `mkdir -p` | Create a folder, including parents | `mkdir -p project/reads` |
| `cp` | Copy a file | `cp a.txt b.txt` |
| `mv` | Move or rename | `mv a.txt b.txt` |
| `rm` | Delete a file, with no recycle bin | `rm a.txt` |
| `rm -r` | Delete a folder and everything in it | `rm -r old_results` |
| `ln -s` | Create a symbolic link | see below |
| `du -sh` | Size of a folder | `du -sh results` |
| `df -h` | Free space on a disk | `df -h /scratch` |

There is no undo for `rm`. Check twice, especially with `rm -r`.

### Paths

A path that starts with `/` is **absolute**, and means the same from everywhere. Any other path is **relative**
to the current folder. In `project/reads/a.txt`, the shell looks for `project` inside the current folder.
Snakemake rules almost always use relative paths, and Snakemake runs them from the project folder. That lets you
move a whole project to another place and keep it working.

Two short forms are worth knowing: `..` is the folder above the current one, and `~` is your home folder.

### Symbolic links

A **symbolic link** is a small file that points to another file. Programs reading the link get the content of
the file it points to. This is how you use a large file in several places without copying it:

```text
$ ln -s "$PWD/data/sampleB_R1.fastq.gz" project/reads/sampleB.fastq.gz
$ ls -l project/reads | cut -c1-10,42-
total 8
-rw-r--r--sampleA_R1.fastq.gz
lrwxrwxrwxsampleB.fastq.gz -> /scratch/project_demo/examples/00_linux/data/sampleB_R1.fastq.gz
```

The `l` at the start and the arrow show that it is a link. The first rule of this pipeline does exactly this:
`reads__link__run` links your raw FASTQ files into `results/reads/` under uniform names, without copying them
(@sec-module-reads). Use an absolute path as the target, because a relative target is resolved from the place
of the link, which rarely is what you meant.

## Looking at files

The data files in this field are too large to open in an editor, so you look at parts of them.

A **FASTQ** file stores sequencing reads, with four lines per read: a name starting with `@`, the sequence, a `+`,
and a quality string with one character per base. These files are almost always compressed with gzip, and end in
`.gz`. `zcat` decompresses to the screen, and `head` keeps the first lines:

```text
$ zcat data/sampleA_R1.fastq.gz | head -n 4
@sampleA.0/1
AGCCCAATAAACCACTCTGACTGGCCGAATAGGGATATAGGCAA
+
IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII
```

The `|` is a **pipe**, and the next section is about it. To count the reads, count the lines and divide by four:

```text
$ zcat data/sampleA_R1.fastq.gz | wc -l
160
```

So this file has 40 reads. These small tools can answer many questions when you combine them:

```text
$ zcat data/sampleA_R1.fastq.gz | awk 'NR % 4 == 2' | head -n 2 | cut -c1-40
AGCCCAATAAACCACTCTGACTGGCCGAATAGGGATATAG
GACATGTGCGGCGACCCTTGCGACAGTGACGCTTTCGCCG

$ zcat data/sampleA_R1.fastq.gz | awk 'NR % 4 == 2 { print length($0) }' | sort -n | tail -n 1
100

$ zcat data/sampleA_R1.fastq.gz | grep -c '^@sampleA'
40
```

The first command prints the sequences only: `awk` runs a small program on each line, `NR` is the line number,
and `NR % 4 == 2` is true on every second line of four. The second prints the longest read. The third counts
lines starting with the read name. The `^` means "at the start of the line".

Here are the tools you will see most in this book's rules:

| Tool | What it does |
|------|--------------|
| `less file` | Page through a file. Press `q` to leave, `/` to search |
| `head`, `tail` | First or last lines |
| `wc -l` | Count lines |
| `cut -f 1,5` | Keep some columns of a table |
| `sort`, `uniq` | Sort lines, and remove repeated ones |
| `grep` | Keep lines matching a pattern |
| `sed` | Replace text |
| `awk` | A small language for working on columns |
| `paste` | Put files or lines side by side |
| `zcat`, `gzip -dc` | Decompress to the screen |

::: {.callout-warning}
## `grep -c` on FASTQ is a trap

The example above works because our read names are predictable. In real FASTQ data, the quality line can also
start with `@`, so counting lines that start with `@` may overcount. Always count reads as lines divided by four.
:::

## Compressed files and archives

Bioinformatics tools produce a lot of data, so files are nearly always compressed. You will see four names:

- **gzip** is the standard one, with files ending in `.gz`. `gzip file` replaces the file with a compressed one.
- **pigz** does the same as gzip but uses several CPU cores, and its files are normal gzip files.
- **bgzip** writes gzip files in small blocks, so that tools can jump into the middle. Genome FASTA files must be
  compressed this way before `samtools faidx` accepts them, and this is why the module `reference` recompresses the
  host genomes (@sec-module-reference).
- **tar** packs a whole folder into one file, and is usually combined with compression:

```text
$ tar -czf archive.tar.gz archive
$ tar -tzf archive.tar.gz
archive/
archive/inner/
archive/inner/file.txt
```

In `-czf`, `c` means create, `z` compress with gzip and `f` names the archive. In `-tzf`, `t` lists the content,
and `-xzf` unpacks. A cluster's shared disks handle millions of small files badly, so the pipeline packs the working
folders of the assemblers and of GTDB-Tk into archives when they are done.

## Pipes and redirection

Every program has three standard channels:

- **stdin** (channel 0) is where it reads its input.
- **stdout** (channel 1) is where it writes its results.
- **stderr** (channel 2) is where it writes messages and errors.

Normally stdout and stderr go to your screen. You can redirect them:

| Syntax | Meaning |
|--------|---------|
| `cmd > file` | Write stdout to a file, replacing it |
| `cmd >> file` | Append stdout to a file |
| `cmd 2> file` | Write stderr to a file |
| `cmd > file 2>&1` | Write both to the same file |
| `cmd1 \| cmd2` | Send stdout of `cmd1` to stdin of `cmd2` |

```text
$ zcat data/sampleA_R1.fastq.gz | wc -l > lines.txt
$ cat lines.txt
160

$ ls data/does_not_exist.gz > listing.txt 2> errors.txt; echo "exit code of ls: $?"
exit code of ls: 2
$ cat errors.txt
ls: cannot access 'data/does_not_exist.gz': No such file or directory
```

The separation is why tools can write results to stdout and still show progress messages: a pipe only carries
stdout. That is also the reason for a very common line in this pipeline's rules:

```bash
exec > {log} 2>&1
```

`exec` with only redirections changes the channels of the running script itself. Everything the rule's commands
print from then on goes to the log file, without repeating `> {log} 2>&1` on every line.

The order in `> file 2>&1` matters: first stdout moves to the file, then stderr goes to where stdout now points.
If you write `2>&1 > file`, stderr still goes to the screen.

### Process substitution

Some tools want a file name and can't read from a pipe. `<(command)` makes the output of a command look like a file:

```text
$ paste <(zcat data/sampleA_R1.fastq.gz | head -n 1) <(zcat data/sampleB_R1.fastq.gz | head -n 1)
@sampleA.0/1	@sampleB.0/1
```

The pipeline uses this to hand compressed files to tools that only read plain FASTA. For example, the CONCOCT rule
runs `cut_up_fasta.py <(zcat {input.contigs})` (@sec-tool-concoct). Not every tool can read from such a pseudo-file,
because some need to jump around in the file. Nonpareil is one of these, so its rule writes a real temporary file.

## Exit codes: how programs report failure

When a program ends, it leaves a number called the **exit code**. By convention, `0` means success, and anything
else means failure. The shell keeps the last one in `$?`:

```text
$ true; echo "true gives $?"; false; echo "false gives $?"
true gives 0
false gives 1
```

Exit codes are how Snakemake knows that a rule failed. There are two traps, and Snakemake deals with both.

The first trap is that a script normally continues after a failing command, and reports only the exit code of its
last command. The setting `set -e` makes the script stop at the first failure.

The second trap is that a pipe reports only the exit code of its last command:

```text
$ false | true; echo "without pipefail: $?"
without pipefail: 0

$ set -o pipefail; false | true; echo "with pipefail: $?"
with pipefail: 1
```

So `zcat broken.gz | wc -l > count.txt` looks like a success without `pipefail`, even if the file was damaged. You
would get a wrong number and no error at all.

Snakemake runs every shell command in **strict mode**, which is `set -euo pipefail`: stop at any failure (`-e`), treat
unset variables as errors (`-u`), and let a pipe fail if any part of it fails (`-o pipefail`). This protects you, as long as
nothing switches it off, and @sec-strict-mode shows how easily that can happen. Strict mode also has one surprising effect. A command like `zcat file | head -n 1` can stop `zcat` with an error when `head` has
what it needs and closes the pipe early. This depends on timing and on the amount of data, and shows up as the exit
code 141. Keep it in mind if a rule with `head` fails only on large files.

## Variables and quoting

A shell variable holds a text. You set it without spaces around the `=`, and read it with `$`:

```text
$ SAMPLE=sampleA
$ echo "The sample is $SAMPLE and its file is data/${SAMPLE}_R1.fastq.gz"
The sample is sampleA and its file is data/sampleA_R1.fastq.gz
```

The braces in `${SAMPLE}` mark where the name ends. Without them, the shell would look for a variable called
`SAMPLE_R1`.

Quotes control what the shell does with your text. Inside double quotes, variables are replaced and spaces stay
part of the text. Inside single quotes, nothing is replaced. As a habit, write `"$file"` with double quotes, so that a
file name with a space doesn't turn into two arguments.

A variable normally exists only in your current shell. `export` passes it on to programs you start:

```text
$ export MY_SETTING=42
$ bash -c 'echo "A new program sees MY_SETTING=$MY_SETTING and YOUR_SETTING=$YOUR_SETTING"'
A new program sees MY_SETTING=42 and YOUR_SETTING=
```

This matters on a cluster, since jobs usually inherit the environment of the shell that submitted them. It is how
the setting `PIPELINE_DEBUG=1` reaches the rules, and also the cause of a class of odd errors in this pipeline: the
scheduler sets `$TMPDIR` to a folder on the node, and a program inside a container may not be able to see this folder.
Several rules deal with this, and @sec-containers explains why.

Some variables you will meet often:

| Variable | Meaning |
|----------|---------|
| `$HOME` | Your home folder |
| `$PATH` | The folders searched for programs |
| `$TMPDIR` | Where programs should put temporary files |
| `$SLURM_JOB_ID` | The job's number, inside a SLURM job |
| `$LOCAL_SCRATCH` | The local disk of the node, on CSC systems |

## Loops and arrays

A `for` loop repeats commands for each item. Here it runs over a pattern that the shell expands to matching files:

```text
$ for file in data/*_R1.fastq.gz; do
      echo "$(basename "$file" _R1.fastq.gz): $(zcat "$file" | wc -l) lines"
  done
sampleA: 160 lines
sampleB: 240 lines
sampleC: 100 lines
```

`$(command)` puts the output of a command into the text, and `basename` removes the folder and the given ending.

An **array** holds several values. You will see them in the binning rules, which collect the names of temporary files:

```text
$ files=(data/sampleA_R1.fastq.gz data/sampleB_R1.fastq.gz)
$ echo "${#files[@]} files, the first is ${files[0]}"
2 files, the first is data/sampleA_R1.fastq.gz
```

`"${files[@]}"` expands to all values, each as its own argument, and `${#files[@]}` gives their number.

Inside a Snakemake rule, you will see these with doubled braces, such as `"${{files[@]}}"`. @sec-first-rule explains why.

## Scripts

A script is a text file with commands. You run it with `bash script.sh`. The first line, starting with `#!`, says which
program runs the file, and a good script starts like this:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Working in $(pwd)"
```

## Permissions

The first column of `ls -l` shows who may do what, for example `-rw-r--r--`: `r` is read, `w` is write and `x` is execute,
in three groups for the owner, the group and everyone else. On a cluster, the group is usually your project, so that
colleagues can read your results.

| Command | What it does |
|---------|--------------|
| `chmod +x script.sh` | Make a script executable |
| `chmod g+rw file` | Let the group read and write |
| `chgrp -R project_2009831 folder` | Change the group of a folder and its content |

## Software modules

A cluster has many versions of many programs, so they aren't all available at once. A system called **environment
modules** makes them available on request:

```bash
module avail snakemake        # which versions exist?
module load snakemake/9.11.6  # make this one available
module list                   # what is loaded now?
```

The run script of the pipeline loads Snakemake this way. These commands weren't run for this book, because the test
cluster has no module system. All other tools of the pipeline come in containers instead, which @sec-containers covers.

## File formats you will meet

This table is only a first map. Part II explains each format where its tool uses it.

| Format | Ending | Content |
|--------|--------|---------|
| FASTQ | `.fastq.gz`, `.fq.gz` | Reads with qualities |
| FASTA | `.fa`, `.fasta`, `.fa.gz` | Sequences without qualities: contigs, genomes, proteins |
| SAM, BAM, CRAM | `.sam`, `.bam`, `.cram` | Reads aligned to a reference. BAM is the binary form, and CRAM is smaller, but needs the reference |
| GFF, GTF | `.gff`, `.gtf` | Positions of genes on sequences |
| TSV | `.tsv`, `.txt` | Tables with tabs between columns |
| YAML | `.yaml`, `.yml` | Configuration files, as used in `config/` |

## What's next

You can now find your way around a cluster's files and read a pipe. The next chapter is about the part that makes a
cluster a cluster: asking the scheduler for resources.
