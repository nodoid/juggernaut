; keytest.s - keyboard matrix test.
;
; Not part of the game: this builds as its own tape (make keytest) and shows
; the eight by eight key matrix as solid blocks, with a bar at the bottom left
; that grows and shrinks so you can see the loop is running.
;
;   cell at (column, row) = two bytes wide, eight lines tall
;   row 0 column 0 is the top left cell
;
; If the bar moves but no block lights up, the matrix is being read but the
; keys are not arriving.  If the bar is frozen, the frame timer is the problem.

        .include "hw.inc"
        .include "zp.inc"

        .export _game_run

        .import hw_init, wait_frame, kbd_scan, keys
        .importzp frame_count
        .import scr_init, blit_setup, gtext

        .segment "BSS"
kt_i:   .res 1
kt_b:   .res 1
kt_x:   .res 1
kt_n:   .res 1
seen:   .res 8             ; every key that has been down at any time

        .code
_game_run:
        sei
        jsr hw_init
        jsr scr_init
        lda #<t_hdr
        sta txtptr
        lda #>t_hdr
        sta txtptr+1
        ldx #2
        ldy #2
        jsr gtext

@loop:  jsr wait_frame
        jsr kbd_scan
        jsr latch
        jsr draw_matrix
        jsr draw_beat
        jmp @loop

; latch - remember any key that is down, so a quick tap leaves a mark
latch:
        ldx #7
@l:     lda keys,x
        ora seen,x
        sta seen,x
        dex
        bpl @l
        rts

; ---------------------------------------------------------------------------
; draw_matrix - a solid block for every key held down
draw_matrix:
        lda #0
        sta kt_i
@cell:  lda kt_i
        lsr a
        lsr a
        lsr a
        tax                     ; row 0..7
        lda seen,x
        sta kt_b
        lda kt_i
        and #7
        tay                     ; column 0..7
        lda kt_b
        and bit8,y
        beq @off
        lda #$7F
        bne @have
@off:   lda #BLANK
@have:  sta kt_b
        lda kt_i
        and #7
        asl a                   ; two bytes per cell
        sta kt_x
        lda kt_i
        lsr a
        lsr a
        lsr a
        asl a
        asl a
        asl a                   ; eight lines per cell, from line 16
        clc
        adc #16
        ldx kt_x
        jsr blit_setup
        ldy #8
@line:  lda kt_b
        ldx #0
        sta (dptr,x)
        inx
        sta (dptr,x)
        clc
        lda dptr
        adc #SCR_BYTES
        sta dptr
        bcc @nc
        inc dptr+1
@nc:    dey
        bne @line
        inc kt_i
        lda kt_i
        cmp #64
        bne @cell
        rts

bit8:   .byte $01, $02, $04, $08, $10, $20, $40, $80

; ---------------------------------------------------------------------------
; draw_beat - a bar that steps along eight cells, one step every eight frames
draw_beat:
        lda frame_count
        lsr a
        lsr a
        lsr a
        and #7
        sta kt_n
        lda #190
        ldx #0
        jsr blit_setup
        ldy #0
@l:     sty kt_i
        cpy kt_n
        bcs @off
        lda #$7F
        bne @put
@off:   lda #BLANK
@put:   ldy kt_i
        sta (dptr),y
        iny
        cpy #8
        bne @l
        rts

        .segment "RODATA"
t_hdr:  .byte "KEY TEST",0
