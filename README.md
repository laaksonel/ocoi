# OCaml On Ice
OCaml On Ice is a web framework in the style of Ruby on Rails, built on top of
[Opium](https://github.com/rgrinberg/opium). It is designed for building REST APIs, espeically ones that are consumed by
BuckleScript or js\_of\_ocaml frontends. Documentation is [here](https://roddyyaga.github.io/ocoi/ocoi/index.html), in
particular see the [tutorial](https://roddyyaga.github.io/ocoi/ocoi/tutorial.html) and [design philosophy](https://roddyyaga.github.io/ocoi/ocoi/designphilosophy.html).

## Project status
Currently (2020-5-5) building a project with it and reworking parts as I go. I plan to release a stableish version with good docs in a few weeks, but if you're feeling brave it should be usable in the mean time (the tutorial should be fairly up to date).

## Installation
Ice isn't on OPAM yet as it relies on the master version of Opium. You can install it with `git clone git@github.com:roddyyaga/ocoi.git && cd ocoi && opam install .`. It also depends on PostgreSQL and [inotify-tools](https://github.com/rvoicilas/inotify-tools/wiki).
To check the install worked:
```
$ ocoi version
```

## Summary
### Features
- Command-line tool (`ocoi`):
  - Code generation from record types
    - Database schemas and queries
    - Controllers
  - Project scaffolding
  - Development server that watches source code

- Library (`Ocoi`):
  - Controller modules
  - Authentication
  - Middleware
    - Logging
    - Enabling CORS

### Design
- MVCish Rails-inspired project structure
- But designed from the beginning for web apps with a REST API backend/modern (compiled-to)-JS framework frontend architecture
  - (rather than rendering pages server-side with templates)
- Where relevant, code should be shareable with frontends written in OCaml (or ReasonML)
- Database code generation rather than an ORM (for now at least)

### Example
After successfully installing Ice, executing these commands with a running Postgres instance on `localhost:5432` with password `12345` gives an API that exposes CRUD functionality (Create Read Update Delete and Index) for the specified todo type on `localhost:3000/todos`.
```bash
# Create a new project
ocoi new todo &&
cd todo &&
# Create a model
echo "type t = {id: int; title: string; completed: bool} [@@deriving yojson]" > app/models/todo.ml &&
# Generate code for the model
ocoi generate scaffold app/models/todo.ml &&
# Create the DB table for the model
ocoi db migrate todo &&
# Create routes for the model's controller
sed -i 's!|> hello_world!|> Ocoi.Controllers.register_crud "/todos" (module Controllers.Todo.Crud)!g' app/main.ml &&
# Start the server
ocoi server
```
