; dash.s - the lorry's dashboard, the top 64 lines of the screen
;
; Laid out like the Spectrum original: the load sheet on the left, the
; instrument bars in the middle and the wheel, gear and clock on the right.

        .include "hw.inc"
        .include "zp.inc"

        .export dash_init, dash_update, dash_bar, gchar, gtext_p, dash_num3
        .export dash_num2, dash_num3, dash_tons

        .import blit_or, blit_setup
        .import text_char, text_str, text_dec2
        .import wheel_sprite

        .bss
dv_val:  .res 1
dv_col:  .res 1
dv_line: .res 1
dv_r:    .res 1
dv_t:    .res 1
gch_c:   .res 1
gch_x:   .res 1
gch_y:   .res 1
gch_off: .res 2
gch_cnt: .res 1
db_val:  .res 1
db_fill: .res 1
db_col:  .res 1
db_line: .res 1
dt_t:    .res 1
dt_col:  .res 1
dt_line: .res 1
dt_d1:   .res 1
dt_d2:   .res 1

        .code

; ---------------------------------------------------------------------------
; gtext_p - A = low byte, X = high byte of a string, then X/Y = col/line
; Convenience wrapper: caller sets txtptr itself for the general case.
gtext_p:
        jmp gtext

; ---------------------------------------------------------------------------
; gchar - A = character, X = byte column, Y = line
gchar:
        sta gch_c
        stx gch_x
        sty gch_y
        sec
        sbc #32
        bcs @1
        lda #0
@1:     cmp #96
        bcc @2
        lda #0
@2:     asl a
        sta gch_off
        lda #0
        rol a
        sta gch_off+1
        asl gch_off
        rol gch_off+1
        asl gch_off
        rol gch_off+1
        lda #<(CHARSET+$100)
        clc
        adc gch_off
        sta sptr
        lda #>(CHARSET+$100)
        adc gch_off+1
        sta sptr+1
        lda gch_y
        ldx gch_x
        jsr blit_setup
        lda #8
        sta gch_cnt
@row:   ldy #0
        lda (sptr),y
        sta (dptr),y
        inc sptr
        bne @n1
        inc sptr+1
@n1:    clc
        lda dptr
        adc #SCR_BYTES
        sta dptr
        bcc @n2
        inc dptr+1
@n2:    dec gch_cnt
        bne @row
        rts

; gtext - string at txtptr, X = column, Y = line
gtext:
        stx gch_x
        sty gch_y
@l:     ldy #0
        lda (txtptr),y
        beq @done
        ldx gch_x
        ldy gch_y
        jsr gchar
        inc gch_x
        inc txtptr
        bne @l
        inc txtptr+1
        jmp @l
@done:  rts

; ---------------------------------------------------------------------------
; The dashboard is eight character rows of eight lines each.  Text on two
; rows only four lines apart would collide, so everything sits on the grid:
;
;   row 0  LENGTH (FT) 38          DAMAGE
;   row 1  CAPACITY T(KG)          [damage bar]
;   row 2  16T(16000)              FUEL
;   row 3  STOCK      TARGET       [fuel bar]
;   row 4  TIMBER ...              SPEED
;   row 5  COAL   ...              [speed bar]
;   row 6  OIL    ...
;   row 7  FRUIT+V ...             gear, speed and clock go in the text row
;
; The left column ends at byte 27 and the bars start at byte 30, so the two
; never meet.
.macro SAYPTR lbl, col, line
        lda #<lbl
        sta txtptr
        lda #>lbl
        sta txtptr+1
        ldx #col
        ldy #line
        jsr gtext
.endmacro

dash_init:
        SAYPTR s_length,    0,  0
        SAYPTR s_capacity,  0,  8
        SAYPTR s_stockhdr, 11, 24
        SAYPTR s_targethdr, 18, 24
        SAYPTR s_timber,    0, 32
        SAYPTR s_coal,      0, 40
        SAYPTR s_oil,       0, 48
        SAYPTR s_fruit,     0, 56
        SAYPTR s_damage,   25,  0
        SAYPTR s_fuel,     25, 16
        SAYPTR s_speed,    25, 32
        ; length and capacity are fixed for the run
        lda trk_len
        ldx #12
        ldy #0
        jsr dash_num2
        lda trk_cap
        ldx #23
        ldy #16
        jsr dash_tons
        jmp dash_status

; ---------------------------------------------------------------------------
dash_update:
        lda stock+0
        ldx #14
        ldy #32
        jsr dash_tons
        lda target+0
        ldx #23
        ldy #32
        jsr dash_tons
        lda stock+1
        ldx #14
        ldy #40
        jsr dash_tons
        lda target+1
        ldx #23
        ldy #40
        jsr dash_tons
        lda stock+2
        ldx #14
        ldy #48
        jsr dash_tons
        lda target+2
        ldx #23
        ldy #48
        jsr dash_tons
        lda stock+3
        ldx #14
        ldy #56
        jsr dash_tons
        lda target+3
        ldx #23
        ldy #56
        jsr dash_tons
        lda trk_dmg
        ldx #31
        ldy #8
        jsr dash_bar
        lda trk_fuel
        ldx #31
        ldy #24
        jsr dash_bar
        lda trk_spd
        asl a
        asl a
        asl a                   ; 0..255 for the bar
        ldx #31
        ldy #40
        jsr dash_bar
        jmp dash_status

; ---------------------------------------------------------------------------
; dash_status - gear, speed and the clock live in the text row under the
; picture, where there is a whole forty columns to play with.
dash_status:
        lda #<s_gear
        sta txtptr
        lda #>s_gear
        sta txtptr+1
        ldx #1
        ldy #1
        jsr text_str
        lda trk_gear
        clc
        adc #48
        ldx #1
        ldy #6
        jsr text_char
        lda #<s_mph
        sta txtptr
        lda #>s_mph
        sta txtptr+1
        ldx #1
        ldy #9
        jsr text_str
        lda trk_spd
        bpl @p
        eor #$FF
        clc
        adc #1
@p:     lsr a
        lsr a
        lsr a
        sta dv_t
        asl a
        asl a
        clc
        adc dv_t
        ldx #1
        ldy #13
        jsr text_dec2
        lda #<s_time
        sta txtptr
        lda #>s_time
        sta txtptr+1
        ldx #1
        ldy #18
        jsr text_str
        lda time_m
        ldx #1
        ldy #23
        jsr text_dec2
        lda #':'
        ldx #1
        ldy #25
        jsr text_char
        lda time_s
        ldx #1
        ldy #26
        jmp text_dec2

; ---------------------------------------------------------------------------
; dash_tons - A = tons, X = last column of the field, Y = line.
;
; Prints the weight both ways round, right aligned so the columns line up:
; 9 tons becomes "9/9000" and 15 tons "15/15000", the kilo figure under the
; T/KG heading.  One metric ton is a thousand kilos, so the kilo digits are
; the ton digits with 000 after them.  The characters are laid down from the
; right, so the caller only has to know where the number has to end.
dash_tons:
        sta dt_t
        stx dt_col
        sty dt_line
        lda #'0'
        jsr dt_put
        jsr dt_put
        jsr dt_put
        jsr dt_digits           ; kilo digits: same as the tons
        lda #'/'
        jsr dt_put
        jmp dt_digits           ; the tons themselves

dt_digits:
        lda dt_t
        jsr dt_split
        lda dt_d2
        clc
        adc #48
        jsr dt_put
        lda dt_d1
        beq @done
        clc
        adc #48
        jmp dt_put
@done:  rts

dt_split:                       ; A = 0..99 -> dt_d1 = tens, dt_d2 = units
        ldx #0
@l:     cmp #10
        bcc @d
        sbc #10
        inx
        jmp @l
@d:     stx dt_d1
        sta dt_d2
        rts

dt_put:                         ; A = character, written at dt_col/dt_line.
        sta dt_ch                   ; gchar clobbers A, and callers write the
        ldx dt_col                  ; same character more than once.
        ldy dt_line
        lda dt_ch
        jsr gchar
        dec dt_col
        lda dt_ch
        rts

dt_ch:   .byte 0

; ---------------------------------------------------------------------------
; dash_num2 - A = 2 digit value at X = column, Y = line
dash_num2:
        sta dv_val
        stx dv_col
        sty dv_line
        ldx #0
@t:     cmp #10
        bcc @t2
        sbc #10
        inx
        jmp @t
@t2:    sta dv_r
        txa
        beq @space
        clc
        adc #48
        jsr dnum_put
        jmp @unit
@space: lda #32
        jsr dnum_put
@unit:  lda dv_r
        clc
        adc #48
        jmp dnum_put

; dash_num3 - A = 0..255 as three digits
dash_num3:
        sta dv_val
        stx dv_col
        sty dv_line
        ldx #0
@h:     cmp #100
        bcc @h2
        sbc #100
        inx
        jmp @h
@h2:    sta dv_r
        txa
        clc
        adc #48
        jsr dnum_put
        lda dv_r
        ldx #0
@t:     cmp #10
        bcc @t2
        sbc #10
        inx
        jmp @t
@t2:    sta dv_r
        txa
        clc
        adc #48
        jsr dnum_put
        lda dv_r
        clc
        adc #48
dnum_put:
        sta dnp_c
        ldx dv_col
        ldy dv_line
        lda dnp_c
        jsr gchar
        inc dv_col
        rts
dnp_c:  .byte 0

; ---------------------------------------------------------------------------
; dash_bar - A = value 0..255, X = column, Y = line: nine cells wide and two
; lines tall, filled from the left.
dash_bar:
        sta db_val
        stx db_col
        sty db_line
        ldx #0
@div:   cmp #28
        bcc @got
        sbc #28
        inx
        jmp @div
@got:   stx db_fill
        ldx db_col
        lda db_line
        jsr blit_setup
        ldy #0
@l:     lda #BLANK
        cpy db_fill
        bcs @s
        lda #$7F
@s:     sta (dptr),y
        iny
        cpy #9
        bne @l
        clc
        lda dptr
        adc #SCR_BYTES
        sta dptr
        bcc @n
        inc dptr+1
@n:     ldy #0
@l2:    lda #BLANK
        cpy db_fill
        bcs @s2
        lda #$7F
@s2:    sta (dptr),y
        iny
        cpy #9
        bne @l2
        rts

        .segment "RODATA"
s_length:   .byte "LENGTH (FT)",0
s_capacity: .byte "CAPACITY T/KG",0
s_stockhdr: .byte "STOCK",0
s_targethdr: .byte "TARGET",0
s_timber:   .byte "TIMBER",0
s_coal:     .byte "COAL",0
s_oil:      .byte "OIL",0
s_fruit:    .byte "FRUIT+V",0
s_damage:   .byte "DAMAGE",0
s_fuel:     .byte "FUEL",0
s_speed:    .byte "SPEED",0
s_gear:     .byte "GEAR",0
s_time:     .byte "TIME",0
s_mph:      .byte "MPH",0

