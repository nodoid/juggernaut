; truck.s - the articulated lorry
;
; Positions are 16 bit in 1/16 pixel: the town is 600 x 384 pixels, so 9600
; x 6144 units, and a speed of 32 units a frame is 2 pixels a frame (40 mph).
; Heading is 0..63 with 0 = north.  A frame of travel is
;
;       delta = speed * dir[heading] / 128       (dir is scaled by 127)
;
; which keeps the multiply inside eight bits.

        .include "hw.inc"
        .include "zp.inc"

        .export truck_reset, truck_step, truck_place, truck_draw, truck_erase
        .export truck_mph, camera_update, truck_off_x, truck_off_y
        .export truck_cell_x, truck_cell_y

        .import town_cell_at, town_solid
        .import blit_or, row_addr, xtab, tile_data
        .import snd_crash, snd_engine
        .import dir_dx, dir_dy, back_dx, back_dy, lorry_sprites
        .import view_cell_col, view_cell_row

        .bss
mprodl:   .res 1
mprodh:   .res 1
mult_lo:  .res 1
mult_hi:  .res 1
msa:      .res 1
msb:      .res 1
smneg:    .res 1
pxlo:     .res 1
pxhi:     .res 1
rr_line:  .res 1
rr_cnt:   .res 1
ax_lo:    .res 1
ax_hi:    .res 1

        .code

; ---------------------------------------------------------------------------
; signed_mul - A = a, X = b (both signed); A = (a * b) / 128
signed_mul:
        sta msa
        stx msb
        lda #0
        sta smneg
        lda msa
        bpl @1
        eor #$FF
        clc
        adc #1
        sta msa
        inc smneg
@1:     lda msb
        bpl @2
        eor #$FF
        clc
        adc #1
        sta msb
        inc smneg
@2:     lda msa
        sta mult_lo
        lda #0
        sta mult_hi
        sta mprodl
        sta mprodh
        ldx #8
@l:     lsr msb
        bcc @s
        clc
        lda mprodl
        adc mult_lo
        sta mprodl
        lda mprodh
        adc mult_hi
        sta mprodh
@s:     asl mult_lo
        rol mult_hi
        dex
        bne @l
        ldx #7
@sh:    lsr mprodh
        ror mprodl
        dex
        bne @sh
        lda smneg
        and #1
        beq @done
        lda mprodl
        eor #$FF
        clc
        adc #1
@done:  rts

; ---------------------------------------------------------------------------
; pos_pixels - A = hi, X = lo of a 1/16 pixel position -> pxhi/pxlo = pixels
pos_pixels:
        sta pxhi
        stx pxlo
        lsr pxhi
        ror pxlo
        lsr pxhi
        ror pxlo
        lsr pxhi
        ror pxlo
        lsr pxhi
        ror pxlo
        rts

; view_px - view_cx * 6 -> numlo/numhi
view_px:
        lda view_cx
        asl a
        sta tmp1
        lda #0
        rol a
        sta tmp2
        asl tmp1
        rol tmp2
        clc
        lda tmp1
        adc view_cx
        sta numlo
        lda tmp2
        adc #0
        sta numhi
        clc
        lda numlo
        adc view_cx
        sta numlo
        lda numhi
        adc #0
        sta numhi
        rts

; view_py - view_cy * 8 -> numlo/numhi
view_py:
        lda view_cy
        asl a
        sta numlo
        lda #0
        rol a
        sta numhi
        asl numlo
        rol numhi
        asl numlo
        rol numhi
        rts

; ---------------------------------------------------------------------------
; screen_off - A/X = 1/16 pixel position -> A = pixels - view origin
;              carry clear when the result is 0..255
screen_off:
        jsr pos_pixels
        lda pxlo
        sec
        sbc numlo
        sta tmp3
        lda pxhi
        sbc numhi
        bne @out
        lda tmp3
        sec
        rts
@out:   clc
        rts

; screen_clamped - like screen_off but clamps to 0..239
screen_clamped:
        jsr screen_off
        bcc @low
        cmp #240
        bcs @high
        rts
@low:   lda #0
        rts
@high:  lda #239
        rts

; ---------------------------------------------------------------------------
; truck_reset - A = cell x, X = cell y, Y = heading
truck_reset:
        sta tmp1
        stx tmp2
        sty trk_hdg
        sty trl_hdg
        lda tmp1                ; x = cell x * 6 pixels, in 1/16 pixel
        asl a
        sta numlo
        lda #0
        rol a
        sta numhi
        asl numlo
        rol numhi
        clc
        lda numlo
        adc tmp1
        sta numlo
        lda numhi
        adc #0
        sta numhi
        clc
        lda numlo
        adc tmp1
        sta numlo
        lda numhi
        adc #0
        sta numhi               ; 6 * cell x
        jsr shl4
        lda numlo
        sta trk_x
        lda numhi
        sta trk_xh
        lda tmp2                ; y = cell y * 8 pixels
        asl a
        asl a
        asl a
        sta numlo
        lda #0
        sta numhi
        jsr shl4
        lda numlo
        sta trk_y
        lda numhi
        sta trk_yh
        lda #0
        sta trk_spd
        sta trk_steer
        sta trk_gear
        sta trk_dmg
        sta trk_load
        sta fuel_tick
        lda #200
        sta trk_fuel
        jmp truck_place

; shl4 - numlo/numhi <<= 4
shl4:
        asl numlo
        rol numhi
        asl numlo
        rol numhi
        asl numlo
        rol numhi
        asl numlo
        rol numhi
        rts

; ---------------------------------------------------------------------------
; truck_step - one frame of physics
truck_step:
        ; ---- gear change (only when stopped)
        lda k_fire
        beq @nogear
        lda trk_spd
        cmp #2
        bcs @nogear
        lda trk_gear
        clc
        adc #1
        cmp #6
        bne @gok
        lda #0
@gok:   sta trk_gear
@nogear:
        ; ---- steering wheel towards the key held
        lda k_left
        beq @noleft
        lda trk_steer
        cmp #$FE
        beq @noleft
        dec trk_steer
@noleft:
        lda k_right
        beq @noright
        lda trk_steer
        cmp #2
        beq @noright
        inc trk_steer
@noright:
        lda k_left
        ora k_right
        bne @steerdone
        lda trk_steer
        beq @steerdone
        bmi @sm
        dec trk_steer
        jmp @steerdone
@sm:    inc trk_steer
@steerdone:
        ; ---- accelerator
        lda k_up
        beq @noacc
        ldx trk_gear
        beq @noacc
        cpx #5
        beq @revacc
        lda gearmax,x
        sta tmp1
        lda trk_spd
        cmp tmp1
        bcs @noacc
        clc
        adc #2
        sta trk_spd
        jmp @noacc
@revacc:
        lda trk_spd
        cmp #$F4
        bcc @noacc
        sec
        sbc #2
        sta trk_spd
@noacc:
        ; ---- brake
        lda k_down
        beq @nobrake
        lda trk_spd
        beq @nobrake
        bmi @nobrake
        sec
        sbc #3
        bcs @brk
        lda #0
@brk:   sta trk_spd
@nobrake:
        ; ---- friction
        lda trk_spd
        beq @clamped
        bmi @fneg
        dec trk_spd
        jmp @clamped
@fneg:  inc trk_spd
@clamped:
        ; ---- gear limit
        ldx trk_gear
        lda gearmax,x
        sta tmp1
        lda trk_spd
        bmi @negchk
        cmp tmp1
        bcc @ok
        beq @ok
        lda tmp1
        sta trk_spd
        jmp @ok
@negchk:
        cmp tmp1
        bcs @ok
        lda tmp1
        sta trk_spd
@ok:
        ; ---- steering
        lda trk_steer
        beq @nosteer
        lda trk_spd
        beq @nosteer
        bpl @sp
        eor #$FF
        clc
        adc #1
@sp:    lsr a
        lsr a
        lsr a
        lsr a
        cmp #1
        bcs @turn
        lda #1
        cmp #4
@turn:  cmp #3
        bcc @t2
        lda #3
@t2:    sta tmp2
        lda trk_steer
        bmi @tneg
        clc
        lda trk_hdg
        adc tmp2
        and #63
        sta trk_hdg
        jmp @nosteer
@tneg:  lda trk_hdg
        sec
        sbc tmp2
        and #63
        sta trk_hdg
@nosteer:
        ; ---- move
        ldy trk_hdg
        lda dir_dy,y
        ldx trk_spd
        jsr signed_mul
        jsr add_y
        ldy trk_hdg
        lda dir_dx,y
        ldx trk_spd
        jsr signed_mul
        jsr add_x
        ; ---- fuel
        inc fuel_tick
        lda trk_spd
        bpl @fp
        eor #$FF
        clc
        adc #1
@fp:    cmp #12
        lda fuel_tick
        bcc @slow
        and #15
        bne @fuelok
        jmp @burn
@slow:  and #31
        bne @fuelok
@burn:  lda trk_fuel
        beq @dry
        dec trk_fuel
        jmp @fuelok
@dry:   lda #0
        sta trk_spd
@fuelok:
        ; ---- trailer and collision
        jsr trailer_step
        jsr truck_collide
        ; ---- engine note
        lda trk_spd
        bpl @ep
        eor #$FF
        clc
        adc #1
@ep:    jmp snd_engine

gearmax: .byte 0,8,16,24,32,$F4

; add_y / add_x - A = signed delta, sign extended into the 16 bit position
add_y:
        sta tmp3
        clc
        lda trk_y
        adc tmp3
        sta trk_y
        lda trk_yh
        bit tmp3
        bmi @neg
        adc #0
        sta trk_yh
        rts
@neg:   adc #$FF
        sta trk_yh
        rts

add_x:
        sta tmp3
        clc
        lda trk_x
        adc tmp3
        sta trk_x
        lda trk_xh
        bit tmp3
        bmi @neg
        adc #0
        sta trk_xh
        rts
@neg:   adc #$FF
        sta trk_xh
        rts

; ---------------------------------------------------------------------------
; trailer_step - the trailer heading lags the tractor by two steps a frame
trailer_step:
        lda trk_hdg
        sec
        sbc trl_hdg
        and #63
        cmp #32
        bcs @neg
        cmp #2
        bcc @done
        lda trl_hdg
        clc
        adc #2
        and #63
        sta trl_hdg
        rts
@neg:   eor #$3F
        clc
        adc #1
        cmp #2
        bcc @done
        lda trl_hdg
        sec
        sbc #2
        and #63
        sta trl_hdg
@done:  rts

; ---------------------------------------------------------------------------
; truck_collide - the probe point is six pixels ahead of the tractor centre
truck_collide:
        ldy trk_hdg
        lda dir_dy,y
        ldx #96
        jsr signed_mul
        jsr add_y
        lda trk_yh
        ldx trk_y
        jsr pos_pixels
        lda pxhi
        bne @hit
        lda pxlo
        lsr a
        lsr a
        lsr a
        sta tmp5                ; cell y
        ldy trk_hdg
        lda dir_dx,y
        ldx #96
        jsr signed_mul
        jsr add_x
        lda trk_xh
        ldx trk_x
        jsr pos_pixels
        lda pxhi
        bne @hit
        lda pxlo
        jsr div6
        ldx tmp5
        jsr town_solid
        bcc @nohit
@hit:   lda trk_spd
        beq @nohit
        bpl @cpos
        eor #$FF
        clc
        adc #1
@cpos:  lsr a
        clc
        adc #4
        clc
        adc trk_dmg
        bcc @dmgok
        lda #250
@dmgok: cmp #250
        bcc @store
        lda #250
@store: sta trk_dmg
        lda #0
        sta trk_spd
        jsr snd_crash
@nohit: rts

div6:
        sta ax_lo
        lda #0
        sta ax_hi
        ldx #0
@l:     lda ax_lo
        sec
        sbc #6
        bcc @done
        sta ax_lo
        inx
        jmp @l
@done:  txa
        rts

; ---------------------------------------------------------------------------
; truck_cell_x / truck_cell_y - A = the cell the lorry is in
truck_cell_x:
        lda trk_xh
        ldx trk_x
        jsr pos_pixels
        lda pxlo
        jmp div6

truck_cell_y:
        lda trk_yh
        ldx trk_y
        jsr pos_pixels
        lda pxlo
        lsr a
        lsr a
        lsr a
        rts

; ---------------------------------------------------------------------------
; truck_mph - A = whole mph
truck_mph:
        lda trk_spd
        bpl @p
        eor #$FF
        clc
        adc #1
@p:     lsr a
        lsr a
        lsr a
        sta tmp1
        asl a
        asl a
        clc
        adc tmp1
        rts

; ---------------------------------------------------------------------------
; truck_place - tractor screen position and trailer world position
truck_place:
        ldy trl_hdg
        lda back_dx,y
        clc
        adc trk_x
        sta trl_x
        lda back_dx+64,y
        adc trk_xh
        sta trl_xh
        lda back_dy,y
        clc
        adc trk_y
        sta trl_y
        lda back_dy+64,y
        adc trk_yh
        sta trl_yh
        ; tractor screen y
        jsr view_py
        lda trk_yh
        ldx trk_y
        jsr screen_off
        bcc @y0
        cmp #VIEW_H
        bcc @y1
@y0:    lda #0
@y1:    sta trk_sy
        ; tractor screen x
        jsr view_px
        lda trk_xh
        ldx trk_x
        jsr screen_clamped
        tax
        lda xtab,x
        sta trk_sx
        rts

; trailer screen column (A) and line (X) helpers
truck_off_x:
        jsr view_px
        lda trl_xh
        ldx trl_x
        jsr screen_clamped
        tax
        lda xtab,x
        rts

truck_off_y:
        jsr view_py
        lda trl_yh
        ldx trl_y
        jsr screen_off
        bcc @z
        cmp #VIEW_H
        bcc @ok
@z:     lda #0
@ok:    clc
        adc #VIEW_Y              ; the caller wants a screen line, not a view one
        rts

; ---------------------------------------------------------------------------
; truck_erase - restore the map under the trailer and the tractor
truck_erase:
        jsr truck_off_x
        sta spx
        jsr truck_off_y
        sec
        sbc #6
        sta spy
        jsr restore_rect
        lda trk_sx
        sta spx
        lda trk_sy
        clc
        adc #VIEW_Y              ; trk_sy is measured inside the view
        sec
        sbc #6
        sta spy
        jmp restore_rect

; restore_rect - redraw a 2 x 14 byte box at (spx, spy) from the town map
restore_rect:
        lda spy
        sta rr_line
        lda #14
        sta rr_cnt
@line:  lda rr_line
        cmp #VIEW_Y
        bcc @next
        cmp #VIEW_Y+VIEW_H
        bcs @next
        sec
        sbc #VIEW_Y
        sta tmp1
        lsr a
        lsr a
        lsr a
        clc
        adc view_cy
        sta tmp6                ; cell row
        lda tmp1
        and #7
        sta tmp4                ; line inside the cell
        lda #0
        sta tmp5
@cell:  clc
        lda tmp5
        adc spx
        clc
        adc view_cx
        ldx tmp6
        jsr town_cell_at
        asl a
        asl a
        asl a
        clc
        adc tmp4
        tax
        lda tile_data,x
        sta tmp3
        lda rr_line
        jsr row_addr
        clc
        lda tmp5
        adc spx
        tay
        lda tmp3
        sta (dptr),y
        inc tmp5
        lda tmp5
        cmp #2
        bne @cell
@next:  inc rr_line
        dec rr_cnt
        bne @line
        rts

; ---------------------------------------------------------------------------
; truck_draw - trailer first, then tractor
truck_draw:
        jsr truck_off_x
        sta spx
        jsr truck_off_y
        sec
        sbc #6
        sta spy
        lda #2
        sta spw
        lda #14
        sta sph
        lda trl_hdg
        and #7
        jsr sprite_addr
        jsr blit_or
        lda trk_sx
        sta spx
        lda trk_sy
        clc
        adc #VIEW_Y
        sec
        sbc #6
        sta spy
        lda #2
        sta spw
        lda #14
        sta sph
        lda trk_hdg
        and #7
        jsr sprite_addr
        jmp blit_or

sprite_addr:
        asl a
        asl a
        asl a
        asl a
        asl a                   ; 32 bytes per orientation
        clc
        adc #<lorry_sprites
        sta sptr
        lda #>lorry_sprites
        adc #0
        sta sptr+1
        rts

; ---------------------------------------------------------------------------
; camera_update - keep the lorry in the middle band of the view
camera_update:
        lda trk_sy
        cmp #34
        bcs @vlow
        lda view_cy
        beq @vdone
        lda #0
        jsr view_cell_row
        jsr truck_place
        jmp @vdone
@vlow:  cmp #70
        bcc @vdone
        cmp #200
        bcs @vdone
        lda #1
        jsr view_cell_row
        jsr truck_place
@vdone:
        lda trk_sx
        cmp #10
        bcs @hhigh
        lda view_cx
        beq @hdone
        lda #0
        jsr view_cell_col
        jsr truck_place
        jmp @hdone
@hhigh:
        cmp #28
        bcc @hdone
        lda #1
        jsr view_cell_col
        jsr truck_place
@hdone:
        rts
