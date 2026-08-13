
process MULTICDHIT {

    // label 'process_low'

    input:
    path(allcds)
    path(allpep)
    path(task_num)

    output:
    path("*_geneset_protein.fa"),emit:"pep"
    path("*_geneset_gene.fa"),emit:"cds"
    path("*_geneset_gene_length.xls"),emit:"gene_length"
    path("*_geneset_gene_ID_mapping.xls"),emit:"gene_info"
    path("*_geneset_cdhit_clstr.txt"),emit:"clstr"
    path("split/*.fa"),emit:"split"
    path("geneset_Gene_report"),emit:"geneset_gene_report"

    script:
    def split_num = task_num.getSimpleName().toInteger()
    def cdhit_queue_system = params.cdhit_queue_system ?: params.drep_queue_system ?: 'slurm'
    def cdhit_queue = params.cdhit_queue ?: params.drep_queue ?: task.queue
    def cdhit_queue_type
    def cdhit_queue_options

    switch (cdhit_queue_system.toLowerCase()) {
        case 'sge':
            cdhit_queue_type = 'SGE'
            cdhit_queue_options = "-A ${params.Account} -q ${cdhit_queue} -pe smp ${params.cdhit_split_run_eachthread} -l h_rss=${params.cdhit_split_mem}G,mem_free=${params.cdhit_split_mem}G"
            break
        case 'pbs':
        case 'pbspro':
            cdhit_queue_type = 'PBS'
            cdhit_queue_options = "-A ${params.Account} -q ${cdhit_queue} -l nodes=1:ppn=${params.cdhit_split_run_eachthread} -l mem=${params.cdhit_split_mem}gb"
            break
        case 'slurm':
            cdhit_queue_type = 'slurm'
            cdhit_queue_options = "-A ${params.Account} -p ${cdhit_queue} -c ${params.cdhit_split_run_eachthread} --mem ${params.cdhit_split_mem}G"
            break
        default:
            error "Unsupported CD-HIT child scheduler: ${cdhit_queue_system}"
    }
    
    """
    
    cd-hit-cluster.pl -i ${allcds} -o unique.fa --P cd-hit-est \\
        --prog_options \"-c 0.95 -aS 0.9 -d 0 -M 0 -T ${params.cdhit_split_run_eachthread}\" --S ${split_num} \\
        --queue_options \"${cdhit_queue_options}\" --T ${cdhit_queue_type} --Q 100

    mv unique.fa.clstr ${params.pipeline_prefix}_geneset_cdhit_clstr.txt

    merge_psort_pep.pl -fa unique.fa -input ${allpep} \\
        -preprocessed -cpu ${task.cpus} \\
        -output unique_protein.fa

    awk '/^>/ { printf(">NC_%010d\\n", ++count); next } { print }' unique.fa > ${params.pipeline_prefix}_geneset_gene.fa
    paste <(grep ">" unique.fa | cut -d '>' -f2 | cut -d ' ' -f1) <(grep ">" ${params.pipeline_prefix}_geneset_gene.fa | cut -d '>' -f2) > ${params.pipeline_prefix}_geneset_gene_ID_mapping.xls

    awk '/^>/ { printf(">NC_%010d\\n", ++count); next } { print }' unique_protein.fa > ${params.pipeline_prefix}_geneset_protein.fa

    rm -rf unique.fa unique_protein.fa
    
    seqkit fx2tab -l -i -n ${params.pipeline_prefix}_geneset_gene.fa | awk -v OFS='\\t' '{print NR, \$0}' | sed '1iID\tname\tlength' > ${params.pipeline_prefix}_geneset_gene_length.xls

    seqkit split ${params.pipeline_prefix}_geneset_protein.fa -s ${params.eggnog_protein_chunk_size} -O split
    
    mkdir geneset_Gene_report
    cp ${params.pipeline_prefix}_geneset_gene_length.xls geneset_Gene_report/genesetLenStat.xls
    

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cdhit: \$(cd-hit-est 2>&1 | grep 'CD-HIT version' | sed 's/CD-HIT //')
    END_VERSIONS

    """

    stub:
    """
    touch ${params.pipeline_prefix}_geneset_protein.fa
    touch ${params.pipeline_prefix}_geneset_gene.fa
    touch ${params.pipeline_prefix}_geneset_gene_length.xls
    touch ${params.pipeline_prefix}_geneset_gene_ID_mapping.xls
    touch ${params.pipeline_prefix}_geneset_cdhit_clstr.txt
    mkdir -p split
    touch split/empty_file.fa
    mkdir -p geneset_Gene_report
    touch geneset_Gene_report/genesetLenStat.xls
    """

}
