# About

`docker-blueprint` provides modular ephemeral development environments that
allow developers to bring up local development environment while only having
[docker](https://www.docker.com/) on their host machine.

# Features

- 💻 **Ephemeral development environments** - easily build up and tear down
development environments for your projects. No strings attached.
- 📦 **Modular blueprints** - mix and match your own development environment
depending on your requirements.
- ✏️ **Extensible** - take existing blueprint as a base and add your own
components to it.
- 🐳 **Automatic dockerfile & docker-compose.yml file generation** - set up
your development environment first - learn about docker later. You are free
to tweak generated files as you please.

# Requirements

Any platform that is able to run **docker** and has **git** and **bash 4+**
installed.

# Installation

Installation is done by cloning this repository and symlinking the
`entrypoint.sh` script to one of the `bin` directories on the system
(`/usr/local/bin` by default).

To ease the process of installation you can invoke this one-liner that will
handle the installation process for you:

with **curl**:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/docker-blueprint/core/master/install.sh)"
```

with **wget**:

```sh
bash -c "$(wget -O- https://raw.githubusercontent.com/docker-blueprint/core/master/install.sh)"
```

Of course, you can inspect install script yourself prior to download:
https://github.com/docker-blueprint/core/blob/master/install.sh

> NOTICE: This project is not affiliated with Docker (the company).
>
> Docker and the Docker logo are trademarks or registered trademarks of
> Docker, Inc. in the United States and/or other countries. Docker, Inc.
> and other parties may also have trademark rights in other terms used herein
