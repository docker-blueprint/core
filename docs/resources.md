# Blueprint resources

There are four types of blueprint resources:

## 1) `docker-blueprint.yml` chunks

These are the `blueprint.yml` files inside the blueprint root as well as both
common and environment modules directories.

Example blueprint structure containing multiple `blueprint.yml` files:

```
 sample-blueprint/
|-- blueprint.yml ------------------>|
|-- modules/                         |
|   `-- module-1/                    |
|       `-- blueprint.yml ---------->| M
`-- env/                             | E
    `-- env-1/                       | R
        |-- blueprint.yml ---------->| G
        `-- modules/                 | E
            `-- module-1/            |
                `-- blueprint.yml -->|
                                     |
                                     V
                            docker-blueprint.yml
```

All of them have the same format and are merged into the final
`docker-blueprint.yml` at the project root.

## 2) `docker-compose.yml` chunks

```
 sample-blueprint/
|-- docker-compose.yml --------------------->||
`-- modules/                                 ||
    `-- module-1/                            ||
        |-- docker-compose.yml ------------->||
        `-- docker-compose.development.yml ->||
                                             ||
                                             \/
                          - docker-compose.yml (merged base & module-1)
                          - docker-compose.development.yml (only module-1)
```

## 3) `Dockerfile` templates

Operations on Dockerfiles are different, since it is impossible to merge them
the same way as YAML files. Instead, `docker-blueprint` uses its own
preprocessor in order to substitute special blueprint variables (e.g. `%BLUEPRINT_DIR`) and execute preprocessor directives (e.g. `#include`).

Because of this they are called **templates**, since at this stage it is
impossible to build a working container with these files.

This simple templating approach allows to make Dockerfiles modular by enabling
only those parts of the template which are provided by the currently enabled
modules.

## 4) Auxiliary files

Any other auxiliary files that are required by the given blueprint or its module.

> Tip: These files are copied into the container

# `docker-blueprint.yml` file format

Each project that uses docker-blueprint has a `docker-blueprint.yml`
file at its root.
This file's function is similar to what `package.json` is for npm or any other
dependency manager configuration file in that it stores project configuration.

Since blueprints are self-contained git repositories, modules that are defined
inside `docker-blueprint.yml` file are specific to the current blueprint in use.
Current version of the blueprint is locked by the `blueprint.version` property
which is a hash of the latest commit at the time when the blueprint was
pulled for the given project.
