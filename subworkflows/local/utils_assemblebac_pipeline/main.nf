//
// Subworkflow with functionality specific to the nf-core/pipeline pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFSCHEMA_PLUGIN     } from '../../nf-core/utils_nfschema_plugin'
include { paramsSummaryMap          } from 'plugin/nf-schema'
include { samplesheetToList         } from 'plugin/nf-schema'
include { completionEmail           } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary         } from '../../nf-core/utils_nfcore_pipeline'
include { imNotification            } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE     } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NEXTFLOW_PIPELINE   } from '../../nf-core/utils_nextflow_pipeline'

/*
========================================================================================
    SUBWORKFLOW TO INITIALISE PIPELINE
========================================================================================
*/

workflow PIPELINE_INITIALISATION {

    take:
    version           // boolean: Display version and exit
    help              // boolean: Display help text
    validate_params   // boolean: Boolean whether to validate parameters against the schema at runtime
    monochrome_logs   // boolean: Do not use coloured log outputs
    nextflow_cli_args // array: List of positional nextflow CLI args
    outdir            // string: The output directory where the results will be saved
    input             // string: Path to input samplesheet

    main:

    ch_versions = Channel.empty()

     //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE (
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //
    UTILS_NFSCHEMA_PLUGIN (
        workflow,
        validate_params,
        null
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE (
        nextflow_cli_args
    )

    //
    // Create channel from input file provided through params.input
    //
    Channel
        .fromList(samplesheetToList(params.input, "assets/schema_input.json"))
        .map {
            meta, fastq_1, fastq_2 ->
                if (!fastq_2) {
                    return [ meta.id, meta + [ single_end:true ], [ fastq_1 ] ]
                } else {
                    return [ meta.id, meta + [ single_end:false ], [ fastq_1, fastq_2 ] ]
                }
        }
        .groupTuple()
        .map {
            validateInputSamplesheet(it)
        }
        .map {
            meta, fastqs ->
                return [ meta, fastqs.flatten() ]
        }
        .set { ch_samplesheet }

    emit:
    samplesheet = ch_samplesheet
    versions    = ch_versions

}

/*
========================================================================================
    SUBWORKFLOW FOR PIPELINE COMPLETION
========================================================================================
*/

workflow PIPELINE_COMPLETION {

    take:
    email           //  string: email address
    email_on_fail   //  string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir          //    path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output
    hook_url        //  string: hook URL for notifications
    multiqc_report  //  string: Path to MultiQC report

    main:
    summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def multiqc_reports = multiqc_report.toList()

    //
    // Completion email and summary
    //
    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(
                summary_params,
                email,
                email_on_fail,
                plaintext_email,
                outdir,
                monochrome_logs,
                multiqc_reports.getVal(),
            )
        }

        completionSummary(monochrome_logs)
        if (hook_url) {
            imNotification(summary_params, hook_url)
        }
    }

    workflow.onError {
        log.error "Pipeline failed. Please refer to troubleshooting docs: https://nf-co.re/docs/usage/troubleshooting"
    }
}

/*
========================================================================================
    FUNCTIONS
========================================================================================
*/

//
// Validate channels from input samplesheet
//
def validateInputSamplesheet(input) {
    def (metas, fastqs) = input[1..2]

    // Check that multiple runs of the same sample are of the same datatype i.e. single-end / paired-end
    def endedness_ok = metas.collect{ it.single_end }.unique().size == 1
    if (!endedness_ok) {
        error("Please check input samplesheet -> Multiple runs of a sample must be of the same datatype i.e. single-end or paired-end: ${metas[0].id}")
    }

    return [ metas[0], fastqs ]
}

//
// Generate methods description for MultiQC
//
def toolCitationText() {
    def text_denovo_assembly = [
        "De novo genome assembly was conducted with Shovill (https://github.com/tseemann/shovill)."
    ].join(' ').trim()
   
    def text_mlst = [
        "MLST prediction was done with mlst (https://github.com/tseemann/mlst)."
    ].join(' ').trim()
    
    def text_assembly_qc = [
        "Assembly quality control was carried out with QUAST (Gurevich et al. 2013).",
        "Assembly completeness and contamination was assessed with CheckM2 (Chklovski et al. 2023)"
    ].join(' ').trim()
    
    def annotation_text  = [
            "Annotation was carried out with BAKTA (Schwengers et al. 2021)."
    ].join(' ').trim()

    def citation_text = [
        "Tools used in the workflow included:",
        text_denovo_assembly,
        params.skip_mlst           ? "" : text_mlst,
        params.skip_assemblyqc     ? "" : text_assembly_qc,
        params.skip_annotation     ? "" : annotation_text,
        "Pipeline results statistics were summarised with MultiQC (Ewels et al. 2016)."
    ].join(' ').trim().replaceAll("[,|.] +\\.", ".")

    return citation_text
}

def toolBibliographyText() {
    def text_denovo_assembly = [
        "<li>Seeman T. (2019). Shovill, URL: <a href=\"https://github.com/tseemann/shovill\">https://github.com/tseemann/shovill</a></li>"
    ].join(' ').trim()

    def text_mlst = [
        "<li>Seeman T. (2014). MLST, URL: <a href=\"https://github.com/tseemann/mlst\">https://github.com/tseemann/mlst</a></li>"
    ].join(' ').trim()
    
    def text_assembly_qc = [
        "<li>Gurevich A., Saveliev V., Vyahhi N., & Tesler G. (2013). QUAST: quality assessment tool for genome assemblies. Bioinformatics. 29(8):1072-5. <a href=\"https:/doi.org/10.1093/bioinformatics/btt086\">10.1093/bioinformatics/btt086.</a></li>",
        "<li>Chklovski A., Parks D.H., Woodcroft B.J., & Tyson G.W. (2023). CheckM2: a rapid, scalable and accurate tool for assessing microbial genome quality using machine learning. Nature Methods. 20(8):1203-1212. <a href=\"https:/doi.org/10.1038/s41592-023-01940-w\">10.1038/s41592-023-01940-w.</a></li>"
    ].join(' ').trim()
    
    def annotation_text  = [
        "<li>Schwengers, O., Jelonek, L., Dieckmann, M.A., Beyvers, S., Blom J., & Goesmann A. (2021). Bakta: rapid and standardized annotation of bacterial genomes via alignment-free sequence identification. Microbial Genomics, 7(11):000685. <a href=\"https:/doi.org/10.1099/mgen.0.000685\">10.1099/mgen.0.000685.</a></li>"
    ].join(' ').trim()

    def reference_text = [
        text_denovo_assembly,
        params.skip_mlst           ? "" : text_mlst,
        params.skip_assemblyqc     ? "" : text_assembly_qc,
        params.skip_annotation     ? "" : annotation_text,,
        "<li>Ewels, P., Magnusson, M., Lundin, S., & Käller, M. (2016). MultiQC: summarize analysis results for multiple tools and samples in a single report. Bioinformatics , 32(19), 3047–3048. <a href=\"https:/doi.org/10.1093/bioinformatics/btw354\">10.1093/bioinformatics/btw354.</a></li>"
    ].join(' ').trim().replaceAll("[,|.] +\\.", ".")

    return reference_text
}

def methodsDescriptionText( mqc_methods_yaml ) {

    def meta = [:]

    meta.workflow = workflow.toMap()
    meta["manifest_map"] = workflow.manifest.toMap()

    // Pipeline DOI
    if (meta.manifest_map.doi) {
        // Using a loop to handle multiple DOIs
        // Removing `https://doi.org/` to handle pipelines using DOIs vs DOI resolvers
        // Removing ` ` since the manifest.doi is a string and not a proper list
        def temp_doi_ref = ""
        String[] manifest_doi = meta.manifest_map.doi.tokenize(",")
        for (String doi_ref: manifest_doi) temp_doi_ref += "(doi: <a href=\'https://doi.org/${doi_ref.replace("https://doi.org/", "").replace(" ", "")}\'>${doi_ref.replace("https://doi.org/", "").replace(" ", "")}</a>), "
        meta["doi_text"] = temp_doi_ref.substring(0, temp_doi_ref.length() - 2)
    } else meta["doi_text"] = ""
    meta["nodoi_text"] = meta.manifest_map.doi ? "" : "<li>If available, make sure to update the text to include the Zenodo DOI of version of the pipeline used. </li>"

    // meta["tool_citations"] = ""
    // meta["tool_bibliography"] = ""

    meta["tool_citations"] = toolCitationText().replaceAll(", \\.", ".").replaceAll("\\. \\.", ".").replaceAll(", \\.", ".")
    meta["tool_bibliography"] = toolBibliographyText()

    def methods_text = mqc_methods_yaml.text

    def engine =  new groovy.text.SimpleTemplateEngine()
    def description_html = engine.createTemplate(methods_text).make(meta)

    return description_html.toString()
}