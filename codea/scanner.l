%{
#include <stdio.h>
#include <stdlib.h>
#include "oxout.tab.h"
#include <string.h>

long parse_number(const char *text, int base) {
    char buf[256];
    int j = 0;

    for (int i = 0; text[i] != '\0'; ++i) {
        if (text[i] != '_') {
            buf[j] = text[i];
            ++j;
        }
    }
    buf[j] = '\0';

    return strtol(buf, NULL, base); // prefix 0x is dropped automatically for hex
}
%}

%%

 /* Comments and other stuff to ignore */
--.*        { }
[ \t\n]+    { }

 /* Special Characters */
":="                { return ASSIGN; }
"->"                { return ARROW; }
";"                 { return ';'; }
"("                 { return '('; }
")"                 { return ')'; }
","                 { return ','; }
":"                 { return ':'; }
"*"                 { return '*'; }
"+"                 { return '+'; }
">"                 { return '>'; }
"="                 { return '='; }
"-"                 { return '-'; }
"["                 { return '['; }
"]"                 { return ']'; }

 /* Keywords */
"end"               { return END; }
"return"            { return RETURN; }
"var"               { return VAR; }
"cond"              { return COND; }
"continue"          { return CONTINUE; }
"break"             { return BREAK; }
"and"               { return AND; }
"not"               { return NOT; }

 /* Identifier */
[A-Za-z][A-Za-z0-9_]*   return ID; @{ @ID.name@ = strdup(yytext); @}

 /* Numbers */
0x[0-9A-Fa-f_]+     return NUM; @{ @NUM.val@ = parse_number(yytext, 16); @}
[0-9][0-9_]*        return NUM; @{ @NUM.val@ = parse_number(yytext, 10); @}

 /* Error */
. {
    fprintf(stderr, "Lexikalischer Fehler: %s\n", yytext);
    exit(1);
}

 /* return 0 at EOF */
    
%% 
