# avantonder/assembleBAC pipeline parameters                                                                                       
                                                                                                                                   
is a bioinformatics best-practise analysis pipeline for assembling and annotating bacterial genomes. It also predicts the Sequence Type (ST) and provides QC metrics with `Quast` and`CheckM2`.                                                                                          
                                                                                                                                   
## Input/output options                                                                                                            
                                                                                                                                   
Define where the pipeline should find input data and save output data.                                                             
                                                                                                                                   
| Parameter | Description | Type | Default | Required | Hidden |                                                                   
|-----------|-----------|-----------|-----------|-----------|-----------|                                                          
| `input` | Path to comma-separated file containing information about the samples in the experiment.          <details><summary>Help</summary><small>You will need to create a design file with information about the samples in your experiment before running the pipeline. Use this parameter to specify its location. It has to be a comma-separated file with 3 columns, and a header row.</small></details>| `string` |  | True | |                                                                          
| `outdir` | The output directory where the results will be saved. You have to use absolute paths to storage on Cloud    infrastructure. | `string` |  | True |  |                                                                                          
| `email` | Email address for completion summary. <details><summary>Help</summary><small>Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits. If set in your user config file (`~/.nextflow/config`) then you don't need to specify this on the command line for every run.</small></details>| `string` |  |  |                                                                                                          
| `multiqc_title` | MultiQC report title. Printed as page header, used for filename if not otherwise specified. | `string` |  |  | 
|                                                                                                                                  
                                                                                                                                   
## Generic options                                                                                                                 
                                                                                                                                   
Less common options for the pipeline, typically set in a config file.                                                              
                                                                                                                                   
| Parameter | Description | Type | Default | Required | Hidden |                                                                   
|-----------|-----------|-----------|-----------|-----------|-----------|                                                          
| `version` | Display version and exit. | `boolean` |  |  | True |                                                                 
| `validate_params` | Boolean whether to validate parameters against the schema at runtime | `boolean` | True |  | True |          
| `publish_dir_mode` | Method used to save pipeline results to output directory. <details><summary>Help</summary><small>The Nextflow `publishDir` option specifies which intermediate files should be saved to the output directory. This option tells the pipeline what method should be used to move these files. See [Nextflow docs](https://www.nextflow.io/docs/latest/process.html#publishdir) for details.</small></details>| `string` | copy |  | True |     
| `trace_report_suffix` | Suffix to add to the trace report filename. Default is the date and time in the format      yyyy-MM-dd_HH-mm-ss. | `string` |  |  | True |                                                                                     
| `multiqc_config` | Custom config file to supply to MultiQC. | `string` |  |  | True |                                            
| `multiqc_logo` | Custom logo file to supply to MultiQC. File name must also be set in the MultiQC config file | `string` |  |  |True |                                                                                                                      
| `multiqc_methods_description` | Custom MultiQC yaml file containing HTML including a methods description. | `string` |  |  |  |  
| `email_on_fail` | Email address for completion summary, only when pipeline fails. <details><summary>Help</summary><small>An email address to send a summary email to when the pipeline is completed - ONLY sent if the pipeline does not exit successfully.</small></details>| `string` |  |  | True |                                                                           
| `plaintext_email` | Send plain-text email instead of HTML. | `boolean` |  |  | True |                                            
| `max_multiqc_email_size` | File size limit when attaching MultiQC reports to summary emails. | `string` | 25.MB |  | True |      
| `monochrome_logs` | Do not use coloured log outputs. | `boolean` |  |  | True |                                                  
| `hook_url` | Incoming hook URL for messaging service <details><summary>Help</summary><small>Incoming hook URL for messaging service. Currently, MS Teams and Slack are supported.</small></details>| `string` |  |  | True |                                   
| `pipelines_testdata_base_path` | Base URL or local path to location of pipeline test dataset files | `string` |         https://raw.githubusercontent.com/nf-core/test-datasets/ |  |  |                                                                   
                                                                                                                                   
## Institutional config options                                                                                                    
                                                                                                                                   
                                                                                                                                   
                                                                                                                                   
| Parameter | Description | Type | Default | Required | Hidden |                                                                   
|-----------|-----------|-----------|-----------|-----------|-----------|                                                          
| `custom_config_version` | Git commit id for Institutional configs. | `string` | master |  | True |                               
| `custom_config_base` | Base directory for Institutional configs. <details><summary>Help</summary><small>If you're running offline, Nextflow will not be able to fetch the institutional config files from the internet. If you don't need them, then this is not a problem. If you do need them, you should download the files from the repo and tell Nextflow where to find them with this parameter.</small></details>| `string` | https://raw.githubusercontent.com/nf-core/configs/master |  | True |                      
| `config_profile_name` | Institutional config name. | `string` |  |  | True |                                                     
| `config_profile_description` | Institutional config description. | `string` |  |  | True |                                       
| `config_profile_contact` | Institutional config contact information. | `string` |  |  | True |                                   
| `config_profile_url` | Institutional config URL link. | `string` |  |  | True |                                                  
                                                                                                                                   
## Assembly options                                                                                                                
                                                                                                                                   
                                                                                                                                   
                                                                                                                                   
| Parameter | Description | Type | Default | Required | Hidden |                                                                   
|-----------|-----------|-----------|-----------|-----------|-----------|                                                          
| `genome_size` | Estimated genome size (e.g. 4M) | `string` | 4M |  |  |                                                          
                                                                                                                                   
## Annotation options                                                                                                              
                                                                                                                                   
                                                                                                                                   
                                                                                                                                   
| Parameter | Description | Type | Default | Required | Hidden |                                                                   
|-----------|-----------|-----------|-----------|-----------|-----------|                                                          
| `skip_annotation` | Skip annotation with Bakta | `boolean` |  |  |  |                                                            
| `baktadb` | Path to Bakta database directory | `string` |  |  |  |                                                               
| `proteins` | Fasta file of trusted protein sequences for CDS annotation | `string` |  |  |  |                                    
| `prodigal_tf` | Path to existing Prodigal training file to use for CDS prediction | `string` |  |  |  |                          
| `skip_mlst` | Skip MLST assignment with mlst | `boolean` |  |  |  |                                                              
                                                                                                                                   
## Assembly QC options                                                                                                             
                                                                                                                                   
                                                                                                                                   
                                                                                                                                   
| Parameter | Description | Type | Default | Required | Hidden |                                                                   
|-----------|-----------|-----------|-----------|-----------|-----------|                                                          
| `skip_assemblyqc` | Skip assembly QC with CheckM2 and QUAST | `boolean` |  |  |  |                                               
| `skip_quast` | Skip assembly QC with QUAST | `boolean` |  |  |  |                                                                
| `checkm2db` | Path to CheckM2 DIAMOND database file | `string` |  |  |  | 