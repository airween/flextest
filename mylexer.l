%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wordexp.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>


int parse_config_include(const char * fname);
int open_and_parse(const char * fname);
int close_and_cleanup(int finish);

int parse_config_directive(const char * confdir);

size_t lineno = 0;

int include_stack_ptr = 0;
YY_BUFFER_STATE include_stack[10];
FILE *fps[10];
char inputbuffers[10][1024];
char filenames[10][256];
char dirnames[10][256];

const char default_config_directives[][50] = {
    "ConfKey1",
    "ConfKey2",
    ""
};

%}
%option caseless
%option nounput
%option noinput

%x ST_COMMENT
%x ST_INCLUDE_DIRECTIVE
%x ST_CONFIG_DIRECTIVE
%x ST_CONFIG_DIRECTIVE_QUOTED_ARGUMENT

%%

  /* Simple configuration directives */

<INITIAL>(\s*)Conf[a-zA-Z0-9]+                    { printf("Directive: %s\n", yytext); parse_config_directive(yytext); }
<INITIAL>include                                  { printf("Include\n"); BEGIN(ST_INCLUDE_DIRECTIVE); }
<ST_INCLUDE_DIRECTIVE>[0-9A-Za-z_\/\.\-\*\:]+     { printf("Include file: %s\n", yytext); include_stack_ptr++; parse_config_include(yytext); BEGIN(INITIAL); }
<ST_CONFIG_DIRECTIVE>((?:\\\ |[^\ \t\n])+)        { printf("Directive argument: %s\n", yytext); }
  /* END Simple configuration directives */

\#.*[^\r\n]             { printf("Comment: %s\n", yytext); }
\#(\n|\r\n)             { lineno++; printf("Comment: %s\n", yytext); }


<*>(\n|\r\n)  {
                lineno++;
              }  

<*>[ \t]      {  }
<*>.|\n|\r\n  { printf("UNKNOWN TOKEN: '%s' in line %zu\n", yytext, lineno+1); }
<<EOF>>       {
                  printf("-> Got EOF, stack_ptr: %d\n", include_stack_ptr);
                  BEGIN(INITIAL);
                  if (include_stack_ptr >= 0) {
                      close_and_cleanup(0);
                  }
                  if (include_stack_ptr < 0) {
                      yyterminate();
                  }
              }

%%

int parse_config_directive(const char * confdir) {
    int i = 0;
    while(default_config_directives[i][0] != '\0') {
        if (strcmp(default_config_directives[i], confdir) == 0) {
            BEGIN(ST_CONFIG_DIRECTIVE);
        }
        i++;
    }
    i = 0;
    return 0;
}

int parse_config_include(const char * inpname) {

    wordexp_t p;
    char **w;
    int rc;
    struct stat fstat;


    wordexp(inpname, &p, 0);
    w = p.we_wordv;
    for (size_t wi = 0; wi < p.we_wordc; wi++) {
        // check file exists
        if (lstat(w[wi], &fstat) == -1) {
            printf("File not found: %s\n", w[wi]);
            wordfree(&p);
            include_stack_ptr--;
            close_and_cleanup(1);
            exit(1);
        }

        // avoid the inclusion loop
        if (include_stack_ptr > 0) {
            for(int fi = 0; fi < include_stack_ptr; fi++) {
                if (strcmp(w[wi], filenames[fi]) == 0) {
                    printf("File inclusion loop detected: %s\n", filenames[fi]);
                    wordfree(&p);
                    include_stack_ptr--;
                    close_and_cleanup(1);
                    exit(1);
                }
            }
        }
        // end of avoid the inclusion loop

        // try to parse file
        BEGIN(INITIAL);
        rc = open_and_parse(w[wi]);
        if (rc != 0) {
            break;
        }
    }
    wordfree(&p);

    return 0;
}

int open_and_parse(const char * fname) {

    long i;
    int c;
    int last_is_slash = 0;

    printf("-> Opening file: %s\n", fname);
    if ((fps[include_stack_ptr] = fopen(fname, "r"))) {

        strcpy(filenames[include_stack_ptr], fname);

        i = 0;
        // strip slashes
        c = fgetc(fps[include_stack_ptr]);
        while(c > 0) {
            if (last_is_slash == 0) {
                if (c == '\\') {
                    last_is_slash = 1;
                }
                inputbuffers[include_stack_ptr][i++] = c;
            }
            else {
                last_is_slash = 0;
                if (c != '\\') {
                    inputbuffers[include_stack_ptr][i++] = c;
                }
            }
            c = fgetc(fps[include_stack_ptr]);
        }
        inputbuffers[include_stack_ptr][i] = '\0';

        if (include_stack_ptr == 0) {
            yy_scan_string(inputbuffers[include_stack_ptr]);
            while(yylex());
        }
        else {
            include_stack[include_stack_ptr-1] = YY_CURRENT_BUFFER;
            yy_scan_string(inputbuffers[include_stack_ptr]);
        }
    }
    else {
        printf("Can't open file: %s\n", fname);
        return 1;
    }

    return 0;
}

int close_and_cleanup(int finish) {

    if (include_stack_ptr >= 0) {
        printf("-> Closing file: %s\n", filenames[include_stack_ptr]);
        fclose(fps[include_stack_ptr]);
    }

    if (include_stack_ptr <=  0) {
        yylex_destroy();
    }
    else {
        if (include_stack_ptr > 0) {
            yy_delete_buffer(YY_CURRENT_BUFFER);
            yy_switch_to_buffer(include_stack[include_stack_ptr-1]);
        }
    }

    include_stack_ptr--;
    if (finish == 1 && include_stack_ptr >= 0) {
        close_and_cleanup(1);
    }

    if (include_stack_ptr >= 0) {
        return 1;
    }
    else {
        return 0;
    }
}

int main(int argc, char ** argv) {

    if (argc < 2) {
        printf("Argument missing\n");
        return(1);
    }

    parse_config_include(argv[1]);

    return 0;
}