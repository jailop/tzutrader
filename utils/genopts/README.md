genopts.awk
================

Overview
--------

genopts.awk is a small AWK script that generates a C++ header
providing a Config struct, a parse_args() function and a print_help()
function from a simple, human-readable option specification file.

The script reads a spec file describing command-line options and
positional argument(s), then writes a header (typically redirected to
generated_config.h) which can be included in C++ programs to handle
argument parsing and help text automatically.

Input specification format
--------------------------

Each non-empty, non-comment line in the spec file has this form:

TYPE NAME DEFAULT "Description text"

where:

- TYPE: the C++ type to declare for this option (e.g. bool, int, size_t,
  double, std::string, etc.).
- NAME: the option name used for the long flag ("--NAME") and as the
  struct member.
- DEFAULT: the default value emitted into the struct field (e.g. 0, 1,
  "", false).
- Description: a quoted string used in the generated help output.

To declare a positional argument (a filename or other required
positional value), set DEFAULT to the literal POSITIONAL; the script
then emits a std::string member for the positional argument and includes
it in the Usage line.

Behavior and supported conversions
---------------------------------

- Boolean options (TYPE == "bool") become flags that set the struct
  member to true when present.
- Numeric types are converted using std::stoi (int), std::stoul (size_t)
  and std::stod (double) in the generated parser.
- Other types (including string-like types) are assigned the argv value
  as-is.
- Short flags are auto-assigned using the first unused letter of the
  NAME; a -h/--help handler is emitted to print usage and exit.

Generated output
----------------

The script emits a C++ header guarded by #ifndef/#endif, defining:

- struct Config { ... } with members for each option
- inline void print_help() to print usage and option descriptions
- inline void parse_args(Config&, int, char** ) which parses argc/argv
  and fills the Config

Usage
-----

Make the AWK script executable (it already has a shebang) and run it
against a spec file:

    ./genopts.awk spec.txt > generated_config.h

Then include the generated header in your C++ project and call
parse_args(cfg, argc, argv) to populate the Config instance.

Example spec
------------

Example spec.txt:

    bool verbose false "Enable verbose logging"
    int threads 4 "Number of worker threads"
    size_t limit 1024 "Size limit in bytes"
    std::string out "output.txt" "Output filename"
    std::string input POSITIONAL "Input file"

Examples
--------

Generate the header, include it in your program, and compile:

    ./genopts.awk spec.txt > generated_config.h
    g++ main.cpp -o myprog

Notes
-----

- The script makes assumptions about default value formatting; ensure
  defaults are valid C++ literals where necessary.
- The generated parser uses simple argument scanning and does not
  support combined short flags or advanced getopt-style syntax.
