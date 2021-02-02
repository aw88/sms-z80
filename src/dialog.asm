.section "Dialog routines" free
DrawDialogBottom:
    TILE_XY_TO_ADDR 1, 18
    SET_VDP_ADDR
    ld hl, $00fb
    WRITE_VDP_DATA
    ld hl, $00fc
    .repeat 29
        WRITE_VDP_DATA
    .endr
    ld hl, $00fb|TILE_FLIP_X
    WRITE_VDP_DATA
    ld hl, $0000
    WRITE_VDP_DATA

    ld b, 4
    -:
        ld hl, $00fd
        WRITE_VDP_DATA
        ld hl, $00a0
        .repeat 29
            WRITE_VDP_DATA
        .endr
        ld hl, $00fd|TILE_FLIP_X
        WRITE_VDP_DATA
        ld hl, $0000
        WRITE_VDP_DATA
        djnz -

    ld hl, $00fb|TILE_FLIP_Y
    WRITE_VDP_DATA
    ld hl, $00fc|TILE_FLIP_Y
    .repeat 29
        WRITE_VDP_DATA
    .endr
    ld hl, $00fb|TILE_FLIP_X|TILE_FLIP_Y
    WRITE_VDP_DATA
    ld hl, $0000
    WRITE_VDP_DATA

    ret

DrawDialogText:
    push hl
    pop bc                  ; Move message address to BC
    ld h, 0
    ld d, 0

DialogNewLine:
    inc d
    push bc
        TILE_XY_TO_ADDR 2, 18   ; Start at row 18
        ld bc, 64
        ld e, d
    -:  add hl, bc              ; Add d * 64 (d rows)
        dec e
        jr nz, -
        SET_VDP_ADDR            ; Set the VDP address
    pop bc

    DialogLoop:
        ld a, (bc)          ; Read next char
        cp $80              ; $80 marks end of string
        jr z, DialogLoopEnd ; Finish
        cp $81              ; $81 marks new line
        jr nz, +
        inc bc              ; Move to next char
        jp DialogNewLine 
    +:  ld h, 0
        ld l, a             ; Move char into HL (low)
        WRITE_VDP_DATA      ; Write HL to VDP Data
        halt
        halt
        inc bc              ; Move to next char
        jr DialogLoop

DialogLoopEnd:
    ret
.ends