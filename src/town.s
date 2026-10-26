; town.s - the town of Scarthorpe and the scrolling top down view
;
; The town is a grid of cells, one Oric screen byte each: 6 pixels across and
; 8 lines down.  A cell therefore maps straight on to screen memory, which is
; what makes the view affordable to scroll: moving the view one byte column
; left is a memmove of the 104 line view block plus 104 bytes fetched from the
; map.  Moving right or down is rare enough to redraw the whole view instead.

        .include "hw.inc"
        .include "zp.inc"

        .export town_rows_init, town_cell_at, town_cell_ptr, town_solid
        .export view_draw, view_scroll_left, view_scroll_up
        .export view_cell_col, view_cell_row
        .export memcopy_fwd

        .import town_cells, tile_data
        .import blit_setup, viewrows, row_addr

        .bss
town_rows:  .res 96             ; 48 words: start of each town row
tcx:        .res 1
tcy:        .res 1
vline:      .res 1
vcx:        .res 1
vcy:        .res 1
dcc_line:   .res 1
dcc_col:    .res 1
dcc_off:    .res 1
tileoff:    .res 1

        .code

; ---------------------------------------------------------------------------
; town_rows_init - build the row pointer table
town_rows_init:
        lda #<town_cells
        sta tptr
        lda #>town_cells
        sta tptr+1
        ldx #0
@l:     txa
        asl a
        tay
        lda tptr
        sta town_rows,y
        lda tptr+1
        sta town_rows+1,y
        clc
        lda tptr
        adc #100
        sta tptr
        bcc @nc
        inc tptr+1
@nc:    inx
        cpx #48
        bne @l
        rts

; ---------------------------------------------------------------------------
; town_cell_ptr - A = cell x, X = cell y -> sptr = address of that cell
town_cell_ptr:
        sta tcx
        txa
        asl a
        tay
        lda town_rows,y
        sta sptr
        lda town_rows+1,y
        sta sptr+1
        lda tcx
        clc
        adc sptr
        sta sptr
        bcc @nc
        inc sptr+1
@nc:    rts

; town_cell_at - A = cell x, X = cell y -> A = tile
town_cell_at:
        jsr town_cell_ptr
        ldy #0
        lda (sptr),y
        rts

; town_solid - A = cell x, X = cell y -> carry set when the cell is a building
town_solid:
        cpx #48
        bcs @solid
        cmp #100
        bcs @solid
        jsr town_cell_at
        cmp #1                  ; T_BUILD
        beq @solid
        clc
        rts
@solid: sec
        rts

; ---------------------------------------------------------------------------
; memcopy_fwd - copy (tmp2,tmp3) bytes from sptr to dptr
memcopy_fwd:
        ldy #0
        ldx tmp3
        beq @rem
@pg:    lda (sptr),y
        sta (dptr),y
        iny
        bne @pg
        inc sptr+1
        inc dptr+1
        dex
        bne @pg
@rem:   cpy tmp2
        beq @done
        lda (sptr),y
        sta (dptr),y
        iny
        bne @rem
@done:  rts

; ---------------------------------------------------------------------------
; view_draw - redraw the whole view from the map at (view_cx, view_cy)
view_draw:
        lda #0
        sta vline
@line:  lda vline
        lsr a
        lsr a
        lsr a                   ; cell row inside the view
        clc
        adc view_cy
        asl a
        tay
        lda town_rows,y
        sta tileptr
        lda town_rows+1,y
        sta tileptr+1
        lda view_cx
        clc
        adc tileptr
        sta tileptr
        bcc @nc
        inc tileptr+1
@nc:    ldx vline
        lda viewrows,x
        sta dptr
        lda viewrows+128,x
        sta dptr+1
        lda vline
        and #7
        sta tileoff             ; row inside the tile
        ldy #0
@col:   lda (tileptr),y
        asl a
        asl a
        asl a
        clc
        adc tileoff
        tax
        lda tile_data,x
        sta (dptr),y
        iny
        cpy #40
        bne @col
        inc vline
        lda vline
        cmp #VIEW_H
        bne @line
        rts

; ---------------------------------------------------------------------------
; draw_cell_column - A = first line, X = byte column, Y = tile*8
draw_cell_column:
        sta dcc_line
        stx dcc_col
        sty dcc_off
        ldx #0
@l:     txa
        pha
        clc
        adc dcc_line
        jsr row_addr
        pla
        pha
        clc
        adc dcc_off
        tay
        lda tile_data,y
        ldy dcc_col
        sta (dptr),y
        pla
        tax
        inx
        cpx #8
        bne @l
        rts

; ---------------------------------------------------------------------------
; view_scroll_left - move the view one byte column left and fill the new edge
view_scroll_left:
        lda #<(HIRES+VIEW_Y*SCR_BYTES)
        sta sptr
        sta dptr
        lda #>(HIRES+VIEW_Y*SCR_BYTES)
        sta sptr+1
        sta dptr+1
        inc sptr                ; source is one byte to the right
        bne @nc
        inc sptr+1
@nc:    lda #<(VIEW_H*SCR_BYTES)
        sta tmp2
        lda #>(VIEW_H*SCR_BYTES)
        sta tmp3
        jsr memcopy_fwd
        ; new right hand edge: cell column view_cx+39
        lda view_cx
        clc
        adc #39
        sta tcx
        lda #0
        sta vcy
@l:     lda tcx
        ldx vcy
        jsr town_cell_at
        asl a
        asl a
        asl a
        sta tileoff
        lda vcy
        asl a
        asl a
        asl a
        clc
        adc #VIEW_Y
        ldx #39
        ldy tileoff
        jsr draw_cell_column
        inc vcy
        lda vcy
        cmp #(VIEW_H/8)
        bne @l
        rts

; ---------------------------------------------------------------------------
; view_scroll_up - move the view up one cell row and draw the new bottom row
view_scroll_up:
        lda #<(HIRES+VIEW_Y*SCR_BYTES)
        sta dptr
        lda #>(HIRES+VIEW_Y*SCR_BYTES)
        sta dptr+1
        lda #<(HIRES+(VIEW_Y+8)*SCR_BYTES)
        sta sptr
        lda #>(HIRES+(VIEW_Y+8)*SCR_BYTES)
        sta sptr+1
        lda #<((VIEW_H-8)*SCR_BYTES)
        sta tmp2
        lda #>((VIEW_H-8)*SCR_BYTES)
        sta tmp3
        jsr memcopy_fwd
        lda view_cy
        clc
        adc #(VIEW_H/8)-1
        sta tcy
        lda #0
        sta vcx
@l:     lda vcx
        ldx tcy
        jsr town_cell_at
        asl a
        asl a
        asl a
        sta tileoff
        lda #(VIEW_Y+VIEW_H-8)
        ldx vcx
        ldy tileoff
        jsr draw_cell_column
        inc vcx
        lda vcx
        cmp #40
        bne @l
        rts

; ---------------------------------------------------------------------------
; view_cell_col - A = 0: view one cell left, A = 1: one cell right
view_cell_col:
        cmp #0
        beq @left
        lda view_cx
        cmp #59
        bcs @out
        inc view_cx
        jsr view_scroll_left
        rts
@left:  lda view_cx
        beq @out
        dec view_cx
        jmp view_redraw_and_scroll
@out:   rts

; view_cell_row - A = 0: view one cell up, A = 1: one cell down
view_cell_row:
        cmp #0
        beq @up
        lda view_cy
        cmp #34
        bcs @out
        inc view_cy
        jmp view_redraw
@up:    lda view_cy
        beq @out
        dec view_cy
        jmp view_scroll_up
@out:   rts

view_redraw_and_scroll:
view_redraw:
        jmp view_draw
