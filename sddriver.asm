        .ident "TYPE:"
.text
        .ident "CODE:large"   
				.globl  _SDDriverConnectCard
		.type   _SDDriverConnectCard,@function
				.globl  _SDDriverEndComunication
		.type   _SDDriverEndComunication,@function
				.globl  _SDDriverInitSFR
		.type   _SDDriverInitSFR,@function
				.globl  _SDDriverReadBlock
		.type  _SDDriverReadBlock,@function
				.globl  _SDDriverReadMultiBlocks
		.type   _SDDriverReadMultiBlocks,@function
				.globl  _SDDriverSendCommand
		.type   _SDDriverSendCommand,@function
				.globl  _SDDriverWriteBlock
		.type  _SDDriverWriteBlock,@function
				.globl  _SDDriverWriteMultiBlocks
		.type   _SDDriverWriteMultiBlocks,@function
	.p2align	2

.equ BLKCON0,0XF028
.equ	DSIO0,0
.equ	DI2C0,1
.equ	DI2C1,2
.equ	DTM0,3
.equ	DMD0,4
.equ	P1D		,0xF220
.equ	P1DIR	,0xF221
.equ	P1CON	,0xF222
.equ		P1CON0,0xF222
.equ		P1CON1,0xF223
.equ	P1MOD	,0xF224
.equ	SIO0BUF		,0xF280
.equ		SIO0BUFL,0xF280
.equ		SIO0BUFH,0xF281
.equ	SIO0CON		,0xF282
.equ	SIO0MOD		,0xF284
.equ		SIO0MOD0,0xF284
.equ		SIO0MOD1,0xF285
.equ	LTBR		,0xF00C

.macro SPI_TRANSFER_BLOCK reg
    .ifb \reg         
    .else
        st \reg, SIO0BUF 
    .endif
sb SIO0CON,0
.local loop_\@       
loop_\@:
    tb SIO0CON,0
    bne loop_\@      
.endm

.macro SPI_SET_LENGTH length
    .if \length == 8
        rb SIO0MOD0, 3  
    .elseif \length == 16
        sb SIO0MOD0, 3   
    .else
        .error "Invalid length value. Only 8 or 16 is allowed."
    .endif
.endm
_SDDriverInitSFR:;uint8_t(void)
rb BLKCON0,DSIO0
mov r0,0x00 ;leave sout high?idk
mov r1,0x01
st er0,P1D ;P1DIR
mov r0,0X0e
mov r1,0x0f
st er0,P1CON;cmos output and pull-up input(alternative:high-impedance)
mov r0,0x07
st r0,P1MOD;second function
;mov er0,0
;st er0,SIO0BUF
;st r0,SIO0CON
mov r0,0x0f
mov r1,0x10;MSB,16bit,r/w,1HSCLK,MODE0
st er0,SIO0MOD
;MOSI(master out slave in)-sout
;MISO-sin
rt

_SDDriverConnectCard:;uint8_t(void)
push lr
sb SIO0MOD1,2;turn to 1/16 for init
sb P1D,3;CS

;at least 74 clk
mov er0,-1
st er0,SIO0BUF
mov r0,#5
1:
SPI_TRANSFER_BLOCK
add r0,-1
bne 1b

;reset card
rb P1D,3
mov er0,0
push er0
push er0
bl _SDDriverSendCommand
add sp,4
cmp r0,0x01
bne 9f

;啥都不想管了，我的驱动不养闲卡
;may unecessary
;sb P1D,3
;mov r0,0xff
;SPI_TRANSFER_BLOCK r0
;mov r0,127
;mov r1,0xff
;st r1 SIO0BUF
;1:
;SPI_TRANSFER_BLOCK
;add r0,-1
;bne 1b
;CHECK CMD8
mov er0,0
push er0
mov r0 ,0xAA
mov r1,0x01
push er0
mov r0,8
bl _SDDriverSendCommand
add sp,4
mov r0,0xff
st r0,SIO0BUF
mov r1,4
1:
SPI_TRANSFER_BLOCK 
add r1,-1
bne 1b
l r0,SIO0BUF
cmp r0,0xAA
bne 10f


;We suppose the card is SD2,SD1 is rare
;init to spi mode
l r3,LTBR
1:
push r3

mov er0,0
push er0
push er0
mov r0,55
bl _SDDriverSendCommand
add sp,4
mov r0,0x00
mov r1,0x40
push er0
push r0
mov r0,41
bl _SDDriverSendCommand
add sp,4
cmp r0,0
pop r3
beq 2f
l r2,LTBR
sub r2,r3
cmp r2,200;too big may have problem
blt 1b
b 11f
2:

;check type
mov er0,0
push er0
push er0
mov r0,58
bl _SDDriverSendCommand
add sp,4
cmp r0,0
bne 12f
mov r1,0xff
SPI_TRANSFER_BLOCK r1
rb _SDType,0
tb SIO0BUF,6;bit30:1:block 0:byte
beq	 1f
sb _SDType,0;SD_CARD_TYPE_SDHC/SDXC
1:
mov r0,3
1:
SPI_TRANSFER_BLOCK
add r0,-1
bne 1b

;set block to 512
mov er0,0
push er0
mov r1,0x02
push er0
mov r0,16
bl _SDDriverSendCommand
add sp,4
mov r0,r0
bne 13f

mov r0,0
8:
sb P1D,3
mov r1,0xff
SPI_TRANSFER_BLOCK r1
rb SIO0MOD1,2
pop pc
9:10:11:12:13:
mov r0,0xff
b 8b;TODO:need seperated error code
_SDDriverSendCommand:;only support cmd0's crc uint8_t(uint8_t cmd,uint32_t arg)
;TODO:urgent to be optimized as it's too slow
rb P1D,3
;waitready:
mov r2,0xff
st r2,SIO0BUF
SPI_SET_LENGTH 8
l r2,LTBR
1:
SPI_TRANSFER_BLOCK
l r3,SIO0BUF
cmp r3,0xff
beq 2f
l r3,LTBR
sub r3,r2
cmp r3,40;300ms
blt 1b
2:

;send head

or r0,0x40
cmp r0,0x40
bne 1f

SPI_TRANSFER_BLOCK r0
SPI_SET_LENGTH 16
pop xr0
add sp,-4
SPI_TRANSFER_BLOCK er2
SPI_TRANSFER_BLOCK er0
SPI_SET_LENGTH 8
mov r0,0x95;CRC

b 2f
1:

SPI_TRANSFER_BLOCK r0
SPI_SET_LENGTH 16
pop xr0
add sp,-4
SPI_TRANSFER_BLOCK er2
SPI_TRANSFER_BLOCK er0
SPI_SET_LENGTH 8
mov r0,0x87;CRC

2:
SPI_TRANSFER_BLOCK r0

;wait for response
mov r0,0xff
mov r1,8
st r0,SIO0BUF
1:
SPI_TRANSFER_BLOCK
l r0,SIO0BUF
cmp r0,0xff
bne 2f
add r1,-1
bne 1b
2:
rt
_SDDriverReadBlock:;uint8_t(uint32_t block_addr,uint16_t *buf)
push lr
push fp
;todo:need optimize,use pipeline instead
mov fp,sp
tb _SDType,0
bne 1f
mov r3,r2
mov r2,r1
mov r1,r0
mov r0,0
sllc r3,1
sllc r2,1
sll r1,1
1:
push xr0
mov r0,17
bl _SDDriverSendCommand
add sp,4
mov r0,r0
bne 9f

mov er0,-1
st er0,SIO0BUF


l er0,6[fp]
lea er0


mov r2,0x00
mov r3,0x01
mov r0,0x01
1:
SPI_TRANSFER_BLOCK
tb SIO0BUF,0
;l r0,SIO0BUF
;cmp r0,0xfe;about 0.5ms for class 10,caution158us
bne 1b
SPI_SET_LENGTH 16

DI
st r0,SIO0CON
nop
nop
nop
nop
nop
nop

nop

nop

nop
1:
nop

nop
nop
nop
nop
nop
nop
nop
st r0,SIO0CON
l er0,SIO0BUF
st r1,[ea+]
st r0,[ea+]
mov r0,0x01
add er2,-1
bne 1b
;sb SIO0CON,0
;1:
;tb SIO0CON,0
;bne 1b
;sb SIO0CON,0
;l er0,SIO0BUF
;st r1,[ea+]
;st r0,[ea+]
;add er2,-1
;bne 1b

EI
1:
tb SIO0CON,0
bne 1b


mov r0,0
8:
;sb P1D,3
pop fp
pop pc

9:
mov r0,0xff
bal 8b


_SDDriverReadMultiBlocks:;uint8_t(uint32_t block_addr,uint16_t *buf,uint16_t blocks)
push lr
push fp
;todo:need optimize,use pipeline instead
mov fp,sp
tb _SDType,0
bne 1f
mov r3,r2
mov r2,r1
mov r1,r0
mov r0,0
sllc r3,1
sllc r2,1
sll r1,1
1:
push xr0
mov r0,18
bl _SDDriverSendCommand
add sp,4
mov r0,r0
bne 9f

mov er0,-1
st er0,SIO0BUF


l er0,6[fp]
lea er0
l fp,8[fp]
3:
mov r2,0x00
mov r3,0x01
mov r0,0x01

1:
SPI_TRANSFER_BLOCK
tb SIO0BUF,0
;l r0,SIO0BUF
;cmp r0,0xfe;about 0.5ms for class 10,caution158us
bne 1b

SPI_SET_LENGTH 16


DI
st r0,SIO0CON
nop
nop
nop
nop
nop
nop

nop

nop

nop
1:
nop

nop
nop
nop
nop
nop
nop
nop
st r0,SIO0CON
l er0,SIO0BUF
st r1,[ea+]
st r0,[ea+]
mov r0,0x01
add er2,-1
bne 1b
;sb SIO0CON,0
;1:
;tb SIO0CON,0
;bne 1b
;sb SIO0CON,0
;l er0,SIO0BUF
;st r1,[ea+]
;st r0,[ea+]
;add er2,-1
;bne 1b

EI
1:
tb SIO0CON,0
bne 1b
add fp,-1
bne 3b
mov er0,0
push er0
push er0
mov r0,12
bl _SDDriverSendCommand
add sp,4
mov r0,r0
bne 9f

mov r0,0
8:
;sb P1D,3
pop fp
pop pc

9:
mov r0,0xff
bal 8b

_SDDriverWriteBlock:;uint8_t(uint32_t block_addr,uint16_t*buf)
;;no blocking as the next command must wait till the last command is over
;;but if the program is over,you need end communication to ensure nothing is processing
push lr
push fp
mov fp,sp
tb _SDType,0
bne 1f
mov r3,r2
mov r2,r1
mov r1,r0
mov r0,0
sllc r3,1
sllc r2,1
sll r1,1
1:
push xr0
mov r0,24
bl _SDDriverSendCommand
add sp,4
mov r0,r0
bne 9f

mov er0,-2
SPI_TRANSFER_BLOCK er0
SPI_SET_LENGTH 16
l er0,6[fp]

lea er0
mov r2,0xff
mov r3,0x01


l r1,[ea+]
l r0,[ea+]
st er0,SIO0BUF
1:
st r3,SIO0CON
l r1,[ea+]
l r0,[ea+]
st er0,SIO0BUF
add r2,-1
nop
nop
nop
nop
nop
nop
nop
nop

bne 1b
1:
tb SIO0CON,0
bne 1b
SPI_TRANSFER_BLOCK
mov er0,-1
SPI_TRANSFER_BLOCK er0
SPI_SET_LENGTH 8
1:
SPI_TRANSFER_BLOCK
l r0,SIO0BUF
and r0,0x1f
cmp r0,0x05;TODO:no need do this,three times of read is enough,nut i choose to keep it 
bne 1b



mov r0,0
8:
;sb P1D,3
pop fp
pop pc
9:
mov r0,0xff
bal 8b

_SDDriverWriteMultiBlocks:;uint8_t(uint32_t block_addr,uint16_t*buf,uint16_t blocks)

push lr
push fp
mov fp,sp
tb _SDType,0
bne 1f
mov r3,r2
mov r2,r1
mov r1,r0
mov r0,0
sllc r3,1
sllc r2,1
sll r1,1
1:
push xr0
mov r0,25
bl _SDDriverSendCommand
add sp,4
mov r0,r0
bne 9f



l er0,6[fp]
lea er0
l fp,8[fp]

3:

mov er0,-4
SPI_TRANSFER_BLOCK r0
SPI_SET_LENGTH 16
mov r2,0xff
mov r3,0x01


l r1,[ea+]
l r0,[ea+]
st er0,SIO0BUF
1:
st r3,SIO0CON
l r1,[ea+]
l r0,[ea+]
st er0,SIO0BUF
add r2,-1
nop
nop
nop
nop
nop
nop
nop
nop

bne 1b
1:
tb SIO0CON,0
bne 1b
SPI_TRANSFER_BLOCK
mov er0,-1
SPI_TRANSFER_BLOCK er0
SPI_SET_LENGTH 8
1:
SPI_TRANSFER_BLOCK
l r0,SIO0BUF
and r0,0x1f
cmp r0,0x05;TODO:no need do this,three times of read is enough,but i choose to keep it 
bne 1b


1:
SPI_TRANSFER_BLOCK
l r1,SIO0BUF
cmp r1,0xff
bne 1b


add fp,-1
bne 3b

mov r0,0xfd
SPI_TRANSFER_BLOCK r0

mov r0,0
8:
;sb P1D,3
pop fp
pop pc
9:
mov r0,0xff
bal 8b

_SDDriverEndComunication:
rb P1D,3
;waitready:
mov r2,0xff
st r2,SIO0BUF
SPI_SET_LENGTH 8
l r2,LTBR
1:
SPI_TRANSFER_BLOCK
l r3,SIO0BUF
cmp r3,0xff
beq 2f
l r3,LTBR
sub r3,r2
cmp r3,40;300ms
blt 1b
2:
sb P1D,3
mov r0,0xff
SPI_SET_LENGTH 8
SPI_TRANSFER_BLOCK r0
rt




	.type	_SDType,@object
	.section	.bss,"aw",@nobits
	.globl	_SDType
	.p2align	1
_SDType:
	.byte	0
	.size	_SDType, 1