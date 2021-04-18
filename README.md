<p align="center">
    <a href="https://docker-blueprint.github.io" target="_blank">
        <img src="https://raw.githubusercontent.com/docker-blueprint/docker-blueprint.github.io/master/docs/_media/icon.png" width="600">
    </a>
</p>

<p align="center">
    <img alt="Platform: Linux" src="https://img.shields.io/badge/platform-linux-lightgrey">
    <img alt="License" src="https://img.shields.io/github/license/docker-blueprint/core">
</p>

- 💻 **Ephemeral development environments** - easily build up and tear down
local development environments for your projects on any machine that can run
docker.
- 📦 **Modular blueprints** - create your own unique development environment.
Use the specific technologies that your project requires - build your own stack
by choosing the database, cache & other technologies.
- 🐳 **Automatic dockerfile & docker-compose.yml file generation** - set up
your development environment first - learn all the intricacies of docker later!
- ✏️ **Extensible** - tweak the generated files as you please, or better yet -
extend existing blueprint, so other people could use the same features that you
will implement.

# About Docker Blueprint

`docker-blueprint` provides an ability to create modular **ephemeral**
development environments.

## Create

This allows developers to easily bring up local development environment
on any machine, building `Dockerfile` and `docker-compose.yml` files with a simple command:

```
docker-blueprint new php --env laravel --with mysql redis horizon
```

## Interact

Better yet, `docker-blueprint` makes working with a containerized development
environment a breeze - blurring the line between files on your work machine
and runtime environment inside the container!

Access your development environment seamlessly:

```
docker-blueprint npm run watch
```

## Share

Once you have initialized the blueprint for your project - you will have a
`docker-blueprint.yml` file in its directory, which describes your project
configuration.
Now you can push these changes into a VCS repository and reproduce this same
development environment on another machine:

```
docker-blueprint up
```

Interested in setting up your development environment?

# Try it yourself!

Get started by installing `docker-blueprint` on your machine https://docker-blueprint.github.io/#/getting-started
