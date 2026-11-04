#!/usr/bin/env bash
# Start all services of the one-node cluster and register an account for the examples.
set -e
mkdir -p /run/munge /run/mysqld
chown -R munge:munge /run/munge /etc/munge /var/lib/munge /var/log/munge 2>/dev/null || true
[ -s /etc/munge/munge.key ] || { dd if=/dev/urandom bs=1 count=1024 of=/etc/munge/munge.key 2>/dev/null; chown munge:munge /etc/munge/munge.key; chmod 400 /etc/munge/munge.key; }
su -s /bin/bash munge -c "munged --force" || munged --force
chown -R mysql:mysql /run/mysqld /var/lib/mysql
mysqld_safe --skip-networking=0 --bind-address=127.0.0.1 > /dev/null 2>&1 &
for i in $(seq 1 60); do mysqladmin ping --silent 2>/dev/null && break; sleep 1; done
mysql -e "CREATE DATABASE IF NOT EXISTS slurm_acct_db; CREATE USER IF NOT EXISTS 'slurm'@'localhost' IDENTIFIED BY 'slurm'; GRANT ALL ON slurm_acct_db.* TO 'slurm'@'localhost'; FLUSH PRIVILEGES;"
slurmdbd
for i in $(seq 1 30); do sacctmgr -n list cluster > /dev/null 2>&1 && break; sleep 1; done
sacctmgr -i add cluster minicluster > /dev/null 2>&1 || true
sacctmgr -i add account project_demo Description="Examples" > /dev/null 2>&1 || true
sacctmgr -i add user root account=project_demo > /dev/null 2>&1 || true
slurmctld
slurmd
for i in $(seq 1 30); do sinfo -h -o %T 2>/dev/null | grep -q -E 'idle|mix' && break; sleep 1; done
sinfo
