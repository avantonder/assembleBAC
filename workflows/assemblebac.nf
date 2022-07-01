/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowAssembleBac.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.multiqc_config]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config        = file("$projectDir/assets/multiqc_config.yml",       checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? file(params.multiqc_config) : []

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//

// Local: Sub-workflows
include { INPUT_CHECK                 } from '../subworkflows/local/input_check'
include { FASTQC_FASTP                } from '../subworkflows/local/fastqc_fastp'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules

include { SHOVILL } from './modules/nf-core/modules/shovill/main'
include { PROKKA  } from './modules/nf-core/modules/prokka/main'
include { QUAST   } from './modules/nf-core/modules/quast/main'

include { MULTIQC                                                 } from '../modules/nf-core/modules/multiqc/main'
include { MULTIQC_TSV_FROM_LIST as MULTIQC_TSV_FAIL_READS         } from '../modules/local/multiqc_tsv_from_list'
include { CUSTOM_DUMPSOFTWAREVERSIONS                             } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main' 

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []
def fail_mapped_reads = [:]

workflow ASSEMBLEBAC {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    //
    // SUBWORKFLOW: Read QC and trim adapters
    //
    FASTQC_FASTP (
        INPUT_CHECK.out.reads,
        params.save_trimmed_fail,
        false
    )
    ch_variants_fastq = FASTQC_FASTP.out.reads
    ch_versions = ch_versions.mix(FASTQC_FASTP.out.versions)

    //
    // Filter empty FastQ files after adapter trimming
    //
    ch_fail_reads_multiqc = Channel.empty()
    if (!params.skip_fastp) {
        ch_variants_fastq
            .join(FASTQC_FASTP.out.trim_json)
            .map {
                meta, reads, json ->
                    pass = WorkflowBacQC.getFastpReadsAfterFiltering(json) > 0
                    [ meta, reads, json, pass ]
            }
            .set { ch_pass_fail_reads }

        ch_pass_fail_reads
            .map { meta, reads, json, pass -> if (pass) [ meta, reads ] }
            .set { ch_variants_fastq }

        ch_pass_fail_reads
            .map {
                meta, reads, json, pass ->
                if (!pass) {
                    fail_mapped_reads[meta.id] = 0
                    num_reads = WorkflowBacQC.getFastpReadsBeforeFiltering(json)
                    return [ "$meta.id\t$num_reads" ]
                }
            }
            .set { ch_pass_fail_reads }

        MULTIQC_TSV_FAIL_READS (
            ch_pass_fail_reads.collect(),
            ['Sample', 'Reads before trimming'],
            'fail_mapped_reads'
        )
        .set { ch_fail_reads_multiqc }
    }

    //
    // MODULE: Run shovill
    //
    SHOVILL (
            ch_reads
        )
        ch_assemblies_prokka     = SHOVILL.out.contigs
        ch_assemblies_quast      = SHOVILL.out.contigs
        ch_versions     = ch_versions.mix(SHOVILL.out.versions.first().ifEmpty(null))

    //
    // MODULE: Run prokka
    //
    PROKKA (
            ch_assemblies_prokka           
        )
        ch_gff               = PROKKA.out.gff
        ch_versions     = ch_versions.mix(PROKKA.out.versions.first().ifEmpty(null))

    //
    // MODULE: Run quast
    //
    QUAST (
            ch_assemblies_quast,
            ch_gff
        )
        ch_versions     = ch_versions.mix(QUAST.out.versions.first().ifEmpty(null))
    
    //
    // MODULE: Collate software versions
    //
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowBacQC.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)
    
    MULTIQC (
        ch_multiqc_config,
        ch_multiqc_custom_config,
        CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect(),
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'),
        ch_fail_reads_multiqc.ifEmpty([]),
        FASTQC_FASTP.out.fastqc_raw_zip.collect{it[1]}.ifEmpty([]),
        FASTQC_FASTP.out.trim_json.collect{it[1]}.ifEmpty([]),
        QUAST.out.results.collect{it[1]}.ifEmpty([]) 
        )
    multiqc_report = MULTIQC.out.report.toList()
    ch_versions    = ch_versions.mix(MULTIQC.out.versions)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report, fail_mapped_reads)
    }
    NfcoreTemplate.summary(workflow, params, log)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/