# Containers {#sec-containers}

This pipeline runs about 40 tools. Each has its own dependencies, some of these conflict with each other, and results can change between versions. If everyone had to install all of this, few people could run the pipeline, and no two installations would be the same. **Containers** solve this problem.

## What a container is

A **container image** is a file that holds a program together with everything it needs: libraries, other tools, even a small operating system. When you run a program from an image, it sees the files of the image instead of those of the host system, while it still uses the host's Linux kernel, CPU and memory. It isn't a virtual machine, so it starts right away and has no noticeable slowdown.

For our purposes, this brings three benefits:

- **Nothing to install**, apart from the program that runs the containers.
- **The same software everywhere.** A given image contains the same version of each tool on any computer.
- **Reproducibility.** When a paper names an image, others can use exactly the same software years later.

## Docker and Apptainer

Two programs come up constantly, and they work with the same images:

| Program | Used on | How it runs |
|---------|---------|-------------|
| **Docker** | Laptops and servers | With a background service and root rights, which clusters don't allow |
| **Apptainer** (formerly Singularity) | Clusters | As your own user, without a service |

Images are typically built and published with Docker, and on a cluster Apptainer converts them into a single file ending in `.sif`. That is why the configuration of this pipeline holds addresses starting with `docker://`, though it runs with Apptainer on Puhti. Snakemake's option is still called `--use-singularity`, for historical reasons.

An image's address has a name and a **tag**, which usually is a version:

```
docker://fischuu/hrp_bowtie2:0.1
         ------- ----------- ---
         owner   name        tag
```

Always use a specific tag. An address without one means `latest`, which changes over time, and your results may change with it.

## Running a tool from a container

This section uses a real container of the pipeline. We ran it with Docker, because Apptainer can't start containers on the Mac where the examples of this book were run: it runs in an emulator there, and can only download images.

So the output comes from this Docker command:

```text
$ docker run --rm --platform linux/amd64 --entrypoint bash fischuu/hrp_bowtie2:0.1 -c '
      bowtie2 --version 2>&1 | head -1 | cut -c1-90
      samtools --version | head -1
      head -1 /etc/os-release
      which bowtie2 samtools
      ls /scratch'
/opt/conda/envs/hrp_bowtie2/bin/bowtie2-align-s version 2.5.1
samtools 1.18
PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"
/opt/conda/envs/hrp_bowtie2/bin/bowtie2
/opt/conda/envs/hrp_bowtie2/bin/samtools
ls: cannot access '/scratch': No such file or directory
```

This shows the main properties of a container: it has its own tools, it has its own operating system, and **it doesn't see the host's folders unless you allow it**. The last line is exactly the point. Inside this container, `/scratch` doesn't exist.

On the cluster, the same thing looks like this. These commands weren't run for this book, so they have no output here:

```bash
# Download the image and convert it into one file
apptainer pull bowtie2.sif docker://fischuu/hrp_bowtie2:0.1

# Run one command inside
apptainer exec bowtie2.sif bowtie2 --version

# Run a command that needs your data: make the folder visible
apptainer exec --bind /scratch bowtie2.sif ls /scratch

# Open a shell inside, to look around
apptainer shell --bind /scratch bowtie2.sif
```

## Bind mounts: what a container can see

Making a folder visible in a container is called a **bind mount**, and `--bind` (`-B`) does this. Apptainer binds a few things on its own, such as your home folder and the current folder, but other disks need to be named.

This is the source of the most common container error:

```
No such file or directory
```

The file exists, and you can see it from outside. But the program in the container can't, because its folder wasn't bound. So the pipeline's run script binds all important places on Puhti, and if you use another cluster, this line is what you have to adjust:

```bash
--singularity-args "-B /scratch,/projappl,/users,/dev/shm:/dev/shm,/run,$projectFolder/tmp:/tmp"
```

`source:target` binds a folder under another name. Here, `$projectFolder/tmp:/tmp` means that `/tmp` inside the container is the folder `tmp/` of your project.

### The `TMPDIR` trap

That last bind has a side effect, which caused real bugs in this pipeline. SLURM sets `$TMPDIR` to a folder such as `/tmp/job_12345` on the node's real `/tmp`. Inside the container, the environment variable is still set, but `/tmp` is now a different folder, and `job_12345` doesn't exist there. Tools that write temporary files to `$TMPDIR` then fail, often with a confusing message that says nothing about temporary files.

So you will see this in several rules, like those for prodigal in MAGScoT, DRAM and Bakta. The rule creates its own folder, and sets the variable itself:

```bash
TMPDIR="/tmp/magscot_prodigal.{wildcards.assembly_id}.{resources.attempt}.$$"
export TMPDIR
mkdir -p "$TMPDIR"
```

`$$` is the shell's process number. It makes the name unique, since this `/tmp` is one folder shared by all jobs in the project.

## Containers in Snakemake

A rule names its container with `container:`:

```python
rule quantify__bowtie2__build:
    input:
        MAG_CATALOGUE,
    output:
        index=touch(MAG_INDEX / "dereplicated_genomes"),
    container:
        docker["bowtie2"]
    shell:
        "bowtie2-build --threads {threads} {input} {output.index}"
```

With `--use-singularity`, Snakemake downloads each image once, and then runs the whole `shell:` block inside it. Without the option, it ignores `container:`, and runs the command on the host.

In this pipeline, `docker` is a dictionary loaded from `config/.docker.yml`, which holds the images:

```yaml
assemble: "docker://fischuu/hrp_assemble:0.2"
bowtie2: "docker://fischuu/hrp_bowtie2:0.1"
concoct: "docker://fischuu/hrp_concoct:0.1"
```

Most images hold the tools of one module or a tool with special needs, and some come from elsewhere, like those for 4CAC, REMAG and Tiara. @sec-tool-versions lists all of them, with the versions they contain.

Keep the following in mind:

- **Downloading takes time and space.** Images are often several gigabytes. The option `--singularity-prefix` keeps them in the project folder, and the variables `APPTAINER_TMPDIR` and `APPTAINER_CACHEDIR` in the run script send the temporary files of the conversion to scratch. Without these, they would go to your home folder, and fill it up.
- **A shell script in `workflow/scripts/` has to be visible in the container too.** So the pipeline folder has to be under a bound path, and in the run script, `/users` and `/projappl` are bound for this reason.
- **All tools in a rule must be in that rule's container.** A rule that calls `samtools` and `bowtie2` needs an image that has both. This is why the images group tools by module.
- **Debugging in a container** works as you would expect: open a shell in the rule's image, go to the project folder, and run the rendered command by hand.

```bash
apptainer shell --bind /scratch,/projappl,/users docker_images/<the image>.simg
```

To find which image file belongs to a rule, look at a dry run with `-p`, or at the rule's SLURM log, which names the image in use.

## What about conda?

Snakemake can also create **conda environments** for rules, using the directive `conda:`. Many workflows do that. This pipeline uses containers only: the images save the time of solving and installing environments on every system, and they keep working when packages disappear from a channel. The images themselves were built with conda inside, which is the `/opt/conda/envs/hrp_bowtie2` you can see in the output above.

## Summary

- A container bundles a tool and its dependencies, and the host's folders stay invisible unless you bind them.
- Docker builds and shares the images, and Apptainer runs them on clusters.
- `container:` names the image of a rule, and `--use-singularity` makes Snakemake use it.
- "No such file or directory" in a container usually means a missing bind.
- `$TMPDIR` set from outside may not exist inside.
