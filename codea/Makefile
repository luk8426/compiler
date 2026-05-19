all: codea

clean:
        rm -f *.o
        rm -f lex.yy.c
        rm -f codea.brg codea.c
        rm -f codea
        rm -f oxout*

codea: oxout.tab.o lex.yy.o codea.o
        cc -o codea y.tab.o lex.yy.o codea.o -lfl

oxout.tab.c oxout.tab.h: oxout.y
        bison -d oxout.y

oxout.y: parser.y scanner.l
        ox parser.y scanner.l

oxout.l: parser.y scanner.l
        ox parser.y scanner.l

lex.yy.c: oxout.l
        flex oxout.l

oxout.tab.o: oxout.tab.c codea.h
        cc -c oxout.tab.c

yy.lex.o: lex.yy.c oxout.tab.h codea.h
        cc -c lex.yy.c

codea.brg: codea.bfe
        bfe codea.bfe >codea.brg

codea.c: codea.brg
        iburg codea.brg >codea.c

codea.o: codea.c codea.h
        gcc -c codea.c