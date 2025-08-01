# avantonder/assembleBAC: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v2.0.2 - [18/06/2025]

### `Fixed`

- Fix `process.shell` in `nextflow.config` ([#3416](https://github.com/nf-core/tools/pull/3416))

## v2.0.1 - [18/03/2025]

### `Fixed`

- Documentation updated
- DOI generated with Zenodo

## v2.0.0 - [10/03/25]

### `Added`

- Significant recoding of pipeline to bring it more in line with current nf-core template

### `Fixed`

- Update Bakta from version 1.9.4 to version 1.10.4
- Update mlst from version 2.19.0 to version 2.23.0
- Update MultiQC from version 1.14 to version 1.25.1

## v1.2.1 - [19/07/24]

### `Fixed` 

- shebang in check_samplesheet.py changed to python3 to work on systems with no 'python' alias
- Bakta updated to version 1.9.4 to fix AMRfinder bug with database
- Bakta database installation instructions updated in README.md to avoid AMRfinder bug

## v1.2 - [07/07/23]

### `Added`

- Parse mlst outputs to produce summary tsv in metadata directory

### `Fixed`

- Fix CheckM2 parser script so summary tsv only contains single header line
- Add Quast outputs to multqc html report
- Edit output document to add mlst summary tsv

## v1.1 - [08/06/23]

### `Fixed`

- Fix CPU requirements for input check

## v1.0 - [17/03/23]

Initial release of avantonder/assembleBAC, created with the [nf-core](https://nf-co.re/) template.

### `Added`

### `Fixed`

### `Dependencies`

### `Deprecated`
