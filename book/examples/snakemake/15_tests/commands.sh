snakemake --lint text | head -n 12

snakemake --cores 2 --quiet rules

snakemake --generate-unit-tests --cores 1 2>&1 | tail -n 1

find .tests -type f | sort | head -n 12

sed -n 1,40p .tests/unit/test_summary.py

pytest -q .tests/unit 2>&1 | tail -n 3
