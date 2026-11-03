#!/bin/bash

# Input FASTA file
input_fasta=$1

# Create a directory to store the individual fasta files
output_dir=$2
mkdir -p $output_dir

# Initialize variables
entry=""
header=""
index=0

# Function to sanitize and truncate filenames
sanitize_filename() {
    local filename="$1"
    # Remove the leading '>'
    filename="${filename#>}"
    # Replace spaces and special characters with underscores
    filename=$(echo "$filename" | tr -c '[:alnum:]_' '_')
    # Truncate the filename to the first 50 characters
    filename=${filename:0:50}
    echo "$filename"
}

# Read the input FASTA file line by line
while IFS= read -r line || [ -n "$line" ]
do
    if [[ $line == ">"* ]]; then
        # If the line starts with '>', it's a header line
        # Save the previous entry to a file
        if [[ -n $header ]]; then
            # Create a sanitized and truncated filename from the header
            filename=$(sanitize_filename "$header")
            # Add the running index to the filename
            filename="${filename}_${index}"
            echo -e "$entry" > "$output_dir/$filename.fasta"
            index=$((index + 1))
        fi
        # Start a new entry
        header=$line
        entry="$line"
    else
        # If it's not a header line, add it to the current entry
        entry+=$'\n'"$line"
    fi
done < "$input_fasta"

# Save the last entry to a file
if [[ -n $header ]]; then
    filename=$(sanitize_filename "$header")
    filename="${filename}_${index}"
    echo -e "$entry" > "$output_dir/$filename.fasta"
fi

echo "FASTA entries have been split into individual files in the '$output_dir' directory."
