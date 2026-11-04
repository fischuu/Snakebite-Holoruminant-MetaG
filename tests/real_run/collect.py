#!/usr/bin/env python3
"""Pack the small things of a complete run into one archive. Call it in the project folder.

The archive holds the records of run_stage.sh, the tool versions, the configuration, the job logs,
the beginning of every result file, and checksums. The results stay where they are, nothing in
results/ is changed, and no read or assembly is included apart from its first lines.

Only the Python standard library is used, so that any python3 on a cluster can run this.
"""

import gzip
import hashlib
import os
import shutil
import sys
import tarfile
import time

WHOLE_FILE = 1024 * 1024  # text files up to this size are kept whole
HEAD_LINES = 200  # of bigger text files, these many lines are kept
SEQUENCE_LINES = 12  # of sequences, only these many lines are kept
LINE_WIDTH = 500  # characters per kept line of a big file
LOG_LINES = 300  # last lines of each job log
CHECKSUM_LIMIT = 200 * 1024 * 1024  # bigger files get no checksum, it would take too long

SEQUENCE = (".fa", ".fasta", ".fna", ".faa", ".ffn", ".fq", ".fastq", ".gff", ".gff3", ".gtf", ".gbff", ".gbk", ".embl",
            ".sam")
BINARY = (".bam", ".cram", ".crai", ".bai", ".gzi", ".dmnd", ".pdf", ".png", ".zip", ".npz", ".pkl", ".pickle",
          ".h5", ".bt2", ".bt2l", ".tar", ".simg", ".sif", ".rds", ".rda", ".hmm", ".fai")


def inner_name(path):
    return path[:-3] if path.endswith(".gz") else path


def is_binary(path):
    return inner_name(path).lower().endswith(BINARY) or path.lower().endswith(".tar.gz")


def is_sequence(path):
    return inner_name(path).lower().endswith(SEQUENCE)


def opener(path):
    if path.endswith(".gz"):
        return gzip.open(path, "rt", errors="replace")
    return open(path, "rt", errors="replace")


def sample(path, target):
    """Copy a text file, or its first lines. Tells whether something was written."""
    size = os.path.getsize(path)
    if not path.endswith(".gz") and not is_sequence(path) and size <= WHOLE_FILE:
        os.makedirs(os.path.dirname(target), exist_ok=True)
        shutil.copyfile(path, target)
        return True
    limit = SEQUENCE_LINES if is_sequence(path) else HEAD_LINES
    lines = []
    try:
        with opener(path) as handle:
            for number, line in enumerate(handle):
                if number >= limit:
                    break
                lines.append(line[:LINE_WIDTH].rstrip("\n"))
    except (OSError, EOFError, UnicodeError):
        return False
    if any("\0" in line for line in lines):
        return False
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(inner_name(target), "w") as handle:
        handle.write("\n".join(lines) + "\n")
    return True


def md5(path):
    digest = hashlib.md5()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def tail(path, target, lines):
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(path, "rt", errors="replace") as handle:
        kept = handle.readlines()[-lines:]
    with open(target, "w") as handle:
        handle.writelines(kept)


def walk(folder):
    for root, _, names in os.walk(folder):
        for name in sorted(names):
            yield os.path.join(root, name)


def main():
    if not os.path.isdir("book_run") or not os.path.isfile("config/config.yaml"):
        sys.exit("ERROR: run this in the project folder that setup_project.sh created")
    stamp = time.strftime("%Y%m%d_%H%M%S")
    name = "book_run_" + stamp
    if os.path.exists(name):
        sys.exit("ERROR: " + name + " exists already")
    os.makedirs(name)

    shutil.copytree("book_run", os.path.join(name, "records"))
    shutil.copytree("config", os.path.join(name, "config"), symlinks=True)
    shutil.copyfile("run_Snakebite-Holoruminant-MetaG.sh", os.path.join(name, "run_Snakebite-Holoruminant-MetaG.sh"))

    if os.path.isdir(".snakemake/log"):
        for path in walk(".snakemake/log"):
            tail(path, os.path.join(name, "snakemake_logs", os.path.basename(path)), 100000)
    jobs = 0
    if os.path.isdir(".snakemake/slurm_logs"):
        for path in walk(".snakemake/slurm_logs"):
            tail(path, os.path.join(name, path[len(".snakemake/"):]), LOG_LINES)
            jobs += 1

    files = samples = 0
    with open(os.path.join(name, "result_files.tsv"), "w") as listing:
        listing.write("size\tmd5\tpath\n")
        for path in walk("results") if os.path.isdir("results") else []:
            if os.path.islink(path) and not os.path.exists(path):
                listing.write("0\tbroken-link\t" + path + "\n")
                continue
            size = os.path.getsize(path)
            checksum = md5(path) if size <= CHECKSUM_LIMIT else "too-big"
            listing.write(str(size) + "\t" + checksum + "\t" + path + "\n")
            files += 1
            if size and not is_binary(path) and sample(path, os.path.join(name, "samples", path)):
                samples += 1

    # The reports are small, and they are useful whole
    if os.path.isdir("Rreports"):
        shutil.copytree("Rreports", os.path.join(name, "Rreports"))

    archive = name + ".tar.gz"
    with tarfile.open(archive, "w:gz") as tar:
        tar.add(name)
    shutil.rmtree(name)
    print("{} result files listed, {} sampled, {} job logs".format(files, samples, jobs))
    print("Archive: {} ({:.1f} MB)".format(os.path.abspath(archive), os.path.getsize(archive) / 1e6))


if __name__ == "__main__":
    main()
