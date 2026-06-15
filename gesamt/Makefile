all: gesamt

test: gesamt
	@for f in input/* ; do  echo "input:"; cat $$f; echo "output:"; ./example <$$f; echo "---------------------------"; done
clean:
	rm -f *.o
	rm -f lex.yy.c
	rm -f gesamt.brg gesamt.c
	rm -f gesamt
	rm -f oxout*

gesamt: oxout.tab.o lex.yy.o gesamt.o
	cc -g -o gesamt oxout.tab.o lex.yy.o gesamt.o -lfl

oxout.tab.c oxout.tab.h: oxout.y
	bison -d oxout.y

oxout.y: parser.y scanner.l
	ox parser.y scanner.l

oxout.l: parser.y scanner.l
	ox parser.y scanner.l

lex.yy.c: oxout.l
	flex oxout.l

oxout.tab.o: oxout.tab.c gesamt.h
	cc -g -c oxout.tab.c

yy.lex.o: lex.yy.c oxout.tab.h gesamt.h
	cc -g -c lex.yy.c

gesamt.brg: gesamt.bfe
	bfe gesamt.bfe >gesamt.brg

gesamt.c: gesamt.brg
	iburg gesamt.brg >gesamt.c

gesamt.o: gesamt.c gesamt.h
	gcc -g -c gesamt.c
