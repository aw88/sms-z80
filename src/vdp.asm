;==============================================================================
; VDP Defines
;==============================================================================

.define VDPControl              $bf
.define VDPStatus               $bf
.define VDPData                 $be
.define VRAMWrite               $4000
.define CRAMWrite               $c000

.define VDP_EXTRA_HEIGHT        %00000010
.define VDP_SHIFT_SPRITES       %00001000
.define VDP_LEFT_COL_BLANK      %00100000
.define VDP_LOCK_HSCROLL        %00000100
.define VDP_LOCK_VSCROLL        %00001000

.define VDP_ZOOM_SPRITES        %00000001
.define VDP_TALL_SPRITES        %00000010
.define VDP_MD_MODE_5           %00000100
.define VDP_30_ROW              %00001000
.define VDP_28_ROW              %00010000
.define VDP_VBLANK_ENABLE       %00100000
.define VDP_DISPLAY_ENABLE      %01000000

.define TILE_FLIP_X             $0200
.define TILE_FLIP_Y             $0400
.define TILE_USE_SPRITE_PAL     $0800
.define TILE_PRIORITY           $1000

.section "Copy to VDP" free
CopyToVDP:
; Copies data to the VDP
; hl = start address, bc = data length
; Affects: a, hl, bc
-:  ld a, (hl)
    out (VDPData), a
    inc hl
    dec bc
    ld a, b
    or c
    jr nz, -
    ret
.ends

.section "Default VDP registers" free
VdpData:
.db $04, $80    ; 0: Mode 4
.db $00, $81    ; 1:
.db $ff, $82
.db $ff, $85
.db $ff, $86
.db $ff, $87
.db $00, $88
.db $00, $89
.db $ff, $8a
VdpDataEnd:
.ends

.section "Wait for a VBlank" free
WaitForVBlank:
    xor a
    ld (VBlankFlag), a
-:  ld a, (VBlankFlag)
    or a
    jr z, -
    ret
.ends
