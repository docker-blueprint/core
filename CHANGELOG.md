# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Added support for local branches when pulling blueprints (useful during local development)
- Added support for multiple docker and docker-compose files both in blueprint and in modules
- Added dockerfile preprocessor
- Added dockerfile blueprint variable substitution
- Added dockerfile directives
- Added proxy for common docker-compose commands such as `up`, `down`, `start`, etc
- Added nested dependency resolvement during both initialization & build stages

### Updated
- Upgraded yq to version 4 (removed undocumented dependency on jq)
