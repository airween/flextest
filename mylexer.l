%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wordexp.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

#include "myparser.tab.h"

int parse_config_include(const char * fname);
int open_and_parse(const char * fname);
int close_and_cleanup(int finish);
void get_state(char * state);
int parse_config_directive(const char * confdir);

void push_sym();

size_t lineno = 0;
int lexonly = 0;
int debug = 0;

int include_stack_ptr = -1;
YY_BUFFER_STATE include_stack[32];
char inputbuffers[32][1024];
char filenames[32][256];
char dirnames[32][256];

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

%%

  /* Simple configuration directives */

<INITIAL>(\s*)Conf[a-zA-Z0-9]+                    { push_sym(); return parse_config_directive(yytext); }
<INITIAL>include                                  { push_sym(); BEGIN(ST_INCLUDE_DIRECTIVE); return T_INCLUDE; }
<ST_INCLUDE_DIRECTIVE>[0-9A-Za-z_\/\.\-\*\:]+     { push_sym(); BEGIN(INITIAL); parse_config_include(yytext); return T_INCLUDE_SOURCE; }
<ST_CONFIG_DIRECTIVE>((?:\\\ |[^\ \t\n])+)        { push_sym(); return T_CONFIG_DIRECTIVE_ARGUMENT; }
  /* END Simple configuration directives */

\#.*[^\r\n]             { push_sym(); return T_COMMENT; }
\#(\n|\r\n)             { lineno++; }


<*>(\n|\r\n)  {
                BEGIN(INITIAL);
                lineno++;
              }  

<*>[ \t]      {  }
<*>.|\n|\r\n  { char state[50]; get_state(state); printf("UNKNOWN TOKEN: '%s' in file: %s, line %zu, state: %s\n", yytext, filenames[include_stack_ptr], lineno+1, state); return T_UNKNOWN; }
<<EOF>>       {
                // {}
                include_stack_ptr--;
                if (include_stack_ptr >= 0) {

                    yy_delete_buffer(include_stack[include_stack_ptr+1]);
                    BEGIN(INITIAL);
                    // switch to prev. buffer
                    yy_switch_to_buffer(include_stack[include_stack_ptr]);
                }

                if (include_stack_ptr < 0 || !YY_CURRENT_BUFFER || (include_stack_ptr == 0 && (*YY_CURRENT_BUFFER->yy_buf_pos) == '\0')) {
                    if (include_stack_ptr < 0) {
                        include_stack_ptr++;
                    }
                    yyterminate();
                }
              }

%%

void get_state(char * state) {

    switch(YYSTATE) {
        case ST_COMMENT:
            strcpy(state, "ST_COMMENT");
            break;
        case ST_INCLUDE_DIRECTIVE:
            strcpy(state, "ST_INCLUDE_DIRECTIVE");
            break;
        case ST_CONFIG_DIRECTIVE:
            strcpy(state, "ST_CONFIG_DIRECTIVE");
            break;
        case INITIAL:
            strcpy(state, "INITIAL");
            break;
        default:
            sprintf(state, "UNKNOWN (%d)", YYSTATE);
            break;
    }
}

void push_sym() {
    if (yytext != NULL) {
        yylval.s = strdup(yytext);
        if (yylval.s[strlen(yytext)-1] == '\n') {
            yylval.s[strlen(yytext)-1] = '\0';
        }
    }
    if (debug == 1) {
        char state[20];
        get_state(state);
        printf("state: %s, token: %s\n", state, yylval.s);
    }
}

int parse_config_directive(const char * confdir) {
    int i = 0;
    while(default_config_directives[i][0] != '\0') {
        if (strcmp(default_config_directives[i], confdir) == 0) {
            BEGIN(ST_CONFIG_DIRECTIVE);
            return T_CONFIG_DIRECTIVE;
        }
        i++;
    }
    i = 0;
    return T_UNKNOWN;
}

int parse_config_include(const char * inpname) {

    wordexp_t p;
    char **w;
    int rc;
    struct stat fstat;


    wordexp(inpname, &p, 0);
    w = p.we_wordv;
    for (int wi = p.we_wordc-1; wi >= 0; wi--) {
        // check file exists
        if (lstat(w[wi], &fstat) == -1) {
            printf("File not found: %s\n", w[wi]);
            wordfree(&p);
            close_and_cleanup(1);
            exit(1);
        }

        // avoid the inclusion loop
        if (include_stack_ptr > 0) {
            for(int fi = 0; fi < include_stack_ptr; fi++) {
                if (strcmp(w[wi], filenames[fi]) == 0) {
                    printf("File inclusion loop detected: %s\n", filenames[fi]);
                    wordfree(&p);
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
    FILE * fp;

    if ((fp = fopen(fname, "r"))) {

        include_stack_ptr++;
        strcpy(filenames[include_stack_ptr], fname);

        i = 0;
        // strip slashes
        c = fgetc(fp);
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
            c = fgetc(fp);
        }
        inputbuffers[include_stack_ptr][i] = '\0';

        fclose(fp);

        yy_scan_string(inputbuffers[include_stack_ptr]);
        include_stack[include_stack_ptr] = YY_CURRENT_BUFFER;
        if (include_stack_ptr == 0) {
            if (lexonly == 1) {
                while(yylex());
            }
            else {
                yyparse();
                printf("parser finished\n");
            }
        }
    }
    else {
        printf("Can't open file: %s\n", fname);
        return 1;
    }

    return 0;
}

int close_and_cleanup(int finish) {

    include_stack_ptr--;

    if (include_stack_ptr > 0) {
        BEGIN(INITIAL);
        yy_delete_buffer(include_stack[include_stack_ptr+1]);
        yy_switch_to_buffer(include_stack[include_stack_ptr]);
    }
    if (include_stack_ptr == 0 || !YY_CURRENT_BUFFER || (include_stack_ptr == 0 && (*YY_CURRENT_BUFFER->yy_buf_pos) == '\0')) {
        if(YY_CURRENT_BUFFER) {
            yy_delete_buffer(YY_CURRENT_BUFFER);
        }
    }
    if (finish == 1 && include_stack_ptr >= 0) {
        close_and_cleanup(finish);
    }
    return 1;
}

int main(int argc, char ** argv) {

    if (argc < 2) {
        printf("Argument missing\n");
        return(1);
    }

    if (argc > 2) {
        for(int i=2; i<argc; i++) {
            if (strcmp(argv[i], "lexonly") == 0) {
                lexonly = 1;
            }
            if (strcmp(argv[i], "debug") == 0) {
                debug = 1;
            }
        }
    }

    open_and_parse(argv[1]);

    return 0;
}