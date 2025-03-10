/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryMap         } from 'plugin/nf-schema'
include { paramsSummaryMultiqc     } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText   } from '../subworkflows/local/utils_assemblebac_pipeline'

// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.multiqc_config, params.baktadb, params.checkm2db,
                           params.multiqc_logo, params.multiqc_methods_description ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if ( params.input ) {
    ch_input = file(params.input, checkIfExists: true)
} else {
    error("Input samplesheet not specified")
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { CHECKM2       } from '../modules/local/checkm2/main'
include { CHECKM2_PARSE } from '../modules/local/checkm2_parse'
include { MLST_PARSE    } from '../modules/local/mlst_parse'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules

include { SHOVILL } from '../modules/nf-core/shovill/main'
include { MLST    } from '../modules/nf-core/mlst/main'
include { BAKTA   } from '../modules/nf-core/bakta/main'
include { QUAST   } from '../modules/nf-core/quast/main'
include { MULTIQC } from '../modules/nf-core/multiqc/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow ASSEMBLEBAC {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:
    
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // MODULE: Run shovill
    //
    SHOVILL (
            ch_samplesheet,
            params.genome_size
        )
        ch_assemblies_bakta   = SHOVILL.out.contigs
        ch_assemblies_mlst    = SHOVILL.out.contigs
        ch_assemblies_checkm2 = SHOVILL.out.contigs
        ch_assemblies_quast   = SHOVILL.out.contigs
        ch_versions           = ch_versions.mix( SHOVILL.out.versions )

    //
    // MODULE: Run mlst
    //
    if (!params.skip_mlst) {
        MLST (
                ch_assemblies_mlst        
            )
            ch_mlst_mlstparse = MLST.out.tsv
            ch_versions = ch_versions.mix( MLST.out.versions )

        //
        // MODULE: Summarise mlst outputs
        //
        MLST_PARSE (
                ch_mlst_mlstparse.collect{it[1]}.ifEmpty([])
            )
            ch_versions = ch_versions.mix( MLST_PARSE.out.versions )
    }
    
    //
    // MODULE: Run bakta
    //
    ch_baktadb = Channel.empty()

    if (!params.skip_annotation) {
        ch_baktadb = file(params.baktadb)
        
        BAKTA_BAKTA (
                ch_assemblies_bakta,
                ch_baktadb,
                [],
                []           
            )
            ch_versions = ch_versions.mix(BAKTA_BAKTA.out.versions.first())
    }

    ch_checkm2db = Channel.empty()
    
    if (!params.skip_assemblyqc) {
        ch_checkm2db = file(params.checkm2db)
        //
        // MODULE: Run checkm2
        //
        CHECKM2 (
                ch_assemblies_checkm2,
                ch_checkm2db          
            )
            ch_checkm2_checkm2parse = CHECKM2.out.tsv
            ch_versions = ch_versions.mix(CHECKM2.out.versions.first())

        //
        // MODULE: Summarise checkm2 outputs
        //
        CHECKM2_PARSE (
                ch_checkm2_checkm2parse.collect{it[1]}.ifEmpty([])
            )
            ch_versions = ch_versions.mix( CHECKM2_PARSE.out.versions )

        //
        // MODULE: Run quast
        //
        if (!params.skip_quast) {
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
                ch_versions = ch_versions.mix( QUAST.out.versions )
        }
    }
    
    /*
        MODULE: MultiQC
    */

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'avantonder_'  +  'assemblebac_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.fromPath("${workflow.projectDir}/docs/images/assemblebac_logo.png", checkIfExists: true)

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))

    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    if (!params.skip_quast) {
        ch_multiqc_files = ch_multiqc_files.mix(QUAST.out.tsv.collect())
    }

    if (!params.skip_annotation) {
        ch_multiqc_files = ch_multiqc_files.mix(BAKTA_BAKTA.out.txt.collect{it[1]}.ifEmpty([]))
    }

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/