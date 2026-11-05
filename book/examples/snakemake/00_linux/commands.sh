pwd

ls data

ls -lh data | head -n 4

mkdir -p project/reads
cp data/sampleA_R1.fastq.gz project/reads/
ls project/reads

ln -s "$PWD/data/sampleB_R1.fastq.gz" project/reads/sampleB.fastq.gz
ls -l project/reads | cut -c1-10,42-

zcat data/sampleA_R1.fastq.gz | head -n 4

zcat data/sampleA_R1.fastq.gz | wc -l

zcat data/sampleA_R1.fastq.gz | awk 'NR % 4 == 2' | head -n 2 | cut -c1-40

zcat data/sampleA_R1.fastq.gz | awk 'NR % 4 == 2 { print length($0) }' | sort -n | tail -n 1

zcat data/sampleA_R1.fastq.gz | grep -c '^@sampleA'

zcat data/sampleA_R1.fastq.gz > sampleA.fastq
gzip sampleA.fastq
ls sampleA*

zcat data/sampleA_R1.fastq.gz | wc -l > lines.txt
cat lines.txt

ls data/does_not_exist.gz > listing.txt 2> errors.txt; echo "exit code of ls: $?"
cat errors.txt

true; echo "true gives $?"; false; echo "false gives $?"

false | true; echo "without pipefail: $?"

set -o pipefail; false | true; echo "with pipefail: $?"

SAMPLE=sampleA
echo "The sample is $SAMPLE and its file is data/${SAMPLE}_R1.fastq.gz"

export MY_SETTING=42
bash -c 'echo "A new program sees MY_SETTING=$MY_SETTING and YOUR_SETTING=$YOUR_SETTING"'

for file in data/*_R1.fastq.gz; do
    echo "$(basename "$file" _R1.fastq.gz): $(zcat "$file" | wc -l) lines"
done

files=(data/sampleA_R1.fastq.gz data/sampleB_R1.fastq.gz)
echo "${#files[@]} files, the first is ${files[0]}"

paste <(zcat data/sampleA_R1.fastq.gz | head -n 1) <(zcat data/sampleB_R1.fastq.gz | head -n 1)

mkdir -p archive/inner
echo "hello" > archive/inner/file.txt
tar -czf archive.tar.gz archive
tar -tzf archive.tar.gz

du -sh data

df -h /scratch | tail -n 1 | awk '{print "free space:", $4}'
