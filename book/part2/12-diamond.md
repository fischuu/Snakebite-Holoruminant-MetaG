# DIAMOND {#sec-tool-diamond}

## What it does

DIAMOND compares DNA or protein sequences with a protein database, as BLAST does, but thousands of times faster. It's the tool to use when you want to know which known proteins your reads or genes resemble. It's often a hidden component of other tools too, like eggNOG-mapper, HUMAnN, CAMPER and DRAM.

## Why compare at the protein level

DNA changes faster than proteins, because different codons can code for the same amino acid, so two distantly related genes can look unrelated as DNA, but alike as proteins. So to find the function of a gene, you often want to compare proteins.

## How it works

Like BLAST, DIAMOND looks for short exact matches, called seeds, and extends them into alignments. To make that fast, it uses a few tricks: it reduces the alphabet of amino acids, it uses seeds with a pattern of positions that have to match, and it sorts both the query seeds and the database seeds and walks through both lists together.

The sensitivity is a choice. The default is quick, and it finds strong similarities. Options such as `--sensitive` and `--ultra-sensitive` find more distant matches, and they take longer.

## Input

| Command | Input |
|---------|-------|
| `diamond makedb` | Protein FASTA, which it turns into a `.dmnd` database |
| `diamond blastx` | DNA reads or genes (`-q`), translated in all six reading frames, and a database (`-d`) |
| `diamond blastp` | Proteins (`-q`), and a database (`-d`) |

## Output

By default, DIAMOND writes the tabular format of BLAST (format 6), with these columns:

| Column | Content |
|--------|---------|
| 1, 2 | Query and database sequence |
| 3 | Percentage of identical positions |
| 4 | Length of the alignment |
| 5, 6 | Mismatches and gap openings |
| 7, 8 | Start and end on the query |
| 9, 10 | Start and end on the database sequence |
| 11 | E-value: how many such hits you'd expect by chance |
| 12 | Bit score |

A query with no hit doesn't appear. So to get the share of reads with a hit, you have to divide by the number of reads yourself.

## When to use it

Use it to search reads or proteins against a specific protein database, when you're interested in a certain function: CAZymes, hydrogenases, antibiotic resistance. Read-based use has one great advantage, in that it needs no assembly. It also has weaknesses: a read of 100 bases gives only about 33 amino acids, so distant matches are uncertain.

Comparing reads with a whole general database like UniRef takes much longer, and it can be done, but specialized tools like HUMAnN do it in a smarter way.

## In this pipeline

| Rule | Mode | Query | Database |
|------|------|-------|----------|
| `read_annotate__diamond__assign` | `blastx` | Each mate of the clean reads | `diamond` in `features.yaml`, by default CAZy |
| `contig_annotate__diamond__assign` | `blastp` | Proteins from Prodigal | `diamond_contig_protein`, by default HydDB |

The rule for reads uses `--max-target-seqs 1`, so it reports just one hit per read, and this makes counting simple. Both rules first copy the database to fast storage, as @sec-module-read-annotate explains.

Sensitivity stays at the default, so distant homologs may be missed.

An R script turns the hits of the reads into feature tables, in `read_annotate__diamond__summarise`. It's chosen by the name of the database, so for a new database you have to provide such a script.

## Pitfalls

- **`--max-target-seqs 1` doesn't mean the best hit.** DIAMOND reports the best hit it finds with the current settings, and with the fast defaults this is usually, but not always, the best one in the database.
- **Memory.** It's controlled by the block size `-b`, and the number of chunks `-c`. By default a job of this kind needs some tens of GB. If it's killed for memory, make the blocks smaller.
- **The two mates count separately.** In the rule for reads, each mate gets its own hit. Don't count them as two independent observations of a fragment.
- **Hits aren't functions.** A hit to an enzyme with low identity doesn't prove the same activity. Filter by identity and by alignment length.

## Reference

Buchfink B, Reuter K, Drost HG (2021). Sensitive protein alignments at tree-of-life scale using DIAMOND. *Nature Methods*. <https://doi.org/10.1038/s41592-021-01101-x>
