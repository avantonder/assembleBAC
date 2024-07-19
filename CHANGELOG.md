# avantonder/assembleBAC: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
