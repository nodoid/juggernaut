; header.s - tape header switches.
;
; The atmos target emits a 31 byte tape header in front of the program.  The
; header, and the short BASIC stub at $0501 that CALLs the machine code, come
; from cc65's atmos library; these two symbols are declared "weak" by the
; linker config so a program can override them.  $C7 in the autostart byte
; makes the Oric run the program as soon as the tape has loaded.
        .export __AUTORUN__: absolute
        .export __PROGFLAG__: absolute

__AUTORUN__  = $C7
__PROGFLAG__ = $00
