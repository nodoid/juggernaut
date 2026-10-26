/* main.c - the only C in Juggernaut.
 *
 * Everything that matters (screen, sound, input, physics, world, game logic)
 * lives in the ca65 sources next door.  This file exists to give the program
 * a C entry point and to own the one job that is genuinely easier in C: the
 * high score table comparison.
 */
#include <atmos.h>

#include "juggernaut.h"

int main(void)
{
    /* Never returns: the game owns the machine from here on. */
    game_run();
    return 0;
}

/* hs_beats - is score 'score' better than entry 'slot' of a 10 row table?
 *
 * Rows are 9 bytes: 8 name characters followed by the (binary) score, high
 * score first.  A zero score in a row means the row is still empty.
 * Returns 1 if the score belongs in that row, 0 if not.
 */
unsigned char hs_beats(const unsigned char *row, unsigned score)
{
    unsigned stored;

    stored = row[8] | ((unsigned)row[9] << 8);
    if (stored == 0)
        return 1;
    return score > stored;
}
