# avantonder/assembleBAC

**Pipeline for assembling and annotating bacterial genomes**.

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A522.04.3-23aa62.svg?labelColor=000000)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

## Introduction

**avantonder/assembleBAC** is a bioinformatics best-practise analysis pipeline for assembling and annotating bacterial genomes. It also predicts the Sequence Type (ST) and provides QC metrics with quast and checkm2.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It comes with docker containers making installation trivial and results highly reproducible.

## Pipeline summary

By default, the pipeline currently performs the following:

1. *de novo* genome assembly ([`Shovill`](https://github.com/tseemann/shovill))
2. Sequence Type assignment ([`mlst`](https://github.com/tseemann/mlst))
3. Annotation ([`Bakta`](https://github.com/oschwengers/bakta))
4. Assembly metrics ([`Quast`](https://quast.sourceforge.net/))
5. Assembly completeness ([`CheckM2`](https://github.com/chklovski/CheckM2))
6. Assembly metrics summary and pipeline information ([`MultiQC`](http://multiqc.info/))

## Quick Start

1. Install [`nextflow`](https://nf-co.re/usage/installation)(`>=22.04.3`)

2. Install any of [`Docker`](https://docs.docker.com/engine/installation/), [`Singularity`](https://www.sylabs.io/guides/3.0/user-guide/), [`Podman`](https://podman.io/), [`Shifter`](https://nersc.gitlab.io/development/shifter/how-to-use/) or [`Charliecloud`](https://hpc.github.io/charliecloud/) for full pipeline reproducibility _(please only use [`Conda`](https://conda.io/miniconda.html) as a last resort; see [docs](https://nf-co.re/usage/configuration#basic-configuration-profiles))_

3. Download the `Bakta` light database (`Bakta` is required to run the `amrfinder_update` command):

    ```bash
    wget https://zenodo.org/record/7669534/files/db-light.tar.gz
    tar -xzf db-light.tar.gz
    rm db-light.tar.gz
    amrfinder_update --force_update --database db-light/amrfinderplus-db/
    ```

4. Download the `CheckM2` database (`CheckM2` is required):

    ```bash
    checkm2 database --download --path path/to/checkm2db
    ```

5. An executable Python script called [`fastq_dir_to_samplesheet.py`](https://github.com/avantonder/bovisanalyzer/blob/main/bin/fastq_dir_to_samplesheet.py) has been provided to auto-create an input samplesheet based on a directory containing FastQ files **before** you run the pipeline (requires Python 3 installed locally) e.g.

     ```console
     wget -L https://raw.githubusercontent.com/avantonder/bovisanalyzer/main/bin/fastq_dir_to_samplesheet.py

     python fastq_dir_to_samplesheet.py <FASTQ_DIR> \
        samplesheet.csv \
        -r1 <FWD_FASTQ_SUFFIX> \
        -r2 <REV_FASTQ_SUFFIX>

Alternatively the samplesheet.csv file created by [`nf-core/fetchngs`](https://nf-co.re/fetchngs) can also be used.

6. Start running your own analysis!
    - Typical command for assembly and annotation

    ```bash
    nextflow run avantonder/assembleBAC \
        -profile singularity \
        -c <INSTITUTION>.config \
        --input samplesheet.csv \
        --genome_size <ESTIMATED GENOME SIZE e.g. 4M> \
        --outdir <OUTDIR> \
        --baktadb path/to/baktadb/dir \
        --checkm2db path/to/checkm2db/diruniref100.KO.1.dmnd \
        -resume
    ```

See [usage docs](docs/usage.md) for all of the available options when running the pipeline.

## Documentation

The avantonder/assembleBAC pipeline comes with documentation about the pipeline [usage](docs/usage.md), [parameters](docs/parameters.md) and [output](docs/output.md).

## Credits

avantonder/assembleBAC was originally written by Andries van Tonder.  I wouldn't have been able to write this pipeline with out the tools, documentation, pipelines and modules made available by the fantastic [nf-core community](https://nf-co.re/).

## Feedback

If you have any issues, questions or suggestions for improving assembleBAC, please submit them to the [Issue Tracker](https://github.com/avantonder/assembleBAC/issues).

## Citations

If you use the avantonder/assembleBAC pipeline, please cite it using the following doi: ZENODO_DOI

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.
