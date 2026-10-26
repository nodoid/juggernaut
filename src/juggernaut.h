#ifndef JUGGERNAUT_H
#define JUGGERNAUT_H

/* game_run - the assembly game.  Takes the machine over and never returns. */
void __fastcall__ game_run(void);

/* hs_beats - does 'score' belong in this high score row? */
unsigned char hs_beats(const unsigned char *row, unsigned score);

#endif
