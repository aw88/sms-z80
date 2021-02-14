.define MaxSprites      64
.define SATAddress      $7f00

.struct SpriteY
y DB
.endst

.struct SpriteXN
x DB
n DB
.endst

.ramsection "sprite engine variables" slot 3
    SpriteTableY            INSTANCEOF SpriteY MaxSprites STARTFROM 0
    SpriteTableXN           INSTANCEOF SpriteXN MaxSprites STARTFROM 0
    SpriteNextFree          db      
.ends

.section "Sprite engine" free

SpriteInit:
    ld hl, SpriteNextFree
    ld (hl), $00
    ret

SpriteCopyToSAT:
    ld hl, SATAddress
    SET_VDP_ADDR

    ld a, (SpriteNextFree)
    or a
    jr z, _noSprites
    ld b, a
    ld c, VDPData
    ld hl, SpriteTableY
_nextSpriteY:
    outi
    jp nz, _nextSpriteY
    cp 64
    jr z, _noSpriteTerminator
    ld a, $d0
    out (c), a
_noSpriteTerminator:
    ld hl, SATAddress+128
    SET_VDP_ADDR

    ld c, VDPData
    ld a, (SpriteNextFree)
    add a, a
    ld b, a
    ld hl, SpriteTableXN
_nextSpriteXN:
    outi
    jp nz, _nextSpriteXN
    ret

_noSprites:
    ld a, $d0
    out (VDPData), a                ; Write terminator
    ret

; Adds a sprite to the in-memory Sprite Table
; Input: d: Tile number
;        e: X position
;        a: Y position
; Returns: a: Sprite index
SpriteAdd:
    ld l, a
    ld a, (SpriteNextFree)
    cp MaxSprites
    jr nc, _maxSpritesHit
    ld c, a                         ; Store SpriteNextFree in c
    ld a, l

    ld hl, SpriteTableY
    ld b, $00
    add hl, bc                      ; hl += SpriteNextFree
    dec a
    ld (hl), a                      ; Write Y to SpriteTable

    ld hl, SpriteTableXN
    ld a, c                         ; a = SpriteNextFree
    sla c
    add hl, bc                      ; hl += SpriteNextFree*2
    ld (hl), e                      ; Write X to SpriteTable
    inc hl
    ld (hl), d                      ; Write tile number to SpriteTable

    inc a
    ld (SpriteNextFree), a
    dec a

    ret

    _maxSpritesHit:
        ld a, $ff
        ret

.ends
