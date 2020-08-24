# Flex example for file inclusion

A simple test project to demonstrate how flex (part of GNU [bison](https://www.gnu.org/software/bison/)) works.

## Description

The lex file (mylexer.l) contains a very simple lexical analyzer. It capable to recognize comments, "ConfKey1" and "Confkey2" directives (the list is extendable), and the "include" directive with an argument (filename). If the lexer founds an "include" line, it opens the file and continue the analysis from that point.

## Getting Started

### Dependencies

To compile and test you need:

* GNU Bison (flex at least)
* GCC - or another C compiler, just replace it in Makefile
* make

### Installing

* download the source
* type a single `make` command

This will generate the lex.yy.c C source, and the `myparser` binary.

### Executing program

The source tree contains some configs, you can check the different behaviors.

* first, just run this progam: `./myparser config1.conf`. In the result, you can see the operations with a "->" prefix, and the recognized tokens
  ```
  $ cat config1.conf
  # file: config1.conf
  # this is a config
  
  ConfKey1  foo

  $ ./myparser config1.conf
  -> Opening file: config1.conf
  Comment: # file: config1.conf
  Comment: # this is a config
  Directive: ConfKey1
  Directive argument: foo
  -> Got EOF, stack_ptr: 0
  -> Closing file: config1.conf
  ```
* then run `./myparser inctest_01.conf`. This file contains two `include` lines sequentually
* finally, run the binary with `inctest_02.conf`, and see the differences

## Authors

[Ervin Hegedüs](https://github.com/airween)

## Version History

* 0.1
    * Initial Release

## License

This project is licensed under the GNU GPL License - see the LICENSE file for details.

