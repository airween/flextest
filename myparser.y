%{

#ifdef YYDEBUG
  yydebug = 1;
#endif

#include <stdio.h>
#include <stdlib.h>


extern int yylex();
extern int yyparse();
extern size_t lineno;
extern int include_stack_ptr;
extern char filenames[32][256];

void yyerror(const char* s);
%}

%union {
    char *s;
}

%token <s> T_UNKNOWN
%token <s> T_COMMENT

%token <s> T_CONFIG_DIRECTIVE
%token <s> T_CONFIG_DIRECTIVE_ARGUMENT
%token <s> T_INCLUDE
%token <s> T_INCLUDE_SOURCE

%start config

%%

config: /* empty */
        | config line
;

line: comment
    | config_line
;

comment: T_COMMENT	{ printf("THIS IS A COMMENT in line %zu: '%s'\n", lineno+1, $1); free($1); }
;

config_line:  config_directive_line
            | config_include_line
;

config_directive_line:
      T_CONFIG_DIRECTIVE T_CONFIG_DIRECTIVE_ARGUMENT  { printf("This is a configuration directive and argument: '%s' '%s'\n", $1, $2); free($1); free($2); }
;

config_include_line:
      T_INCLUDE T_INCLUDE_SOURCE         { printf("%s %s\n", $1, $2); free($1); free($2); }
;


%%

void yyerror(const char* s) {
	fprintf(stderr, "Parse error: %s in file %s, line %zu\n", s, filenames[include_stack_ptr], lineno+1);
	exit(1);
}

