library("DiagrammeR")
library("DiagrammeRsvg")
library("rsvg")

# Create a DiagrammeR graph
graph <- grViz("
  digraph snakemake_pipeline {
    graph [layout = dot, rankdir = LR]

    node [shape = box, style = filled, fillcolor = lightblue]
    edge [arrowhead = vee]

    # Define new reads nodes
    input_reads [label = 'Input Reads', shape = folder]
    link [label = 'Link \n Assign names']
    fastqc [label = 'FastQC, v0.12.1 \n Raw reads QC']

    # Define preprocessing nodes
    pre_bowtie2 [label = 'Bowtie2, v2.5.1 \n Decontamination']
    pre_fastp [label = 'Fastp, v0.23.4 \n QC trimming']
    pre_fastqc [label = 'FastQC, v0.12.1']

    # Define the read_annotate
    read_annot_kraken2 [label = 'Kraken2, v2.1.3 \n RefSeqV205_Complete \n Standard_20240112']
    read_annot_humann [label = 'HumanN3, v3.9 \n Chocophlan v201901_v31 \n Uniref uniref90_201901b_full']
    read_annot_metaphlan [label = 'MetaPhlAn, v4.1.1 \n mpa_vJun23_CHOCOPhlAnSGB_202307']
    read_annot_phyloflash [label = 'PhyloFlash, v3.4.2 \n SILVA_SSU.noLSU 138.2']
    read_annot_nonpareil [label = 'Nonpareil, v.3.4.1']
    read_annot_singlem [label = 'SingleM, v0.18.0 \n S4.3.0.GTDB_r220.metapackage_20240523']
    read_annot_sylph [label = 'Sylph, v0.7.0 \n gtdb-r220-c200-dbv1']
    read_annot_diamond [label = 'Diamond, v.2.1.8 \n Cazy 07142024']
    read_annot_krona [label = 'Krona, v.x.x.x']
    
    # Define the read_annotate_extra nodes
    read_annot_ncyc [label = 'NCycDB \n Jul2019']

    # Define assembly nodes
    ass_bowtie2 [label = 'Bowtie2, v2.5.1']
    ass_concoct [label = 'Concoct, v1.1.0']
    ass_drep [label = 'DRep, v3.4.3']
    ass_magscot [label = 'MAGScot, v???']
    ass_maxbin2 [label = 'MaxBin2, v2.2.7']
    ass_megahit [label = 'MEGAHIT, v1.2.9']
    ass_metabat2 [label = 'MetaBAT2, v2.15']
    ass_metaspades [label = 'MetaSPAdes, v4.0.0']
    ass_provided [label = 'Self-provided']

    # Define annotation nodes
    annotate_bakta [label = 'Bakta, v1.9.3']
    annotate_baktamag [label = 'Bakta, v1.9.3 \n bakta_mag']
    annotate_camper [label = 'Camper, v1.0.0']
    annotate_quast [label = 'QUAST, v5.2.0']
    annotate_gtdbtk [label = 'GTDB-Tk, v2.4.0 \n Release 220']
    annotate_dram [label = 'DRAM, v1.5.0 \n 20240524']
    annotate_drammag [label = 'DRAM, v1.5.0 \n 20240524 \n dram_mag']
    annotate_eggnog [label = 'EggNOG, v2.1.12 \n emapperdb-5.0.2']
    annotate_checkm2 [label = 'CheckM2, v1.0.2 \n uniref100.KO.1.dmnd']
    annotate_proteinortho [label = 'Proteinortho, v6.3.1']
    annotate_phylophlan [label = 'PhyloPhlan, v3.1.1']

    # Define the contig annotate nodes
    contig_annotate_prodigal [label = 'Prodigal, v2.6.3']
    contig_annotate_eggnog [label = 'Eggnog, v2.1.12 \n emapperdb-5.0.2']
    contig_annotate_eggnog7 [label = 'Eggnog7, v20251223 \n eggnog7-annotator, v0.1']
    contig_annotate_bowtie [label = 'Bowtie, v2.5.1']
    contig_annotate_camper [label = 'Camper, v1.0.0']
    contig_annotate_hmmer [label = 'HMMER, v3.3.2 \n HydDB 20251126 (2022)']
    contig_annotate_diamond [label = 'Diamond, v.2.1.8 \n HydDB 20251126 (2022)']
    contig_annotate_feature [label = 'FeatureCounts, v2.0.1']
    
    # Define quantify nodes
    quantify_bowtie2 [label = 'Bowtie2, v2.5.1']
    quantify_coverm [label = 'CoverM, v0.6.1']
    quantify_samtools [label = 'Samtools, v1.18']
    

    # Define a representative node for the user input boxes
    pre_host [label = 'Host genomes', style=dotted, color=gray]
    ass_assembler_rep [label = 'Select Assembler', style=dotted, color=gray]
    ass_assembly [label = 'Metagenome Assembly', style=dotted, color=gray]


    # Define edges for input reads
    input_reads -> link
    input_reads -> fastqc
    link -> pre_fastp
    

    # Define edges for preprocessing
    pre_fastp -> pre_host
    pre_host -> pre_bowtie2
    pre_fastp -> pre_fastqc
    pre_bowtie2 -> pre_fastqc
    pre_fastp -> read_annot_kraken2
    pre_bowtie2 -> read_annot_humann
    pre_bowtie2 -> read_annot_metaphlan
    pre_bowtie2 -> read_annot_phyloflash
    pre_bowtie2 -> read_annot_nonpareil
    pre_bowtie2 -> read_annot_singlem
    pre_bowtie2 -> ass_assembler_rep
    pre_bowtie2 -> read_annot_diamond
    pre_bowtie2 -> read_annot_sylph
    pre_bowtie2 -> read_annot_ncyc
    read_annot_kraken2 -> read_annot_krona
    
    # Define edges for assembly
    ass_assembly -> ass_bowtie2
    ass_assembly -> ass_concoct
    ass_bowtie2 -> ass_concoct
    ass_concoct -> ass_magscot
    ass_metabat2 -> ass_magscot
    ass_maxbin2 -> ass_magscot
    ass_magscot -> ass_drep
    ass_assembly -> ass_magscot
    ass_assembly -> ass_maxbin2
    ass_bowtie2 -> ass_maxbin2
    ass_megahit -> ass_assembly
    ass_metaspades -> ass_assembly
    ass_assembly -> ass_metabat2
    ass_bowtie2 -> ass_metabat2

    # Define edges for quantify
    ass_drep -> quantify_bowtie2
    ass_drep -> quantify_coverm
    quantify_bowtie2 -> quantify_coverm
    ass_drep -> quantify_samtools
    quantify_bowtie2 -> quantify_samtools
    
    # Define the edges for annotate
    ass_drep -> annotate_bakta
    ass_magscot -> annotate_baktamag
    ass_magscot -> annotate_drammag
    ass_drep -> annotate_checkm2
    annotate_gtdbtk -> annotate_dram
    ass_drep -> annotate_dram
    ass_drep -> annotate_eggnog
    ass_drep -> annotate_gtdbtk
    ass_drep -> annotate_phylophlan
    annotate_bakta -> annotate_proteinortho
    ass_drep -> annotate_quast
#    dram_dbs -> annotate_dram
    ass_drep -> annotate_camper

    # Define the edges for contig annotate
    ass_assembly -> contig_annotate_prodigal
    contig_annotate_prodigal -> contig_annotate_eggnog
    contig_annotate_prodigal -> contig_annotate_eggnog7
    contig_annotate_prodigal -> contig_annotate_bowtie
    contig_annotate_prodigal -> contig_annotate_camper
    contig_annotate_prodigal -> contig_annotate_hmmer
    contig_annotate_prodigal -> contig_annotate_diamond
    ass_assembly -> contig_annotate_bowtie
    contig_annotate_bowtie -> contig_annotate_feature
    
    # Define edges between nodes and the representative node
    ass_assembler_rep -> ass_megahit
    ass_assembler_rep -> ass_metaspades

    # Define a subgraph to group preprocessing nodes
    subgraph cluster_preprocess {
      label = 'Preprocess'
      style = dashed
      color = lightgray

      pre_bowtie2
      pre_fastp
      pre_fastqc
      pre_host
    }

    # Define a subgraph to group preprocessing nodes
    # Define a subgraph to group assembler nodes
      subgraph cluster_read_annot_all {
        label = ''
        style = dashed
        color = lightgray
        
        subgraph cluster_read_annot {
          label = 'Read Annotate'
          style = dashed
          color = lightgray
    
          read_annot_kraken2
          read_annot_krona
          read_annot_humann
          read_annot_metaphlan
          read_annot_phyloflash
          read_annot_nonpareil
          read_annot_singlem
          read_annot_diamond
          read_annot_sylph
        }
        
          subgraph cluster_read_annot_extra {
          label = 'Read Annotate Extra'
          style = dashed
          color = lightgray
        
          read_annot_ncyc
          }
      }

    # Define a subgraph to group assembly nodes
    subgraph cluster_assemble {
      label = 'Assemble'
      style = dashed
      color = lightgray

      ass_bowtie2
      ass_concoct
      ass_drep
      ass_magscot
      ass_maxbin2
      ass_assembly
      ass_metabat2

      # Define a subgraph to group assembler nodes
      subgraph cluster_assembler {
        label = 'Assembler'
        style = dashed
        color = lightgray

        ass_megahit
        ass_metaspades
        ass_provided
      }
      
       # Define a subgraph to group binner nodes
      subgraph cluster_binner {
        label = 'Binner'
        style = dashed
        color = lightgray

        ass_concoct
        ass_metabat2
        ass_maxbin2
      }
    }

# Define a subgraph to group quantify nodes
    subgraph cluster_quantify {
      label = 'Quantify'
      style = dashed
      color = lightgray

      quantify_bowtie2
      quantify_coverm
      quantify_samtools
    }

    # Define a subgraph to group reads nodes
    subgraph cluster_reads {
      label = 'Reads'
      style = dashed
      color = lightgray

      link
      fastqc
    }

    # Define a subgraph to group contig annotate nodes
    subgraph cluster_contig_annotate {
      label = 'Contig annotate'
      style = dashed
      color = lightgray

      contig_annotate_prodigal
      contig_annotate_camper
      contig_annotate_eggnog
      contig_annotate_eggnog7
      contig_annotate_bowtie
      contig_annotate_feature
      contig_annotate_hmmer
      contig_annotate_diamond
    }

    # Define a subgraph to group annotation nodes
    subgraph cluster_annotate {
      label = 'MAG Annotate'
      style = dashed
      color = lightgray

      annotate_bakta
      annotate_baktamag
      annotate_camper
      annotate_quast
      annotate_gtdbtk
      annotate_dram
      annotate_drammag
      annotate_eggnog
      annotate_checkm2
      annotate_proteinortho
      annotate_phylophlan
    }
  }
")

# Convert to SVG and save as PNG
graph_svg <- export_svg(graph)
rsvg_png(charToRaw(graph_svg), "flowchart/flowchart.png", width = 2876)


# Render the graph
graph

# Export to SVG
svg_code <- export_svg(graph)

# Save as an HTML file
html_code <- paste0('<html><body>', svg_code, '</body></html>')
write(html_code, file = "pipeline_diagram.html")

