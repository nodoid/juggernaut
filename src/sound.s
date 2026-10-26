; sound.s - engine note and crash, on the AY-3-8912 through the VIA
        .include "hw.inc"
        .include "zp.inc"

        .export snd_init, snd_engine, snd_crash, snd_tick, snd_quiet

        .import ay_set

        .bss
snd_timer: .res 1
snd_spd:   .res 1

        .code

; snd_init - tone on channel A only, silent
snd_init:
        lda #0
        sta snd_timer
        lda #7
        ldx #$3E
        jsr ay_set
        lda #8
        ldx #0
        jsr ay_set
        lda #0
        ldx #30
        jsr ay_set
        rts

snd_quiet:
        lda #8
        ldx #0
        jmp ay_set

; ---------------------------------------------------------------------------
; snd_engine - A = speed 0..32: a low note that climbs with the revs
snd_engine:
        sta snd_spd
        cmp #1
        bcs @on
        lda #8
        ldx #0
        jmp ay_set
@on:    asl a
        asl a
        asl a                   ; speed * 8
        clc
        adc #64
        sta tmp1
        lda #0
        ldx tmp1
        jsr ay_set              ; channel A fine tune
        lda #1
        ldx #0
        jsr ay_set
        lda #8
        ldx #7
        jmp ay_set

; ---------------------------------------------------------------------------
; snd_crash - noise burst that fades out over a fifth of a second
snd_crash:
        lda #6
        ldx #12                 ; noise period
        jsr ay_set
        lda #7
        ldx #$16                ; tone A and noise A
        jsr ay_set
        lda #8
        ldx #15
        jsr ay_set
        lda #10
        sta snd_timer
        rts

; snd_tick - called once a frame
snd_tick:
        lda snd_timer
        beq @done
        dec snd_timer
        bne @done
        lda #7
        ldx #$3E
        jsr ay_set
        lda #8
        ldx #0
        jmp ay_set
@done:  rts
