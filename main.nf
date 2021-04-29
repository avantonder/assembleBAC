#!/usr/bin/env nextflow
/*
========================================================================================
                         avantonder/assembleBAC
========================================================================================
 avantonder/assembleBAC Analysis Pipeline.
 #### Homepage / Documentation
 https://github.com/avantonder/assembleBAC
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

////////////////////////////////////////////////////
/* --               PRINT HELP                 -- */
////////////////////////////////////////////////////

def json_schema = "$projectDir/nextflow_schema.json"
if (params.help) {
    def command = "nextflow run avantonder/assembleBAC --input samplesheet.csv -profile docker"
    log.info Schema.params_help(workflow, params, json_schema, command)
    exit 0
}

////////////////////////////////////////////////////
/* --         PRINT PARAMETER SUMMARY          -- */
////////////////////////////////////////////////////

def summary_params = Schema.params_summary_map(workflow, params, json_schema)
log.info Schema.params_summary_log(workflow, params, json_schema)

////////////////////////////////////////////////////
/* --          PARAMETER CHECKS                -- */
////////////////////////////////////////////////////

// Check that conda channels are set-up correctly
if (params.enable_conda) {
    Checks.check_conda_channels(log)
}

// Check AWS batch settings
Checks.aws_batch(workflow, params)

// Check the hostnames against configured profiles
Checks.hostname(workflow, params, log)

////////////////////////////////////////////////////
/* --          VALIDATE INPUTS                 -- */
////////////////////////////////////////////////////

checkPathParamList = [ params.input, params.multiqc_config ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

////////////////////////////////////////////////////
/* --          CONFIG FILES                    -- */
////////////////////////////////////////////////////

ch_multiqc_config        = file("$projectDir/assets/multiqc_config.yaml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()

////////////////////////////////////////////////////
/* --       IMPORT MODULES / SUBWORKFLOWS      -- */
////////////////////////////////////////////////////

// Don't overwrite global params.modules, create a copy instead and use that within the main script.
def modules = params.modules.clone()
def multiqc_options   = modules['multiqc']
multiqc_options.args += params.multiqc_title ? Utils.joinModuleArgs(["--title \"$params.multiqc_title\""]) : ''

// Local: Modules
include { GET_SOFTWARE_VERSIONS } from './modules/local/get_software_versions'     addParams( options: [publish_files : ['csv':'']] )

// nf-core: Modules
include { SHOVILL } from './modules/nf-core/software/shovill/main'                  addParams( options: modules['shovill'])
include { MULTIQC } from './modules/nf-core/software/multiqc/main'                  addParams( options: modules['multiqc'])
include { PROKKA  } from './modules/nf-core/software/prokka/main'                   addParams( options: modules['prokka'])
include { QUAST   } from './modules/nf-core/software/multiqc/main'                  addParams( options: modules['quast'])

// Local: Sub-workflows
def fastp_options   = modules['fastp']

include { INPUT_CHECK       } from './modules/local/subworkflow/input_check'        addParams( options: [:] )
include { FASTQC_FASTP      } from './subworkflows/nf-core/fastqc_fastp'            addParams( fastqc_raw_options: modules['fastqc_raw'], fastqc_trim_options: modules['fastqc_trim'], fastp_options: fastp_options )

////////////////////////////////////////////////////
/* --           RUN MAIN WORKFLOW              -- */
////////////////////////////////////////////////////

// Info required for completion email and summary
def multiqc_report = []

workflow {

    ch_software_versions = Channel.empty()

    /*
     * SUBWORKFLOW: Read in samplesheet, validate and stage input files
     */
    
    INPUT_CHECK ( 
        ch_input
    )

    /*
     * SUBWORKFLOW: Read QC and trim adapters
     */
    
    FASTQC_FASTP (
        INPUT_CHECK.out.sample_info
    )
    ch_reads             = FASTQC_FASTP.out.reads
    ch_software_versions = ch_software_versions.mix(FASTQC_FASTP.out.fastqc_version.first().ifEmpty(null))
    ch_software_versions = ch_software_versions.mix(FASTQC_FASTP.out.fastp_version.first().ifEmpty(null))

    /*
    * MODULE: Run shovill
    */
    
    SHOVILL (
            ch_reads
        )
        ch_assemblies_prokka     = SHOVILL.out.contigs
        ch_assemblies_quast      = SHOVILL.out.contigs
        ch_software_versions     = ch_software_versions.mix(SHOVILL.out.version.first().ifEmpty(null))

    /*
    * MODULE: Run prokka
    */

    PROKKA (
            ch_assemblies_prokka           
        )
        ch_gff               = PROKKA.out.gff
        ch_software_versions = ch_software_versions.mix(PROKKA.out.version.first().ifEmpty(null))

    /*
    * MODULE: Run quast
    */

    QUAST (
            ch_assemblies_quast,
            ch_gff
        )
        ch_software_versions = ch_software_versions.mix(QUAST.out.version.first().ifEmpty(null))
    
    /*
     * MODULE: Pipeline reporting
     */
    
    GET_SOFTWARE_VERSIONS ( 
        ch_software_versions.map { it }.collect()
    ) 
    
    /*
    * MODULE: Run MultiQC
    */
    
    MULTIQC (
            ch_multiqc_config,
            ch_multiqc_custom_config.collect().ifEmpty([]),
            GET_SOFTWARE_VERSIONS.out.yaml.collect(),
            FASTQC_FASTP.out.fastqc_raw_zip.collect{it[1]}.ifEmpty([]),
            FASTQC_FASTP.out.trim_json.collect{it[1]}.ifEmpty([]),
            QUAST.out.results.collect{it[1]}.ifEmpty([]) 
        )
        multiqc_report = MULTIQC.out.report.toList()   
}

////////////////////////////////////////////////////
/* --              COMPLETION EMAIL            -- */
////////////////////////////////////////////////////

workflow.onComplete {
    Completion.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    Completion.summary(workflow, params, log)
}

////////////////////////////////////////////////////
/* --                  THE END                 -- */
////////////////////////////////////////////////////

