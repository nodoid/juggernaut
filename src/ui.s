; ui.s - title screen, menus, the icon strip and the town map

        .include "hw.inc"
        .include "zp.inc"

        .export ui_title, ui_menu, ui_menu_mark, ui_drive, ui_icons
        .export ui_map, ui_map_marker, ui_clear_view, ui_clear_all, ui_msg
        .export ui_box, ui_high, ui_panel
        .export menu_main_tab, menu_main_n
        .export menu_prac_tab, menu_prac_n
        .export menu_phone_tab, menu_phone_n

        .import gtext, gchar, blit_or, outline, blit_setup, fill_screen
        .import text_str, text_clear, row_addr, plotpix, hline, xtab
        .import icon_sprites, lorry_sprites, town_cell_at
        .import truck_cell_x, truck_cell_y
        .import poi_tab, dest

MAP_Y = VIEW_Y + 32            ; the town map sits under the icon strip

        .bss
mn_cnt:  .res 1
mn_i:    .res 1
mn_y:    .res 1
mcy:     .res 1
mcx:     .res 1
mm_x:    .res 1
mm_y:    .res 1

        .code

; ---------------------------------------------------------------------------
ui_clear_all:
        lda #BLANK
        jmp fill_screen

; ui_clear_view - blank the driving view area
ui_clear_view:
        lda #VIEW_Y
        sta tmp1
@l:     lda tmp1
        jsr row_addr
        ldy #0
        lda #BLANK
@c:     sta (dptr),y
        iny
        cpy #SCR_BYTES
        bne @c
        inc tmp1
        lda tmp1
        cmp #VIEW_Y+VIEW_H
        bne @l
        rts

; ui_box - frame round the view area
ui_box:
        lda #0
        ldx #239
        ldy #VIEW_Y
        jsr hline
        lda #0
        ldx #239
        ldy #VIEW_Y+VIEW_H-1
        jmp hline

; ui_msg - X = row, Y = column, txtptr = string
ui_msg:
        jmp text_str

; ---------------------------------------------------------------------------
ui_title:
        jsr ui_clear_all
        jsr text_clear
        lda #<t_title
        sta txtptr
        lda #>t_title
        sta txtptr+1
        ldx #12
        ldy #40
        jsr gtext
        lda #<t_credit
        sta txtptr
        lda #>t_credit
        sta txtptr+1
        ldx #12
        ldy #56
        jsr gtext
        lda #<t_from
        sta txtptr
        lda #>t_from
        sta txtptr+1
        ldx #11
        ldy #72
        jsr gtext
        lda #<t_oric
        sta txtptr
        lda #>t_oric
        sta txtptr+1
        ldx #13
        ldy #88
        jsr gtext
        lda #<lorry_sprites
        sta sptr
        lda #>lorry_sprites
        sta sptr+1
        lda #2
        sta spw
        lda #14
        sta sph
        lda #19
        sta spx
        lda #112
        sta spy
        jsr blit_or
        lda #<t_press
        sta txtptr
        lda #>t_press
        sta txtptr+1
        ldx #7
        ldy #150
        jmp gtext

; ---------------------------------------------------------------------------
; ui_menu - A = item count, tptr = table of word pointers
ui_menu:
        sta mn_cnt
        lda #0
        sta mn_i
@l:     lda mn_i
        asl a
        asl a
        asl a
        asl a
        clc
        adc #44
        sta mn_y
        lda #32
        jsr menu_mark
        lda mn_i
        asl a
        tay
        lda (tptr),y
        sta txtptr
        iny
        lda (tptr),y
        sta txtptr+1
        lda mn_i
        cmp menu_sel
        bne @draw
        lda #62
        jsr menu_mark
@draw:  ldx #14
        ldy mn_y
        jsr gtext
        inc mn_i
        lda mn_i
        cmp mn_cnt
        bne @l
        rts

menu_mark:
        ldx #12
        ldy mn_y
        jmp gchar

; ui_menu_mark - only the selection column, after the highlight moves
ui_menu_mark:
        lda #0
        sta mn_i
@l:     lda mn_i
        asl a
        asl a
        asl a
        asl a
        clc
        adc #44
        sta mn_y
        lda #32
        jsr menu_mark
        lda mn_i
        cmp menu_sel
        bne @n
        lda #62
        jsr menu_mark
@n:     inc mn_i
        lda mn_i
        cmp mn_cnt
        bne @l
        rts

; ---------------------------------------------------------------------------
; ui_icons - six icons with labels along lines 64..93, with a bar under the
; one that is selected so the player can see what the fire key will do.
ui_icons:
        jsr icon_strip_clear
        lda #0
        sta mn_i
@l:     lda mn_i
        asl a
        sta tmp1
        asl a
        clc
        adc tmp1
        clc
        adc #4
        sta spx                ; 4 + i*6
        lda #64
        sta spy
        lda #3
        sta spw
        lda #18
        sta sph
        lda mn_i
        asl a
        tay
        lda icon_tab,y
        sta sptr
        lda icon_tab+1,y
        sta sptr+1
        jsr blit_or
        ; label under the icon
        lda mn_i
        asl a
        tay
        lda icon_labels,y
        sta txtptr
        lda icon_labels+1,y
        sta txtptr+1
        lda mn_i
        asl a
        sta tmp1
        asl a
        clc
        adc tmp1
        clc
        adc #4
        tax
        ldy #86
        jsr gtext
        inc mn_i
        lda mn_i
        cmp #6
        bne @l
        ; selection bar under the chosen label
        lda menu_sel
        asl a
        sta tmp1
        asl a
        clc
        adc tmp1
        clc
        adc #4                  ; byte column of the icon
        asl a                   ; *2
        sta tmp1
        asl a                   ; *4
        clc
        adc tmp1                ; *6, the six pixels of a character
        sta sel_x0
        clc
        adc #17
        sta sel_x1
        lda sel_x0
        ldx sel_x1
        ldy #95
        jmp hline

sel_x0: .byte 0
sel_x1: .byte 0

; icon_strip_clear - blank the two lines the selection bar can use
icon_strip_clear:
        lda #BLANK
        ldy #94
        jsr strip_band
        lda #BLANK
        ldy #95
        jmp strip_band


; strip_band - A = byte, Y = line: fill that whole line with it
strip_band:
        sta sb_v
        sty sb_line
        lda sb_line
        jsr row_addr
        ldy #0
        lda sb_v
@l:     sta (dptr),y
        iny
        cpy #SCR_BYTES
        bne @l
        rts
sb_v:    .byte 0
sb_line: .byte 0

; ui_panel - highlight the selected drive icon with a frame
ui_panel:
        lda menu_sel
        asl a
        sta tmp1
        asl a
        clc
        adc tmp1
        clc
        adc #4
        tax
        lda xtab,x
        sta tmp5
        lda #0
        rts

; ---------------------------------------------------------------------------
; ui_drive - icons plus the town map
ui_drive:
        jsr ui_icons

; ui_map - the town at two pixels a cell
ui_map:
        lda #0
        sta mcy
@row:   lda mcy
        asl a
        clc
        adc #MAP_Y
        sta mm_y
        lda #0
        sta mcx
@col:   lda mcx
        ldx mcy
        jsr town_cell_at
        cmp #1                  ; T_BUILD
        bne @next
        lda mcx
        asl a
        clc
        adc #20
        sta mm_x
        lda mm_x
        ldx mm_y
        jsr plotpix
        lda mm_x
        clc
        adc #1
        ldx mm_y
        jsr plotpix
        lda mm_x
        ldx mm_y
        inx
        jsr plotpix
        lda mm_x
        clc
        adc #1
        ldx mm_y
        inx
        jsr plotpix
@next:  inc mcx
        lda mcx
        cmp #100
        bne @col
        inc mcy
        lda mcy
        cmp #48
        bne @row
        lda #<t_town
        sta txtptr
        lda #>t_town
        sta txtptr+1
        ldx #2                  ; the third text row, out of the map's way
        ldy #13
        jsr text_str
        jmp ui_map_marker

; ---------------------------------------------------------------------------
ui_map_marker:
        jsr truck_cell_x
        asl a
        clc
        adc #20
        sta mm_x
        jsr truck_cell_y
        asl a
        clc
        adc #MAP_Y
        sta mm_y
        lda mm_x
        ldx mm_y
        jsr plotpix
        lda mm_x
        clc
        adc #1
        ldx mm_y
        jsr plotpix
        lda mm_x
        ldx mm_y
        inx
        jsr plotpix
        lda mm_x
        clc
        adc #1
        ldx mm_y
        inx
        jsr plotpix
        ; and a two by two cross where the phone said to go
        lda dest
        cmp #255
        beq @done
        asl a
        asl a
        tay
        lda poi_tab,y
        asl a
        clc
        adc #20
        sta mm_x
        lda poi_tab+1,y
        asl a
        clc
        adc #MAP_Y
        sta mm_y
        lda mm_x
        ldx mm_y
        jsr plotpix
        lda mm_x
        clc
        adc #1
        ldx mm_y
        jsr plotpix
        lda mm_x
        ldx mm_y
        inx
        jsr plotpix
        lda mm_x
        clc
        adc #1
        ldx mm_y
        inx
        jmp plotpix
@done:  rts

; ---------------------------------------------------------------------------
ui_high:
        lda #<t_hs
        sta txtptr
        lda #>t_hs
        sta txtptr+1
        ldx #14
        ldy #VIEW_Y+6
        jmp gtext

; ---------------------------------------------------------------------------
        .segment "RODATA"
t_title:  .byte "JUGGERNAUT",0
t_credit: .byte "CRL 1985",0
t_from:   .byte "PETE COOKE",0
t_oric:   .byte "ORIC ATMOS",0
t_press:  .byte "PRESS FIRE",0
t_town:   .byte "SCARTHORPE",0
t_hs:     .byte "HIGH SCORES",0

icon_tab:
        .word icon_sprites, icon_sprites+54, icon_sprites+108
        .word icon_sprites+162, icon_sprites+216, icon_sprites+270

icon_labels:
        .word l_start, l_phone, l_load, l_unload, l_pause, l_resign
l_start:  .byte "START",0
l_phone:  .byte "PHONE",0
l_load:   .byte "LOAD",0
l_unload: .byte "UNLOAD",0
l_pause:  .byte "PAUSE",0
l_resign: .byte "RESIGN",0

menu_main_tab:
        .word m_drive, m_size, m_practice, m_high, m_keys
menu_main_n: .byte 5
m_drive:    .byte "DRIVE",0
m_size:     .byte "LORRY SIZE",0
m_practice: .byte "PRACTICE",0
m_high:     .byte "HIGH SCORES",0
m_keys:     .byte "DEFINE KEYS",0

menu_prac_tab:
        .word p_open, p_cross, p_park, p_round, p_stop
menu_prac_n: .byte 5
p_open:   .byte "OPEN ROAD",0
p_cross:  .byte "CROSSROADS",0
p_park:   .byte "PARKING",0
p_round:  .byte "ROUNDABOUT",0
p_stop:   .byte "STOP",0

menu_phone_tab:
        .word f_timber, f_coal, f_oil, f_fruit, f_garage, f_cancel
menu_phone_n: .byte 6
f_timber: .byte "TIMBER",0
f_coal:   .byte "COAL",0
f_oil:    .byte "OIL",0
f_fruit:  .byte "FRUIT+VEG",0
f_garage: .byte "GARAGES",0
f_cancel: .byte "CANCEL",0
