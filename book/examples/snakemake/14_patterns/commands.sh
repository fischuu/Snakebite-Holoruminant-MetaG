tree -a config workflow

PIPELINE_DEBUG=1 bash run_pipeline.sh qc -n --quiet rules

bash run_pipeline.sh qc --quiet rules

ls results/qc

cat results/qc/fragile.log.try1

cat results/qc/fragile.log

sacct -X --format=JobID,Comment%24,Partition,AllocCPUS,ReqMem,State | tail -n 4
