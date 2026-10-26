; zp.inc - the game's zero page variables.
;
; cc65 reserves $E2-$FB for its runtime, so everything here lives below $80.
; The addresses are fixed equates rather than a .zeropage segment so that the
; standard atmos linker config (which only has 26 bytes of ZP) is not needed.

; general pointers
scrptr  = $10                   ; 2 bytes: screen address
sptr    = $12                   ; 2 bytes: source pointer
dptr    = $14                   ; 2 bytes: destination pointer
txtptr  = $16                   ; 2 bytes: string pointer
tptr    = $18                   ; 2 bytes: table pointer

; sprite blit
spx     = $1A                   ; byte column 0..39
spy     = $1B                   ; line 0..199
spw     = $1C                   ; width in bytes
sph     = $1D                   ; height in lines

; scratch
tmp1    = $1E
tmp2    = $1F
tmp3    = $20
tmp4    = $21
tmp5    = $22
tmp6    = $23

; maths
numlo   = $24                   ; 16 bit accumulator
numhi   = $25
cnt     = $26
mulcnt  = $27

; screen.s internal scratch
ra0     = $80                   ; row_addr
ra1     = $81
tileptr = $82                   ; town.s: map row pointer (needs to be zero page)
trk_sx  = $84                   ; screen byte column of the tractor
trk_sy  = $85                   ; screen line of the tractor
fuel_tick = $86

; ---------------------------------------------------------------------------
; truck state
trk_x   = $30                   ; 16 bit world x in pixels (0..65535)
trk_xh  = $31
trk_y   = $32                   ; 16 bit world y in pixels
trk_yh  = $33
trk_hdg = $34                   ; heading, 0..63 (64 steps per turn)
trk_spd = $35                   ; forward speed in 1/8 px per frame (signed)
trk_gear= $36                   ; 0=reverse 1..5
trk_steer = $37                 ; steering input, -2..+2
trk_dmg = $38                   ; damage 0..255 (255 = written off)
trk_fuel= $39                   ; fuel 0..255
trk_eng = $3A                   ; engine revs 0..255
trk_on  = $3B                   ; 1 = engine running
trk_len = $3C                   ; lorry length in feet (24/30/38)
trk_cap = $3D                   ; capacity in tons
trk_load= $3E                   ; tons on board
trk_jx  = $3F                   ; jackknife angle in 1/32 turn (trailer heading - truck)

trl_hdg = $40                   ; trailer heading, 0..63
trl_x   = $41                   ; trailer world x (16 bit)
trl_xh  = $42
trl_y   = $43                   ; trailer world y
trl_yh  = $44

; ---------------------------------------------------------------------------
; view
view_x  = $48                   ; 16 bit world x of the left edge (pixel)
view_xh = $49
view_y  = $4A                   ; world y of the top edge (pixel, cell aligned)
view_yh = $4B
view_cx = $4C                   ; cell column of the left edge
view_cy = $4D                   ; cell row of the top edge

; ---------------------------------------------------------------------------
; game state
game_state = $50                ; see game.s
menu_sel   = $51                ; highlighted icon
menu_page  = $52                ; 0 main, 1 drive, 2 practice, 3 high, 4 keys
tick       = $53                ; frame counter, game time in 1/50 s
time_s     = $54                ; seconds elapsed (16 bit)
time_sh    = $55
time_m     = $56                ; minutes
score      = $57                ; 16 bit score
score_hi   = $58
target     = $59                ; 4 bytes: tons still to deliver
stock      = $5D                ; 4 bytes: tons on board
delivered  = $61                ; 4 bytes
fine_flag  = $65
police     = $66                ; near a police station?
msg_timer  = $67
flash      = $68
phone_sel  = $69
load_sel   = $6A
pause_flag = $6B
lsize      = $6C                ; 0 = small, 1 = large
icon_press = $6D

; keys (latched this frame)
k_up    = $70
k_down  = $71
k_left  = $72
k_right = $73
k_fire  = $74
k_s     = $75
k_prev  = $76
kflags  = $77                   ; keys held this frame, bits KF_*
lastk   = $78                   ; the same for the previous frame
edge    = $79                   ; newly pressed keys this frame
