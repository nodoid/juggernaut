; hw.s - Oric Atmos hardware layer
;
; The ROM is not used: interrupts are masked, VIA timer 1 runs free at 50Hz
; only so the main loop can pace itself, the keyboard matrix is scanned
; directly and the AY-3-8912 is driven through the VIA.

        .include "hw.inc"

        .export hw_init, wait_frame, kbd_scan, key_row, key_down, any_key
        .export keys, ay_set, ay_reg, ay_val, ay_silence
        .exportzp frame_count

        .zeropage
frame_count: .res 1
kacc:   .res 1
krow:   .res 1

        .bss
keys:   .res 8                  ; matrix, bit set = key down

        .code

; ---------------------------------------------------------------------------
; hw_init - take the machine over.  Returns with interrupts still masked.
hw_init:
        sei
        cld
        ; NB: no TXS here - the C runtime already set the stack up and a reset
        ; of it would destroy our own return address.
        lda #$7F
        sta VIA_IER             ; mask every VIA interrupt source
        lda #$F7
        sta VIA_DDRB            ; PB3 = keyboard sense input
        lda #$FF
        sta VIA_DDRA
        lda #$DD
        sta VIA_PCR             ; AY bus idle
        lda #$40
        sta VIA_ACR             ; T1 free run
        lda #<19998
        sta VIA_T1CL
        lda #>19998
        sta VIA_T1CH            ; 20ms period
        lda VIA_IFR             ; clear anything pending
        ; keyboard sense line low, all AY channels off
        lda #14
        ldx #$FF
        jsr ay_set
        lda #7
        ldx #$7F
        jsr ay_set
        lda #8
        ldx #0
        jsr ay_set
        lda #9
        ldx #0
        jsr ay_set
        lda #10
        ldx #0
        jsr ay_set
        lda #0
        sta frame_count
        rts

; ---------------------------------------------------------------------------
; ay_reg: A = register.  ay_val: A = value.  ay_set: A = register, X = value.
; All preserve X and Y.
ay_reg:
        sta VIA_ORA
        lda #$FF
        sta VIA_PCR
        lda #$DD
        sta VIA_PCR
        rts

ay_val:
        sta VIA_ORA
        lda #$FD
        sta VIA_PCR
        lda #$DD
        sta VIA_PCR
        rts

ay_set:
        php
        sei
        pha
        jsr ay_reg
        txa
        jsr ay_val
        pla
        plp
        rts

; ay_silence - volume 0 on all three channels
ay_silence:
        php
        sei
        ldx #0
        lda #8
        jsr ay_set
        lda #9
        jsr ay_set
        lda #10
        jsr ay_set
        plp
        rts

; ---------------------------------------------------------------------------
; wait_frame - block until the next 20ms VIA tick.  Returns with Z set.
wait_frame:
@l:     lda VIA_IFR
        and #$40                ; T1
        beq @l
        lda VIA_T1CL            ; acknowledge
        inc frame_count
        lda #0
        rts

; ---------------------------------------------------------------------------
; kbd_scan - read the 8x8 key matrix into keys[row] (bit = column, 1 = down)
kbd_scan:
        php
        sei
        lda #14
        jsr ay_reg
        ldx #7
@row:   stx krow
        lda VIA_ORB
        and #$F8
        ora krow
        sta VIA_ORB
        lda #0
        sta kacc
        ldy #7
@col:   lda colmask,y
        sta VIA_ORA
        lda #$FD
        sta VIA_PCR
        lda #$DD
        sta VIA_PCR
        nop
        nop
        nop
        nop
        lda VIA_ORB
        and #$08
        cmp #$08                ; C = 1 when the key is down
        rol kacc
        dey
        bpl @col
        lda kacc
        sta keys,x
        dex
        bpl @row
        plp
        rts

colmask: .byte $FE,$FD,$FB,$F7,$EF,$DF,$BF,$7F

; ---------------------------------------------------------------------------
; key_row: X = matrix row -> A = columns held (bit set = key down).
; Preserves X and Y.
key_row:
        php
        sei
        lda #14
        jsr ay_reg
        stx krow
        lda VIA_ORB
        and #$F8
        ora krow
        sta VIA_ORB
        tya
        pha
        lda #0
        sta kacc
        ldy #7
@col:   lda colmask,y
        sta VIA_ORA
        lda #$FD
        sta VIA_PCR
        lda #$DD
        sta VIA_PCR
        nop
        nop
        nop
        nop
        lda VIA_ORB
        and #$08
        cmp #$08
        rol kacc
        dey
        bpl @col
        pla
        tay
        lda kacc
        plp
        cmp #0                  ; Z set when no key in this row
        rts

; ---------------------------------------------------------------------------
; key_down: X = row, A = column mask -> Z set when that key is down
key_down:
        pha
        jsr key_row
        sta kacc
        pla
        and kacc
        rts

; any_key: A != 0 when any key is held
any_key:
        ldx #7
@r:     jsr key_row
        bne @yes
        dex
        bpl @r
        lda #0
        rts
@yes:   lda #$FF
        rts
