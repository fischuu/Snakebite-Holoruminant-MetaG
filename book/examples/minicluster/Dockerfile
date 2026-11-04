# A one-node SLURM cluster with Snakemake, used to run the examples of the book on any computer with
# Docker. It behaves like a small HPC system: you submit jobs with sbatch, and sacct reports on them.
FROM debian:trixie-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        slurm-wlm slurmdbd mariadb-server munge procps less tree graphviz \
        python3 python3-venv ca-certificates gawk \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/snakemake \
    && /opt/snakemake/bin/pip install --no-cache-dir \
        "snakemake==9.11.6" "snakemake-executor-plugin-slurm" pandas pytest \
    && ln -s /opt/snakemake/bin/snakemake /usr/local/bin/snakemake \
    && ln -s /opt/snakemake/bin/python /usr/local/bin/python \
    && ln -s /opt/snakemake/bin/pytest /usr/local/bin/pytest

# Apptainer has official packages for x86-64 only, which is also what the pipeline's containers need
RUN if [ "$(dpkg --print-architecture)" = "amd64" ]; then \
        apt-get update && apt-get install -y --no-install-recommends curl uidmap squashfs-tools fuse2fs fakeroot \
        && curl -sSL -o /tmp/apptainer.deb https://github.com/apptainer/apptainer/releases/download/v1.5.5/apptainer_1.5.5-trixie+_amd64.deb \
        && apt-get install -y /tmp/apptainer.deb \
        && rm -rf /tmp/apptainer.deb /var/lib/apt/lists/*; \
    fi

COPY slurm.conf slurmdbd.conf cgroup.conf gres.conf /etc/slurm/
COPY start-cluster.sh /usr/local/bin/start-cluster
RUN chmod +x /usr/local/bin/start-cluster && chmod 600 /etc/slurm/slurmdbd.conf \
    && mkdir -p /var/spool/slurmctld /var/spool/slurmd /var/log/slurm /run/munge /scratch/project_demo /work

WORKDIR /work
