all: codeb

clean:
        rm -f *.o
        rm -f lex.yy.c
        rm -f codeb.brg codeb.c
        rm -f codeb
        rm -f oxout*

codeb: oxout.tab.o lex.yy.o codeb.o
        cc -o codeb y.tab.o lex.yy.o codeb.o -lfl

oxout.tab.c oxout.tab.h: oxout.y
        bison -d oxout.y

oxout.y: parser.y scanner.l
        ox parser.y scanner.l

oxout.l: parser.y scanner.l
        ox parser.y scanner.l

lex.yy.c: oxout.l
        flex oxout.l

oxout.tab.o: oxout.tab.c codeb.h
        cc -c oxout.tab.c

yy.lex.o: lex.yy.c oxout.tab.h codeb.h
        cc -c lex.yy.c

codeb.brg: codeb.bfe
        bfe codeb.bfe >codeb.brg

codeb.c: codeb.brg
        iburg codeb.brg >codeb.c

codeb.o: codeb.c codeb.h
        gcc -c codeb.c