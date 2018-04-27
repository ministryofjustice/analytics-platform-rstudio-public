# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2018-04-24
### Changed
- R version 3.4.2
- Base Image: `rocker/verse:3.4.2@sha256:f82e4b3a2c5410f338c7c199de0557ea75ca537e51220e8925747d75989377cd`
- Building the image from tagged digest for reproducibility
- [Trello1](https://trello.com/c/pZ1NCUhn), [Trello2](https://trello.com/c/eJxjZKFn)
- Revised Dockerfile:
    * Modified R package installs to use install2.r wrapper (It's newer and used mostly by rocker)
    * Shifted R packages to separate file for readability
    * Install pinned PhantomJS from apt (Could not get Webdriver install to work)
    * Install R package `rGL` dependencies `mesa-common-dev`, `libglu1-mesa-dev` 
    * Install Athena ODBC drivers
