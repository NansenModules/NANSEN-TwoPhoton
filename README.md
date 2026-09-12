# NANSEN-TwoPhoton

The two-photon calcium imaging module for [NANSEN](https://github.com/VervaekeLab/NANSEN). It provides the two-photon session methods, file adapters, scanner readers (SciScan, ScanImage, PrairieView, ThorLabs, MScan), ROI signal extraction and dF/F, the FluFinder autosegmentation, motion-correction orchestration, integrations with Suite2p, EXTRACT, NoRMCorre, Flow Registration and CaImAn, and the imviewer/signalviewer plugins that expose them.

## Requirements

- MATLAB R2023a or newer.
- NANSEN on the MATLAB path. This module is a NANSEN module: NANSEN discovers it as `nansen.module.twophoton` as soon as the `code` folder of this repository is on the path.
- The community toolboxes listed in `code/+nansen/+module/+twophoton/dependencies.nansen.json`. NANSEN's add-on manager installs them: `nansen_install(Modules="nansen.module.twophoton")`.

## Layout

```
code/+nansen/+module/+twophoton/   the module package (nansen.module.twophoton)
  +fileadapter, +sessionmethod       NANSEN extension points
  +roisignals, +roi, +autosegmentation, +motioncorrection, +io
                                     module-owned implementations
  +integration                       adapters for external toolboxes
  +ui                                imviewer and signalviewer plugins
  resources                          data variables and data locations
tests/                               matlab.unittest suites (twophotontest.*)
tools/                               CI tasks and toolbox metadata
```

## Running the tests

```matlab
addpath(genpath('code')); addpath(genpath('tests'));
runtests('twophotontest', 'IncludeSubpackages', true)
```

`tools/tasks/testToolbox.m` is what CI runs: it installs NANSEN and its requirements with [MatBox](https://github.com/ehennestad/MatBox) and then runs the suites.

## History

This repository was extracted from the NANSEN repository with `git filter-repo`, so the history of every file reaches back to its original location in NANSEN.
