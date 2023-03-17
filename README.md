# avantonder/assembleBAC

**Pipeline for assembling and annotating bacterial genomes**.

[![GitHub Actions CI Status](https://github.com/avantonder/assembleBAC/workflows/nf-core%20CI/badge.svg)](https://github.com/avantonder/assembleBAC/actions)
[![GitHub Actions Linting Status](https://github.com/avantonder/assembleBAC/workflows/nf-core%20linting/badge.svg)](https://github.com/avantonder/assembleBAC/actions)
[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A522.04.3-brightgreen.svg)](https://www.nextflow.io/)

[![install with bioconda](https://img.shields.io/badge/install%20with-bioconda-brightgreen.svg)](https://bioconda.github.io/)
[![Docker](https://img.shields.io/docker/automated/nfcore/assemblebac.svg)](https://hub.docker.com/r/nfcore/assemblebac)

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

3. Download the pipeline and test it on a minimal dataset with a single command:

    ```bash
    nextflow run avantonder/assembleBAC -profile test,<docker/singularity/podman/shifter/charliecloud/conda/institute>
    ```

4. Download the `Bakta` light database (`Bakta` is required to run the `amrfinder_update` command):

    ```bash
    wget https://zenodo.org/record/7669534/files/db-light.tar.gz
    tar -xzf db-light.tar.gz
    rm db-light.tar.gz
    amrfinder_update --force_update --database db-light/amrfinderplus-db/
    ```

5. Download the `CheckM2` database (`CheckM2` is required):

    ```bash
    checkm2 database --download --path .
    ```

6. An executable Python script called [`fastq_dir_to_samplesheet.py`](https://github.com/avantonder/bovisanalyzer/blob/main/bin/fastq_dir_to_samplesheet.py) has been provided to auto-create an input samplesheet based on a directory containing FastQ files **before** you run the pipeline (requires Python 3 installed locally) e.g.

     ```console
     wget -L https://raw.githubusercontent.com/avantonder/bovisanalyzer/main/bin/fastq_dir_to_samplesheet.py

     python fastq_dir_to_samplesheet.py <FASTQ_DIR> \
        samplesheet.csv \
        -r1 <FWD_FASTQ_SUFFIX> \
        -r2 <REV_FASTQ_SUFFIX>

Alternatively the samplesheet.csv file created by [`nf-core/fetchngs`](https://nf-co.re/fetchngs) can also be used.

7. Start running your own analysis!
    - Typical command for assembly and annotation

    ```bash
    nextflow run avantonder/assembleBAC \
        -profile <docker/singularity/podman/shifter/charliecloud/conda/institute> \
        --input samplesheet.csv \
        --genome_size <ESTIMATED GENOME SIZE e.g. 4.3M> \
        --outdir assembleBAC_results \
        --baktadb <PATH TO BAKTA DB> \
        --checkm2db <PATH TO CHECKM2 DB>
    ```

See [usage docs](https://nf-co.re/assemblebac/usage) for all of the available options when running the pipeline.

## Documentation

The avantonder/assembleBAC pipeline comes with documentation about the pipeline: [usage](https://nf-co.re/assemblebac/usage) and [output](https://nf-co.re/assemblebac/output).

## Credits

avantonder/assembleBAC was originally written by Andries van Tonder.  I wouldn't have been able to write this pipeline with out the tools, documentation, pipelines and modules made available by the fantastic [nf-core community](https://nf-co.re/).

## Feedback

If you have any issues, questions or suggestions for improving bovisanalyzer, please submit them to the [Issue Tracker](https://github.com/avantonder/assembleBAC/issues).

## Citations

If you use the avantonder/bovisanalyzer pipeline, please cite it using the following doi: ZENODO_DOI

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.
