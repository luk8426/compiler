CC = gcc
CFLAGS = -Wall -g
TARGET = ag

SRC_Y = parser.y
SRC_LEX = scanner.l

OX_Y = oxout.y
OX_L = oxout.l

BISON_C = oxout.tab.c
BISON_H = oxout.tab.h
LEX_C = lex.yy.c

OBJS = oxout.tab.o lex.yy.o

all: $(TARGET)

$(TARGET): $(SRC_Y) $(SRC_LEX)
        ox $(SRC_Y) $(SRC_LEX)
        bison -d $(OX_Y)
        flex $(OX_L)
        $(CC) $(CFLAGS) -c $(BISON_C)
        $(CC) $(CFLAGS) -c $(LEX_C)
        $(CC) $(CFLAGS) -o $(TARGET) $(OBJS) -lfl

clean:
        rm -f $(TARGET)
        rm -f $(OX_Y) $(OX_L)
        rm -f $(BISON_C) $(BISON_H) $(LEX_C)
        rm -f *.o