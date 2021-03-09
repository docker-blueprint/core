# Run

## Description

Run a blueprint command in specified environment.

This command allows to invoke a predefined command to be run inside a service.
Using blueprint commands you can make interaction with the service easier by
hiding away the complex implementation details and instead providing a simple
and user friendly command-line interface to your blueprint.

Moreover, since blueprint commands are a part of the blueprint itself, they can be
be conditionally enabled only with specific modules.

---

For instance, you can create a command to easily import a database backup from
local file into the `database` service that is provided by specific a module
(i.e. `mysql`):

```
docker-blueprint run db:import my-database < dump.sql
```

In the blueprint this the definition for this command would look something
like this:

```yml
commands:
  'db:import':
    no_tty: true # don't allocate pseudo-TTY (pass -T flag to docker-blueprint)
    as_root: true # invoke this program as root user
    service: database
    context: development
    runtime: bash -c # -c flag tells bash to run inline command that follows
    command: | # Multiple lines with line break
      if [[ -z $ARG_1 ]]; then
        echo "Error: no database specified"
        exit 1
      fi

      mysql --database=$ARG_1 < /dev/stdin
```

By specifying this command in the blueprint other users of the same blueprint
won't have to reinvent the wheel and will get an elegant CLI as a bonus.

## Examples

Here follows an attempt to demonstrate several examples of commands which are
defined for different runtimes and utilize all possible properties.

### Bash

Having a sample command with **Bash** runtime:

```yml
commands:
  'test:bash':
    service: database
    context: development
    runtime: bash -c
    environment:
      MY_VAR: Default value
    command: |
      echo "Argument is '$ARG_1'"

      if [[ -n $MY_VAR ]]; then
        echo "MY_VAR is defined and is equal to '$MY_VAR'"
      fi
```

Invoking the following command:

```
$ docker-blueprint run test:bash 'Test Argument'
```

Will produce the following output:

```
Argument is 'Test Argument'
MY_VAR is defined and is equal to 'Default value'
```

---

Running command as root:

```yml
commands:
  'test:bash-root':
    as_root: true
    runtime: bash -c
    command: |
      whoami
```

Outputs:

```
root
```

### Python

Having a sample command with **Python** runtime:

```yml
commands:
  'test:python':
    service: app-that-has-python-installed
    context: development
    runtime: python -c
    command: |
      import os

      name="Python"

      if os.getenv('ARG_1') is not None:
        name=os.getenv('ARG_1')

      print("Hello from {}!".format(name))
```

Invoking the following command:

```
$ docker-blueprint run test:python 'Docker Blueprint'
```

Will produce the following output:

```
Hello from Docker Blueprint!
```
