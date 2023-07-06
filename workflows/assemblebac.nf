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
if (params.baktadb) { ch_baktadb = file(params.baktadb) } else { exit 1, 'bakta database not specified!' }
if (params.checkm2db) { ch_checkm2db = file(params.checkm2db) } else { exit 1, 'checkm2 database not specified!' }

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
include { CHECKM2_PARSE } from '../modules/local/checkm2_parse'
include { MLST_PARSE    } from '../modules/local/mlst_parse'

include { INPUT_CHECK   } from '../subworkflows/local/input_check'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules

include { SHOVILL                     } from '../modules/nf-core/modules/shovill/main'
include { MLST                        } from '../modules/nf-core/modules/mlst/main'
include { BAKTA                       } from '../modules/nf-core/modules/bakta/main'
include { CHECKM2                     } from '../modules/nf-core/modules/checkm2/main'
include { QUAST                       } from '../modules/nf-core/modules/quast/main'
include { MULTIQC                     } from '../modules/nf-core/modules/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main' 

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

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
    // MODULE: Run shovill
    //
    SHOVILL (
            INPUT_CHECK.out.reads,
            params.genome_size
        )
        ch_assemblies_bakta   = SHOVILL.out.contigs
        ch_assemblies_mlst    = SHOVILL.out.contigs
        ch_assemblies_checkm2 = SHOVILL.out.contigs
        ch_assemblies_quast   = SHOVILL.out.contigs
        ch_versions           = ch_versions.mix(SHOVILL.out.versions.first().ifEmpty(null))

    //
    // MODULE: Run mlst
    //
    MLST (
            ch_assemblies_mlst        
        )
        ch_mlst_mlstparse = MLST.out.tsv
        ch_versions = ch_versions.mix(MLST.out.versions.first().ifEmpty(null))

    //
    // MODULE: Summarise mlst outputs
    //
    MLST_PARSE (
              ch_mlst_mlstparse.collect{it[1]}.ifEmpty([])
        )
        ch_versions = ch_versions.mix(MLST_PARSE.out.versions.first())
    
    //
    // MODULE: Run bakta
    //
    BAKTA (
            ch_assemblies_bakta,
            ch_baktadb,
            [],
            []           
        )
        ch_versions = ch_versions.mix(BAKTA.out.versions.first().ifEmpty(null))

    //
    // MODULE: Run checkm2
    //
    CHECKM2 (
            ch_assemblies_checkm2,
            ch_checkm2db          
        )
        ch_checkm2_checkm2parse = CHECKM2.out.tsv
        ch_versions = ch_versions.mix(CHECKM2.out.versions.first().ifEmpty(null))

    //
    // MODULE: Summarise checkm2 outputs
    //
    CHECKM2_PARSE (
              ch_checkm2_checkm2parse.collect{it[1]}.ifEmpty([])
        )
        ch_versions = ch_versions.mix(CHECKM2_PARSE.out.versions.first())
    
    //
    // MODULE: Run quast
    //
    ch_assemblies_quast
        .map { meta, fasta -> fasta }
        .collect()
        .set { ch_to_quast }
    
    QUAST (
            ch_to_quast,
            [],
            [],
            false,
            false
        )
        ch_versions = ch_versions.mix(QUAST.out.versions.first().ifEmpty(null))
    
    //
    // MODULE: Collate software versions
    //
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    if (!params.skip_multiqc) {
        workflow_summary    = WorkflowAssembleBac.paramsSummaryMultiqc(workflow, summary_params)
        ch_workflow_summary = Channel.value(workflow_summary)
        
        MULTIQC (
            ch_multiqc_config,
            ch_multiqc_custom_config,
            CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect(),
            ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'),
            QUAST.out.tsv.collect{it[1]}.ifEmpty([]) 
            )
        multiqc_report = MULTIQC.out.report.toList()
        ch_versions    = ch_versions.mix(MULTIQC.out.versions)
    }
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