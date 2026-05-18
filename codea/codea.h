#ifndef CODE_H_
#define CODE_H_

#define ADD 1
#define REG 2
#define NUM 3
#define ASSIGN 4
#define ADDASSIGN 5

#ifdef USE_IBURG
#ifndef BURM
typedef struct burm_state *STATEPTR_TYPE;
#endif
#else
#define STATEPTR_TYPE int
#endif

typedef struct s_node {
	int		op;
	struct s_node   *kids[2];
	STATEPTR_TYPE	state;
        /* user defined data fields follow here */
	char*		regname;
	int		val;
} treenode;

typedef treenode *treenodep;

#define NODEPTR_TYPE	treenodep
#define OP_LABEL(p)	((p)->op)
#define LEFT_CHILD(p)	((p)->kids[0])
#define RIGHT_CHILD(p)	((p)->kids[1])
#define STATE_LABEL(p)	((p)->state)
#define PANIC		printf

#endif
