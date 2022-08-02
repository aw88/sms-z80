;==============================================================================
; Macros
;==============================================================================

.define BankMappedToSlot2 $ffff

; Set the VDP address to HL
.macro SET_VDP_ADDR
    rst $08
.endm

; Write HL to VDP data port
.macro WRITE_VDP_DATA
    rst $18
.endm

; Set HL to VRAM index for tile at X, Y
.macro TILE_XY_TO_ADDR ARGS TILE_X, TILE_Y
    ld hl, $4000|($3800+(TILE_Y.w<<6)+(TILE_X.w<<1))
.endm

; Load a label's bank into addressable space
.macro LOAD_BANK ARGS LABEL
    ld a, :LABEL
    ld (BankMappedToSlot2), a
.endm

.macro ENABLE_SRAM
    ld a, $08
    ld (SRAMBank), a
.endm

.macro DISABLE_SRAM
    ld a, $80
    ld (SRAMBank), a
.endm