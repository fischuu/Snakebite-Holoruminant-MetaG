# What the Snakefile does with samples.tsv, step by step. Run with: python pandas_samples.py
import pandas as pd

samples = pd.read_table("samples.tsv")
print(samples[["sample_id", "assembly_ids"]])

samples["assembly_id"] = samples["assembly_ids"].map(lambda cell: cell.replace(" ", "").split(","))
print(samples[["sample_id", "assembly_id"]])

samples = samples.explode("assembly_id")
print(samples[["sample_id", "assembly_id"]])

members = samples[samples["assembly_id"] == "combined"]
print(list(zip(members["sample_id"], members["library_id"])))
