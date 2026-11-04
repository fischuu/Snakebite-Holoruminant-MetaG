# Krona {#sec-tool-krona}

## What it does

Krona draws a taxonomic profile as an interactive pie chart with many rings. The inner rings are the high ranks, and they get finer toward the outside. You can click on any part to zoom into it. The result is a single HTML file, which needs nothing but a browser, so it's easy to share.

It's a tool for looking at data and showing it. It doesn't compute anything new.

## Input

`ktImportTaxonomy` reads a table with a taxon number per line. The options say which column holds what:

| Option | Meaning | Default |
|--------|---------|---------|
| `-q` | Column of the query ID, such as a read name | 1 |
| `-t` | Column of the taxon number | 2 |
| `-m` | Column of the magnitude, such as a count. Without it, each line counts once | None |
| `--tax` | Folder of the taxonomy database | Inside the installation |

The taxonomy is a small database (`taxonomy.tab`), and it has to fit the taxon numbers in your data.

## Output

One HTML file. Everything is inside it, and you can add several samples to a single chart.

## When to use it

Use it for exploring one or a few samples, and for showing a colleague what's in them. For comparing many samples, a table or a bar chart works better, as it's hard to compare two pie charts by eye.

## In this pipeline

The rule `read_annotate__krona__visualize` makes one chart per sample and Kraken2 database, from the report:

```bash
ktImportTaxonomy -t 5 -m 3 {input} -o {output} --tax {params.krona_db}
```

The columns are those of a Kraken2 report, which @sec-tool-kraken2 lists: the taxon is in column 5, and the reads assigned directly to it are in column 3.

Krona prints `Score column already in use; not reading scores`. This is harmless: the default column for scores is 3 too, and a report has no scores.

::: {.callout-warning}
## Charts from versions before 0.4.69 are wrong
The rule used to say `-q 2 -t 3`. These options fit the per-read output of Kraken2, in which column 2 is the read name and column 3 is the taxon. But the rule reads the report, in which these two columns are read counts, and so Krona took a count for a taxon number.

In a test with the real tool and the pipeline's taxonomy database, on a small report written by hand, 800 reads assigned to *Escherichia coli* (taxon 562) appeared as *Ancylobacter aquaticus*. `tests/krona/run_test.sh` now checks this. The Kraken2 reports themselves were always right.
:::

## On real data

@sec-tutorial-read-annotate shows it drawing a real report of Kraken2, with a toy database. Charts on these data with a real database will come from a complete run on a cluster, as @sec-tutorial-waiting says.

## Pitfalls

- **A wrong column gives no error**, as this bug shows. Krona draws whatever it gets, so check a chart against the table it comes from.
- **Counts are added up by Krona.** Use the column of the reads assigned directly to a taxon, and not the one with the whole clade. Otherwise, reads get counted several times.
- **An old taxonomy.** Taxon numbers that aren't in the database appear as "No hits". The taxonomy should be about as recent as the database of the classifier.

## Reference

Ondov BD, Bergman NH, Phillippy AM (2011). Interactive metagenomic visualization in a Web browser. *BMC Bioinformatics*. <https://doi.org/10.1186/1471-2105-12-385>
