
all:
	bison -d myparser.y
	flex mylexer.l
	gcc -Wall -Wextra -g -O0 myparser.tab.c lex.yy.c -lfl -o myparser

debug:
	bison -d myparser.y
	flex -d mylexer.l
	gcc -Wall -Wextra -g -O0 myparser.tab.c lex.yy.c -lfl -o myparser

clean:
	rm -f myparser
	rm -f lex.yy.c
	rm -r myparser.tab.c
	rm -r myparser.tab.h
