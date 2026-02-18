#!/usr/bin/env python3
import argparse
import gzip

def rename_contigs(input_fasta, assembly_name, gzip_output=True):
    output_fasta = f"{assembly_name}.fa"
    if gzip_output:
        output_fasta += ".gz"

    # Detect if input is gzipped
    open_func_in = gzip.open if input_fasta.endswith(".gz") else open
    open_func_out = gzip.open if gzip_output else open

    with open_func_in(input_fasta, "rt") as infile, open_func_out(output_fasta, "wt") as outfile:
        contig_index = 1
        for line in infile:
            if line.startswith(">"):
                new_header = f">{assembly_name}:bin_NA@contig_{contig_index:08d}\n"
                outfile.write(new_header)
                contig_index += 1
            else:
                outfile.write(line)

    print(f"Renamed contigs written to {output_fasta} with assembly name '{assembly_name}'")

def main():
    parser = argparse.ArgumentParser(
        description="Rename contigs in a FASTA file to <assembly>:bin_NA@contig_######## format"
    )
    parser.add_argument("-i", "--input", required=True, help="Input FASTA file (can be .fa or .fa.gz)")
    parser.add_argument("-a", "--assembly", required=True, help="Assembly name to use in headers and output filename")
    parser.add_argument("--no-gzip", action="store_true", help="Do not gzip output (default is gzipped)")

    args = parser.parse_args()
    rename_contigs(args.input, args.assembly, gzip_output=not args.no_gzip)

if __name__ == "__main__":
    main()
