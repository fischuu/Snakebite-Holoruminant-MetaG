# The Python used in Snakefiles, one idea per block. Run with: python python_basics.py
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
