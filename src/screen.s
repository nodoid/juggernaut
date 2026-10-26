; screen.s - Oric HIRES screen handling
;
; The display is 40 bytes wide and 200 lines tall at $A000.  Every byte holds
; six pixels in bits 0-5 (bit 5 leftmost) and must keep bit 6 set; bit 7
; inverts the six pixels.  Blank paper is therefore $40, not $00.
;
; Everything is drawn in one ink colour (yellow) on black paper, like the
; Spectrum original's map view, so sprites can simply be OR-ed into the
; screen: a zero pixel bit leaves the background alone.

        .include "hw.inc"
        .include "zp.inc"

        .export scr_init, scr_clear, scr_mode, scr_palette
        .export text_clear, text_char, text_str, text_num8, text_num16
        .export text_tons, text_dec2
        .export blit_or, blit_cp, blit_setup, row_addr, gtext
        .export fill_mem, outline, hline, vline, plotpix, fill_screen
        .export viewrows_init, viewrows
        .exportzp numlo, numhi

        .import font_data, xtab, xbit

        .bss
viewrows: .res 256              ; 128 words: screen address of view line 0..127

        .code

; ---------------------------------------------------------------------------
; scr_palette - nothing to program.
;
; The ULA has no colour registers: it decodes bytes whose bits 5 and 6 are
; both clear as attributes while it draws.  Every scanline starts white on
; black, so the picture needs no attributes at all, and an attribute byte
; would cost six pixels - which is why the view is drawn in white and the
; colour appears only in the character rows underneath.
scr_palette:
        rts

; scr_mode - switch the ULA to HIRES
;
; There is no mode register either.  The trick is to leave a video-mode
; attribute ($1C = HIRES, 50Hz) as the first byte of the text page: the
; raster meets it on the first line of the frame, switches to $A000 and
; never reads $BB80 again, so the mode sticks.
scr_mode:
        lda #$1C
        sta TEXTBASE
        rts

; ---------------------------------------------------------------------------
; scr_init - palette, mode, blank screen, blank text rows, load the font.
scr_init:
        jsr scr_palette
        lda #BLANK
        jsr fill_screen
        jsr scr_mode
        jsr text_clear
        lda #<font_data
        sta sptr
        lda #>font_data
        sta sptr+1
        lda #<(CHARSET+$100)
        sta dptr
        lda #>(CHARSET+$100)
        sta dptr+1
        ldy #0
        ldx #4                  ; 4 pages = 1024 bytes (96 glyphs + slack)
@pg:    lda (sptr),y
        sta (dptr),y
        iny
        bne @pg
        inc sptr+1
        inc dptr+1
        dex
        bne @pg
        jmp viewrows_init

; fill_screen - fill the whole HIRES area with A
fill_screen:
        sta @v
        lda #>HIRES
        sta @st+2
        ldx #0
@l:     lda @v
@st:    sta $A000,x
        inx
        bne @l
        inc @st+2
        lda @st+2
        cmp #>VID_END
        bne @l
        ldx #0
@l2:    lda @v
        sta $BF00,x
        inx
        cpx #(VID_END & $FF)
        bne @l2
        rts
@v:     .byte 0

scr_clear:
        lda #BLANK
        jmp fill_screen

; ---------------------------------------------------------------------------
; fill_mem - A = byte, sptr = start address, tmp2/tmp3 = count low/high
fill_mem:
        sta fm_v
        ldy #0
@pg:    lda fm_v
        sta (sptr),y
        iny
        bne @pg
        inc sptr+1
        dec tmp3
        bne @pg
        ldy #0
@rem:   cpy tmp2
        beq @done
        lda fm_v
        sta (sptr),y
        iny
        bne @rem
@done:  rts
fm_v:   .byte 0

; ---------------------------------------------------------------------------
; viewrows_init - build the 128 view line addresses
viewrows_init:
        lda #0
        sta tmp1
@l:     lda tmp1
        clc
        adc #VIEW_Y
        jsr row_addr
        ldx tmp1
        lda dptr
        sta viewrows,x
        lda dptr+1
        sta viewrows+128,x
        inc tmp1
        lda tmp1
        cmp #VIEW_H
        bne @l
        rts

; ---------------------------------------------------------------------------
; row_addr - A = line 0..199 -> dptr = screen address of that line
row_addr:
        sta ra0
        lda #0
        sta dptr+1
        lda ra0
        asl a
        rol dptr+1              ; *2
        asl a
        rol dptr+1              ; *4
        sta dptr
        clc
        lda dptr
        adc ra0
        sta dptr
        lda dptr+1
        adc #0
        sta dptr+1              ; dptr = line*5
        asl dptr
        rol dptr+1
        asl dptr
        rol dptr+1
        asl dptr
        rol dptr+1              ; *8 -> line*40
        clc
        lda dptr
        adc #<HIRES
        sta dptr
        lda dptr+1
        adc #>HIRES
        sta dptr+1
        rts

; ---------------------------------------------------------------------------
; text_clear - blank the three character rows
text_clear:
        ldx #0
        lda #32
@l:     sta TEXTROWS,x
        inx
        cpx #120
        bne @l
        rts

; text_char - A = character code, X = row 0..2, Y = column 0..39
text_char:
        sta tc_c
        lda tc_rowtab,x
        sta dptr
        lda tc_rowtab+3,x
        sta dptr+1
        lda tc_c
        sta (dptr),y
        rts
tc_c:   .byte 0

tc_rowtab: .byte <TEXTROWS, <(TEXTROWS+40), <(TEXTROWS+80)
           .byte >TEXTROWS, >(TEXTROWS+40), >(TEXTROWS+80)

; text_str - X = row, Y = column, string at (txtptr), zero terminated
text_str:
        stx ts_row
        sty ts_col
@l:     ldy #0
        lda (txtptr),y
        beq @done
        ldx ts_row
        ldy ts_col
        jsr text_char
        inc txtptr
        bne @nc
        inc txtptr+1
@nc:    inc ts_col
        lda ts_col
        cmp #40
        bne @l
@done:  rts
ts_row: .byte 0
ts_col: .byte 0

; ---------------------------------------------------------------------------
; gtext - draw a zero terminated string straight into the HIRES bitmap.
; X = byte column, Y = first line, txtptr = string.  The glyphs replace what
; is on screen, so this also blanks the cell behind each character.
gtext:
        stx gt_col
        sty gt_line
@l:     ldy #0
        lda (txtptr),y
        beq @done
        jsr gt_char
        inc txtptr
        bne @nc
        inc txtptr+1
@nc:    inc gt_col
        lda gt_col
        cmp #40
        bne @l
@done:  rts
gt_col:  .byte 0
gt_line: .byte 0
gt_off:  .word 0
gt_cnt:  .byte 0

gt_char:
        sec
        sbc #32
        bcc @space
        cmp #96
        bcc @ok
@space: lda #0
@ok:    asl a
        sta gt_off
        lda #0
        rol a
        sta gt_off+1
        asl gt_off
        rol gt_off+1
        asl gt_off
        rol gt_off+1              ; offset = index * 8, 16 bit
        lda #<(CHARSET+$100)
        clc
        adc gt_off
        sta sptr
        lda #>(CHARSET+$100)
        adc gt_off+1
        sta sptr+1
        lda gt_line
        ldx gt_col
        jsr blit_setup
        lda #8
        sta gt_cnt
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
@n2:    dec gt_cnt
        bne @row
        rts

; ---------------------------------------------------------------------------
; text_tons - A = tons, X = row, Y = last column of the field.
; Prints "6T (6000KG)" right aligned, so messages can end the figure where
; they want it.  One ton is a thousand kilos.
text_tons:
        sta tt_t
        stx tt_row
        sty tt_col
        lda #')'
        jsr tt_put
        lda #'G'
        jsr tt_put
        lda #'K'
        jsr tt_put
        lda #'0'
        jsr tt_put
        jsr tt_put
        jsr tt_put
        jsr tt_digits
        lda #'('
        jsr tt_put
        lda #' '
        jsr tt_put
        lda #'T'
        jsr tt_put
        jmp tt_digits

tt_digits:
        lda tt_t
        ldx #0
@l:     cmp #10
        bcc @d
        sbc #10
        inx
        jmp @l
@d:     sta tt_u
        stx tt_d
        lda tt_u
        clc
        adc #48
        jsr tt_put
        lda tt_d
        beq @done
        clc
        adc #48
        jmp tt_put
@done:  rts

tt_put:                         ; A = character, at tt_row / tt_col
tt_echo: sta tt_ch
        ldx tt_row
        ldy tt_col
        lda tt_ch
        jsr text_char
        dec tt_col
        lda tt_ch
        rts

tt_ch:   .byte 0
tt_t:    .byte 0
tt_d:    .byte 0
tt_u:    .byte 0
tt_row:  .byte 0
tt_col:  .byte 0

; text_dec2 - A = 0..99 as two digits at X = row, Y = column, with a
; leading space under ten so clocks and speeds stand still.
text_dec2:
        stx td2_row
        sty td2_col
        ldx #0
@l:     cmp #10
        bcc @d
        sbc #10
        inx
        jmp @l
@d:     sta td2_u
        stx td2_d
        lda td2_d
        beq @sp
        clc
        adc #48
        jmp @hi
@sp:    lda #32
@hi:    ldx td2_row
        ldy td2_col
        jsr text_char
        inc td2_col
        lda td2_u
        clc
        adc #48
        ldx td2_row
        ldy td2_col
        jmp text_char

td2_row: .byte 0
td2_col: .byte 0
td2_d:   .byte 0
td2_u:   .byte 0

; text_num8 - A = 0..255 printed as decimal at X = row, Y = column
text_num8:
        sta numlo
        lda #0
        sta numhi
        jmp text_num16

; text_num16 - numlo/numhi printed as decimal at X = row, Y = column
text_num16:
        stx tn_row
        sty tn_col
        lda #0
        sta tn_flag
        sta tn_idx
@dig:   ldx tn_idx
        ldy #0
@sub:   lda numlo
        sec
        sbc divtab,x
        sta tn_l
        lda numhi
        sbc divtab+1,x
        bcc @done
        sta numhi
        lda tn_l
        sta numlo
        iny
        jmp @sub
@done:  tya
        beq @zero
        lda #$FF
        sta tn_flag
@zero:  lda tn_flag
        bne @emit
        ldx tn_idx
        cpx #8
        bne @next
@emit:  lda #$FF
        sta tn_flag
        tya
        clc
        adc #48
        ldx tn_row
        ldy tn_col
        jsr text_char
        inc tn_col
@next:  lda tn_idx
        clc
        adc #2
        sta tn_idx
        cmp #10
        bne @dig
        rts
tn_row:  .byte 0
tn_col:  .byte 0
tn_flag: .byte 0
tn_idx:  .byte 0
tn_l:    .byte 0

divtab: .word 10000, 1000, 100, 10, 1

; ---------------------------------------------------------------------------
; blit_setup - A = line, X = byte column -> dptr = screen address
blit_setup:
        sta tmp6
        txa
        pha
        lda tmp6
        jsr row_addr
        pla
        clc
        adc dptr
        sta dptr
        bcc @nc
        inc dptr+1
@nc:    rts

; blit_or - OR sprite (sptr, spw, sph) into the screen at (spx, spy)
blit_or:
        lda #BLANK
        sta tmp3
        jmp blit_common

; blit_cp - copy sprite over the screen at (spx, spy)
blit_cp:
        lda #0
        sta tmp3
blit_common:
        lda spw
        sta tmp5                ; width, kept for the row advance
        lda spy
        ldx spx
        jsr blit_setup
        lda sph
        sta tmp2
@row:   ldy #0
@col:   lda (sptr),y
        ldx tmp3
        beq @store
        ora (dptr),y
@store: sta (dptr),y
        iny
        cpy tmp5
        bne @col
        clc
        lda sptr
        adc tmp5
        sta sptr
        bcc @nc1
        inc sptr+1
@nc1:   clc
        lda dptr
        adc #SCR_BYTES
        sta dptr
        bcc @nc2
        inc dptr+1
@nc2:   dec tmp2
        bne @row
        rts

; ---------------------------------------------------------------------------
; plotpix - A = x (0..239), X = y (0..199)
plotpix:
        sta pp_x
        txa
        pha
        ldx pp_x
        lda xtab,x
        sta pp_bc
        lda xbit,x
        sta pp_m
        pla
        jsr row_addr
        ldy pp_bc
        lda (dptr),y
        ora pp_m
        sta (dptr),y
        rts
pp_x:  .byte 0
pp_bc: .byte 0
pp_m:  .byte 0

; hline - A = x0, X = x1 (inclusive), Y = line
hline:
        sta hl_x0
        stx hl_x1
        tya
        jsr row_addr
        ldx hl_x0
@l:     lda xtab,x
        tay
        lda xbit,x
        sta hl_m
        lda (dptr),y
        ora hl_m
        sta (dptr),y
        inx
        cpx hl_x1
        bcc @l
        beq @l
        rts
hl_x0: .byte 0
hl_x1: .byte 0
hl_m:  .byte 0

; vline - A = x, X = y0, Y = y1 (inclusive)
vline:
        sta vl_x
        stx vl_y0
        sty vl_y1
        ldx vl_x
        lda xtab,x
        sta vl_bc
        lda xbit,x
        sta vl_m
        ldx vl_y0
@l:     txa
        pha
        jsr row_addr
        ldy vl_bc
        lda (dptr),y
        ora vl_m
        sta (dptr),y
        pla
        tax
        inx
        cpx vl_y1
        bcc @l
        beq @l
        rts
vl_x:    .byte 0
vl_y0:   .byte 0
vl_y1:   .byte 0
vl_bc:   .byte 0
vl_m:    .byte 0

; outline - rectangle; A = x0, X = y0, tmp1 = x1, tmp2 = y1
outline:
        sta ol_x0
        stx ol_y0
        lda tmp1
        sta ol_x1
        lda tmp2
        sta ol_y1
        lda ol_x0
        ldx ol_x1
        ldy ol_y0
        jsr hline
        lda ol_x0
        ldx ol_x1
        ldy ol_y1
        jsr hline
        lda ol_x0
        ldx ol_y0
        ldy ol_y1
        jsr vline
        lda ol_x1
        ldx ol_y0
        ldy ol_y1
        jmp vline
ol_x0: .byte 0
ol_y0: .byte 0
ol_x1: .byte 0
ol_y1: .byte 0
