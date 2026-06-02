# brst-binding-template

Repository for the language binding of the `libBeresta` library, a free,
open-source, cross-platform library for generating PDF files.

## What's in this repository

This repository contains the template code required to start working
on a language binding.

To ensure consistency between language bindings, this repository provides
a sample `CMakeLists.txt` file that references the `libBeresta` library
and defines three build targets:

| Target    | Description                                            |
|:----------|:-------------------------------------------------------|
| `binding` | Preparation (generation) of language binding files     |
| `check`   | Verification of the binding's functionality            |
| `bundle`  | Building a file for the release archive of the binding |

The presence of a `README.md` file containing a description
of the language binding is also required.

Any other targets, parameters, project structure, etc. are left to your
discretion, but the specified targets must be declared and implemented.

## Generating Binding Files

To create a language binding for any library written in C or another
language, you need to prepare code in your target language for each
function and symbol in the library.

In `libBeresta`, library function information is extracted into separate
generator files (in S-expressions, YAML, or JSON formats), which allows
for the creation of bindings in an automated or semi-automated mode.

See [README.md][gen_readme] and
[https://github.com/libBeresta/libBeresta/blob/master/gen/][gen].

## Process

If you want to create a language binding, start by creating
a PR (Pull Request) in this repository.

Based on your PR, we will create a repository in the [libBeresta][org]
organization and transfer the contents of your PR there so you can
continue your work.

[gen_readme]: https://github.com/libBeresta/libBeresta/blob/master/gen/README.md
[gen]: https://github.com/libBeresta/libBeresta/blob/master/gen
[org]: https://github.com/libBeresta
