# Making a `new` blueprint

To automatically initialize docker-blueprint for your project, the `new`
command is used:

```
docker-blueprint new <blueprint> [--env <name>] [--with <modules>]
```

It automatically **pulls** the `<blueprint>` from a [GitHub](https://github.com)
repository, specified in the form of `[VENDOR/]NAME[:TAG]` and checks out
the branch specified as `TAG` (which defaults to `master`).

For example, calling the following command:

```
docker-blueprint new php --env laravel --with mysql redis
```

- Downloads [docker-blueprint/php](https://github.com/docker-blueprint/php)
blueprint from GitHub
- Generates `docker-blueprint.yml` file that specifies blueprint environment,
a list of modules and other project metadata
- Builds `docker-compose` and `Dockerfile` files depending on the environment
and specified modules
- Brings up the docker-compose project for the default [project context](),
building required docker images, if necessary

In this command, `--env` flag specifies the blueprint [environment]() - a
preset of the blueprint for a particular technology or framework (i.e. Laravel,
Wordpress, etc for PHP; Vue, React, etc for Web Front-End; and so on).

On the other hand, `--with` option specifies a list of [blueprint modules]()
to use in the project. For example, while some Laravel projects use MySQL,
others might be using PostgreSQL.
Because blueprints are modular, it is possible to specify various combinations
of technologies for the same blueprint depending on project's requirements and
build `docker-compose` and `Dockerfile` files containing those particular
technologies.

# Bringing `up` the project

Once the blueprint has been generated for the first time, it will try to bring
the project up automatically. To do this yourself later on another machine
using generated files, you can simply invoke:

```
docker-blueprint [--context <name>] up
```

# `Building` the container image

```
docker-blueprint build [--force]
```
