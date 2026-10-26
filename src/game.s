; game.s - Juggernaut: start-up, state machine and the game loop
;
; The C side calls game_run once; from there everything is assembly.  States
; follow the original: title, main menu, practice menu, the drive screen with
; its six icons and town map, the road view, the phone, the loading bay and
; the high score table.

        .include "hw.inc"
        .include "zp.inc"

        .export _game_run
        .export dest
        .export kb_row, kb_mask

        .import hw_init, kbd_scan, wait_frame, key_down, keys
        .import scr_init, text_clear, row_addr, gtext, gchar, text_str
        .import town_rows_init, town_cell_at, view_draw, viewrows_init
        .import text_tons, text_char
        .import view_cell_col, view_cell_row
        .import truck_reset, truck_step, truck_place, truck_draw, truck_erase
        .import camera_update
        .import dash_init, dash_update, dash_num3
        .import truck_cell_x, truck_cell_y
        .import snd_init, snd_tick, snd_crash
        .import ui_title, ui_menu, ui_menu_mark, ui_drive, ui_icons, ui_map
        .import ui_map_marker, ui_clear_view, ui_clear_all, ui_msg, ui_high
        .import ui_keys, ui_keys_prompt
        .import menu_main_tab, menu_main_n, menu_prac_tab, menu_prac_n
        .import menu_phone_tab, menu_phone_n
        .import poi_tab, poi_count, phones, phone_count, town_cells
        .import _hs_beats

        .segment "BSS"
hstab:  .res 90                 ; ten rows of eight name characters + score
hscnt:  .res 1
gi_idx: .res 1
ab_hit: .res 1
ab_cx:  .res 1
ab_cy:  .res 1
ab_i:   .res 1
ab_x:   .res 1
kindwant: .res 1
best:   .res 1
idx:    .res 1
trx:    .res 1
try_:   .res 1
dd:     .res 1
repeat: .res 1
msgdlg: .res 1
dest:   .res 1

; key bindings - one matrix row and one column mask per action, so the player
; can change them on the DEFINE KEYS screen.  Order: accelerate, brake, left,
; right, fire, back to map.
kb_row:  .res 6
kb_mask: .res 6
kb_wait: .res 1                 ; 0 menu, 1 waiting for release, 2 for a press
rawprev: .res 1                 ; raw O/P/fire bits of the previous frame

        .code

; state numbers
S_TITLE  = 0
S_MAIN   = 1
S_PRAC   = 2
S_DRIVE  = 3
S_PLAY   = 4
S_PHONE  = 5
S_LOAD   = 6
S_HIGH   = 7
S_OVER   = 8
S_KEYS   = 9

; ---------------------------------------------------------------------------
_game_run:
        sei
        jsr hw_init
        jsr scr_init
        jsr town_rows_init
        jsr snd_init
        lda #255
        sta dest
        jsr keys_default
        jsr game_new
        jsr ui_title
        lda #S_TITLE
        sta game_state
@loop:  jsr wait_frame
        jsr snd_tick
        jsr kbd_scan
        jsr read_keys
        jsr game_dispatch
        jmp @loop

; ---------------------------------------------------------------------------
; read_keys - kflags holds the keys held this frame, edge the new presses.
; The bits are KF_UP, KF_DOWN, KF_LEFT, KF_RIGHT, KF_FIRE and KF_STOP.
KF_UP    = 1
KF_DOWN  = 2
KF_LEFT  = 4
KF_RIGHT = 8
KF_FIRE  = 16
KF_STOP  = 32

; KEYTEST i, bit - test binding i and set its bit in kflags
.macro KEYTEST i, bit
        .local skip
        ldx kb_row+i
        lda kb_mask+i
        jsr key_down
        beq skip
        lda kflags
        ora #bit
        sta kflags
skip:
.endmacro

; FIREALIAS row, mask - treat a fixed key as fire on top of the binding
.macro FIREALIAS row, mask
        .local skip
        ldx #row
        lda #mask
        jsr key_down
        beq skip
        lda kflags
        ora #KF_FIRE
        sta kflags
skip:
.endmacro

; keys_default - the keys the game starts with
keys_default:
        lda #K_A_ROW
        sta kb_row+0
        lda #K_A_COL
        sta kb_mask+0            ; A = accelerate
        lda #K_Z_ROW
        sta kb_row+1
        lda #K_Z_COL
        sta kb_mask+1            ; Z = brake
        lda #K_O_ROW
        sta kb_row+2
        lda #K_O_COL
        sta kb_mask+2            ; O = left
        lda #K_P_ROW
        sta kb_row+3
        lda #K_P_COL
        sta kb_mask+3            ; P = right
        lda #K_M_ROW
        sta kb_row+4
        lda #K_M_COL
        sta kb_mask+4            ; M = fire / change gear
        lda #K_S_ROW
        sta kb_row+5
        lda #K_S_COL
        sta kb_mask+5            ; S = back to the map
        rts

read_keys:
        lda kflags
        sta lastk
        lda #0
        sta kflags
        KEYTEST 0, KF_UP                        ; accelerate
        KEYTEST 1, KF_DOWN                      ; brake
        KEYTEST 2, KF_LEFT                      ; steer left
        KEYTEST 3, KF_RIGHT                     ; steer right
        KEYTEST 4, KF_FIRE                      ; fire / change gear
        ; M and space are always fire buttons as well as whatever key has been
        ; bound, so changing the fire key can never leave the menus dead
        FIREALIAS K_M_ROW, K_M_COL
        FIREALIAS K_SP_ROW, K_SP_COL
        KEYTEST 5, KF_STOP                      ; back to the map
        lda lastk
        eor #$FF
        and kflags
        sta edge
        ; expose the held keys to truck.s and the menus as 0/1
        lda kflags
        and #KF_UP
        sta k_up
        lda kflags
        and #KF_DOWN
        beq @7
        lda #1
@7:     sta k_down
        lda kflags
        and #KF_LEFT
        beq @8
        lda #1
@8:     sta k_left
        lda kflags
        and #KF_RIGHT
        beq @9
        lda #1
@9:     sta k_right
        lda kflags
        and #KF_FIRE
        beq @10
        lda #1
@10:    sta k_fire
        rts

; ---------------------------------------------------------------------------
game_dispatch:
        lda game_state
        asl a
        tax
        lda state_tab,x
        sta tptr
        lda state_tab+1,x
        sta tptr+1
        jmp (tptr)

state_tab:
        .word st_title, st_main, st_prac, st_drive
        .word st_play, st_phone, st_play, st_high
        .word st_over, st_keys

; ---------------------------------------------------------------------------
st_title:
        lda edge
        and #16
        beq @done
        lda #0
        sta menu_sel
        lda #S_MAIN
        sta game_state
        jsr main_menu
@done:  rts

st_main:
        jsr menu_nav
        lda edge
        and #16
        beq @done
        lda menu_sel
        cmp #0
        bne @1
        jmp go_drive
@1:     cmp #1
        bne @2
        jsr toggle_size
        jmp @done
@2:     cmp #2
        bne @3
        lda #0
        sta menu_sel
        lda #S_PRAC
        sta game_state
        jsr ui_clear_all
        lda #<menu_prac_tab
        sta tptr
        lda #>menu_prac_tab
        sta tptr+1
        lda menu_prac_n
        jsr ui_menu
        jmp @done
@3:     cmp #3
        bne @4
        lda #S_HIGH
        sta game_state
        jsr ui_clear_all
        jsr ui_high
        jmp @done
@4:     lda #S_KEYS
        sta game_state
        lda #0
        sta menu_sel
        sta kb_wait
        lda #$FF                ; treat any key already down as old
        sta rawprev
        jsr ui_clear_all
        jsr text_clear
        jsr ui_keys
        jmp @done
@done:  rts

main_menu:
        jsr ui_clear_all
        lda #<menu_main_tab
        sta tptr
        lda #>menu_main_tab
        sta tptr+1
        lda menu_main_n
        jmp ui_menu

st_prac:
        jsr menu_nav
        lda edge
        and #16
        beq @done
        lda menu_sel
        cmp #4
        bne @start
        lda #0
        sta menu_sel
        lda #S_MAIN
        sta game_state
        jsr main_menu
        jmp @done
@start: jsr practice_start
@done:  rts

st_high:
        lda edge
        and #16
        beq @done
        lda #0
        sta menu_sel
        lda #S_MAIN
        sta game_state
        jsr main_menu
@done:  rts

st_keys:
        jmp keys_input

; ---------------------------------------------------------------------------
; keys_input - the DEFINE KEYS screen.
;
; It cannot use the bindings it is editing, so it reads the O, P, M and space
; matrix positions directly: O and P move, fire picks the action, then the
; first key pressed after everything is released becomes the new binding.
keys_input:
        jsr raw_bits            ; tmp4 = keys newly pressed this frame
        lda kb_wait
        beq @menu
        cmp #1
        beq @release
        jmp @press
@menu:
        lda tmp4
        and #4                  ; fire
        beq @nav
        lda menu_sel
        cmp #6
        bcc @bind
        ; DONE
        lda #0
        sta menu_sel
        sta kb_wait
        lda #S_MAIN
        sta game_state
        jsr main_menu
        rts
@bind:  lda #1
        sta kb_wait
        jsr prompt_release
        rts
@nav:   lda tmp4
        and #1                  ; O = previous action
        beq @right
        lda menu_sel
        beq @out
        dec menu_sel
        jmp @redraw
@right: lda tmp4
        and #2                  ; P = next action
        beq @out
        lda menu_sel
        cmp #6
        bcs @out
        inc menu_sel
@redraw:
        jsr ui_keys
@out:   rts

; wait until every key is up, so the press that opened the binding is not the
; one that gets recorded
@release:
        jsr key_any
        bne @out
        lda #2
        sta kb_wait
        jsr prompt_press
@out2:  rts

; record the first key that goes down
@press:
        jsr key_any
        beq @out2
        ldy #0
@bit:   lda kbits,y
        and keys,x
        bne @got
        iny
        cpy #8
        bne @bit
        ldy #0
@got:   lda kbits,y
        sta tmp3
        stx tmp2
        ldx menu_sel
        lda tmp2
        sta kb_row,x
        lda tmp3
        sta kb_mask,x
        lda #0
        sta kb_wait
        jsr ui_keys_prompt       ; A = 0: blank the prompt
        jmp ui_keys

prompt_release:
        lda #1
        jmp ui_keys_prompt

prompt_press:
        lda #2
        jmp ui_keys_prompt

; key_any - Z set when nothing is held, else X = matrix row that has a key
key_any:
        ldx #7
@l:     lda keys,x
        bne @yes
        dex
        bpl @l
        lda #0                  ; nothing held: Z set
        rts
@yes:   rts

; raw_bits - the raw O/P/fire/space matrix positions as new-press bits
; (1 = O, 2 = P, 4 = fire or space)
raw_bits:
        lda #0
        sta tmp5
        ldx #K_O_ROW
        lda keys,x
        and #K_O_COL
        beq @np
        lda tmp5
        ora #1
        sta tmp5
@np:    ldx #K_P_ROW
        lda keys,x
        and #K_P_COL
        beq @nf
        lda tmp5
        ora #2
        sta tmp5
@nf:    ldx #K_M_ROW
        lda keys,x
        and #K_M_COL
        beq @ns
        lda tmp5
        ora #4
        sta tmp5
@ns:    ldx #K_SP_ROW
        lda keys,x
        and #K_SP_COL
        beq @edge
        lda tmp5
        ora #4
        sta tmp5
@edge:  lda rawprev
        eor #$FF
        and tmp5
        sta tmp4
        lda tmp5
        sta rawprev
        rts

kbits:  .byte $01, $02, $04, $08, $10, $20, $40, $80

; ---------------------------------------------------------------------------
go_drive:
        lda #0
        sta menu_sel
        sta pause_flag
        lda #S_DRIVE
        sta game_state
        jsr ui_clear_all
        jsr dash_init
        jsr ui_drive
        jsr dash_update
        rts

st_drive:
        jsr menu_nav
        lda edge
        and #16
        beq @done
        lda menu_sel
        cmp #0
        bne @1
        jmp start_driving
@1:     cmp #1
        bne @2
        lda #S_PHONE
        sta game_state
        jsr ui_clear_view
        jsr phone_screen
        jmp @done
@2:     cmp #2
        bne @3
        jsr do_load
        jmp @done
@3:     cmp #3
        bne @4
        jsr do_unload
        jmp @done
@4:     cmp #4
        bne @5
        lda pause_flag
        eor #1
        sta pause_flag
        jmp @done
@5:     jmp game_over
@done:  rts

; ---------------------------------------------------------------------------
start_driving:
        lda #1
        sta trk_on
        lda #S_PLAY
        sta game_state
        jsr ui_clear_all
        jsr dash_init
        jsr center_view
        jsr camera_update
        jsr view_draw
        jsr truck_place
        jsr truck_draw
        jsr dash_update
        rts

; centre_view - put the view around the lorry
center_view:
        jsr truck_cell_x
        sec
        sbc #20
        bcs @1
        lda #0
@1:     sta view_cx
        jsr truck_cell_y
        sec
        sbc #6
        bcs @2
        lda #0
@2:     sta view_cy
        jsr truck_place
        rts

st_play:
        lda edge
        and #32                ; S
        beq @nos
        lda trk_spd
        cmp #2
        bcs @nos
        lda #0
        sta menu_sel
        lda #S_DRIVE
        sta game_state
        jsr ui_clear_all
        jsr dash_init
        jsr ui_drive
        jsr dash_update
        rts
@nos:
        lda pause_flag
        bne @paused
        jsr truck_erase
        jsr truck_step
        jsr camera_update
        jsr truck_place
        jsr truck_draw
        jsr dash_update
        jsr tick_time
@paused:
        ; written off?
        lda trk_dmg
        cmp #250
        bcc @ok
        jmp game_over
@ok:    rts

; ---------------------------------------------------------------------------
; tick_time - one second per fifty frames
tick_time:
        inc tick
        lda tick
        cmp #50
        bcc @done
        lda #0
        sta tick
        inc time_s
        lda time_s
        cmp #60
        bcc @done
        lda #0
        sta time_s
        inc time_m
@done:  rts

; ---------------------------------------------------------------------------
; menu_nav - move menu_sel with left/right, with a repeat delay
menu_nav:
        lda edge
        and #12
        bne @new
        ; held: repeat every eight frames
        lda kflags
        and #12
        beq @reset
        inc repeat
        lda repeat
        and #7
        bne @done
        lda #0
        sta edge
        lda #0
        sta tmp1
        lda k_right
        beq @left
        lda #1
        sta tmp1
        jmp @move
@left:  lda k_left
        beq @done
        lda #2
        sta tmp1
@move:  jsr do_move
@done:  rts
@reset: lda #0
        sta repeat
        rts
@new:   lda #0
        sta repeat
        lda edge
        and #8
        beq @leftnew
        lda #1
        jsr do_move
        rts
@leftnew:
        lda #2
        jmp do_move

do_move:
        cmp #1
        bne @left
        lda menu_sel
        cmp mn_max
        bcs @max
        inc menu_sel
@max:   jmp @redraw
@left:  lda menu_sel
        beq @redraw
        dec menu_sel
@redraw:
        lda game_state
        cmp #S_DRIVE
        bne @menu
        jsr ui_icons
        rts
@menu:  jmp redraw_menu

mn_max: .byte 4

redraw_menu:
        lda #<menu_main_tab
        sta tptr
        lda #>menu_main_tab
        sta tptr+1
        lda game_state
        cmp #S_MAIN
        beq @draw
        lda #<menu_prac_tab
        sta tptr
        lda #>menu_prac_tab
        sta tptr+1
        lda game_state
        cmp #S_PRAC
        beq @draw
        lda #<menu_phone_tab
        sta tptr
        lda #>menu_phone_tab
        sta tptr+1
@draw:  lda game_state
        cmp #S_PHONE
        beq @six
        lda #5
        jmp ui_menu
@six:   lda #6
        jmp ui_menu

; ---------------------------------------------------------------------------
; phone
phone_screen:
        lda #<t_phone
        sta txtptr
        lda #>t_phone
        sta txtptr+1
        ldx #16
        ldy #VIEW_Y+4
        jsr gtext
        lda #0
        sta menu_sel
        lda #<menu_phone_tab
        sta tptr
        lda #>menu_phone_tab
        sta tptr+1
        lda #6
        jmp ui_menu

st_phone:
        jsr menu_nav
        lda edge
        and #16
        beq @done
        lda menu_sel
        cmp #5
        bne @pick
        lda #S_DRIVE
        sta game_state
        jsr ui_clear_all
        jsr dash_init
        jsr ui_drive
        jmp @done
@pick:  jsr phone_find
        lda #S_DRIVE
        sta game_state
        jsr ui_clear_all
        jsr dash_init
        jsr ui_drive
        jsr ui_map_marker
@done:  rts

; phone_find - menu_sel -> nearest place of that kind, left in dest
phone_find:
        lda #255
        sta dest
        lda menu_sel
        cmp #4                  ; the garages share one entry
        bne @goods
        lda #T_MARK_G
        jmp @have
@goods: tax
        lda good_tile,x
@have:  sta kindwant
        lda #255
        sta best
        jsr truck_cell_x
        sta trx
        jsr truck_cell_y
        sta try_
        lda #0
        sta idx
@scan:  lda idx
        cmp poi_count
        bcs @done
        asl a
        asl a
        tay
        lda poi_tab+2,y         ; tile kind
        cmp kindwant
        bne @next
        lda poi_tab,y           ; |dx|
        sec
        sbc trx
        bcs @p1
        eor #$FF
        clc
        adc #1
@p1:    sta dd
        lda poi_tab+1,y         ; |dy|
        sec
        sbc try_
        bcs @p2
        eor #$FF
        clc
        adc #1
@p2:    clc
        adc dd
        cmp best
        bcs @next
        sta best
        lda idx
        sta dest
@next:  inc idx
        jmp @scan
@done:  rts

good_tile: .byte T_MARK_T, T_MARK_C, T_MARK_O, T_MARK_F

; ---------------------------------------------------------------------------
; do_load - load goods at a wholesaler, refuel and repair at a garage
do_load:
        jsr at_bay
        cmp #255
        bne @bay
        jmp flash_msg
@bay:   cmp #T_MARK_G
        bne @notgarage
        lda #0
        sta trk_dmg
        lda #200
        sta trk_fuel
        jsr say_fixed
        jmp dash_update
@notgarage:
        cmp #T_MARK_H
        bne @goods
        jsr say_home_load
        jmp dash_update
@goods: jsr good_index          ; A = good 0..3, carry set when not goods
        bcc @ok
        jmp flash_msg
@ok:    sta gi_idx
        lda trk_cap
        sec
        sbc trk_load
        beq @full
        sta tmp5                ; tons that still fit
        lda trk_load
        clc
        adc tmp5
        sta trk_load
        ldx gi_idx
        lda stock,x
        clc
        adc tmp5
        sta stock,x
        jsr say_loaded
        jmp dash_update
@full:  jsr say_full
        jmp dash_update

; good_index - A = marker tile -> A = 0..3 goods index, carry set otherwise
good_index:
        cmp #T_MARK_T
        beq @timber
        cmp #T_MARK_C
        beq @coal
        cmp #T_MARK_O
        beq @oil
        cmp #T_MARK_F
        beq @fruit
        sec
        rts
@timber: lda #0
        clc
        rts
@coal:  lda #1
        clc
        rts
@oil:   lda #2
        clc
        rts
@fruit: lda #3
        clc
        rts

; do_unload - tip the load at the depot
do_unload:
        jsr at_bay
        cmp #T_MARK_H
        beq @home
        jsr say_nohome
        jmp dash_update
@home:  lda #0
        sta tmp6                ; tons delivered
        ldx #3
@l:     lda stock,x
        beq @next
        clc
        adc delivered,x
        sta delivered,x
        lda target,x
        sec
        sbc stock,x
        bcs @t
        lda #0
@t:     sta target,x
        lda stock,x
        clc
        adc tmp6
        sta tmp6
        lda #0
        sta stock,x
@next:  dex
        bpl @l
        lda #0
        sta trk_load
        lda tmp6
        bne @some
        jsr say_empty
        jmp dash_update
@some:  jsr say_delivered
        jmp dash_update

; at_bay - A = marker tile under the lorry, or 255 when it is not on a bay.
; The marker is a single cell in the middle of a four by three apron, so the
; nine cells round the tractor are searched rather than just the one.
at_bay:
        lda #255
        sta ab_hit
        jsr truck_cell_y
        sta ab_cy
        jsr truck_cell_x
        sta ab_cx
        ldx #8
@l:     stx ab_i
        lda ab_cx
        clc
        adc bay_dx,x
        sta ab_x
        lda ab_cy
        clc
        adc bay_dy,x
        tax
        lda ab_x
        jsr town_cell_at
        cmp #T_MARK_H
        bcc @next
        cmp #T_MARK_P
        bcc @hit                ; home or a wholesaler or a garage
        cmp #T_MARK_B
        bne @next
@hit:   sta ab_hit
@next:  ldx ab_i
        dex
        bpl @l
        lda ab_hit
        rts

bay_dx: .byte 255,0,1,255,0,1,255,0,1
bay_dy: .byte 255,255,255,0,0,0,1,1,1

; ---------------------------------------------------------------------------
; the little messages that go in the three character rows under the picture
say_fixed:
        lda #<t_fixed
        sta txtptr
        lda #>t_fixed
        sta txtptr+1
        ldx #0
        ldy #1
        jmp ui_msg

say_home_load:
        lda #<t_depot
        sta txtptr
        lda #>t_depot
        sta txtptr+1
        ldx #0
        ldy #1
        jmp ui_msg

say_full:
        lda #<t_full
        sta txtptr
        lda #>t_full
        sta txtptr+1
        ldx #0
        ldy #1
        jmp ui_msg

say_empty:
        lda #<t_empty
        sta txtptr
        lda #>t_empty
        sta txtptr+1
        ldx #0
        ldy #1
        jmp ui_msg

say_nohome:
        lda #<t_nohome
        sta txtptr
        lda #>t_nohome
        sta txtptr+1
        ldx #0
        ldy #1
        jmp ui_msg

; say_loaded / say_delivered print the tonnage both ways round
say_loaded:
        lda #<t_loaded
        sta txtptr
        lda #>t_loaded
        sta txtptr+1
        ldx #0
        ldy #1
        jsr ui_msg
        lda tmp5
        ldx #0
        ldy #28
        jmp text_tons

say_delivered:
        lda #<t_delivered
        sta txtptr
        lda #>t_delivered
        sta txtptr+1
        ldx #0
        ldy #1
        jsr ui_msg
        lda tmp6
        ldx #0
        ldy #28
        jmp text_tons

flash_msg:
        lda #<t_nobay
        sta txtptr
        lda #>t_nobay
        sta txtptr+1
        ldx #1
        ldy #1
        jmp ui_msg

; ---------------------------------------------------------------------------
toggle_size:
        lda lsize
        eor #1
        sta lsize
        beq @small
        lda #38
        sta trk_len
        lda #16
        sta trk_cap
        rts
@small: lda #24
        sta trk_len
        lda #6
        sta trk_cap
        rts

; ---------------------------------------------------------------------------
practice_start:
        ; practice uses the same town; drop the lorry on the open road
        lda #30
        ldx #20
        ldy #0
        jsr truck_reset
        lda #0
        sta trk_dmg
        jmp start_driving

; ---------------------------------------------------------------------------
game_new:
        lda #0
        sta time_m
        sta time_s
        sta tick
        sta score
        sta score_hi
        sta trk_load
        sta trk_dmg
        sta stock+0
        sta stock+1
        sta stock+2
        sta stock+3
        lda #9
        sta target+0
        lda #6
        sta target+1
        lda #15
        sta target+2
        lda #10
        sta target+3
        lda #0
        sta delivered+0
        sta delivered+1
        sta delivered+2
        sta delivered+3
        jsr toggle_size
        lda lsize
        eor #1
        sta lsize
        jsr toggle_size
        lda #31                 ; the loading bay at the depot
        ldx #26
        ldy #0
        jmp truck_reset

; ---------------------------------------------------------------------------
game_over:
        lda #S_OVER
        sta game_state
        jsr ui_clear_all
        jsr text_clear
        lda #<t_over
        sta txtptr
        lda #>t_over
        sta txtptr+1
        ldx #14
        ldy #60
        jsr gtext
        ; score
        jsr calc_score
        lda score_hi
        ldx #16
        ldy #80
        jsr dash_num3m
        lda #<t_press2
        sta txtptr
        lda #>t_press2
        sta txtptr+1
        ldx #9
        ldy #120
        jmp gtext

st_over:
        lda edge
        and #16
        beq @done
        lda #0
        sta menu_sel
        jsr game_new
        lda #S_MAIN
        sta game_state
        lda #0
        sta lsize
        jsr toggle_size
        jsr main_menu
@done:  rts

; dash_num3m - A = value, X/Y = column/line (3 digits)
dash_num3m:
        jmp dash_num3

dummy_unused:
        rts

calc_score:
        ; score = delivered * 100 + 400 - seconds - damage
        lda delivered+0
        clc
        adc delivered+1
        clc
        adc delivered+2
        clc
        adc delivered+3
        sta tmp1
        lda #0
        sta tmp2
        ; tmp1 * 100
        ldx #0
@l:     clc
        lda tmp2
        adc #100
        sta tmp2
        inx
        cpx tmp1
        bne @l
        lda tmp2
        sta score
        lda #0
        sta score_hi
        ; minus seconds and damage
        lda score
        sec
        sbc time_s
        sta score
        bcs @nc
        dec score_hi
@nc:    lda score
        sec
        sbc trk_dmg
        sta score
        bcs @nc2
        dec score_hi
@nc2:   rts

; ---------------------------------------------------------------------------
        .segment "RODATA"
t_phone:  .byte "PHONE ENQUIRIES",0
t_loaded: .byte "LOADING",0
t_fixed:  .byte "REPAIRED AND FUELLED",0
t_nobay:  .byte "YOU MUST STOP ON A BAY",0
t_nohome: .byte "NOT AT THE DEPOT",0
t_depot:  .byte "THIS IS THE DEPOT",0
t_full:   .byte "NO ROOM LEFT",0
t_empty:  .byte "NOTHING TO UNLOAD",0
t_delivered: .byte "DELIVERED",0
t_over:   .byte "GAME OVER",0
t_press2: .byte "PRESS FIRE",0
