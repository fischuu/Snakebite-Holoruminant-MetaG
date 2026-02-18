# Additional tools

There are a few additional tools that are not included into the standard module setup
and which need to be called individually. They will be clustered in the `_extra` modules
for joint running.

## read_annotate_extra

### NCyc
NCyc refers to the NCycDB, which is a curated, integrative database of nitrogen cycling
genes designed for fast and accurate profiling of nitrogen cycle functional genes from
shotgun metagenomic data.

Usage:
```
# Download the prepared reference databases
  cd $PROJECTFOLDER/resources/databases
  wget https://a3s.fi/Holoruminant-data/2026.02.18.ncyc.tar.gz
  
# Unpack the corresponding database
  tar -xvf 2026.02.18.ncyc.tar.gz
  
# Run the tool
  bash run_Snakebite-Holoruminant-MetaG.sh read_annotate__ncyc
```
