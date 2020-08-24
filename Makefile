
all:
	flex mylexer.l
	gcc -Wall -Wextra -g -O0 lex.yy.c -lfl -o myparser

clean:
	rm -f myparser
	rm -f lex.yy.c
