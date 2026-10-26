# Juggernaut for the Oric Atmos

A recreation of CRL's 1985 Spectrum game *Juggernaut* by Pete Cooke, written for
the 48K Oric Atmos.  You drive an articulated lorry around the town of
Scarthorpe collecting Timber, Coal, Oil and Fruit & Veg from the wholesalers
and tipping them at the depot, keeping an eye on the damage, the fuel and the
clock.

Almost all of it is 6502 assembly (`src/*.s`).  The C compiler is only used to
give the program an entry point and to compare high scores (`src/main.c`); the
C runtime starts, calls `game_run()` and the assembly never comes back.

## Building

You need [cc65](https://cc65.github.io/) (`cl65`, `ca65`, `ld65`) and Python 3.

```sh
make            # builds build/juggernaut.tap
make run        # boots the tape in Oricutron
```

The generated sources in `data/` (font, town map, sprites) are checked in, but
they can be rebuilt:

```sh
python3 tools/gen_assets.py    # font and lookup tables
python3 tools/gen_town.py      # the town of Scarthorpe
python3 tools/gen_gfx.py       # lorry, icons and the wheel
make
```

`build/juggernaut.tap` loads and runs on an Atmos from BASIC with `CLOAD""`, or
with `oricutron -m atmos -t build/juggernaut.tap -a`.

## Controls

| Key | Action |
|-----|--------|
| `A` | accelerate |
| `Z` | brake / slow down |
| `O` | steer left |
| `P` | steer right |
| `M` or Space | fire: menus, change gear (only when stopped) |
| `S` | back to the map, when the lorry is stopped |

Gears run 0 (neutral) to 5 (reverse), with 1 to 4 forwards.  The lorry only
moves in gear, and you can only change gear when it is stationary, exactly as
in the original.

Every one of those keys can be changed: DEFINE KEYS on the main menu lists the
six actions with the key each one is on, `O`/`P` move up and down the list and
the fire key starts a rebinding - let go of everything, then press the key you
want.  DONE goes back to the main menu.  The new keys last until the machine is
reset.  That screen always answers to `O`, `P`, `M`, Space and to the fire key you
have just chosen, so it can never lock you out, and the arrow keys, Escape and
the shifts and controls can all be bound (they are shown shortened: `UP`, `LT`,
`ES`, `RC` and so on).
`M` and Space also keep working as fire everywhere else, whatever the fire key
has been changed to, so the menus can never be left without one.

## How it is put together

| File | What it does |
|------|--------------|
| `src/header.s` | tape and BASIC headers so the file autoloads |
| `src/hw.s` | VIA, AY-3-8912, keyboard matrix, 50Hz frame timer |
| `src/screen.s` | HIRES screen, the ULA mode attribute, text rows, plotting |
| `src/dash.s` | the dashboard: load sheet, gauges, gear/speed/clock |
| `src/town.s` | tile map, view drawing, collision |
| `src/truck.s` | tractor and trailer physics, camera, damage |
| `src/ui.s` | title, menus, the drive icons and the town map |
| `src/game.s` | state machine, jobs, loading, unloading, scoring |
| `src/sound.s` | engine note and crash on the AY |

### The screen

The picture is HIRES: 200 lines of 40 bytes at `$A000`, six pixels per byte.
The ULA has no mode register - a byte whose bits 5 and 6 are both clear is an
attribute, and the mode is chosen by leaving a `$1C` video-mode attribute as
the first byte of the text page, where the raster meets it on the first line
of the frame.  That is why blank pixels are `$40` and not `$00`: a zero byte
would be read as an attribute and change the colours.

The bottom three character rows (`$BF68` upwards) are drawn by the ULA from
the ROM character set, so the gear, speed, clock and the messages use ordinary
ASCII there.

### Weights

Every tonnage is shown with its kilos as well.  The dashboard uses the columns
under the `CAPACITY T/KG` heading and shows `9/9000`, meaning nine tons,
nine thousand kilos; the messages at the bottom spell it out as `6T (6000KG)`.
One ton is a thousand kilos.

## Testing

`tools/simrun.py` runs the tape image on a host 6502 (py65) with enough of the
VIA and AY modelled to serve the keyboard, then renders the screen the way the
ULA would.  It is the quick way to see a screen without the emulator:

```sh
# press M (matrix row 2, column 0) twice: title to menu, menu to drive
python3 tools/simrun.py --steps 400000 \
    --press 2:0:95000:105000 \
    --press 2:0:180000:190000 \
    --out /tmp/drive.png
```

`--press ROW:COL:FROM:TO` holds a key matrix position down between two
instruction counts, so a sequence of key presses can drive the game into any
screen.  ROW and COL are indices 0-7, not masks; the matrix layout is in
`src/hw.inc`.  `--trace ADDR` prints a byte whenever it changes, which is how
the state machine and the key bindings can be followed step by step.

## What is in and what is not

Working: the title, the main menu, defining keys, the practice menu, the drive
screen with its six icons, the town map and phone directory, driving with gears,
steering, the trailer, damage on kerbs and buildings, fuel, the clock, loading
at the wholesalers, unloading at the depot, the garage, the tonnage in tons and
kilos, and the end of game score.

Simplified compared with the Spectrum original: there are no other vehicles on
the roads, the load quantity is "as much as fits" rather than a number you
choose with left/right, the high score table is displayed but not yet filled
in, the key definitions are not saved anywhere, and the practice menu has one
course rather than the five in the original.
