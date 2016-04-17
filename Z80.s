*************************************************
*						*
*	 Z80 Emulator for 68000 Ver 1.01	*
*						*
*	Copyright  1993/03/06 Koji Morita	*
*						*
*************************************************


*	d0   00 00  -- --	a0   ---- ----
*	d1   00 00  -- --	a1   ---- ----
*	d2   -- F'  -- F	a2   0000 SP.w
*	d3  IYHIYL IXHIXL	a3   PC.l
*	d4   I  A'  I  A	a4   T_OPC
*	d5   B' C'  B  C	a5   A_MEM*
*	d6   D' E'  D  E	a6   A_BAS*
*	d7   H' L'  H  L

*	F=vhhn_SZVC

F_ROM	set	0

F_NEXT	set	1
F_ADAW	set	1
F_SPER	set	1
F_OUTC	set	1

	.globl	Z80
	.globl	A_BAS
	.globl	IFF1,V_INT
	.globl	T_PF
	.globl	T_OPC,T_INT,T_NMI,T_RES
	.globl	A_MEM

	.globl	T_ROM,A_WOM

	.xref	INP,OUT
	.xref	INITIO
	.xref	INTRQ
	.xref	FCALL
	.xref	A_RND

FR	set	d2
XY	set	d3
AC	set	d4
BC	set	d5
DE	set	d6
HL	set	d7

aSP	set	a2
aPC	set	a3
aTO	set	a4
aME	set	a5
aBS	set	a6


*---------------------------------------*
*	      Z80 Emulator		*
*---------------------------------------*

	.text
				if F_ROM=0
Z80:
	lea	A_BAS,aBS
	lea	A_MEM,aME
	suba.l	aSP,aSP
	moveq	#0,d0

A_RES:	lea	T_OPC,aTO
	lea	(aME),aPC		* PC = 0000
	clr.b	IFF1			* IFF1 = 0
	clr.b	IFF2			* IFF2 = 0
	andi.l	#$00FF00FF,AC		* Reg.I = 00
	jsr	S_IM0			* IM 0
	jsr	S_EDED
	jsr	INITIO

	moveq	#0,d1
	jsr	z00

	rts

RESET:
	tst.l	(sp)+
	jmp	A_RES

S_IM0:
	lea	T_INT,a0
	move.w	#(IM0-A_BAS),d0
	move.w	#$100-1,d1
LP_IM0:	move.w	d0,(a0)+
	dbf	d1,LP_IM0
	move.w	#(IM0_76-A_BAS),T_INT+($76*2)
	rts

S_EDED:
	move.w	#$EDED,d0
	lea	A_MEM-$90,a0
	bsr.s	WREDED
	lea	A_MEM+$10000,a0
WREDED:	move.w	#$90/2-1,d1
LPEDED:	move.w	d0,(a0)+
	dbf	d1,LPEDED
	rts
				endif

*---------------------------------------
*

ADQA	macro	ID,AR						* 4/8

if F_ADAW=1
	addq.w	ID,AR			*  4
else
	addq.l	ID,AR			*  8
endif

	endm


SBQA	macro	ID,AR						* 4/8

if F_ADAW=1
	subq.w	ID,AR			*  4
else
	subq.l	ID,AR			*  8
endif

	endm


C_ROM	macro							* 0/24
	local	H8000

if F_ROM=1
	lea	(aME),a0		*  4
	bmi.s	H8000			*  8(10)
	lea	A_WOM,a0		* 12
H8000:
aME	set	a0
endif

	endm


C_ROM1	macro	DR						* 0/28

if F_ROM=1
	tst.w	DR			*  4
	C_ROM				* 24
endif

	endm


C_ROM2	macro

if F_ROM=1
aME	set	a5
endif

	endm


M_HL	macro	DR						* 4/8/16

if F_IXY=0
	move.w	HL,DR			*  4
else
if F_XYCB=0
	move.b	(aPC)+,DR		*  8
endif
	ext.w	DR			*  4
	add.w	HL,DR			*  4
endif

	endm


R_HL	macro	DR						* 18

	M_HL	d0			*  4
	move.b	(aME,d0.l),DR		* 14

	endm


NEXT	macro							* 44

	moveq	#0,d1			*  4
	NEXT2				* 40

	endm


NEXT2	macro							* 40

	C_ROM2
if F_IXY=2
	swap	XY			*  4
endif

if F_NEXT=1
	move.b	(aPC)+,d1		*  8
	add.w	d1,d1			*  4
	move.w	(aTO,d1.w),d0		* 14
	jmp	(aBS,d0.w)		* 14
else
	bra.w	A_NEXT2			* 10
endif

	endm

*
*---------------------------------------

*---------------------------------------*
*    ALU (Arithmetic Logical Unit)	*
*---------------------------------------*

HL	set	d7
F_IXY	set	0
F_XYCB	set	0

*---------------------------------------
*

R_WORD	macro	DR						* 32

	move.b	(aPC)+,d1		*  8
	move.b	(aPC)+,-(sp)		* 12
	move.w	(sp)+,DR		*  8
	move.b	d1,DR			*  4

	endm


M_01	macro	DR				* LD ss,nn	72(25)		2.88

	R_WORD	DR			* 32
	NEXT2				* 40

	endm


M_02	macro	DR				* LD (ss),A	58(17.5)	3.314

	move.w	DR,d0			*  4
	C_ROM
	move.b	AC,(aME,d0.l)		* 14
	NEXT2				* 40

	endm


M_03	macro	DR				* INC ss	44(15)		2.933

	addq.w	#1,DR			*  4
	NEXT2				* 40

	endm


M_04	macro	DR				* INC rh	90(10)		9.0	***V0-
	local	OZ

	andi.w	#%0000_0001,FR		*  8
	addi.w	#$0100,DR		*  8

	move	sr,d0			*  6
	bcs.s	OZ			*  8(10)

	andi.w	#%0000_1010,d0		*  8
	ori.w	#%1100_0000,d0		*  8
	or.w	d0,FR			*  4
	NEXT2				* 40

OZ:	andi.w	#%0000_1010,d0		*  8
	ori.w	#%1100_0100,d0		*  8
	or.w	d0,FR			*  4
	NEXT2				* 40

	endm


M_05	macro	DR				* DEC rh	98(10)		9.8	***V1-
	local	OZ

	andi.w	#%0000_0001,FR		*  8
	subi.w	#$0100,DR		*  8

	move	sr,d0			*  6
	cmpi.w	#$00FF,DR		*  8
	bls.s	OZ			*  8(10)

	andi.w	#%0000_1010,d0		*  8
	ori.w	#%1101_0000,d0		*  8
	or.w	d0,FR			*  4
	NEXT2				* 40

OZ:	andi.w	#%0000_1010,d0		*  8
	ori.w	#%1101_0100,d0		*  8
	or.w	d0,FR			*  4
	NEXT2				* 40

	endm


M_06	macro	DR				* LD rh,n	68(17.5)	3.886

	move.w	DR,-(sp)		*  8
	move.b	(aPC)+,(sp)		* 12
	move.w	(sp)+,DR		*  8
	NEXT2				* 40

	endm


M_09	macro	DR			*:*	* ADD HL,ss	62(27.5)	2.255	--*-0*
	local	NC

	andi.w	#%1000_1110,FR		*  8
	add.w	DR,HL			*  4
	bcc.s	NC			*  8(10)

	addq.w	#%0000_0001,FR		*  4
NC:	NEXT2				* 40

	endm


M_0A	macro	DR				* LD A,(ss)	58(17.5)	3.314

	move.w	DR,d0			*  4
	move.b	(aME,d0.l),AC		* 14
	NEXT2				* 40

	endm


M_0B	macro	DR				* DEC ss	44(15)		2.933

	subq.w	#1,DR			*  4
	NEXT2				* 40

	endm


M_0C	macro	DR				* INC rl	78(10)		7.8	***V0-

	addq.b	#1,DR			*  4

	move	sr,d0			*  6
	andi.w	#%0000_1110,d0		*  8
	ori.w	#%1100_0000,d0		*  8
	andi.w	#%0000_0001,FR		*  8
	or.w	d0,FR			*  4
	NEXT2				* 40

	endm


M_0D	macro	DR				* DEC rl	78(10)		7.8	***V1-

	subq.b	#1,DR			*  4

	move	sr,d0			*  6
	andi.w	#%0000_1110,d0		*  8
	ori.w	#%1101_0000,d0		*  8
	andi.w	#%0000_0001,FR		*  8
	or.w	d0,FR			*  4
	NEXT2				* 40

	endm


M_0E	macro	DR				* LD rl,n	48(17.5)	2.743

	move.b	(aPC)+,DR		*  8
	NEXT2				* 40

	endm

*
*---------------------------------------
				if F_ROM=0
z00:						* NOP		40(10)		4.0
	NEXT2				* 40

z01:	M_01	BC				* LD BC,nn
				endif
z02:	M_02	BC				* LD (BC),A
				if F_ROM=0
z03:	M_03	BC				* INC BC

z04:	M_04	BC				* INC B

z05:	M_05	BC				* DEC B

z06:	M_06	BC				* LD B,n

z07:						* RLCA		62(10)		6.2	--0-0*
	andi.w	#%1000_1110,FR		*  8
	add.b	AC,AC			*  4
	bcc.s	NC_07			*  8(10)

	addq.w	#%0000_0001,FR		*  4
	addq.b	#1,AC			*  4
NC_07:	NEXT2				* 40

z08:*						* EX AF,AF'	48(10)		4.8
	swap	AC			*  4
	swap	FR			*  4
	NEXT2				* 40

z09:	M_09	BC				* ADD HL,BC

z0A:	M_0A	BC				* LD A,(BC)

z0B:	M_0B	BC				* DEC BC

z0C:	M_0C	BC				* INC C

z0D:	M_0D	BC				* DEC C

z0E:	M_0E	BC				* LD C,n

z0F:						* RRCA		66(10)		6.6	--0-0*
	andi.w	#%1000_1110,FR		*  8
	ror.b	#1,AC			*  8
	bcc.s	NC_0F			*  8(10)

	addq.w	#%0000_0001,FR		*  4
NC_0F:	NEXT2				* 40

z10:						* DJNZ e	70/88(20/32.5)	3.5/2.708
	subi.w	#$0100,BC		*  8
	cmpi.w	#$00FF,BC		*  8
	bls.s	OZ_10			*  8(10)

	move.b	(aPC)+,d0		*  8
	ext.w	d0			*  4
	lea	(aPC,d0.w),aPC		* 12
	NEXT2				* 40

OZ_10:	ADQA	#1,aPC			*  4
	NEXT2				* 40

z11:	M_01	DE				* LD DE,nn
				endif
z12:	M_02	DE				* LD (DE),A
				if F_ROM=0
z13:	M_03	DE				* INC DE

z14:	M_04	DE				* INC D

z15:	M_05	DE				* DEC D

z16:	M_06	DE				* LD D,n

z17:						* RLA		74(10)		7.4	--0-0*
	move.b	FR,d0			*  4
	lsr.b	#1,d0			*  8

	andi.w	#%1000_1110,FR		*  8
	addx.b	AC,AC			*  4
	bcc.s	NC_17			*  8(10)

	addq.w	#%0000_0001,FR		*  4
NC_17:	NEXT2				* 40

z18:						* JR e		64(30)		2.133
	move.b	(aPC)+,d0		*  8
	ext.w	d0			*  4
	lea	(aPC,d0.w),aPC		* 12
	NEXT2				* 40

z19:	M_09	DE				* ADD HL,DE

z1A:	M_0A	DE				* LD A,(DE)

z1B:	M_0B	DE				* DEC DE

z1C:	M_0C	DE				* INC E

z1D:	M_0D	DE				* DEC E

z1E:	M_0E	DE				* LD E,n

z1F:						* RRA		78(10)		7.8	--0-0*
	move.b	FR,d0			*  4
	lsr.b	#1,d0			*  8

	andi.w	#%1000_1110,FR		*  8
	roxr.b	#1,AC			*  8
	bcc.s	NC_1F			*  8(10)

	addq.w	#%0000_0001,FR		*  4
NC_1F:	NEXT2				* 40
				endif
*---------------------------------------
*

JRcc	macro	Bc,BN				* JR cc,e	62/80(17.5/30)	3.543/2.667
	local	FALSE

	moveq	#1<<BN,d0		*  4
	and.b	FR,d0			*  4
	Bc.s	FALSE			*  8(10)

	move.b	(aPC)+,d0		*  8
	ext.w	d0			*  4
	lea	(aPC,d0.w),aPC		* 12
	NEXT2				* 40

FALSE:	ADQA	#1,aPC			*  4
	NEXT2				* 40

	endm


LD_nnss	macro	SS				* LD (nn),HL/ss	112(40/50)	2.8/2.24

	R_WORD	d0			* 32
	C_ROM1	d0
	move.b	SS,0(aME,d0.l)		* 14
	move.w	SS,-(sp)		*  8
	move.b	(sp)+,1(aME,d0.l)	* 18
	NEXT2				* 40

	endm


LD_ssnn	macro	SS				* LD HL/ss,(nn)	112(40/50)	2.8/2.24

	R_WORD	d0			* 32
	move.b	1(aME,d0.l),-(sp)	* 18
	move.w	(sp)+,SS		*  8
	move.b	0(aME,d0.l),SS		* 14
	NEXT2				* 40

	endm

*
*---------------------------------------
				if F_ROM=0
z20:	JRcc	bne,2				* JR NZ,e

z21:	M_01	HL				* LD HL,nn
				endif
z22:	LD_nnss	HL				* LD (nn),HL
				if F_ROM=0
z23:	M_03	HL				* INC HL

z24:	M_04	HL				* INC H

z25:	M_05	HL				* DEC H

z26:	M_06	HL				* LD H,n

*---------------------------------------
*

R_HF	macro							* 20

	moveq	#$0F,d0			*  4
	move.b	AC,d1			*  4
	and.b	d0,d1			*  4
	and.b	(aBS),d0		*  8

	endm

*
*---------------------------------------

z27:*						* DAA		(10)			***P-*
	moveq	#%0111_0000,d0		*  4
	and.w	FR,d0			*  4
	lsr.w	#2,d0			* 10
	jmp	T_HF(pc,d0.w)		* 14
T_HF:
	bra.w	DA_RES			* 10	000
	bra.w	DA_SBH			* 10	001
	bra.w	DA_ADD			* 10	010
	bra.w	DA_SUB			* 10	011
	bra.w	DA_INC			* 10	100
	bra.w	DA_DEC			* 10	101
	bra.w	DA_ADS			* 10	110
	bra.w	DA_SET			* 10	111

DA_ADD:	R_HF				* 20
	cmp.b	d1,d0			*  4

	shi	d1			*  4/6
	bra.w	DA_ADJa			* 10

DA_SUB:	R_HF				* 20
	cmp.b	d1,d0			*  4

	scs	d1			*  4/6
	bra.w	DA_ADJs			* 10

DA_SBH:	R_HF				* 20
	add.b	d1,d0			*  4
	andi.b	#$F0,d0			*  8

	sne	d1			*  4/6
	bra.w	DA_ADJs			* 10

DA_INC:	moveq	#$0F,d0			*  4
	and.b	AC,d0			*  4

	seq	d1			*  4/6
	bra.w	DA_ADJa			* 10

DA_DEC:	moveq	#$0F,d0			*  4
	and.b	AC,d0			*  4
	cmpi.b	#$0F,d0			*  8

	seq	d1			*  4/6
	bra.w	DA_ADJs			* 10

DA_ADS:	moveq	#$10,d0			*  4
	and.b	AC,d0			*  4

	sne	d1			*  4/6
	bra.w	DA_ADJa			* 10

DA_RES:	sf	d1			* 4
	bra.w	DA_ADJa			* 10

DA_SET:	st	d1			* 6
	bra.w	DA_ADJs			* 10


DA_ADJa:
	clr.w	d0			*  4
	move.b	AC,d0			*  4
	lea	T_DA-A_BAS(aBS),a0	*  8
	move.b	(a0,d0.w),d0		* 14

	andi.w	#%0000_0001,FR		*  8
	beq.s	NC_DAa			*  8(10)
	ori.b	#$60,d0			*  8

NC_DAa:	tst.b	d1			*  4
	beq.s	NH_DAa			*  8(10)
	ori.b	#$06,d0			*  8

NH_DAa:	add.b	d0,AC			*  4
	move	sr,FR			*  6
	andi.w	#%0000_1101,FR		*  8
	move.b	AC,(aBS)		*  8
	NEXT2				* 40


DA_ADJs:
	clr.b	d0			*  4
	andi.w	#%0000_0001,FR		*  8
	beq.s	NC_DAs			*  8(10)
	move.b	#$A0,d0			*  8

NC_DAs:	tst.b	d1			*  4
	beq.s	NH_DAs			*  8(10)
	subq.b	#$06,d0			*  4

NH_DAs:	add.b	d0,AC			*  4
	move	sr,FR			*  6
	andi.w	#%0000_1101,FR		*  8
	move.b	AC,(aBS)		*  8
	NEXT2				* 40


z28:	JRcc	beq,2				* JR Z,e

z29:	M_09	HL				* ADD HL,HL

z2A:	LD_ssnn	HL				* LD HL,(nn)

z2B:	M_0B	HL				* DEC HL

z2C:	M_0C	HL				* INC L

z2D:	M_0D	HL				* DEC L

z2E:	M_0E	HL				* LD L,n

z2F:						* CPL		52(10)		5.2	--1-1-
	not.b	AC			*  4
	ori.w	#%0111_0000,FR		*  8
	NEXT2				* 40

z30:	JRcc	bne,0				* JR NC,e

z31:						* LD SP,nn	76(25)		3.04
	R_WORD	d0			* 32
	movea.l	d0,aSP			*  4
	NEXT2				* 40	
				endif
z32:						* LD (nn),A	86(32.5)	2.646
	R_WORD	d0			* 32
	C_ROM1	d0
	move.b	AC,(aME,d0.l)		* 14
	NEXT2				* 40
				if F_ROM=0
z33:						* INC SP	52(15)		3.467
	move.l	aSP,d0			*  4
	addq.w	#1,d0			*  4
	movea.l	d0,aSP			*  4
	NEXT2				* 40
				endif
*---------------------------------------
*

M_34	macro					* INC (HL)	96(27.5)	3.491	***V0-

	M_HL	d0			*  4

if F_ROM=0
	addq.b	#1,(aME,d0.l)		* 18
	move	sr,d0			*  6
else
	C_ROM
	C_ROM2
	adda.l	d0,a0			*  8
	move.b	(aME,d0.l),d1		* 14
	addq.b	#1,d1			*  4
	move	sr,d0			*  6
	move.b	d1,(a0)			*  8
endif

	andi.w	#%0000_1110,d0		*  8
	ori.w	#%1100_0000,d0		*  8
	andi.w	#%0000_0001,FR		*  8
	or.w	d0,FR			*  4
	NEXT2				* 40

	endm


M_35	macro					* DEC (HL)	96(27.5)	3.491	***V1-

	M_HL	d0			*  4

if F_ROM=0
	subq.b	#1,(aME,d0.l)		* 18
	move	sr,d0			*  6
else
	C_ROM
	C_ROM2
	adda.l	d0,a0			*  8
	move.b	(aME,d0.l),d1		* 14
	subq.b	#1,d1			*  4
	move	sr,d0			*  6
	move.b	d1,(a0)			*  8
endif

	andi.w	#%0000_1110,d0		*  8
	ori.w	#%1101_0000,d0		*  8
	andi.w	#%0000_0001,FR		*  8
	or.w	d0,FR			*  4
	NEXT2				* 40

	endm


M_36	macro					* LD (HL),n	62(25)		2.48

	M_HL	d0			*  4
	C_ROM
	move.b	(aPC)+,(aME,d0.l)	* 18
	NEXT2				* 40

	endm

*
*---------------------------------------

z34:	M_34					* INC (HL)

z35:	M_35					* DEC (HL)

z36:	M_36					* LD (HL),n
				if F_ROM=0
z37:						* SCF		52(10)		5.2	--0-01
	andi.w	#%1000_1110,FR		*  8
	addq.w	#%0000_0001,FR		*  4
	NEXT2				* 40

z38:	JRcc	beq,0				* JR C,e

z39:	M_09	aSP				* ADD HL,SP

z3A:						* LD A,(nn)	86(32.5)	2.646
	R_WORD	d0			* 32
	move.b	(aME,d0.l),AC		* 14
	NEXT2				* 40

z3B:						* DEC SP	52(15)		3.467
	move.l	aSP,d0			*  4
	subq.w	#1,d0			*  4
	movea.l	d0,aSP			*  4
	NEXT2				* 40

z3C:	M_0C	AC				* INC A

z3D:	M_0D	AC				* DEC A

z3E:	M_0E	AC				* LD A,n

z3F:*						* CCF		56(10)		5.6	--*-0*
	eori.w	#%0000_0001,FR		*  8
	andi.w	#%1000_1111,FR		*  8
	NEXT2				* 40
				endif
*---------------------------------------
*

LD_hh	macro	Rd,Rs				* LD rh,rh	52(10)		5.2

	move.b	Rd,d0			*  4
	move.w	Rs,Rd			*  4
	move.b	d0,Rd			*  4
	NEXT2				* 40

	endm


LD_hl	macro	Rd,Rs				* LD rh,rl	64(10)		6.4

	move.w	Rd,-(sp)		*  8
	move.b	Rs,(sp)			*  8
	move.w	(sp)+,Rd		*  8
	NEXT2				* 40

	endm


LD_lh	macro	Rd,Rs				* LD rl,rh	56(10)		5.6

	move.w	Rs,-(sp)		*  8
	move.b	(sp)+,Rd		*  8
	NEXT2				* 40

	endm


LD_ll	macro	Rd,Rs				* LD rl,rl	44(10)		4.4

	move.b	Rs,Rd			*  4
	NEXT2				* 40

	endm


LD_hHL	macro	Rd				* LD rh,(HL)	78(17.5)	4.457

	move.w	Rd,-(sp)		*  8
	M_HL	d0			*  4
	move.b	(aME,d0.l),(sp)		* 18
	move.w	(sp)+,Rd		*  8
	NEXT2				* 40

	endm


LD_lHL	macro	Rd				* LD rl,(HL)	58(17.5)	3.314

	M_HL	d0			*  4
	move.b	(aME,d0.l),Rd		* 14
	NEXT2				* 40

	endm


LD_HLh	macro	Rs				* LD (HL),rh	70(17.5)	4.0

	move.w	Rs,-(sp)		*  8
	M_HL	d0			*  4
	C_ROM
	move.b	(sp)+,(aME,d0.l)	* 18
	NEXT2				* 40

	endm


LD_HLl	macro	Rs				* LD (HL),rl	58(17.5)	3.314

	M_HL	d0			*  4
	C_ROM
	move.b	Rs,(aME,d0.l)		* 14
	NEXT2				* 40

	endm

*
*---------------------------------------
				if F_ROM=0
z40:	NEXT2				* 40	* LD B,B	40(10)		4.0

z41:	LD_hl	BC,BC				* LD B,C

z42:	LD_hh	BC,DE				* LD B,D

z43:	LD_hl	BC,DE				* LD B,E

z44:	LD_hh	BC,HL				* LD B,H

z45:	LD_hl	BC,HL				* LD B,L

z46:	LD_hHL	BC				* LD B,(HL)

z47:	LD_hl	BC,AC				* LD B,A

z48:	LD_lh	BC,BC				* LD C,B

z49:	NEXT2				* 40	* LD C,C	40(10)		4.0

z4A:	LD_lh	BC,DE				* LD C,D

z4B:	LD_ll	BC,DE				* LD C,E

z4C:	LD_lh	BC,HL				* LD C,H

z4D:	LD_ll	BC,HL				* LD C,L

z4E:	LD_lHL	BC				* LD C,(HL)

z4F:	LD_ll	BC,AC				* LD C,A

z50:	LD_hh	DE,BC				* LD D,B

z51:	LD_hl	DE,BC				* LD D,C

z52:	NEXT2				* 40	* LD D,D	40(10)		4.0

z53:	LD_hl	DE,DE				* LD D,E

z54:	LD_hh	DE,HL				* LD D,H

z55:	LD_hl	DE,HL				* LD D,L

z56:	LD_hHL	DE				* LD D,(HL)

z57:	LD_hl	DE,AC				* LD D,A

z58:	LD_lh	DE,BC				* LD E,B

z59:	LD_ll	DE,BC				* LD E,C

z5A:	LD_lh	DE,DE				* LD E,D

z5B:	NEXT2				* 40	* LD E,E	40(10)		4.0

z5C:	LD_lh	DE,HL				* LD E,H

z5D:	LD_ll	DE,HL				* LD E,L

z5E:	LD_lHL	DE				* LD E,(HL)

z5F:	LD_ll	DE,AC				* LD E,A

z60:	LD_hh	HL,BC				* LD H,B

z61:	LD_hl	HL,BC				* LD H,C

z62:	LD_hh	HL,DE				* LD H,D

z63:	LD_hl	HL,DE				* LD H,E

z64:	NEXT2				* 40	* LD H,H	40(10)		4.0

z65:	LD_hl	HL,HL				* LD H,L

z66:	LD_hHL	HL				* LD H,(HL)

z67:	LD_hl	HL,AC				* LD H,A

z68:	LD_lh	HL,BC				* LD L,B

z69:	LD_ll	HL,BC				* LD L,C

z6A:	LD_lh	HL,DE				* LD L,D

z6B:	LD_ll	HL,DE				* LD L,E

z6C:	LD_lh	HL,HL				* LD L,H

z6D:	NEXT2				* 40	* LD L,L	40(10)		4.0

z6E:	LD_lHL	HL				* LD L,(HL)

z6F:	LD_ll	HL,AC				* LD L,A
				endif
z70:	LD_HLh	BC				* LD (HL),B

z71:	LD_HLl	BC				* LD (HL),C

z72:	LD_HLh	DE				* LD (HL),D

z73:	LD_HLl	DE				* LD (HL),E

z74:	LD_HLh	HL				* LD (HL),H

z75:	LD_HLl	HL				* LD (HL),L
				if F_ROM=0
z76:						* HALT		28(10)		2.8
	move.w	(aTO,d1.w),d0		* 14
	jmp	(aBS,d0.w)		* 14
				endif
z77:	LD_HLl	AC				* LD (HL),A
				if F_ROM=0
z78:	LD_lh	AC,BC				* LD A,B

z79:	LD_ll	AC,BC				* LD A,C

z7A:	LD_lh	AC,DE				* LD A,D

z7B:	LD_ll	AC,DE				* LD A,E

z7C:	LD_lh	AC,HL				* LD A,H

z7D:	LD_ll	AC,HL				* LD A,L

z7E:	LD_lHL	AC				* LD A,(HL)

z7F:	NEXT2				* 40	* LD A,A	40(10)		4.0

*---------------------------------------
*

SF_ADD	macro	ID						* 62			***V0*

	move	sr,FR			*  6
	moveq	#%0000_1111,d1		*  4
	and.w	d1,FR			*  4
	ori.w	#ID,FR			*  8
	NEXT2				* 40

	endm


ADD_h	macro	DR				* ADD A,rh	78(10)		7.8	***V0*

	move.w	DR,(aBS)		*  8
	add.b	(aBS),AC		*  8
	SF_ADD	%1010_0000		* 62
	endm


ADD_l	macro	DR				* ADD A,rl	74(10)		7.4	***V0*

	move.b	AC,(aBS)		*  8
	add.b	DR,AC			*  4
	SF_ADD	%1010_0000		* 62

	endm


ADC_h	macro	DR				* ADC A,rh	102(10)		10.2	***V0*

	move.b	AC,(aBS)		*  8
	move.w	DR,-(sp)		*  8
	move.b	(sp)+,d0		*  8
	lsr.b	#1,FR			*  8
	clr.b	FR			*  4
	addx.b	d0,AC			*  4
	SF_ADD	%1010_0000		* 62

	endm


ADC_l	macro	DR				* ADC A,rl	86(10)		8.6	***V0*

	move.b	AC,(aBS)		*  8
	lsr.b	#1,FR			*  8
	clr.b	FR			*  4
	addx.b	DR,AC			*  4
	SF_ADD	%1010_0000		* 62

	endm


M_86	macro					* ADD A,(HL)	88(17.5)	5.029	***V0*

	move.b	AC,(aBS)		*  8
	M_HL	d0			*  4
	add.b	(aME,d0.l),AC		* 14
	SF_ADD	%1010_0000		* 62

	endm

*
*---------------------------------------

z80:	ADD_h	BC				* ADD A,B

z81:	ADD_l	BC				* ADD A,C

z82:	ADD_h	DE				* ADD A,D

z83:	ADD_l	DE				* ADD A,E

z84:	ADD_h	HL				* ADD A,H

z85:	ADD_l	HL				* ADD A,L

z86:	M_86					* ADD A,(HL)

z87:						* ADD A,A	66(10)		6.6	***V0*
	add.b	AC,AC			*  4
	SF_ADD	%1110_0000		* 62

z88:	ADC_h	BC				* ADC A,B

z89:	ADC_l	BC				* ADC A,C

z8A:	ADC_h	DE				* ADC A,D

z8B:	ADC_l	DE				* ADC A,E

z8C:	ADC_h	HL				* ADC A,H

z8D:	ADC_l	HL				* ADC A,L

z8E:						* ADC A,(HL)	104(17.5)	5.943	***V0*
	R_HL	d1			* 18
	ADC_l	d1			* 86

z8F:						* ADC A,A	78(10)		7.8	***V0*
	lsr.b	#1,FR			*  8
	clr.b	FR			*  4
	addx.b	AC,AC			*  4
	SF_ADD	%1110_0000		* 62

*---------------------------------------
*

SF_SUB	macro	ID						* 62			***V1*

	move	sr,FR			*  6
	moveq	#%0000_1111,d1		*  4
	and.w	d1,FR			*  4
	ori.w	#ID,FR			*  8
	NEXT2				* 40

	endm


SUB_h	macro	DR				* SUB rh	78(10)		7.8	***V1*

	move.w	DR,(aBS)		*  8
	sub.b	(aBS),AC		*  8
	SF_SUB	%1001_0000		* 62

	endm


SUB_l	macro	DR				* SUB rl	74(10)		7.4	***V1*

	move.b	AC,(aBS)		*  8
	sub.b	DR,AC			*  4
	SF_SUB	%1011_0000		* 62

	endm


SBC_h	macro	DR				* SBC A,rh	102(10)		10.2	***V1*

	move.b	AC,(aBS)		*  8
	move.w	DR,-(sp)		*  8
	move.b	(sp)+,d0		*  8
	lsr.b	#1,FR			*  8
	clr.b	FR			*  4
	subx.b	d0,AC			*  4
	SF_SUB	%1011_0000		* 62

	endm


SBC_l	macro	DR				* SBC A,rl	86(10)		8.6	***V1*

	move.b	AC,(aBS)		*  8
	lsr.b	#1,FR			*  8
	clr.b	FR			*  4
	subx.b	DR,AC			*  4
	SF_SUB	%1011_0000		* 62

	endm


M_96	macro					* SUB (HL)	88(17.5)	5.029	***V1*

	move.b	AC,(aBS)		*  8
	M_HL	d0			*  4
	sub.b	(aME,d0.l),AC		* 14
	SF_SUB	%1011_0000		* 62

	endm

*
*---------------------------------------

z90:	SUB_h	BC				* SUB B

z91:	SUB_l	BC				* SUB C

z92:	SUB_h	DE				* SUB D

z93:	SUB_l	DE				* SUB E

z94:	SUB_h	HL				* SUB H

z95:	SUB_l	HL				* SUB L

z96:	M_96					* SUB (HL)

z97:*						* SUB A		56(10)		5.6	010010
	clr.b	AC			*  4
	move.w	#%1000_0100,FR		*  8
	NEXT				* 44

z98:	SBC_h	BC				* SBC A,B

z99:	SBC_l	BC				* SBC A,C

z9A:	SBC_h	DE				* SBC A,D

z9B:	SBC_l	DE				* SBC A,E

z9C:	SBC_h	HL				* SBC A,H

z9D:	SBC_l	HL				* SBC A,L

z9E:						* SBC A,(HL)	104(17.5)	5.943	***V1*
	R_HL	d1			* 18
	SBC_l	d1			* 86

z9F:*						* SBC A,A	70(10)		7.0	***01*
	move.b	FR,AC			*  4
	moveq	#%0000_0001,d1		*  4
	and.b	d1,AC			*  4
	beq.s	NC_9F			*  8(10)

	neg.b	AC			*  4
	move.w	#%1111_1001,FR		*  8
	NEXT2				* 40

NC_9F:	move.w	#%1000_0100,FR		*  8
	NEXT2				* 40

*---------------------------------------
*

SF_AND	macro				*:*			* 62			**1P00

	move	sr,FR			*  6
	moveq	#%0000_1100,d1		*  4
	and.w	d1,FR			*  4
	move.b	AC,(aBS)		*  8
	NEXT2				* 40

	endm


AND_h	macro	DR				* AND rh	78(10)		7.8	**1P00

	move.w	DR,-(sp)		*  8
	and.b	(sp)+,AC		*  8
	SF_AND				* 62

	endm

AND_l	macro	DR				* AND rl	66(10)		6.6	**1P00

	and.b	DR,AC			*  4
	SF_AND				* 62

	endm


SF_OR	macro							* 62			**0P00

	move	sr,FR			*  6
	moveq	#%0000_1100,d1		*  4
	and.w	d1,FR			*  4
	move.b	AC,(aBS)		*  8
	NEXT2				* 40

	endm


XOR_h	macro	DR				* XOR rh	82(10)		8.2	**0P00

	move.w	DR,-(sp)		*  8
	move.b	(sp)+,d0		*  8
	eor.b	d0,AC			*  4
	SF_OR				* 62

	endm


XOR_l	macro	DR				* XOR rl	66(10)		6.6	**0P00

	eor.b	DR,AC			*  4
	SF_OR				* 62

	endm


M_A6	macro					* AND (HL)	80(17.5)	4.571	**1P00

	M_HL	d0			*  4
	and.b	(aME,d0.l),AC		* 14
	SF_AND				* 62

	endm

*
*---------------------------------------

zA0:	AND_h	BC				* AND B

zA1:	AND_l	BC				* AND C

zA2:	AND_h	DE				* AND D

zA3:	AND_l	DE				* AND E

zA4:	AND_h	HL				* AND H

zA5:	AND_l	HL				* AND L

zA6:	M_A6					* AND (HL)

zA7:	AND_l	AC				* AND A

zA8:	XOR_h	BC				* XOR B

zA9:	XOR_l	BC				* XOR C

zAA:	XOR_h	DE				* XOR D

zAB:	XOR_l	DE				* XOR E

zAC:	XOR_h	HL				* XOR H

zAD:	XOR_l	HL				* XOR L

zAE:						* XOR (HL)	84(17.5)	4.8	**0P00
	R_HL	d1			* 18
	XOR_l	d1			* 66

zAF:						* XOR A		56(10)		5.6	010100
	clr.b	AC			*  4
	move.w	#%1000_0110,FR		*  8
	NEXT				* 44

*---------------------------------------
*

OR_h	macro	DR				* OR rh		78(10)		7.8	**0P00

	move.w	DR,-(sp)		*  8
	or.b	(sp)+,AC		*  8
	SF_OR				* 62

	endm

OR_l	macro	DR				* OR rl		66(10)		6.6	**0P00

	or.b	DR,AC			*  4
	SF_OR				* 62

	endm


SF_CP	macro				*:*			* 62			***V1*

	move	sr,FR			*  6
	moveq	#%0000_1111,d1		*  4
	and.w	d1,FR			*  4
	ori.w	#%1000_0000,FR		*  8
	NEXT2				* 40

	endm


CP_h	macro	DR				* CP rh		78(10)		7.8	***V1*

	move.w	DR,-(sp)		*  8
	cmp.b	(sp)+,AC		*  8
	SF_CP				* 62

	endm


CP_l	macro	DR				* CP rl		66(10)		6.6	***V1*

	cmp.b	DR,AC			*  4
	SF_CP				* 62

	endm


M_B6	macro					* OR (HL)	80(17.5)	4.571	**0P00

	M_HL	d0			*  4
	or.b	(aME,d0.l),AC		* 14
	SF_OR				* 62

	endm


M_BE	macro					* CP (HL)	80(17.5)	4.571	***V1*

	M_HL	d0			*  4
	cmp.b	(aME,d0.l),AC		* 14
	SF_CP				* 62

	endm

*
*---------------------------------------

zB0:	OR_h	BC				* OR B

zB1:	OR_l	BC				* OR C

zB2:	OR_h	DE				* OR D

zB3:	OR_l	DE				* OR E

zB4:	OR_h	HL				* OR H

zB5:	OR_l	HL				* OR L

zB6:	M_B6					* OR (HL)

zB7:	OR_l	AC				* OR A

zB8:	CP_h	BC				* CP B

zB9:	CP_l	BC				* CP C

zBA:	CP_h	DE				* CP D

zBB:	CP_l	DE				* CP E

zBC:	CP_h	HL				* CP H

zBD:	CP_l	HL				* CP L

zBE:	M_BE					* CP (HL)

zBF:*						* CP A		52(10)		5.2	010010
	move.w	#%1000_0100,FR		*  8
	NEXT				* 44
				endif
*---------------------------------------
*

PUSH	macro	DR						* 52

	move.l	aSP,d1			*  4
	subq.w	#2,d1			*  4
	movea.l	d1,aSP			*  4
	C_ROM
	move.b	DR,0(aME,aSP.l)		* 14
	move.w	DR,-(sp)		*  8
	move.b	(sp)+,1(aME,aSP.l)	* 18
	C_ROM2

	endm


POP	macro	DR						* 52

	move.b	1(aME,aSP.l),-(sp)	* 18
	move.w	(sp)+,DR		*  8
	move.b	0(aME,aSP.l),DR		* 14
	move.l	aSP,d1			*  4
	addq.w	#2,d1			*  4
	movea.l	d1,aSP			*  4

	endm


JPcc	macro	Bc,BN				* JP cc,nn	62/100(25)	2.48/4.0
	local	FALSE

	moveq	#1<<BN,d1		*  4
	and.b	FR,d1			*  4
	Bc.s	FALSE			*  8(10)

	R_WORD	d0			* 32
	lea	(aME,d0.l),aPC		* 12
	NEXT2				* 40

FALSE:	ADQA	#2,aPC			*  4
	NEXT2				* 40

	endm


CALLcc	macro	Bc,BN				* CALL cc,nn	62/166(25/42.5)	2.48/3.906
	local	FALSE

	moveq	#1<<BN,d1		*  4
	and.b	FR,d1			*  4
	Bc.s	FALSE			*  8(10)

	R_WORD	d0			* 32
	add.l	aME,d0			*  8
	exg	d0,aPC			*  6
	sub.l	aME,d0			*  8
	PUSH	d0			* 52
	NEXT				* 44

FALSE:	ADQA	#2,aPC			*  4
	NEXT2				* 40

	endm


RETcc	macro	Bc,BN				* RET cc	58/124(12.5/27.5) 4.64/4.509
	local	FALSE

	moveq	#1<<BN,d1		*  4
	and.b	FR,d1			*  4
	Bc.s	FALSE			*  8(10)

	POP	d0			* 52
	lea	(aME,d0.l),aPC		* 12
	moveq	#0,d1			*  4

FALSE:	NEXT2				* 40

	endm


RST	macro	AD				* RST n		116(27.5)	4.218

	move.l	aPC,d0			*  4
	sub.l	aME,d0			*  8
	PUSH	d0			* 52
	lea	AD(aME),aPC		*  8
	NEXT				* 44

	endm


S_JOP	macro	TBL,DR						* 52

	lea	TBL-A_BAS(aBS),a0	*  8
	moveq	#0,d1			*  4
	move.b	(aPC)+,d1		*  8
	add.w	d1,d1			*  4
	move.w	(a0,d1.w),DR		* 14
	jmp	(aBS,DR.w)		* 14

	endm


M_JOP	macro	TBL

	S_JOP	TBL,d0

	endm


M_JOP2	macro	TBL

	S_JOP	TBL,d1

	endm

*
*---------------------------------------
				if F_ROM=0
zC0:	RETcc	bne,2				* RET NZ

zC1:						* POP BC	96(25)		3.84
	POP	BC			* 52
	NEXT				* 44

zC2:	JPcc	bne,2				* JP NZ,nn

zC3:						* JP nn		88(25)		3.52
	R_WORD	d0			* 32
	lea	(aME,d0.l),aPC		* 12
	NEXT				* 44
				endif
zC4:	CALLcc	bne,2				* CALL NZ,nn

zC5:						* PUSH BC	96(27.5)	3.491
	PUSH	BC			* 52
	NEXT				* 44
				if F_ROM=0
zC6:						* ADD A,n	78(17.5)	4.457	***V0*
	ADD_l	(aPC)+			* 74+4
				endif
zC7:						* RST 00H	112(27.5)	4.073
	move.l	aPC,d0			*  4
	sub.l	aME,d0			*  8
	PUSH	d0			* 52
	lea	(aME),aPC		*  4
	NEXT				* 44
				if F_ROM=0
zC8:	RETcc	beq,2				* RET Z

zC9:						* RET		108(25)		4.32
	POP	d0			* 52
	lea	(aME,d0.l),aPC		* 12
	NEXT				* 44

zCA:	JPcc	beq,2				* JP Z,nn

zCB:	M_JOP	T_CB				* $CB
				endif
zCC:	CALLcc	beq,2				* CALL Z,nn

zCD:						* CALL nn	150(42.5)	3.529
	R_WORD	d0			* 32
	add.l	aME,d0			*  8
	exg	d0,aPC			*  6
	sub.l	aME,d0			*  8
	PUSH	d0			* 52
	NEXT				* 44
				if F_ROM=0
zCE:						* ADC A,n	94(17.5)	5.371	***V0*
	move.b	(aPC)+,d0		*  8
	ADC_l	d0			* 86
				endif
zCF:	RST	$08				* RST 08H
				if F_ROM=0
zD0:	RETcc	bne,0				* RET NC

zD1:						* POP DE	96(25)		3.84
	POP	DE			* 52
	NEXT				* 44

zD2:	JPcc	bne,0				* JP NC,nn

zD3:						* OUT n,A	106+(27.5)	3.855+
	move.w	BC,-(sp)		*  8
	move.b	AC,-(sp)		*  8
	move.w	(sp)+,BC		*  8
	move.b	(aPC)+,BC		*  8
	move.b	AC,d1			*  4
	jsr	OUT-A_BAS(aBS)		* 18 +
	move.w	(sp)+,BC		*  8
	NEXT				* 44
				endif
zD4:	CALLcc	bne,0				* CALL NC,nn

zD5:						* PUSH DE	96(27.5)	3.491
	PUSH	DE			* 52
	NEXT				* 44
				if F_ROM=0
zD6:						* SUB n		78(17.5)	4.457	***V1*
	SUB_l	(aPC)+			* 74+4
				endif
zD7:	RST	$10				* RST 10H
				if F_ROM=0
zD8:	RETcc	beq,0				* RET C

zD9:						* EXX		56(10)		5.6
	swap	BC			*  4
	swap	DE			*  4
	swap	HL			*  4
	NEXT				* 44

zDA:	JPcc	beq,0				* JP C,nn

zDB:						* IN A,n	106+(27.5)	3.855+
	move.w	BC,-(sp)		*  8
	move.b	AC,-(sp)		*  8
	move.w	(sp)+,BC		*  8
	move.b	(aPC)+,BC		*  8
	jsr	INP-A_BAS(aBS)		* 18 +
	move.b	d1,AC			*  4
	move.w	(sp)+,BC		*  8
	NEXT				* 44
				endif
zDC:	CALLcc	beq,0				* CALL C,nn
				if F_ROM=0
zDD:	M_JOP	T_DD				* $DD

zDE:						* SBC A,n	94(17.5)	5.371	***V1*
	move.b	(aPC)+,d0		*  8
	SBC_l	d0			* 86
				endif
zDF:	RST	$18				* RST 18H

*---------------------------------------
*

C_PF	macro				*:*			* 14/38
	local	Ov

	tst.b	FR			*  4
	bmi.s	Ov			*  8(10)

	clr.w	d0			*  4
	move.b	(aBS),d0		*  8
	or.b	T_PF-A_BAS(aBS,d0.w),FR	* 14
Ov:

	endm


M_E3	macro					* EX (SP),HL	114(47.5)	2.4

if F_ROM=0
	lea	(aME,aSP.l),a0		* 12
	move.b	(a0),d0			*  8
	move.b	HL,(a0)+		*  8
	move.b	(a0),HL			*  8
	rol.w	#8,HL			* 22
	move.b	HL,(a0)+		*  8
	move.b	d0,HL			*  4
	NEXT				* 44
else
	move.w	aSP,d0			*  4
	C_ROM
	C_ROM2
	adda.l	aSP,a0			*  8
	move.b	0(aME,aSP.l),d0		* 14
	move.b	HL,(a0)+		*  8
	move.b	1(aME,aSP.l),HL		* 14
	rol.w	#8,HL			* 22
	move.b	HL,(a0)+		*  8
	move.b	d0,HL			*  4
	NEXT				* 44
endif

	endm


M_E9	macro					* JP (HL)	60(10)		6.0

	move.w	HL,d0			*  4
	lea	(aME,d0.l),aPC		* 12
	NEXT				* 44

	endm

*
*---------------------------------------
				if F_ROM=0
zE0:						* RET PO	72/162(12.5/27.5) 5.76/5.891
	C_PF				* 14/38
	RETcc	bne,1			* 58/124

zE1:						* POP HL	96(25)		3.84
	POP	HL			* 52
	NEXT				* 44

zE2:						* JP PO,nn	76/138(25)	3.04/5.52
	C_PF				* 14/38
	JPcc	bne,1			* 62/100
				endif
zE3:	M_E3					* EX (SP),HL

zE4:						* CALL PO,nn	76/204(25/42.5)	3.04/4.8
	C_PF				* 14/38
	CALLcc	bne,1			* 62/166

zE5:						* PUSH HL	96(27.5)	3.491
	PUSH	HL			* 52
	NEXT				* 44
				if F_ROM=0
zE6:						* AND n		70(17.5)	4.0	**1P00
	AND_l	(aPC)+			* 66+4
				endif
zE7:	RST	$20				* RST 20H
				if F_ROM=0
zE8:						* RET PE	72/162(12.5/27.5) 5.76/5.891
	C_PF				* 14/38
	RETcc	beq,1			* 58/124

zE9:	M_E9					* JP (HL)

zEA:						* JP PE,nn	76/138(25)	3.04/5.52
	C_PF				* 14/38
	JPcc	beq,1			* 62/100

zEB:						* EX DE,HL	56(10)		5.6
	move.w	DE,d0			*  4
	move.w	HL,DE			*  4
	move.w	d0,HL			*  4
	NEXT				* 44
				endif
zEC:						* CALL PE,nn	76/204(25/42.5)	3.04/4.8
	C_PF				* 14/38
	CALLcc	beq,1			* 62/166
				if F_ROM=0
zED:	M_JOP	T_ED				* $ED

zEE:						* XOR n		74(17.5)	4.229	**0P00
	move.b	(aPC)+,d0		*  8
	XOR_l	d0			* 66
				endif
zEF:	RST	$28				* RST 28H
				if F_ROM=0
zF0:	RETcc	bne,3				* RET P

zF1:*						* POP AF	84(25)		3.36
	move.b	1(aME,aSP.l),AC		* 14
	move.b	0(aME,aSP.l),FR		* 14
	move.l	aSP,d1			*  4
	addq.w	#2,d1			*  4
	movea.l	d1,aSP			*  4
	NEXT				* 44

zF2:	JPcc	bne,3				* JP P,nn

zF3:						* DI		56(10)		5.6
	moveq	#0,d1			*  4
	move.w	d1,IFF1-A_BAS(aBS)	* 12
	NEXT2				* 40
				endif
zF4:	CALLcc	bne,3				* CALL P,nn

zF5:*						* PUSH AF	84(27.5)	3.055
	move.l	aSP,d1			*  4
	subq.w	#2,d1			*  4
	movea.l	d1,aSP			*  4
	C_ROM
	move.b	FR,0(aME,aSP.l)		* 14
	move.b	AC,1(aME,aSP.l)		* 14
	NEXT				* 44
				if F_ROM=0
zF6:						* OR n		70(17.5)	4.0	**0P00
	OR_l	(aPC)+			* 66+4
				endif
zF7:	RST	$30				* RST 30H
				if F_ROM=0
zF8:	RETcc	beq,3				* RET M

*---------------------------------------
*

M_F9	macro					* LD SP,HL	52(15)		3.467

	move.w	HL,d0			*  4
	movea.l	d0,aSP			*  4
	NEXT				* 44

	endm

*
*---------------------------------------

zF9:	M_F9					* LD SP,HL

zFA:	JPcc	beq,3				* JP M,nn

zFB:						* EI		72+(10)		7.2+
	tst.b	IFF1-A_BAS(aBS)		* 12
	bne.s	OIF_FB			*  8(10)

	moveq	#0,d1			*  4
	move.b	(aPC)+,d1		*  8
	add.w	d1,d1			*  4
	move.w	(aTO,d1.w),d0		* 14

	lea	T_NEI-A_BAS(aBS),aTO	*  8
	jmp	(aBS,d0.w)		* 14

OIF_FB:	NEXT				* 44
				endif
zFC:	CALLcc	beq,3				* CALL M,nn
				if F_ROM=0
zFD:						* $FD		56
	swap	XY			*  4
	M_JOP	T_FD			* 52

zFE:						* CP n		70(17.5)	4.0	***V1*
	CP_l	(aPC)+			* 66+4
				endif
zFF:	RST	$38				* RST 38H


*---------------------------------------*
*	       CB xx (+52)		*
*---------------------------------------*

*---------------------------------------
*

SF_Rh	macro	DR						* 66			**0P0*

	move	sr,FR			*  6
	moveq	#%0000_1101,d1		*  4
	and.w	d1,FR			*  4
	move.b	d0,DR			*  4
	move.w	DR,(aBS)		*  8
	NEXT2				* 40

	endm


SF_Rl	macro	DR						* 62			**0P0*

	move	sr,FR			*  6
	moveq	#%0000_1101,d1		*  4
	and.w	d1,FR			*  4
	move.b	DR,(aBS)		*  8
	NEXT2				* 40

	endm


SF_RRh	macro	DR						* 78			**0P0*

	add.b	DR,DR			*  4
	clr.b	DR			*  4
	move.w	DR,(aBS)		*  8

	move	sr,FR			*  6
	moveq	#%0000_1100,d1		*  4
	and.w	d1,FR			*  4
	addx.b	DR,FR			*  4
	move.b	d0,DR			*  4
	NEXT2				* 40

	endm


SF_RHL	macro							* 76			**0P0*

	move	sr,FR			*  6
	C_ROM1	d0
	move.b	d1,(aME,d0.l)		* 14
	move.b	d1,(aBS)		*  8
	moveq	#%0000_1101,d1		*  4
	and.w	d1,FR			*  4
	NEXT2				* 40

	endm


RLC_h	macro	DR				* RLC rh	78(20)		3.9	**0P0*

	move.w	DR,d0			*  4
	smi	DR			*  4/6
	add.w	DR,DR			*  4
	SF_Rh	DR			* 66

	endm


RLC_l	macro	DR				* RLC rl	70(20)		3.5	**0P0*

	rol.b	#1,DR			*  8
	SF_Rl	DR			* 62

	endm


RRC_h	macro	DR				* RRC rh	92(20)		4.6	**0P0*

	move.b	DR,d0			*  4
	btst	#8,DR			* 10
	sne	DR			*  4/6
	ror.w	#1,DR			*  8
	SF_Rh	DR			* 66

	endm


RRC_l	macro	DR				* RRC rl	70(20)		3.5	**0P0*

	ror.b	#1,DR			*  8
	SF_Rl	DR			* 62

	endm

*
*---------------------------------------
				if F_ROM=0
CB_00:	RLC_h	BC				* RLC B

CB_01:	RLC_l	BC				* RLC C

CB_02:	RLC_h	DE				* RLC D

CB_03:	RLC_l	DE				* RLC E

CB_04:	RLC_h	HL				* RLC H

CB_05:	RLC_l	HL				* RLC L
				endif
CB_06:						* RLC (HL)	102(37.5)	2.72	**0P0*
	R_HL	d1			* 18
	rol.b	#1,d1			*  8
	SF_RHL				* 76
				if F_ROM=0
CB_07:	RLC_l	AC				* RLC A

CB_08:	RRC_h	BC				* RRC B

CB_09:	RRC_l	BC				* RRC C

CB_0A:	RRC_h	DE				* RRC D

CB_0B:	RRC_l	DE				* RRC E

CB_0C:	RRC_h	HL				* RRC H

CB_0D:	RRC_l	HL				* RRC L
				endif
CB_0E:						* RRC (HL)	102(37.5)	2.72	**0P0*
	R_HL	d1			* 18
	ror.b	#1,d1			*  8
	SF_RHL				* 76
				if F_ROM=0
CB_0F:	RRC_l	AC				* RRC A

*---------------------------------------
*

RL_h	macro	DR				* RL rh		86(20)		4.3	**0P0*

	move.b	DR,d0			*  4
	lsr.b	#1,FR			*  8
	scs	DR			*  4/6
	add.w	DR,DR			*  4
	SF_Rh	DR			* 66

	endm


RL_l	macro	DR				* RL rl		78(20)		3.9	**0P0*

	lsr.b	#1,FR			*  8
	roxl.b	#1,DR			*  8
	SF_Rl	DR			* 62

	endm


RR_h	macro	DR				* RR rh		94(20)		4.7	**0P0*

	move.b	DR,d0			*  4
	move.b	FR,DR			*  4
	ror.w	#1,DR			*  8
	SF_RRh	DR			* 78

	endm


RR_l	macro	DR				* RR rl		78(20)		3.9	**0P0*

	lsr.b	#1,FR			*  8
	roxr.b	#1,DR			*  8
	SF_Rl	DR			* 62

	endm

*
*---------------------------------------

CB_10:	RL_h	BC				* RL B

CB_11:	RL_l	BC				* RL C

CB_12:	RL_h	DE				* RL D

CB_13:	RL_l	DE				* RL E

CB_14:	RL_h	HL				* RL H

CB_15:	RL_l	HL				* RL L
				endif
CB_16:						* RL (HL)	110(37.5)	2.933	**0P0*
	R_HL	d1			* 18
	lsr.b	#1,FR			*  8
	roxl.b	#1,d1			*  8
	SF_RHL				* 76
				if F_ROM=0
CB_17:	RL_l	AC				* RL A

CB_18:	RR_h	BC				* RR B

CB_19:	RR_l	BC				* RR C

CB_1A:	RR_h	DE				* RR D

CB_1B:	RR_l	DE				* RR E

CB_1C:	RR_h	HL				* RR H

CB_1D:	RR_l	HL				* RR L
				endif
CB_1E:						* RR (HL)	110(37.5)	2.933	**0P0*
	R_HL	d1			* 18
	lsr.b	#1,FR			*  8
	roxr.b	#1,d1			*  8
	SF_RHL				* 76
				if F_ROM=0
CB_1F:	RR_l	AC				* RR A

*---------------------------------------
*

SLA_h	macro	DR				* SLA rh	78(20)		3.9	**0P0*

	move.b	DR,d0			*  4
	clr.b	DR			*  4
	add.w	DR,DR			*  4
	SF_Rh	DR			* 66

	endm


SLA_l	macro	DR				* SLA rl	66(20)		3.3	**0P0*

	add.b	DR,DR			*  4
	SF_Rl	DR			* 62

	endm


SRA_h	macro	DR				* SRA rh	90(20)		4.5	**0P0*

	move.b	DR,d0			*  4
	asr.w	#1,DR			*  8
	SF_RRh	DR			* 78

	endm


SRA_l	macro	DR				* SRA rl	70(20)		3.5	**0P0*

	asr.b	#1,DR			*  8
	SF_Rl	DR			* 62

	endm

*
*---------------------------------------

CB_20:	SLA_h	BC				* SLA B

CB_21:	SLA_l	BC				* SLA C

CB_22:	SLA_h	DE				* SLA D

CB_23:	SLA_l	DE				* SLA E

CB_24:	SLA_h	HL				* SLA H

CB_25:	SLA_l	HL				* SLA L
				endif
CB_26:						* SLA (HL)	98(37.5)	2.613	**0P0*
	R_HL	d1			* 18
	add.b	d1,d1			*  4
	SF_RHL				* 76
				if F_ROM=0
CB_27:	SLA_l	AC				* SLA A

CB_28:	SRA_h	BC				* SRA B

CB_29:	SRA_l	BC				* SRA C

CB_2A:	SRA_h	DE				* SRA D

CB_2B:	SRA_l	DE				* SRA E

CB_2C:	SRA_h	HL				* SRA H

CB_2D:	SRA_l	HL				* SRA L
				endif
CB_2E:						* SRA (HL)	102(37.5)	2.72	**0P0*
	R_HL	d1			* 18
	asr.b	#1,d1			*  8
	SF_RHL				* 76
				if F_ROM=0
CB_2F:	SRA_l	AC				* SRA A

*---------------------------------------
*

SRL_h	macro	DR				* SRL rh	90(20)		4.5	**0P0*

	move.b	DR,d0			*  4
	lsr.w	#1,DR			*  8
	SF_RRh	DR			* 78

	endm


SRL_l	macro	DR				* SRL rl	70(20)		3.5	**0P0*

	lsr.b	#1,DR			*  8
	SF_Rl	DR			* 62

	endm

*
*---------------------------------------

CB_38:	SRL_h	BC				* SRL B

CB_39:	SRL_l	BC				* SRL C

CB_3A:	SRL_h	DE				* SRL D

CB_3B:	SRL_l	DE				* SRL E

CB_3C:	SRL_h	HL				* SRL H

CB_3D:	SRL_l	HL				* SRL L
				endif
CB_3E:						* SRL (HL)	102(37.5)	2.72	**0P0*
	R_HL	d1			* 18
	lsr.b	#1,d1			*  8
	SF_RHL				* 76
				if F_ROM=0
CB_3F:	SRL_l	AC				* SRL A

*---------------------------------------
*

SF_BIT	macro	BN						* 50			?*1?0-
	local	NZ

if BN=7.or.BN=15
	bmi.s	NZ			*  8(10)
else
	bne.s	NZ			*  8(10)
endif
	addq.w	#%0000_0100,FR		*  4
NZ:	NEXT2				* 40

	endm


BIT_h	macro	BN,DR				* BIT b,rh	68(20)		3.4	?*1?0-

	BIT_l	BN+8,DR			* 68

	endm


BIT_l	macro	BN,DR			*:*	* BIT b,rl	66(20)		3.3	?*1?0-

	moveq	#%0000_1001,d1		*  4
	and.w	d1,FR			*  4
if BN<=6
	moveq	#1<<BN,d1		*  4
	and.b	DR,d1			*  4
elseif BN=7
	tst.b	DR			*  4
elseif BN=15
	tst.w	DR			*  4
else
	btst	#BN,DR			* 10
endif
	SF_BIT	BN			* 50

	endm


BIT_HL	macro	BN			*:*	* BIT b,(HL)	80(30)		2.667	?*1?0-

	moveq	#%0000_1001,d1		*  4
	and.w	d1,FR			*  4
	M_HL	d0			*  4
if BN=7
	tst.b	(aME,d0.l)		* 14
else
	btst	#BN,(aME,d0.l)		* 18
endif
	SF_BIT	BN			* 50

	endm

*
*---------------------------------------

CB_40:	BIT_h	0,BC				* BIT 0,B

CB_41:	BIT_l	0,BC				* BIT 0,C

CB_42:	BIT_h	0,DE				* BIT 0,D

CB_43:	BIT_l	0,DE				* BIT 0,E

CB_44:	BIT_h	0,HL				* BIT 0,H

CB_45:	BIT_l	0,HL				* BIT 0,L

CB_46:	BIT_HL	0				* BIT 0,(HL)

CB_47:	BIT_l	0,AC				* BIT 0,A

CB_48:	BIT_h	1,BC				* BIT 1,B

CB_49:	BIT_l	1,BC				* BIT 1,C

CB_4A:	BIT_h	1,DE				* BIT 1,D

CB_4B:	BIT_l	1,DE				* BIT 1,E

CB_4C:	BIT_h	1,HL				* BIT 1,H

CB_4D:	BIT_l	1,HL				* BIT 1,L

CB_4E:	BIT_HL	1				* BIT 1,(HL)

CB_4F:	BIT_l	1,AC				* BIT 1,A

CB_50:	BIT_h	2,BC				* BIT 2,B

CB_51:	BIT_l	2,BC				* BIT 2,C

CB_52:	BIT_h	2,DE				* BIT 2,D

CB_53:	BIT_l	2,DE				* BIT 2,E

CB_54:	BIT_h	2,HL				* BIT 2,H

CB_55:	BIT_l	2,HL				* BIT 2,L

CB_56:	BIT_HL	2				* BIT 2,(HL)

CB_57:	BIT_l	2,AC				* BIT 2,A

CB_58:	BIT_h	3,BC				* BIT 3,B

CB_59:	BIT_l	3,BC				* BIT 3,C

CB_5A:	BIT_h	3,DE				* BIT 3,D

CB_5B:	BIT_l	3,DE				* BIT 3,E

CB_5C:	BIT_h	3,HL				* BIT 3,H

CB_5D:	BIT_l	3,HL				* BIT 3,L

CB_5E:	BIT_HL	3				* BIT 3,(HL)

CB_5F:	BIT_l	3,AC				* BIT 3,A

CB_60:	BIT_h	4,BC				* BIT 4,B

CB_61:	BIT_l	4,BC				* BIT 4,C

CB_62:	BIT_h	4,DE				* BIT 4,D

CB_63:	BIT_l	4,DE				* BIT 4,E

CB_64:	BIT_h	4,HL				* BIT 4,H

CB_65:	BIT_l	4,HL				* BIT 4,L

CB_66:	BIT_HL	4				* BIT 4,(HL)

CB_67:	BIT_l	4,AC				* BIT 4,A

CB_68:	BIT_h	5,BC				* BIT 5,B

CB_69:	BIT_l	5,BC				* BIT 5,C

CB_6A:	BIT_h	5,DE				* BIT 5,D

CB_6B:	BIT_l	5,DE				* BIT 5,E

CB_6C:	BIT_h	5,HL				* BIT 5,H

CB_6D:	BIT_l	5,HL				* BIT 5,L

CB_6E:	BIT_HL	5				* BIT 5,(HL)

CB_6F:	BIT_l	5,AC				* BIT 5,A

CB_70:	BIT_h	6,BC				* BIT 6,B

CB_71:	BIT_l	6,BC				* BIT 6,C

CB_72:	BIT_h	6,DE				* BIT 6,D

CB_73:	BIT_l	6,DE				* BIT 6,E

CB_74:	BIT_h	6,HL				* BIT 6,H

CB_75:	BIT_l	6,HL				* BIT 6,L

CB_76:	BIT_HL	6				* BIT 6,(HL)

CB_77:	BIT_l	6,AC				* BIT 6,A

CB_78:	BIT_h	7,BC				* BIT 7,B

CB_79:	BIT_l	7,BC				* BIT 7,C

CB_7A:	BIT_h	7,DE				* BIT 7,D

CB_7B:	BIT_l	7,DE				* BIT 7,E

CB_7C:	BIT_h	7,HL				* BIT 7,H

CB_7D:	BIT_l	7,HL				* BIT 7,L

CB_7E:	BIT_HL	7				* BIT 7,(HL)

CB_7F:	BIT_l	7,AC				* BIT 7,A
				endif
*---------------------------------------
*

RES_h	macro	BN,DR				* RES b,rh	52(20)		2.6

	RES_l	BN+8,DR			* 52

	endm


RES_l	macro	BN,DR				* RES b,rl	52(20)		2.6

	andi.w	#.loww.(.not.(1<<(BN))),DR	*  8
	NEXT					* 44

	endm


RES_HL	macro	BN				* RES b,(HL)	66(37.5)	1.76

	moveq	#BN,d1			*  4
	M_HL	d0			*  4

if F_ROM=0
	bclr	d1,(aME,d0.l)		* 18
else
	C_ROM
	C_ROM2
	adda.l	d0,a0			*  8
	move.b	(aME,d0.l),d0		* 14
	bclr	d1,d0			*<10
	move.b	d0,(a0)			*  8
endif

	NEXT2				* 40

	endm

*
*---------------------------------------
				if F_ROM=0
CB_80:	RES_h	0,BC				* RES 0,B

CB_81:	RES_l	0,BC				* RES 0,C

CB_82:	RES_h	0,DE				* RES 0,D

CB_83:	RES_l	0,DE				* RES 0,E

CB_84:	RES_h	0,HL				* RES 0,H

CB_85:	RES_l	0,HL				* RES 0,L
				endif
CB_86:	RES_HL	0				* RES 0,(HL)
				if F_ROM=0
CB_87:	RES_l	0,AC				* RES 0,A

CB_88:	RES_h	1,BC				* RES 1,B

CB_89:	RES_l	1,BC				* RES 1,C

CB_8A:	RES_h	1,DE				* RES 1,D

CB_8B:	RES_l	1,DE				* RES 1,E

CB_8C:	RES_h	1,HL				* RES 1,H

CB_8D:	RES_l	1,HL				* RES 1,L
				endif
CB_8E:	RES_HL	1				* RES 1,(HL)
				if F_ROM=0
CB_8F:	RES_l	1,AC				* RES 1,A

CB_90:	RES_h	2,BC				* RES 2,B

CB_91:	RES_l	2,BC				* RES 2,C

CB_92:	RES_h	2,DE				* RES 2,D

CB_93:	RES_l	2,DE				* RES 2,E

CB_94:	RES_h	2,HL				* RES 2,H

CB_95:	RES_l	2,HL				* RES 2,L
				endif
CB_96:	RES_HL	2				* RES 2,(HL)
				if F_ROM=0
CB_97:	RES_l	2,AC				* RES 2,A

CB_98:	RES_h	3,BC				* RES 3,B

CB_99:	RES_l	3,BC				* RES 3,C

CB_9A:	RES_h	3,DE				* RES 3,D

CB_9B:	RES_l	3,DE				* RES 3,E

CB_9C:	RES_h	3,HL				* RES 3,H

CB_9D:	RES_l	3,HL				* RES 3,L
				endif
CB_9E:	RES_HL	3				* RES 3,(HL)
				if F_ROM=0
CB_9F:	RES_l	3,AC				* RES 3,A

CB_A0:	RES_h	4,BC				* RES 4,B

CB_A1:	RES_l	4,BC				* RES 4,C

CB_A2:	RES_h	4,DE				* RES 4,D

CB_A3:	RES_l	4,DE				* RES 4,E

CB_A4:	RES_h	4,HL				* RES 4,H

CB_A5:	RES_l	4,HL				* RES 4,L
				endif
CB_A6:	RES_HL	4				* RES 4,(HL)
				if F_ROM=0
CB_A7:	RES_l	4,AC				* RES 4,A

CB_A8:	RES_h	5,BC				* RES 5,B

CB_A9:	RES_l	5,BC				* RES 5,C

CB_AA:	RES_h	5,DE				* RES 5,D

CB_AB:	RES_l	5,DE				* RES 5,E

CB_AC:	RES_h	5,HL				* RES 5,H

CB_AD:	RES_l	5,HL				* RES 5,L
				endif
CB_AE:	RES_HL	5				* RES 5,(HL)
				if F_ROM=0
CB_AF:	RES_l	5,AC				* RES 5,A

CB_B0:	RES_h	6,BC				* RES 6,B

CB_B1:	RES_l	6,BC				* RES 6,C

CB_B2:	RES_h	6,DE				* RES 6,D

CB_B3:	RES_l	6,DE				* RES 6,E

CB_B4:	RES_h	6,HL				* RES 6,H

CB_B5:	RES_l	6,HL				* RES 6,L
				endif
CB_B6:	RES_HL	6				* RES 6,(HL)
				if F_ROM=0
CB_B7:	RES_l	6,AC				* RES 6,A

CB_B8:	RES_h	7,BC				* RES 7,B

CB_B9:	RES_l	7,BC				* RES 7,C

CB_BA:	RES_h	7,DE				* RES 7,D

CB_BB:	RES_l	7,DE				* RES 7,E

CB_BC:	RES_h	7,HL				* RES 7,H

CB_BD:	RES_l	7,HL				* RES 7,L
				endif
CB_BE:	RES_HL	7				* RES 7,(HL)
				if F_ROM=0
CB_BF:	RES_l	7,AC				* RES 7,A
				endif
*---------------------------------------
*

SET_h	macro	BN,DR				* SET b,rh	52(20)		2.6

	SET_l	BN+8,DR			* 52

	endm


SET_l	macro	BN,DR				* SET b,rl	48(20)		2.4

if BN<7
	moveq	#1<<BN,d1		*  4
	or.b	d1,DR			*  4
else
	moveq	#BN,d1			*  4
	bset	d1,DR			* <8
endif
	NEXT2				* 40

	endm


SET_HL	macro	BN				* SET b,(HL)	66(37.5)	1.76

	moveq	#BN,d1			*  4
	M_HL	d0			*  4

if F_ROM=0
	bset	d1,(aME,d0.l)		* 18
else
	C_ROM
	C_ROM2
	adda.l	d0,a0			*  8
	move.b	(aME,d0.l),d0		* 14
	bset	d1,d0			* <8 *+
	move.b	d0,(a0)			*  8
endif

	NEXT2				* 40

	endm

*
*---------------------------------------
				if F_ROM=0
CB_C0:	SET_h	0,BC				* SET 0,B

CB_C1:	SET_l	0,BC				* SET 0,C

CB_C2:	SET_h	0,DE				* SET 0,D

CB_C3:	SET_l	0,DE				* SET 0,E

CB_C4:	SET_h	0,HL				* SET 0,H

CB_C5:	SET_l	0,HL				* SET 0,L
				endif
CB_C6:	SET_HL	0				* SET 0,(HL)
				if F_ROM=0
CB_C7:	SET_l	0,AC				* SET 0,A

CB_C8:	SET_h	1,BC				* SET 1,B

CB_C9:	SET_l	1,BC				* SET 1,C

CB_CA:	SET_h	1,DE				* SET 1,D

CB_CB:	SET_l	1,DE				* SET 1,E

CB_CC:	SET_h	1,HL				* SET 1,H

CB_CD:	SET_l	1,HL				* SET 1,L
				endif
CB_CE:	SET_HL	1				* SET 1,(HL)
				if F_ROM=0
CB_CF:	SET_l	1,AC				* SET 1,A

CB_D0:	SET_h	2,BC				* SET 2,B

CB_D1:	SET_l	2,BC				* SET 2,C

CB_D2:	SET_h	2,DE				* SET 2,D

CB_D3:	SET_l	2,DE				* SET 2,E

CB_D4:	SET_h	2,HL				* SET 2,H

CB_D5:	SET_l	2,HL				* SET 2,L
				endif
CB_D6:	SET_HL	2				* SET 2,(HL)
				if F_ROM=0
CB_D7:	SET_l	2,AC				* SET 2,A

CB_D8:	SET_h	3,BC				* SET 3,B

CB_D9:	SET_l	3,BC				* SET 3,C

CB_DA:	SET_h	3,DE				* SET 3,D

CB_DB:	SET_l	3,DE				* SET 3,E

CB_DC:	SET_h	3,HL				* SET 3,H

CB_DD:	SET_l	3,HL				* SET 3,L
				endif
CB_DE:	SET_HL	3				* SET 3,(HL)
				if F_ROM=0
CB_DF:	SET_l	3,AC				* SET 3,A

CB_E0:	SET_h	4,BC				* SET 4,B

CB_E1:	SET_l	4,BC				* SET 4,C

CB_E2:	SET_h	4,DE				* SET 4,D

CB_E3:	SET_l	4,DE				* SET 4,E

CB_E4:	SET_h	4,HL				* SET 4,H

CB_E5:	SET_l	4,HL				* SET 4,L
				endif
CB_E6:	SET_HL	4				* SET 4,(HL)
				if F_ROM=0
CB_E7:	SET_l	4,AC				* SET 4,A

CB_E8:	SET_h	5,BC				* SET 5,B

CB_E9:	SET_l	5,BC				* SET 5,C

CB_EA:	SET_h	5,DE				* SET 5,D

CB_EB:	SET_l	5,DE				* SET 5,E

CB_EC:	SET_h	5,HL				* SET 5,H

CB_ED:	SET_l	5,HL				* SET 5,L
				endif
CB_EE:	SET_HL	5				* SET 5,(HL)
				if F_ROM=0
CB_EF:	SET_l	5,AC				* SET 5,A

CB_F0:	SET_h	6,BC				* SET 6,B

CB_F1:	SET_l	6,BC				* SET 6,C

CB_F2:	SET_h	6,DE				* SET 6,D

CB_F3:	SET_l	6,DE				* SET 6,E

CB_F4:	SET_h	6,HL				* SET 6,H

CB_F5:	SET_l	6,HL				* SET 6,L
				endif
CB_F6:	SET_HL	6				* SET 6,(HL)
				if F_ROM=0
CB_F7:	SET_l	6,AC				* SET 6,A

CB_F8:	SET_h	7,BC				* SET 7,B

CB_F9:	SET_l	7,BC				* SET 7,C

CB_FA:	SET_h	7,DE				* SET 7,D

CB_FB:	SET_l	7,DE				* SET 7,E

CB_FC:	SET_h	7,HL				* SET 7,H

CB_FD:	SET_l	7,HL				* SET 7,L
				endif
CB_FE:	SET_HL	7				* SET 7,(HL)
				if F_ROM=0
CB_FF:	SET_l	7,AC				* SET 7,A
				endif

*---------------------------------------*
*	       ED xx (+52)		*
*---------------------------------------*

HL	set	d7
F_IXY	set	0
F_XYCB	set	0
				if F_ROM=0
ED_00:
	move.b	(aPC)+,d1		*  8
	cmpi.b	#'6',d1			*  8
	bne.s	NXe00			*  8(10)
	cmpi.b	#'8',(aPC)		* 12
	bne.s	NXe00			*  8(10)
	ADQA	#1,aPC			*  4

	move.b	(aPC)+,-(sp)		* 12
	move.w	(sp)+,d0		*  8
	move.b	(aPC)+,d0		*  8

	tst.w	d0			*  4
	beq.s	EXIT			*  8(10)
	jsr	FCALL-A_BAS(aBS)	* 18 +

	move.b	(aPC)+,d1		*  8
NXe00:	add.w	d1,d1			*  4
	move.w	(aTO,d1.w),d0		* 14
	jmp	(aBS,d0.w)		* 14

EXIT:
	rts				* 16

*---------------------------------------
*

IN_rh	macro	DR				* IN rh,(C)	108+(30)	3.6+	**0P0-

	jsr	INP-A_BAS(aBS)		* 18 +
	move.w	DR,(aBS)		*  8
	move.b	d1,(aBS)		*  8
	move	sr,d0			*  6
	move.w	(aBS),DR		*  8

	moveq	#%0000_1100,d1		*  4
	and.w	d1,d0			*  4
	andi.w	#%0000_0001,FR		*  8
	or.w	d0,FR			*  4
	NEXT2				* 40

	endm


IN_rl	macro	DR				* IN rl,(C)	96+(30)		3.2+	**0P0-

	jsr	INP-A_BAS(aBS)		* 18 +
	move.b	d1,(aBS)		*  8
	move	sr,d0			*  6
	move.b	d1,DR			*  4

	moveq	#%0000_1100,d1		*  4
	and.w	d1,d0			*  4
	andi.w	#%0000_0001,FR		*  8
	or.w	d0,FR			*  4
	NEXT2				* 40

	endm


OUT_rh	macro	DR				* OUT (C),rh	74+(30)		2.467+

	move.w	DR,-(sp)		*  8
	move.b	(sp)+,d1		*  8
	jsr	OUT-A_BAS(aBS)		* 18 +
if F_OUTC=0
	moveq	#0,d1			*  4
endif
	NEXT2				* 40

	endm


OUT_rl	macro	DR				* OUT (C),rl	62+(30)		2.067+

	move.b	DR,d1			*  4
	jsr	OUT-A_BAS(aBS)		* 18 +
if F_OUTC=0
	moveq	#0,d1			*  4
endif
	NEXT2				* 40

	endm


SBC_ss	macro	SS			*:*	* SBC HL,ss	78(37.5)	2.08	***V1*

	lsr.b	#1,FR			*  8
	clr.b	FR			*  4
	subx.w	SS,HL			*  4

	move	sr,FR			*  6
	andi.w	#%0000_1111,FR		*  8
	ori.w	#%1000_0000,FR		*  8
	NEXT2				* 40

	endm


ADC_ss	macro	SS			*:*	* ADC HL,ss	78(37.5)	2.08	***V0*

	lsr.b	#1,FR			*  8
	clr.b	FR			*  4
	addx.w	SS,HL			*  4

	move	sr,FR			*  6
	andi.w	#%0000_1111,FR		*  8
	ori.w	#%1000_0000,FR		*  8
	NEXT2				* 40

	endm


IM	macro	MD,MD76				* IM mode	2904(20)	145.2
	local	LOOP

	lea	T_INT-A_BAS(aBS),a0			*  8
	move.l	#(MD-A_BAS)*$10000+.loww.(MD-A_BAS),d1	* 12
	moveq	#$100/2-1,d0				*  4

LOOP:	move.l	d1,(a0)+				* 12     1536
	dbf	d0,LOOP					* 14(10) 1284

	move.w	#(MD76-A_BAS),(T_INT+$76*2)-A_BAS(aBS)	* 16
	NEXT						* 44

	endm

*
*---------------------------------------

ED_40:	IN_rh	BC				* IN B,(C)

ED_41:	OUT_rh	BC				* OUT (C),B

ED_42:	SBC_ss	BC				* SBC HL,BC
				endif
ED_43:	LD_nnss	BC				* LD (nn),BC
				if F_ROM=0
ED_44:*						* NEG		74(20)		3.7	***V1*
	move.b	AC,(aBS)		*  8
	neg.b	AC			*  4

	move	sr,FR			*  6
	andi.w	#%0000_1111,FR		*  8
	ori.w	#%1001_0000,FR		*  8
	NEXT2				* 40

ED_45:						* RETN		128(35)		3.657
	POP	d0				* 52
	lea	(aME,d0.l),aPC			* 12
	move.b	IFF2-A_BAS(aBS),IFF1-A_BAS(aBS)	* 20
	NEXT					* 44

ED_46:	IM	IM0,IM0_76			* IM 0

ED_47:						* LD I,A	92(22.5)	4.089
	move.b	AC,-(sp)		*  8
	swap	AC			*  4
	move.w	(sp),d0			*  8
	move.b	AC,d0			*  4

	swap	d0			*  4
	move.w	(sp),d0			*  8
	move.b	(sp)+,d0		*  8
	move.l	d0,AC			*  4

	moveq	#0,d0			*  4
	NEXT2				* 40

ED_48:	IN_rl	BC				* IN C,(C)

ED_49:	OUT_rl	BC				* OUT (C),C

ED_4A:	ADC_ss	BC				* ADC HL,BC

ED_4B:	LD_ssnn	BC				* LD BC,(nn)

ED_4D:*						* RETI		108(35)		3.086
	POP	d0			* 52
	lea	(aME,d0.l),aPC		* 12
	NEXT				* 44

ED_4F:	NEXT2				* 40	* LD R,A	40(22.5)	1.778

ED_50:	IN_rh	DE				* IN D,(C)

ED_51:	OUT_rh	DE				* OUT (C),D

ED_52:	SBC_ss	DE				* SBC HL,DE
				endif
ED_53:	LD_nnss	DE				* LD (nn),DE
				if F_ROM=0
ED_56:	IM	IM1,IM1_76			* IM 1

ED_57:						* LD A,I	110(22.5)	4.889	**0I0-
	move.w	AC,-(sp)		*  8
	move.b	(sp)+,AC		*  8

	move	sr,d0			*  6
	andi.w	#%0000_1100,d0		*  8
	andi.w	#%0000_0001,FR		*  8
	or.w	d0,FR			*  4

	tst.b	IFF2-A_BAS(aBS)		* 12
	bne.s	OI_e57			*  8(10)

	ori.w	#%1000_0000,FR		*  8
	NEXT2				* 40

OI_e57:	ori.w	#%1000_0010,FR		*  8
	NEXT2				* 40

ED_58:	IN_rl	DE				* IN E,(C)

ED_59:	OUT_rl	DE				* OUT (C),E

ED_5A:	ADC_ss	DE				* ADC HL,DE

ED_5B:	LD_ssnn	DE				* LD DE,(nn)

ED_5E:	IM	IM2,IM2_76			* IM 2

ED_5F:						* LD A,R	122(22.5)	5.422	**0I0-
if F_SPER=1
	move.b	A_RND,AC		* 16
	subq.b	#1,AC			*  4
endif
	andi.b	#%0111_1111,AC		*  8

	move	sr,d0			*  6 *+
	andi.w	#%0000_1100,d0		*  8
	andi.w	#%0000_0001,FR		*  8
	or.w	d0,FR			*  4

	tst.b	IFF2-A_BAS(aBS)		* 12
	bne.s	OI_e5F			*  8(10)

	ori.w	#%1000_0000,FR		*  8
	NEXT2				* 40

OI_e5F:	ori.w	#%1000_0010,FR		*  8
	NEXT2				* 40

ED_60:	IN_rh	HL				* IN H,(C)

ED_61:	OUT_rh	HL				* OUT (C),H

ED_62:*						* SBC HL,HL	70(37.5)	1.867	***01*
	move.w	FR,HL			*  4
	andi.w	#%0000_0001,HL		*  8
	beq.s	NC_e62			*  8(10)

	neg.w	HL			*  4
	move.w	#%1111_1001,FR		*  8
	NEXT2				* 40

NC_e62:	move.w	#%1000_0100,FR		*  8
	NEXT2				* 40
				endif
ED_67:						* RRD		158(45)		3.511	**0P0-
	move.b	AC,-(sp)		*  8
	move.w	(sp)+,d1		*  8

	move.w	HL,d0			*  4
	move.b	(aME,d0.l),d1		* 14
	ror.w	#4,d1			* 14
	C_ROM1	d0
	move.b	d1,(aME,d0.l)		* 14

	move.w	d1,(aBS)		*  8
	move.b	(aBS),AC		*  8
	rol.b	#4,AC			* 14

	move	sr,d1			*  6
	andi.w	#%0000_1100,d1		*  8
	andi.w	#%0000_0001,FR		*  8
	or.w	d1,FR			*  4
	NEXT2				* 40
				if F_ROM=0
ED_68:	IN_rl	HL				* IN L,(C)

ED_69:	OUT_rl	HL				* OUT (C),L

ED_6A:	ADC_ss	HL				* ADC HL,HL
				endif
ED_6F:						* RLD		158(45)		3.511	**0P0-
	rol.b	#4,AC			* 14
	move.b	AC,-(sp)		*  8
	move.w	(sp)+,d1		*  8

	move.w	HL,d0			*  4
	move.b	(aME,d0.l),d1		* 14
	rol.w	#4,d1			* 14
	C_ROM1	d0
	move.b	d1,(aME,d0.l)		* 14

	move.w	d1,(aBS)		*  8
	move.b	(aBS),AC		*  8

	move	sr,d1			*  6
	andi.w	#%0000_1100,d1		*  8
	andi.w	#%0000_0001,FR		*  8
	or.w	d1,FR			*  4
	NEXT2				* 40
				if F_ROM=0
ED_72:						* SBC HL,SP	82(37.5)	2.187	***V1*
	move.w	aSP,d0			*  4
	SBC_ss	d0			* 78
				endif
ED_73:						* LD (nn),SP	120(50)		2.4
	R_WORD	d0			* 32
	move.w	aSP,d1			*  4
	C_ROM1	d0
	move.b	d1,0(aME,d0.l)		* 14
	move.w	d1,-(sp)		*  8
	move.b	(sp)+,1(aME,d0.l)	* 18
	NEXT				* 44
				if F_ROM=0
ED_78:	IN_rl	AC				* IN A,(C)

ED_79:	OUT_rl	AC				* OUT (C),A

ED_7A:						* ADC HL,SP	82(37.5)	2.187	***V0*
	move.w	aSP,d0			*  4
	ADC_ss	d0			* 78

ED_7B:						* LD SP,(nn)	120(50)		2.4
	R_WORD	d0			* 32
	move.b	1(aME,d0.l),-(sp)	* 18
	move.w	(sp)+,d1		*  8
	move.b	0(aME,d0.l),d1		* 14
	movea.l	d1,aSP			*  4
	NEXT				* 44
				endif
ED_A0:						* LDI		108(40)		2.7	--0*0-
	move.w	HL,d0			*  4
	move.w	DE,d1			*  4
	C_ROM
	move.b	(a5,d0.l),(aME,d1.l)	* 24

	moveq	#%0000_1101,d1		*  4
	and.w	d1,FR			*  4
	ori.w	#%1000_0010,FR		*  8

	addq.w	#1,HL			*  4
	addq.w	#1,DE			*  4
	subq.w	#1,BC			*  4
	beq.s	OZ_eA0			*  8(10)

	NEXT2				* 40

OZ_eA0:	subq.w	#%0000_0010,FR		*  4
	NEXT2				* 40
				if F_ROM=0
ED_A1:*						* CPI		108(40)		2.7	****1-
	move.w	HL,d0			*  4
	cmp.b	(aME,d0.l),AC		* 14

	move	sr,d1			*  6
	andi.w	#%0000_1100,d1		*  8
	andi.w	#%0000_0001,FR		*  8
	or.w	d1,FR			*  4

	addq.w	#1,HL			*  4
	subq.w	#1,BC			*  4
	beq.s	OZ_eA1			*  8(10)

	ori.w	#%1000_0010,FR		*  8
	NEXT2				* 40

OZ_eA1:	ori.w	#%1000_0000,FR		*  8
	NEXT2				* 40
				endif
*---------------------------------------
*

SF_IOC	macro	ASQ			*:*			* 68			?*??1-
	local	OZ

	moveq	#%0000_1001,d1		*  4
	and.w	d1,FR			*  4

	ASQ.w	#1,HL			*  4
	cmpi.w	#$00FF,BC		*  8
	bls.s	OZ			*  8(10)

	NEXT2				* 40

OZ:	addq.w	#%0000_0100,FR		*  4
	NEXT2				* 40

	endm

*
*---------------------------------------

ED_A2:						* INI		112+(40)	2.8+	?*??1-
	jsr	INP-A_BAS(aBS)		* 18 +
	move.w	HL,d0			*  4
	C_ROM
	move.b	d1,(aME,d0.l)		* 14
	subi.w	#$0100,BC		*  8
	SF_IOC	addq			* 68
				if F_ROM=0
ED_A3:						* OUTI		112+(40)	2.8+	?*??1-
	subi.w	#$0100,BC		*  8
	move.w	HL,d0			*  4
	move.b	(aME,d0.l),d1		* 14
	jsr	OUT-A_BAS(aBS)		* 18 +
	SF_IOC	addq			* 68
				endif
ED_A8:						* LDD		108(40)		2.7	--0*0-
	move.w	HL,d0			*  4
	move.w	DE,d1			*  4
	C_ROM
	move.b	(a5,d0.l),(aME,d1.l)	* 24

	moveq	#%0000_1101,d1		*  4
	and.w	d1,FR			*  4
	ori.w	#%1000_0010,FR		*  8

	subq.w	#1,HL			*  4
	subq.w	#1,DE			*  4
	subq.w	#1,BC			*  4
	beq.s	OZ_eA8			*  8(10)

	NEXT2				* 40

OZ_eA8:	subq.w	#%0000_0010,FR		*  4
	NEXT2				* 40
				if F_ROM=0
ED_A9:*						* CPD		108(40)		2.7	****1-
	move.w	HL,d0			*  4
	cmp.b	(aME,d0.l),AC		* 14

	move	sr,d1			*  6
	andi.w	#%0000_1100,d1		*  8
	andi.w	#%0000_0001,FR		*  8
	or.w	d1,FR			*  4

	subq.w	#1,HL			*  4
	subq.w	#1,BC			*  4
	beq.s	OZ_eA9			*  8(10)

	ori.w	#%1000_0010,FR		*  8
	NEXT2				* 40

OZ_eA9:	ori.w	#%1000_0000,FR		*  8
	NEXT2				* 40
				endif
ED_AA:						* IND		112+(40)	2.8+	?*??1-
	jsr	INP-A_BAS(aBS)		* 18 +
	move.w	HL,d0			*  4
	C_ROM
	move.b	d1,(aME,d0.l)		* 14
	subi.w	#$0100,BC		*  8
	SF_IOC	subq			* 68
				if F_ROM=0
ED_AB:						* OUTD		112+(40)	2.8+	?*??1-
	subi.w	#$0100,BC		*  8
	move.w	HL,d0			*  4
	move.b	(aME,d0.l),d1		* 14
	jsr	OUT-A_BAS(aBS)		* 18 +
	SF_IOC	subq			* 68
				endif
ED_B0:						* LDIR		42(52.5)	0.8	--000-
	subq.w	#1,BC			*  4
	move.w	HL,d0			*  4
	move.w	DE,d1			*  4

LP_eB0:	C_ROM
	move.b	(a5,d0.l),(aME,d1.l)	* 24
	addq.w	#1,d0			*  4
	addq.w	#1,d1			*  4
	dbf	BC,LP_eB0		* 14(10)

	addq.w	#1,BC			*  4
	move.w	d0,HL			*  4
	move.w	d1,DE			*  4

	moveq	#%0000_1101,d1		*  4
	and.w	d1,FR			*  4
	ori.w	#%1000_0000,FR		*  8
	NEXT2				* 40
				if F_ROM=0
ED_B1:*						* CPIR		28(52.5)	0.533	****1-
	subq.w	#1,BC			*  4
	move.w	HL,d0			*  4
	subq.w	#1,d0			*  4

LP_eB1:	addq.w	#1,d0			*  4
	cmp.b	(aME,d0.l),AC		* 14
	dbeq	BC,LP_eB1		* 14(10)

	bne.s	NZ_eB1			*  8(10)

	moveq	#%0000_0001,d1		*  4
	and.w	d1,FR			*  4

	addq.w	#1,d0			*  4
	move.w	d0,HL			*  4
	tst.w	BC			*  4
	beq.s	NV_eB1			*  8(10)

	ori.w	#%1000_0110,FR		*  8
	NEXT2				* 40

NV_eB1:	ori.w	#%1000_0100,FR		*  8
	NEXT2				* 40

NZ_eB1:	move	sr,d1			*  6
	andi.w	#%0000_1000,d1		*  8
	ori.w	#%1000_0000,d1		*  8
	andi.w	#%0000_0001,FR		*  8
	or.w	d1,FR			*  4

	addq.w	#1,BC			*  4
	addq.w	#1,d0			*  4
	move.w	d0,HL			*  4
	NEXT2				* 40
				endif
*---------------------------------------
*

SF_IOR	macro	ASQ,ADR			*:*			* 68			?1??1-

	ASQ.w	#1,HL			*  4
	cmpi.w	#$00FF,BC		*  8
	bhi.s	ADR			*  8(10)

	moveq	#%0000_0100,d1		*  4
	or.w	d1,FR			*  4
	NEXT2				* 40

	endm

*
*---------------------------------------

ED_B2:						* INIR		66+(52.5)	1.257+	?1??1-
	jsr	INP-A_BAS(aBS)		* 18 +
	move.w	HL,d0			*  4
	C_ROM
	move.b	d1,(aME,d0.l)		* 14
	subi.w	#$0100,BC		*  8
	SF_IOR	addq,ED_B2		* 68
				if F_ROM=0
ED_B3:						* OTIR		66+(52.5)	1.257+	?1??1-
	subi.w	#$0100,BC		*  8
	move.w	HL,d0			*  4
	move.b	(aME,d0.l),d1		* 14
	jsr	OUT-A_BAS(aBS)		* 18 +
	SF_IOR	addq,ED_B3		* 68
				endif
ED_B8:						* LDDR		42(52.5)	0.8	--000-
	subq.w	#1,BC			*  4
	move.w	HL,d0			*  4
	move.w	DE,d1			*  4

LP_eB8:	C_ROM
	move.b	(a5,d0.l),(aME,d1.l)	* 24
	subq.w	#1,d0			*  4
	subq.w	#1,d1			*  4
	dbf	BC,LP_eB8		* 14(10)

	addq.w	#1,BC			*  4
	move.w	d0,HL			*  4
	move.w	d1,DE			*  4

	moveq	#%0000_1101,d1		*  4
	and.w	d1,FR			*  4
	ori.w	#%1000_0000,FR		*  8
	NEXT2				* 40
				if F_ROM=0
ED_B9:*						* CPDR		28(52.5)	0.533	****1-
	subq.w	#1,BC			*  4
	move.w	HL,d0			*  4
	addq.w	#1,d0			*  4

LP_eB9:	subq.w	#1,d0			*  4
	cmp.b	(aME,d0.l),AC		* 14
	dbeq	BC,LP_eB9		* 14(10)

	bne.s	NZ_eB9			*  8(10)

	moveq	#%0000_0001,d1		*  4
	and.w	d1,FR			*  4

	subq.w	#1,d0			*  4
	move.w	d0,HL			*  4
	tst.w	BC			*  4
	beq.s	NV_eB9			*  8(10)

	ori.w	#%1000_0110,FR		*  8
	NEXT2				* 40

NV_eB9:	ori.w	#%1000_0100,FR		*  8
	NEXT2				* 40

NZ_eB9:	move	sr,d1			*  6
	andi.w	#%0000_1000,d1		*  8
	ori.w	#%1000_0000,d1		*  8
	andi.w	#%0000_0001,FR		*  8
	or.w	d1,FR			*  4

	addq.w	#1,BC			*  4
	subq.w	#1,d0			*  4
	move.w	d0,HL			*  4
	NEXT2				* 40
				endif
ED_BA:						* INDR		66+(52.5)	1.257+	?1??1-
	jsr	INP-A_BAS(aBS)		* 18 +
	move.w	HL,d0			*  4
	C_ROM
	move.b	d1,(aME,d0.l)		* 14
	subi.w	#$0100,BC		*  8
	SF_IOR	subq,ED_BA		* 68
				if F_ROM=0
ED_BB:						* OTDR		66+(52.5)	1.257+	?1??1-
	subi.w	#$0100,BC		*  8
	move.w	HL,d0			*  4
	move.b	(aME,d0.l),d1		* 14
	jsr	OUT-A_BAS(aBS)		* 18 +
	SF_IOR	subq,ED_BB		* 68

ED_ED:
	cmpa.l	#(A_MEM+$10000+1),aPC	* 14
	bcs.s	SKeED1			*  8(10)

	suba.l	#$10000+2,aPC		* 14
	NEXT				* 44

SKeED1:	cmpa.l	aME,aPC			*  6
	bhi.s	SKeED2			*  8(10)

	adda.l	#$10000-2,aPC		* 14
SKeED2:	NEXT				* 44
				endif

*---------------------------------------*
*	   Reg.IX  DD xx (+52)		*
*---------------------------------------*

HL	set	XY
F_IXY	set	1
F_XYCB	set	0
				if F_ROM=0
DD_09:	M_09	BC				* ADD IX,BC
DD_19:	M_09	DE				* ADD IX,DE
DD_21:	M_01	HL				* LD IX,nn
DD_23:	M_03	HL				* INC IX
DD_24:	M_04	HL				* INC IXH
DD_25:	M_05	HL				* DEC IXH
DD_26:	M_06	HL				* LD IXH,n
DD_29:	M_09	HL				* ADD IX,IX
DD_2A:	LD_ssnn	HL				* LD IX,(nn)
DD_2B:	M_0B	HL				* DEC IX
DD_2C:	M_0C	HL				* INC IXL
DD_2D:	M_0D	HL				* DEC IXL
DD_2E:	M_0E	HL				* LD IXL,n
DD_39:	M_09	aSP				* ADD IX,SP
DD_44:	LD_hh	BC,HL				* LD B,IXH
DD_45:	LD_hl	BC,HL				* LD B,IXL
DD_46:	LD_hHL	BC				* LD B,(IX+d)
DD_4C:	LD_lh	BC,HL				* LD C,IXH
DD_4D:	LD_ll	BC,HL				* LD C,IXL
DD_4E:	LD_lHL	BC				* LD C,(IX+d)
DD_54:	LD_hh	DE,HL				* LD D,IXH
DD_55:	LD_hl	DE,HL				* LD D,IXL
DD_56:	LD_hHL	DE				* LD D,(IX+d)
DD_5C:	LD_lh	DE,HL				* LD E,IXH
DD_5D:	LD_ll	DE,HL				* LD E,IXL
DD_5E:	LD_lHL	DE				* LD E,(IX+d)
DD_64:	LD_hh	d7,HL				* LD H,IXH
DD_65:	LD_hl	d7,HL				* LD H,IXL
DD_66:	LD_hHL	d7				* LD H,(IX+d)
DD_6C:	LD_lh	d7,HL				* LD L,IXH
DD_6D:	LD_ll	d7,HL				* LD L,IXL
DD_6E:	LD_lHL	d7				* LD L,(IX+d)
DD_7C:	LD_lh	AC,HL				* LD A,IXH
DD_7D:	LD_ll	AC,HL				* LD A,IXL
DD_7E:	LD_lHL	AC				* LD A,(IX+d)
DD_84:	ADD_h	HL				* ADD A,IXH
DD_85:	ADD_l	HL				* ADD A,IXL
DD_86:	M_86					* ADD A,(IX+d)
DD_8C:	ADC_h	HL				* ADC A,IXH
DD_8D:	ADC_l	HL				* ADC A,IXL
DD_8E:						* ADC A,(IX+d)
	R_HL	d1
	ADC_l	d1

DD_94:	SUB_h	HL				* SUB IXH
DD_95:	SUB_l	HL				* SUB IXL
DD_96:	M_96					* SUB (IX+d)
DD_9C:	SBC_h	HL				* SBC A,IXH
DD_9D:	SBC_l	HL				* SBC A,IXL
DD_9E:						* SBC A,(IX+d)
	R_HL	d1
	SBC_l	d1

DD_A4:	AND_h	HL				* AND IXH
DD_A5:	AND_l	HL				* AND IXL
DD_A6:	M_A6					* AND (IX+d)
DD_AC:	XOR_h	HL				* XOR IXH
DD_AD:	XOR_l	HL				* XOR IXL
DD_AE:						* XOR (IX+d)
	R_HL	d1
	XOR_l	d1

DD_B4:	OR_h	HL				* OR IXH
DD_B5:	OR_l	HL				* OR IXL
DD_B6:	M_B6					* OR (IX+d)
DD_BC:	CP_h	HL				* CP IXH
DD_BD:	CP_l	HL				* CP IXL
DD_BE:	M_BE					* CP (IX+d)
DD_CB:						* $DD CB	60
	move.b	(aPC)+,d0		*  8
	M_JOP2	T_DDc			* 52
DD_E1:						* POP IX
	POP	HL
	NEXT

DD_E9:	M_E9					* JP (IX)
DD_F9:	M_F9					* LD SP,IX
				endif

DD_22:	LD_nnss	HL				* LD (nn),IX
DD_34:	M_34					* INC (IX+d)
DD_35:	M_35					* DEC (IX+d)
DD_36:	M_36					* LD (IX+d),n
DD_70:	LD_HLh	BC				* LD (IX+d),B
DD_71:	LD_HLl	BC				* LD (IX+d),C
DD_72:	LD_HLh	DE				* LD (IX+d),D
DD_73:	LD_HLl	DE				* LD (IX+d),E
DD_74:	LD_HLh	d7				* LD (IX+d),H
DD_75:	LD_HLl	d7				* LD (IX+d),L
DD_77:	LD_HLl	AC				* LD (IX+d),A
DD_E3:	M_E3					* EX (SP),IX
DD_E5:						* PUSH IX
	PUSH	HL
	NEXT


*---------------------------------------*
*	Reg.IX  DD CB d xx (+112)	*
*---------------------------------------*

F_XYCB	set	1
				if F_ROM=0
DDc04:	RLC_h	HL				* RLC IXH
DDc05:	RLC_l	HL				* RLC IXL
DDc0C:	RRC_h	HL				* RRC IXH
DDc0D:	RRC_l	HL				* RRC IXL
DDc14:	RL_h	HL				* RL IXH
DDc15:	RL_l	HL				* RL IXL
DDc1C:	RR_h	HL				* RR IXH
DDc1D:	RR_l	HL				* RR IXL
DDc24:	SLA_h	HL				* SLA IXH
DDc25:	SLA_l	HL				* SLA IXL
DDc2C:	SRA_h	HL				* SRA IXH
DDc2D:	SRA_l	HL				* SRA IXL
DDc3C:	SRL_h	HL				* SRL IXH
DDc3D:	SRL_l	HL				* SRL IXL
DDc44:	BIT_h	0,HL				* BIT 0,IXH
DDc45:	BIT_l	0,HL				* BIT 0,IXL
DDc46:	BIT_HL	0				* BIT 0,(IX+d)
DDc4C:	BIT_h	1,HL				* BIT 1,IXH
DDc4D:	BIT_l	1,HL				* BIT 1,IXL
DDc4E:	BIT_HL	1				* BIT 1,(IX+d)
DDc54:	BIT_h	2,HL				* BIT 2,IXH
DDc55:	BIT_l	2,HL				* BIT 2,IXL
DDc56:	BIT_HL	2				* BIT 2,(IX+d)
DDc5C:	BIT_h	3,HL				* BIT 3,IXH
DDc5D:	BIT_l	3,HL				* BIT 3,IXL
DDc5E:	BIT_HL	3				* BIT 3,(IX+d)
DDc64:	BIT_h	4,HL				* BIT 4,IXH
DDc65:	BIT_l	4,HL				* BIT 4,IXL
DDc66:	BIT_HL	4				* BIT 4,(IX+d)
DDc6C:	BIT_h	5,HL				* BIT 5,IXH
DDc6D:	BIT_l	5,HL				* BIT 5,IXL
DDc6E:	BIT_HL	5				* BIT 5,(IX+d)
DDc74:	BIT_h	6,HL				* BIT 6,IXH
DDc75:	BIT_l	6,HL				* BIT 6,IXL
DDc76:	BIT_HL	6				* BIT 6,(IX+d)
DDc7C:	BIT_h	7,HL				* BIT 7,IXH
DDc7D:	BIT_l	7,HL				* BIT 7,IXL
DDc7E:	BIT_HL	7				* BIT 7,(IX+d)
DDc84:	RES_h	0,HL				* RES 0,IXH
DDc85:	RES_l	0,HL				* RES 0,IXL
DDc8C:	RES_h	1,HL				* RES 1,IXH
DDc8D:	RES_l	1,HL				* RES 1,IXL
DDc94:	RES_h	2,HL				* RES 2,IXH
DDc95:	RES_l	2,HL				* RES 2,IXL
DDc9C:	RES_h	3,HL				* RES 3,IXH
DDc9D:	RES_l	3,HL				* RES 3,IXL
DDcA4:	RES_h	4,HL				* RES 4,IXH
DDcA5:	RES_l	4,HL				* RES 4,IXL
DDcAC:	RES_h	5,HL				* RES 5,IXH
DDcAD:	RES_l	5,HL				* RES 5,IXL
DDcB4:	RES_h	6,HL				* RES 6,IXH
DDcB5:	RES_l	6,HL				* RES 6,IXL
DDcBC:	RES_h	7,HL				* RES 7,IXH
DDcBD:	RES_l	7,HL				* RES 7,IXL
DDcC4:	SET_h	0,HL				* SET 0,IXH
DDcC5:	SET_l	0,HL				* SET 0,IXL
DDcCC:	SET_h	1,HL				* SET 1,IXH
DDcCD:	SET_l	1,HL				* SET 1,IXL
DDcD4:	SET_h	2,HL				* SET 2,IXH
DDcD5:	SET_l	2,HL				* SET 2,IXL
DDcDC:	SET_h	3,HL				* SET 3,IXH
DDcDD:	SET_l	3,HL				* SET 3,IXL
DDcE4:	SET_h	4,HL				* SET 4,IXH
DDcE5:	SET_l	4,HL				* SET 4,IXL
DDcEC:	SET_h	5,HL				* SET 5,IXH
DDcED:	SET_l	5,HL				* SET 5,IXL
DDcF4:	SET_h	6,HL				* SET 6,IXH
DDcF5:	SET_l	6,HL				* SET 6,IXL
DDcFC:	SET_h	7,HL				* SET 7,IXH
DDcFD:	SET_l	7,HL				* SET 7,IXL
				endif

DDc06:						* RLC (IX+d)
	R_HL	d1
	rol.b	#1,d1
	SF_RHL
DDc0E:						* RRC (IX+d)
	R_HL	d1
	ror.b	#1,d1
	SF_RHL
DDc16:						* RL (IX+d)
	R_HL	d1
	lsr.b	#1,FR
	roxl.b	#1,d1
	SF_RHL
DDc1E:						* RR (IX+d)
	R_HL	d1
	lsr.b	#1,FR
	roxr.b	#1,d1
	SF_RHL
DDc26:						* SLA (IX+d)
	R_HL	d1
	add.b	d1,d1
	SF_RHL
DDc2E:						* SRA (IX+d)
	R_HL	d1
	asr.b	#1,d1
	SF_RHL
DDc3E:						* SRL (IX+d)
	R_HL	d1
	lsr.b	#1,d1
	SF_RHL

DDc86:	RES_HL	0				* RES 0,(IX+d)
DDc8E:	RES_HL	1				* RES 1,(IX+d)
DDc96:	RES_HL	2				* RES 2,(IX+d)
DDc9E:	RES_HL	3				* RES 3,(IX+d)
DDcA6:	RES_HL	4				* RES 4,(IX+d)
DDcAE:	RES_HL	5				* RES 5,(IX+d)
DDcB6:	RES_HL	6				* RES 6,(IX+d)
DDcBE:	RES_HL	7				* RES 7,(IX+d)
DDcC6:	SET_HL	0				* SET 0,(IX+d)
DDcCE:	SET_HL	1				* SET 1,(IX+d)
DDcD6:	SET_HL	2				* SET 2,(IX+d)
DDcDE:	SET_HL	3				* SET 3,(IX+d)
DDcE6:	SET_HL	4				* SET 4,(IX+d)
DDcEE:	SET_HL	5				* SET 5,(IX+d)
DDcF6:	SET_HL	6				* SET 6,(IX+d)
DDcFE:	SET_HL	7				* SET 7,(IX+d)


*---------------------------------------*
*	   Reg.IY  FD xx (+60)		*
*---------------------------------------*

HL	set	XY
F_IXY	set	2
F_XYCB	set	0
				if F_ROM=0
FD_09:	M_09	BC				* ADD IY,BC
FD_19:	M_09	DE				* ADD IY,DE
FD_21:	M_01	HL				* LD IY,nn
FD_23:	M_03	HL				* INC IY
FD_24:	M_04	HL				* INC IYH
FD_25:	M_05	HL				* DEC IYH
FD_26:	M_06	HL				* LD IYH,n
FD_29:	M_09	HL				* ADD IY,IY
FD_2A:	LD_ssnn	HL				* LD IY,(nn)
FD_2B:	M_0B	HL				* DEC IY
FD_2C:	M_0C	HL				* INC IYL
FD_2D:	M_0D	HL				* DEC IYL
FD_2E:	M_0E	HL				* LD IYL,n
FD_39:	M_09	aSP				* ADD IY,SP
FD_44:	LD_hh	BC,HL				* LD B,IYH
FD_45:	LD_hl	BC,HL				* LD B,IYL
FD_46:	LD_hHL	BC				* LD B,(IY+d)
FD_4C:	LD_lh	BC,HL				* LD C,IYH
FD_4D:	LD_ll	BC,HL				* LD C,IYL
FD_4E:	LD_lHL	BC				* LD C,(IY+d)
FD_54:	LD_hh	DE,HL				* LD D,IYH
FD_55:	LD_hl	DE,HL				* LD D,IYL
FD_56:	LD_hHL	DE				* LD D,(IY+d)
FD_5C:	LD_lh	DE,HL				* LD E,IYH
FD_5D:	LD_ll	DE,HL				* LD E,IYL
FD_5E:	LD_lHL	DE				* LD E,(IY+d)
FD_64:	LD_hh	d7,HL				* LD H,IYH
FD_65:	LD_hl	d7,HL				* LD H,IYL
FD_66:	LD_hHL	d7				* LD H,(IY+d)
FD_6C:	LD_lh	d7,HL				* LD L,IYH
FD_6D:	LD_ll	d7,HL				* LD L,IYL
FD_6E:	LD_lHL	d7				* LD L,(IY+d)
FD_7C:	LD_lh	AC,HL				* LD A,IYH
FD_7D:	LD_ll	AC,HL				* LD A,IYL
FD_7E:	LD_lHL	AC				* LD A,(IY+d)
FD_84:	ADD_h	HL				* ADD A,IYH
FD_85:	ADD_l	HL				* ADD A,IYL
FD_86:	M_86					* ADD A,(IY+d)
FD_8C:	ADC_h	HL				* ADC A,IYH
FD_8D:	ADC_l	HL				* ADC A,IYL
FD_8E:						* ADC A,(IY+d)
	R_HL	d1
	ADC_l	d1

FD_94:	SUB_h	HL				* SUB IYH
FD_95:	SUB_l	HL				* SUB IYL
FD_96:	M_96					* SUB (IY+d)
FD_9C:	SBC_h	HL				* SBC A,IYH
FD_9D:	SBC_l	HL				* SBC A,IYL
FD_9E:						* SBC A,(IY+d)
	R_HL	d1
	SBC_l	d1

FD_A4:	AND_h	HL				* AND IYH
FD_A5:	AND_l	HL				* AND IYL
FD_A6:	M_A6					* AND (IY+d)
FD_AC:	XOR_h	HL				* XOR IYH
FD_AD:	XOR_l	HL				* XOR IYL
FD_AE:						* XOR (IY+d)
	R_HL	d1
	XOR_l	d1

FD_B4:	OR_h	HL				* OR IYH
FD_B5:	OR_l	HL				* OR IYL
FD_B6:	M_B6					* OR (IY+d)
FD_BC:	CP_h	HL				* CP IYH
FD_BD:	CP_l	HL				* CP IYL
FD_BE:	M_BE					* CP (IY+d)
FD_CB:						* $FD CB	60
	move.b	(aPC)+,d0		*  8
	M_JOP2	T_FDc			* 52
FD_E1:						* POP IY
	POP	HL
	NEXT

FD_E9:	M_E9					* JP (IY)
FD_F9:	M_F9					* LD SP,IY
				endif

FD_22:	LD_nnss	HL				* LD (nn),IY
FD_34:	M_34					* INC (IY+d)
FD_35:	M_35					* DEC (IY+d)
FD_36:	M_36					* LD (IY+d),n
FD_70:	LD_HLh	BC				* LD (IY+d),B
FD_71:	LD_HLl	BC				* LD (IY+d),C
FD_72:	LD_HLh	DE				* LD (IY+d),D
FD_73:	LD_HLl	DE				* LD (IY+d),E
FD_74:	LD_HLh	d7				* LD (IY+d),H
FD_75:	LD_HLl	d7				* LD (IY+d),L
FD_77:	LD_HLl	AC				* LD (IY+d),A
FD_E3:	M_E3					* EX (SP),IY
FD_E5:						* PUSH IY
	PUSH	HL
	NEXT


*---------------------------------------*
*	Reg.IY  FD CB d xx (+120)	*
*---------------------------------------*

F_XYCB	set	1
				if F_ROM=0
FDc04:	RLC_h	HL				* RLC IYH
FDc05:	RLC_l	HL				* RLC IYL
FDc0C:	RRC_h	HL				* RRC IYH
FDc0D:	RRC_l	HL				* RRC IYL
FDc14:	RL_h	HL				* RL IYH
FDc15:	RL_l	HL				* RL IYL
FDc1C:	RR_h	HL				* RR IYH
FDc1D:	RR_l	HL				* RR IYL
FDc24:	SLA_h	HL				* SLA IYH
FDc25:	SLA_l	HL				* SLA IYL
FDc2C:	SRA_h	HL				* SRA IYH
FDc2D:	SRA_l	HL				* SRA IYL
FDc3C:	SRL_h	HL				* SRL IYH
FDc3D:	SRL_l	HL				* SRL IYL
FDc44:	BIT_h	0,HL				* BIT 0,IYH
FDc45:	BIT_l	0,HL				* BIT 0,IYL
FDc46:	BIT_HL	0				* BIT 0,(IY+d)
FDc4C:	BIT_h	1,HL				* BIT 1,IYH
FDc4D:	BIT_l	1,HL				* BIT 1,IYL
FDc4E:	BIT_HL	1				* BIT 1,(IY+d)
FDc54:	BIT_h	2,HL				* BIT 2,IYH
FDc55:	BIT_l	2,HL				* BIT 2,IYL
FDc56:	BIT_HL	2				* BIT 2,(IY+d)
FDc5C:	BIT_h	3,HL				* BIT 3,IYH
FDc5D:	BIT_l	3,HL				* BIT 3,IYL
FDc5E:	BIT_HL	3				* BIT 3,(IY+d)
FDc64:	BIT_h	4,HL				* BIT 4,IYH
FDc65:	BIT_l	4,HL				* BIT 4,IYL
FDc66:	BIT_HL	4				* BIT 4,(IY+d)
FDc6C:	BIT_h	5,HL				* BIT 5,IYH
FDc6D:	BIT_l	5,HL				* BIT 5,IYL
FDc6E:	BIT_HL	5				* BIT 5,(IY+d)
FDc74:	BIT_h	6,HL				* BIT 6,IYH
FDc75:	BIT_l	6,HL				* BIT 6,IYL
FDc76:	BIT_HL	6				* BIT 6,(IY+d)
FDc7C:	BIT_h	7,HL				* BIT 7,IYH
FDc7D:	BIT_l	7,HL				* BIT 7,IYL
FDc7E:	BIT_HL	7				* BIT 7,(IY+d)
FDc84:	RES_h	0,HL				* RES 0,IYH
FDc85:	RES_l	0,HL				* RES 0,IYL
FDc8C:	RES_h	1,HL				* RES 1,IYH
FDc8D:	RES_l	1,HL				* RES 1,IYL
FDc94:	RES_h	2,HL				* RES 2,IYH
FDc95:	RES_l	2,HL				* RES 2,IYL
FDc9C:	RES_h	3,HL				* RES 3,IYH
FDc9D:	RES_l	3,HL				* RES 3,IYL
FDcA4:	RES_h	4,HL				* RES 4,IYH
FDcA5:	RES_l	4,HL				* RES 4,IYL
FDcAC:	RES_h	5,HL				* RES 5,IYH
FDcAD:	RES_l	5,HL				* RES 5,IYL
FDcB4:	RES_h	6,HL				* RES 6,IYH
FDcB5:	RES_l	6,HL				* RES 6,IYL
FDcBC:	RES_h	7,HL				* RES 7,IYH
FDcBD:	RES_l	7,HL				* RES 7,IYL
FDcC4:	SET_h	0,HL				* SET 0,IYH
FDcC5:	SET_l	0,HL				* SET 0,IYL
FDcCC:	SET_h	1,HL				* SET 1,IYH
FDcCD:	SET_l	1,HL				* SET 1,IYL
FDcD4:	SET_h	2,HL				* SET 2,IYH
FDcD5:	SET_l	2,HL				* SET 2,IYL
FDcDC:	SET_h	3,HL				* SET 3,IYH
FDcDD:	SET_l	3,HL				* SET 3,IYL
FDcE4:	SET_h	4,HL				* SET 4,IYH
FDcE5:	SET_l	4,HL				* SET 4,IYL
FDcEC:	SET_h	5,HL				* SET 5,IYH
FDcED:	SET_l	5,HL				* SET 5,IYL
FDcF4:	SET_h	6,HL				* SET 6,IYH
FDcF5:	SET_l	6,HL				* SET 6,IYL
FDcFC:	SET_h	7,HL				* SET 7,IYH
FDcFD:	SET_l	7,HL				* SET 7,IYL
				endif

FDc06:						* RLC (IY+d)
	R_HL	d1
	rol.b	#1,d1
	SF_RHL
FDc0E:						* RRC (IY+d)
	R_HL	d1
	ror.b	#1,d1
	SF_RHL
FDc16:						* RL (IY+d)
	R_HL	d1
	lsr.b	#1,FR
	roxl.b	#1,d1
	SF_RHL
FDc1E:						* RR (IY+d)
	R_HL	d1
	lsr.b	#1,FR
	roxr.b	#1,d1
	SF_RHL
FDc26:						* SLA (IY+d)
	R_HL	d1
	add.b	d1,d1
	SF_RHL
FDc2E:						* SRA (IY+d)
	R_HL	d1
	asr.b	#1,d1
	SF_RHL
FDc3E:						* SRL (IY+d)
	R_HL	d1
	lsr.b	#1,d1
	SF_RHL

FDc86:	RES_HL	0				* RES 0,(IY+d)
FDc8E:	RES_HL	1				* RES 1,(IY+d)
FDc96:	RES_HL	2				* RES 2,(IY+d)
FDc9E:	RES_HL	3				* RES 3,(IY+d)
FDcA6:	RES_HL	4				* RES 4,(IY+d)
FDcAE:	RES_HL	5				* RES 5,(IY+d)
FDcB6:	RES_HL	6				* RES 6,(IY+d)
FDcBE:	RES_HL	7				* RES 7,(IY+d)
FDcC6:	SET_HL	0				* SET 0,(IY+d)
FDcCE:	SET_HL	1				* SET 1,(IY+d)
FDcD6:	SET_HL	2				* SET 2,(IY+d)
FDcDE:	SET_HL	3				* SET 3,(IY+d)
FDcE6:	SET_HL	4				* SET 4,(IY+d)
FDcEE:	SET_HL	5				* SET 5,(IY+d)
FDcF6:	SET_HL	6				* SET 6,(IY+d)
FDcFE:	SET_HL	7				* SET 7,(IY+d)


*---------------------------------------*
*		 next EI		*
*---------------------------------------*

HL	set	d7
F_IXY	set	0
F_XYCB	set	0
				if F_ROM=0
NEI:
	lea	T_OPC-A_BAS(aBS),aTO	*  8
	jsr	INTRQ-A_BAS(aBS)	* 18
	move.w	(aTO,d1.w),d0		* 14
	move.w	#$FFFF,IFF1-A_BAS(aBS)	* 16
	jmp	(aBS,d0.w)		* 14

 
*---------------------------------------*
*     NMI (Non Maskable Interrupt)	*
*---------------------------------------*

F_ROM	set	1

NMI:
	SBQA	#1,aPC			*  4
NMI_76:	suba.l	aME,aPC			*  8
	move.w	aPC,d0			*  4
	PUSH	d0			* 52+
	lea	$0066(aME),aPC		*  8

	moveq	#0,d1			*  4
	move.b	d1,IFF1-A_BAS(aBS)	* 12
	lea	T_OPC-A_BAS(aBS),aTO	*  8
	NEXT2				* 40

F_ROM	set	0


*---------------------------------------*
*	   Interrupt Mode 0-2		*
*---------------------------------------*

IM0:*
	SBQA	#1,aPC			*  4
IM0_76:	moveq	#0,d1			*  4
	move.w	d1,IFF1-A_BAS(aBS)	* 12
	lea	T_OPC-A_BAS(aBS),aTO	*  8

	move.b	V_INT-A_BAS(aBS),d1	* 12
	add.w	d1,d1			*  4
	move.w	(aTO,d1.w),d0		* 14
	jmp	(aBS,d0.w)		* 14


IM1:
	SBQA	#1,aPC			*  4
IM1_76:	suba.l	aME,aPC			*  8
	move.w	aPC,d0			*  4
	PUSH	d0			* 52
	lea	$0038(aME),aPC		*  8

	moveq	#0,d1			*  4
	move.w	d1,IFF1-A_BAS(aBS)	* 12
	lea	T_OPC-A_BAS(aBS),aTO	*  8
	NEXT2				* 40


IM2:
	SBQA	#1,aPC			*  4
IM2_76:	suba.l	aME,aPC			*  8
	move.w	aPC,d0			*  4
	PUSH	d0			* 52

	move.w	AC,d0			*  4
	move.b	V_INT-A_BAS(aBS),d0	* 12

	move.b	1(aME,d0.l),-(sp)	* 18
	move.w	(sp)+,d1		*  8
	move.b	0(aME,d0.l),d1		* 14
	lea	(aME,d1.l),aPC		* 12

	moveq	#0,d1			*  4
	move.w	d1,IFF1-A_BAS(aBS)	* 12
	lea	T_OPC-A_BAS(aBS),aTO	*  8
	NEXT2				* 40


*---------------------------------------*
*	   illegal instruction		*
*---------------------------------------*

A_NX:	moveq	#0,d1			*  4
A_NX2:	move.b	(aPC)+,d1		*  8
	add.w	d1,d1			*  4
	move.w	(aTO,d1.w),d0		* 14
	jmp	(aBS,d0.w)		* 14

A_NXy:	moveq	#0,d1			*  4
A_NX2y:	swap	XY			*  4
	move.b	(aPC)+,d1		*  8
	add.w	d1,d1			*  4
	move.w	(aTO,d1.w),d0		* 14
	jmp	(aBS,d0.w)		* 14


NEXTA	equ	.loww.(A_NX-A_BAS).w
NEXT2A	equ	.loww.(A_NX2-A_BAS).w
NEXTAy	equ	.loww.(A_NXy-A_BAS).w
NEXT2Ay	equ	.loww.(A_NX2y-A_BAS).w


*---------------------------------------*
*	  base address & tables		*
*---------------------------------------*

A_BAS:	ds.w	1

IFF1:	ds.b	1
IFF2:	ds.b	1

V_INT:	ds.b	1
	.even

T_PF:	dc.b	$82,$80,$80,$82,$80,$82,$82,$80,$80,$82,$82,$80,$82,$80,$80,$82
	dc.b	$80,$82,$82,$80,$82,$80,$80,$82,$82,$80,$80,$82,$80,$82,$82,$80
	dc.b	$80,$82,$82,$80,$82,$80,$80,$82,$82,$80,$80,$82,$80,$82,$82,$80
	dc.b	$82,$80,$80,$82,$80,$82,$82,$80,$80,$82,$82,$80,$82,$80,$80,$82
	dc.b	$80,$82,$82,$80,$82,$80,$80,$82,$82,$80,$80,$82,$80,$82,$82,$80
	dc.b	$82,$80,$80,$82,$80,$82,$82,$80,$80,$82,$82,$80,$82,$80,$80,$82
	dc.b	$82,$80,$80,$82,$80,$82,$82,$80,$80,$82,$82,$80,$82,$80,$80,$82
	dc.b	$80,$82,$82,$80,$82,$80,$80,$82,$82,$80,$80,$82,$80,$82,$82,$80
	dc.b	$80,$82,$82,$80,$82,$80,$80,$82,$82,$80,$80,$82,$80,$82,$82,$80
	dc.b	$82,$80,$80,$82,$80,$82,$82,$80,$80,$82,$82,$80,$82,$80,$80,$82
	dc.b	$82,$80,$80,$82,$80,$82,$82,$80,$80,$82,$82,$80,$82,$80,$80,$82
	dc.b	$80,$82,$82,$80,$82,$80,$80,$82,$82,$80,$80,$82,$80,$82,$82,$80
	dc.b	$82,$80,$80,$82,$80,$82,$82,$80,$80,$82,$82,$80,$82,$80,$80,$82
	dc.b	$80,$82,$82,$80,$82,$80,$80,$82,$82,$80,$80,$82,$80,$82,$82,$80
	dc.b	$80,$82,$82,$80,$82,$80,$80,$82,$82,$80,$80,$82,$80,$82,$82,$80
	dc.b	$82,$80,$80,$82,$80,$82,$82,$80,$80,$82,$82,$80,$82,$80,$80,$82


T_DA:		* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$06,$06,$06,$06,$06,$06	* 00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$06,$06,$06,$06,$06,$06	* 10
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$06,$06,$06,$06,$06,$06	* 20
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$06,$06,$06,$06,$06,$06	* 30
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$06,$06,$06,$06,$06,$06	* 40
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$06,$06,$06,$06,$06,$06	* 50
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$06,$06,$06,$06,$06,$06	* 60
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$06,$06,$06,$06,$06,$06	* 70
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$06,$06,$06,$06,$06,$06	* 80
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$66,$66,$66,$66,$66,$66	* 90
	dc.b	$60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$66,$66,$66,$66,$66,$66	* A0
	dc.b	$60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$66,$66,$66,$66,$66,$66	* B0
	dc.b	$60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$66,$66,$66,$66,$66,$66	* C0
	dc.b	$60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$66,$66,$66,$66,$66,$66	* D0
	dc.b	$60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$66,$66,$66,$66,$66,$66	* E0
	dc.b	$60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$66,$66,$66,$66,$66,$66	* F0
				endif

*---------------------------------------*
*	jump table  OP CODE (xx)	*
*---------------------------------------*

	.data
				if F_ROM=0
T_OPC:
	dc.w	z00-A_BAS	* 00		NOP
	dc.w	z01-A_BAS	* 01		LD	BC,nn
	dc.w	z02-A_BAS	* 02		LD	(BC),A
	dc.w	z03-A_BAS	* 03		INC	BC
	dc.w	z04-A_BAS	* 04		INC	B
	dc.w	z05-A_BAS	* 05		DEC	B
	dc.w	z06-A_BAS	* 06		LD	B,n
	dc.w	z07-A_BAS	* 07		RLCA
	dc.w	z08-A_BAS	* 08		EX	AF,AF'
	dc.w	z09-A_BAS	* 09		ADD	HL,BC
	dc.w	z0A-A_BAS	* 0A		LD	A,(BC)
	dc.w	z0B-A_BAS	* 0B		DEC	BC
	dc.w	z0C-A_BAS	* 0C		INC	C
	dc.w	z0D-A_BAS	* 0D		DEC	C
	dc.w	z0E-A_BAS	* 0E		LD	C,n
	dc.w	z0F-A_BAS	* 0F		RRCA

	dc.w	z10-A_BAS	* 10		DJNZ	e
	dc.w	z11-A_BAS	* 11		LD	DE,nn
	dc.w	z12-A_BAS	* 12		LD	(DE),A
	dc.w	z13-A_BAS	* 13		INC	DE
	dc.w	z14-A_BAS	* 14		INC	D
	dc.w	z15-A_BAS	* 15		DEC	D
	dc.w	z16-A_BAS	* 16		LD	D,n
	dc.w	z17-A_BAS	* 17		RLA
	dc.w	z18-A_BAS	* 18		JR	e
	dc.w	z19-A_BAS	* 19		ADD	HL,DE
	dc.w	z1A-A_BAS	* 1A		LD	A,(DE)
	dc.w	z1B-A_BAS	* 1B		DEC	DE
	dc.w	z1C-A_BAS	* 1C		INC	E
	dc.w	z1D-A_BAS	* 1D		DEC	E
	dc.w	z1E-A_BAS	* 1E		LD	E,n
	dc.w	z1F-A_BAS	* 1F		RRA

	dc.w	z20-A_BAS	* 20		JR	NZ,e
	dc.w	z21-A_BAS	* 21		LD	HL,nn
	dc.w	z22-A_BAS	* 22		LD	(nn),HL
	dc.w	z23-A_BAS	* 23		INC	HL
	dc.w	z24-A_BAS	* 24		INC	H
	dc.w	z25-A_BAS	* 25		DEC	H
	dc.w	z26-A_BAS	* 26		LD	H,n
	dc.w	z27-A_BAS	* 27		DAA
	dc.w	z28-A_BAS	* 28		JR	Z,e
	dc.w	z29-A_BAS	* 29		ADD	HL,HL
	dc.w	z2A-A_BAS	* 2A		LD	HL,(nn)
	dc.w	z2B-A_BAS	* 2B		DEC	HL
	dc.w	z2C-A_BAS	* 2C		INC	L
	dc.w	z2D-A_BAS	* 2D		DEC	L
	dc.w	z2E-A_BAS	* 2E		LD	L,n
	dc.w	z2F-A_BAS	* 2F		CPL

	dc.w	z30-A_BAS	* 30		JR	NC,e
	dc.w	z31-A_BAS	* 31		LD	SP,nn
	dc.w	z32-A_BAS	* 32		LD	(nn),A
	dc.w	z33-A_BAS	* 33		INC	SP
	dc.w	z34-A_BAS	* 34		INC	(HL)
	dc.w	z35-A_BAS	* 35		DEC	(HL)
	dc.w	z36-A_BAS	* 36		LD	(HL),n
	dc.w	z37-A_BAS	* 37		SCF
	dc.w	z38-A_BAS	* 38		JR	C,e
	dc.w	z39-A_BAS	* 39		ADD	HL,SP
	dc.w	z3A-A_BAS	* 3A		LD	A,(nn)
	dc.w	z3B-A_BAS	* 3B		DEC	SP
	dc.w	z3C-A_BAS	* 3C		INC	A
	dc.w	z3D-A_BAS	* 3D		DEC	A
	dc.w	z3E-A_BAS	* 3E		LD	A,n
	dc.w	z3F-A_BAS	* 3F		CCF

	dc.w	z40-A_BAS	* 40		LD	B,B
	dc.w	z41-A_BAS	* 41		LD	B,C
	dc.w	z42-A_BAS	* 42		LD	B,D
	dc.w	z43-A_BAS	* 43		LD	B,E
	dc.w	z44-A_BAS	* 44		LD	B,H
	dc.w	z45-A_BAS	* 45		LD	B,L
	dc.w	z46-A_BAS	* 46		LD	B,(HL)
	dc.w	z47-A_BAS	* 47		LD	B,A
	dc.w	z48-A_BAS	* 48		LD	C,B
	dc.w	z49-A_BAS	* 49		LD	C,C
	dc.w	z4A-A_BAS	* 4A		LD	C,D
	dc.w	z4B-A_BAS	* 4B		LD	C,E
	dc.w	z4C-A_BAS	* 4C		LD	C,H
	dc.w	z4D-A_BAS	* 4D		LD	C,L
	dc.w	z4E-A_BAS	* 4E		LD	C,(HL)
	dc.w	z4F-A_BAS	* 4F		LD	C,A

	dc.w	z50-A_BAS	* 50		LD	D,B
	dc.w	z51-A_BAS	* 51		LD	D,C
	dc.w	z52-A_BAS	* 52		LD	D,D
	dc.w	z53-A_BAS	* 53		LD	D,E
	dc.w	z54-A_BAS	* 54		LD	D,H
	dc.w	z55-A_BAS	* 55		LD	D,L
	dc.w	z56-A_BAS	* 56		LD	D,(HL)
	dc.w	z57-A_BAS	* 57		LD	D,A
	dc.w	z58-A_BAS	* 58		LD	E,B
	dc.w	z59-A_BAS	* 59		LD	E,C
	dc.w	z5A-A_BAS	* 5A		LD	E,D
	dc.w	z5B-A_BAS	* 5B		LD	E,E
	dc.w	z5C-A_BAS	* 5C		LD	E,H
	dc.w	z5D-A_BAS	* 5D		LD	E,L
	dc.w	z5E-A_BAS	* 5E		LD	E,(HL)
	dc.w	z5F-A_BAS	* 5F		LD	E,A

	dc.w	z60-A_BAS	* 60		LD	H,B
	dc.w	z61-A_BAS	* 61		LD	H,C
	dc.w	z62-A_BAS	* 62		LD	H,D
	dc.w	z63-A_BAS	* 63		LD	H,E
	dc.w	z64-A_BAS	* 64		LD	H,H
	dc.w	z65-A_BAS	* 65		LD	H,L
	dc.w	z66-A_BAS	* 66		LD	H,(HL)
	dc.w	z67-A_BAS	* 67		LD	H,A
	dc.w	z68-A_BAS	* 68		LD	L,B
	dc.w	z69-A_BAS	* 69		LD	L,C
	dc.w	z6A-A_BAS	* 6A		LD	L,D
	dc.w	z6B-A_BAS	* 6B		LD	L,E
	dc.w	z6C-A_BAS	* 6C		LD	L,H
	dc.w	z6D-A_BAS	* 6D		LD	L,L
	dc.w	z6E-A_BAS	* 6E		LD	L,(HL)
	dc.w	z6F-A_BAS	* 6F		LD	L,A

	dc.w	z70-A_BAS	* 70		LD	(HL),B
	dc.w	z71-A_BAS	* 71		LD	(HL),C
	dc.w	z72-A_BAS	* 72		LD	(HL),D
	dc.w	z73-A_BAS	* 73		LD	(HL),E
	dc.w	z74-A_BAS	* 74		LD	(HL),H
	dc.w	z75-A_BAS	* 75		LD	(HL),L
	dc.w	z76-A_BAS	* 76		HALT
	dc.w	z77-A_BAS	* 77		LD	(HL),A
	dc.w	z78-A_BAS	* 78		LD	A,B
	dc.w	z79-A_BAS	* 79		LD	A,C
	dc.w	z7A-A_BAS	* 7A		LD	A,D
	dc.w	z7B-A_BAS	* 7B		LD	A,E
	dc.w	z7C-A_BAS	* 7C		LD	A,H
	dc.w	z7D-A_BAS	* 7D		LD	A,L
	dc.w	z7E-A_BAS	* 7E		LD	A,(HL)
	dc.w	z7F-A_BAS	* 7F		LD	A,A

	dc.w	z80-A_BAS	* 80		ADD	A,B
	dc.w	z81-A_BAS	* 81		ADD	A,C
	dc.w	z82-A_BAS	* 82		ADD	A,D
	dc.w	z83-A_BAS	* 83		ADD	A,E
	dc.w	z84-A_BAS	* 84		ADD	A,H
	dc.w	z85-A_BAS	* 85		ADD	A,L
	dc.w	z86-A_BAS	* 86		ADD	A,(HL)
	dc.w	z87-A_BAS	* 87		ADD	A,A
	dc.w	z88-A_BAS	* 88		ADC	A,B
	dc.w	z89-A_BAS	* 89		ADC	A,C
	dc.w	z8A-A_BAS	* 8A		ADC	A,D
	dc.w	z8B-A_BAS	* 8B		ADC	A,E
	dc.w	z8C-A_BAS	* 8C		ADC	A,H
	dc.w	z8D-A_BAS	* 8D		ADC	A,L
	dc.w	z8E-A_BAS	* 8E		ADC	A,(HL)
	dc.w	z8F-A_BAS	* 8F		ADC	A,A

	dc.w	z90-A_BAS	* 90		SUB	B
	dc.w	z91-A_BAS	* 91		SUB	C
	dc.w	z92-A_BAS	* 92		SUB	D
	dc.w	z93-A_BAS	* 93		SUB	E
	dc.w	z94-A_BAS	* 94		SUB	H
	dc.w	z95-A_BAS	* 95		SUB	L
	dc.w	z96-A_BAS	* 96		SUB	(HL)
	dc.w	z97-A_BAS	* 97		SUB	A
	dc.w	z98-A_BAS	* 98		SBC	A,B
	dc.w	z99-A_BAS	* 99		SBC	A,C
	dc.w	z9A-A_BAS	* 9A		SBC	A,D
	dc.w	z9B-A_BAS	* 9B		SBC	A,E
	dc.w	z9C-A_BAS	* 9C		SBC	A,H
	dc.w	z9D-A_BAS	* 9D		SBC	A,L
	dc.w	z9E-A_BAS	* 9E		SBC	A,(HL)
	dc.w	z9F-A_BAS	* 9F		SBC	A,A

	dc.w	zA0-A_BAS	* A0		AND	B
	dc.w	zA1-A_BAS	* A1		AND	C
	dc.w	zA2-A_BAS	* A2		AND	D
	dc.w	zA3-A_BAS	* A3		AND	E
	dc.w	zA4-A_BAS	* A4		AND	H
	dc.w	zA5-A_BAS	* A5		AND	L
	dc.w	zA6-A_BAS	* A6		AND	(HL)
	dc.w	zA7-A_BAS	* A7		AND	A
	dc.w	zA8-A_BAS	* A8		XOR	B
	dc.w	zA9-A_BAS	* A9		XOR	C
	dc.w	zAA-A_BAS	* AA		XOR	D
	dc.w	zAB-A_BAS	* AB		XOR	E
	dc.w	zAC-A_BAS	* AC		XOR	H
	dc.w	zAD-A_BAS	* AD		XOR	L
	dc.w	zAE-A_BAS	* AE		XOR	(HL)
	dc.w	zAF-A_BAS	* AF		XOR	A

	dc.w	zB0-A_BAS	* B0		OR	B
	dc.w	zB1-A_BAS	* B1		OR	C
	dc.w	zB2-A_BAS	* B2		OR	D
	dc.w	zB3-A_BAS	* B3		OR	E
	dc.w	zB4-A_BAS	* B4		OR	H
	dc.w	zB5-A_BAS	* B5		OR	L
	dc.w	zB6-A_BAS	* B6		OR	(HL)
	dc.w	zB7-A_BAS	* B7		OR	A
	dc.w	zB8-A_BAS	* B8		CP	B
	dc.w	zB9-A_BAS	* B9		CP	C
	dc.w	zBA-A_BAS	* BA		CP	D
	dc.w	zBB-A_BAS	* BB		CP	E
	dc.w	zBC-A_BAS	* BC		CP	H
	dc.w	zBD-A_BAS	* BD		CP	L
	dc.w	zBE-A_BAS	* BE		CP	(HL)
	dc.w	zBF-A_BAS	* BF		CP	A

	dc.w	zC0-A_BAS	* C0		RET	NZ
	dc.w	zC1-A_BAS	* C1		POP	BC
	dc.w	zC2-A_BAS	* C2		JP	NZ,nn
	dc.w	zC3-A_BAS	* C3		JP	nn
	dc.w	zC4-A_BAS	* C4		CALL	NZ,nn
	dc.w	zC5-A_BAS	* C5		PUSH	BC
	dc.w	zC6-A_BAS	* C6		ADD	A,n
	dc.w	zC7-A_BAS	* C7		RST	00H
	dc.w	zC8-A_BAS	* C8		RET	Z
	dc.w	zC9-A_BAS	* C9		RET
	dc.w	zCA-A_BAS	* CA		JP	Z,nn
	dc.w	zCB-A_BAS	* CB		$CB
	dc.w	zCC-A_BAS	* CC		CALL	Z,nn
	dc.w	zCD-A_BAS	* CD		CALL	nn
	dc.w	zCE-A_BAS	* CE		ADC	A,n
	dc.w	zCF-A_BAS	* CF		RST	08H

	dc.w	zD0-A_BAS	* D0		RET	NC
	dc.w	zD1-A_BAS	* D1		POP	DE
	dc.w	zD2-A_BAS	* D2		JP	NC,nn
	dc.w	zD3-A_BAS	* D3		OUT	n,A
	dc.w	zD4-A_BAS	* D4		CALL	NC,nn
	dc.w	zD5-A_BAS	* D5		PUSH	DE
	dc.w	zD6-A_BAS	* D6		SUB	n
	dc.w	zD7-A_BAS	* D7		RST	10H
	dc.w	zD8-A_BAS	* D8		RET	C
	dc.w	zD9-A_BAS	* D9		EXX
	dc.w	zDA-A_BAS	* DA		JP	C,nn
	dc.w	zDB-A_BAS	* DB		IN	A,n
	dc.w	zDC-A_BAS	* DC		CALL	C,nn
	dc.w	zDD-A_BAS	* DD		$DD
	dc.w	zDE-A_BAS	* DE		SBC	A,n
	dc.w	zDF-A_BAS	* DF		RST	18H

	dc.w	zE0-A_BAS	* E0		RET	PO
	dc.w	zE1-A_BAS	* E1		POP	HL
	dc.w	zE2-A_BAS	* E2		JP	PO,nn
	dc.w	zE3-A_BAS	* E3		EX	(SP),HL
	dc.w	zE4-A_BAS	* E4		CALL	PO,nn
	dc.w	zE5-A_BAS	* E5		PUSH	HL
	dc.w	zE6-A_BAS	* E6		AND	n
	dc.w	zE7-A_BAS	* E7		RST	20H
	dc.w	zE8-A_BAS	* E8		RET	PE
	dc.w	zE9-A_BAS	* E9		JP	(HL)
	dc.w	zEA-A_BAS	* EA		JP	PE,nn
	dc.w	zEB-A_BAS	* EB		EX	DE,HL
	dc.w	zEC-A_BAS	* EC		CALL	PE,nn
	dc.w	zED-A_BAS	* ED		$ED
	dc.w	zEE-A_BAS	* EE		XOR	n
	dc.w	zEF-A_BAS	* EF		RST	28H

	dc.w	zF0-A_BAS	* F0		RET	P
	dc.w	zF1-A_BAS	* F1		POP	AF
	dc.w	zF2-A_BAS	* F2		JP	P,nn
	dc.w	zF3-A_BAS	* F3		DI
	dc.w	zF4-A_BAS	* F4		CALL	P,nn
	dc.w	zF5-A_BAS	* F5		PUSH	AF
	dc.w	zF6-A_BAS	* F6		OR	n
	dc.w	zF7-A_BAS	* F7		RST	30H
	dc.w	zF8-A_BAS	* F8		RET	M
	dc.w	zF9-A_BAS	* F9		LD	SP,HL
	dc.w	zFA-A_BAS	* FA		JP	M,nn
	dc.w	zFB-A_BAS	* FB		EI
	dc.w	zFC-A_BAS	* FC		CALL	M,nn
	dc.w	zFD-A_BAS	* FD		$FD
	dc.w	zFE-A_BAS	* FE		CP	n
	dc.w	zFF-A_BAS	* FF		RST	38H


*---------------------------------------*
*      jump table  OP CODE (CB xx)	*
*---------------------------------------*

T_CB:
	dc.w	CB_00-A_BAS	* CB 00		RLC	B
	dc.w	CB_01-A_BAS	* CB 01		RLC	C
	dc.w	CB_02-A_BAS	* CB 02		RLC	D
	dc.w	CB_03-A_BAS	* CB 03		RLC	E
	dc.w	CB_04-A_BAS	* CB 04		RLC	H
	dc.w	CB_05-A_BAS	* CB 05		RLC	L
	dc.w	CB_06-A_BAS	* CB 06		RLC	(HL)
	dc.w	CB_07-A_BAS	* CB 07		RLC	A
	dc.w	CB_08-A_BAS	* CB 08		RRC	B
	dc.w	CB_09-A_BAS	* CB 09		RRC	C
	dc.w	CB_0A-A_BAS	* CB 0A		RRC	D
	dc.w	CB_0B-A_BAS	* CB 0B		RRC	E
	dc.w	CB_0C-A_BAS	* CB 0C		RRC	H
	dc.w	CB_0D-A_BAS	* CB 0D		RRC	L
	dc.w	CB_0E-A_BAS	* CB 0E		RRC	(HL)
	dc.w	CB_0F-A_BAS	* CB 0F		RRC	A

	dc.w	CB_10-A_BAS	* CB 10		RL	B
	dc.w	CB_11-A_BAS	* CB 11		RL	C
	dc.w	CB_12-A_BAS	* CB 12		RL	D
	dc.w	CB_13-A_BAS	* CB 13		RL	E
	dc.w	CB_14-A_BAS	* CB 14		RL	H
	dc.w	CB_15-A_BAS	* CB 15		RL	L
	dc.w	CB_16-A_BAS	* CB 16		RL	(HL)
	dc.w	CB_17-A_BAS	* CB 17		RL	A
	dc.w	CB_18-A_BAS	* CB 18		RR	B
	dc.w	CB_19-A_BAS	* CB 19		RR	C
	dc.w	CB_1A-A_BAS	* CB 1A		RR	D
	dc.w	CB_1B-A_BAS	* CB 1B		RR	E
	dc.w	CB_1C-A_BAS	* CB 1C		RR	H
	dc.w	CB_1D-A_BAS	* CB 1D		RR	L
	dc.w	CB_1E-A_BAS	* CB 1E		RR	(HL)
	dc.w	CB_1F-A_BAS	* CB 1F		RR	A

	dc.w	CB_20-A_BAS	* CB 20		SLA	B
	dc.w	CB_21-A_BAS	* CB 21		SLA	C
	dc.w	CB_22-A_BAS	* CB 22		SLA	D
	dc.w	CB_23-A_BAS	* CB 23		SLA	E
	dc.w	CB_24-A_BAS	* CB 24		SLA	H
	dc.w	CB_25-A_BAS	* CB 25		SLA	L
	dc.w	CB_26-A_BAS	* CB 26		SLA	(HL)
	dc.w	CB_27-A_BAS	* CB 27		SLA	A
	dc.w	CB_28-A_BAS	* CB 28		SRA	B
	dc.w	CB_29-A_BAS	* CB 29		SRA	C
	dc.w	CB_2A-A_BAS	* CB 2A		SRA	D
	dc.w	CB_2B-A_BAS	* CB 2B		SRA	E
	dc.w	CB_2C-A_BAS	* CB 2C		SRA	H
	dc.w	CB_2D-A_BAS	* CB 2D		SRA	L
	dc.w	CB_2E-A_BAS	* CB 2E		SRA	(HL)
	dc.w	CB_2F-A_BAS	* CB 2F		SRA	A

	dcb.w	1-$30+$37,NEXT2A
	dc.w	CB_38-A_BAS	* CB 38		SRL	B
	dc.w	CB_39-A_BAS	* CB 39		SRL	C
	dc.w	CB_3A-A_BAS	* CB 3A		SRL	D
	dc.w	CB_3B-A_BAS	* CB 3B		SRL	E
	dc.w	CB_3C-A_BAS	* CB 3C		SRL	H
	dc.w	CB_3D-A_BAS	* CB 3D		SRL	L
	dc.w	CB_3E-A_BAS	* CB 3E		SRL	(HL)
	dc.w	CB_3F-A_BAS	* CB 3F		SRL	A

	dc.w	CB_40-A_BAS	* CB 40		BIT	0,B
	dc.w	CB_41-A_BAS	* CB 41		BIT	0,C
	dc.w	CB_42-A_BAS	* CB 42		BIT	0,D
	dc.w	CB_43-A_BAS	* CB 43		BIT	0,E
	dc.w	CB_44-A_BAS	* CB 44		BIT	0,H
	dc.w	CB_45-A_BAS	* CB 45		BIT	0,L
	dc.w	CB_46-A_BAS	* CB 46		BIT	0,(HL)
	dc.w	CB_47-A_BAS	* CB 47		BIT	0,A
	dc.w	CB_48-A_BAS	* CB 48		BIT	1,B
	dc.w	CB_49-A_BAS	* CB 49		BIT	1,C
	dc.w	CB_4A-A_BAS	* CB 4A		BIT	1,D
	dc.w	CB_4B-A_BAS	* CB 4B		BIT	1,E
	dc.w	CB_4C-A_BAS	* CB 4C		BIT	1,H
	dc.w	CB_4D-A_BAS	* CB 4D		BIT	1,L
	dc.w	CB_4E-A_BAS	* CB 4E		BIT	1,(HL)
	dc.w	CB_4F-A_BAS	* CB 4F		BIT	1,A

	dc.w	CB_50-A_BAS	* CB 50		BIT	2,B
	dc.w	CB_51-A_BAS	* CB 51		BIT	2,C
	dc.w	CB_52-A_BAS	* CB 52		BIT	2,D
	dc.w	CB_53-A_BAS	* CB 53		BIT	2,E
	dc.w	CB_54-A_BAS	* CB 54		BIT	2,H
	dc.w	CB_55-A_BAS	* CB 55		BIT	2,L
	dc.w	CB_56-A_BAS	* CB 56		BIT	2,(HL)
	dc.w	CB_57-A_BAS	* CB 57		BIT	2,A
	dc.w	CB_58-A_BAS	* CB 58		BIT	3,B
	dc.w	CB_59-A_BAS	* CB 59		BIT	3,C
	dc.w	CB_5A-A_BAS	* CB 5A		BIT	3,D
	dc.w	CB_5B-A_BAS	* CB 5B		BIT	3,E
	dc.w	CB_5C-A_BAS	* CB 5C		BIT	3,H
	dc.w	CB_5D-A_BAS	* CB 5D		BIT	3,L
	dc.w	CB_5E-A_BAS	* CB 5E		BIT	3,(HL)
	dc.w	CB_5F-A_BAS	* CB 5F		BIT	3,A

	dc.w	CB_60-A_BAS	* CB 60		BIT	4,B
	dc.w	CB_61-A_BAS	* CB 61		BIT	4,C
	dc.w	CB_62-A_BAS	* CB 62		BIT	4,D
	dc.w	CB_63-A_BAS	* CB 63		BIT	4,E
	dc.w	CB_64-A_BAS	* CB 64		BIT	4,H
	dc.w	CB_65-A_BAS	* CB 65		BIT	4,L
	dc.w	CB_66-A_BAS	* CB 66		BIT	4,(HL)
	dc.w	CB_67-A_BAS	* CB 67		BIT	4,A
	dc.w	CB_68-A_BAS	* CB 68		BIT	5,B
	dc.w	CB_69-A_BAS	* CB 69		BIT	5,C
	dc.w	CB_6A-A_BAS	* CB 6A		BIT	5,D
	dc.w	CB_6B-A_BAS	* CB 6B		BIT	5,E
	dc.w	CB_6C-A_BAS	* CB 6C		BIT	5,H
	dc.w	CB_6D-A_BAS	* CB 6D		BIT	5,L
	dc.w	CB_6E-A_BAS	* CB 6E		BIT	5,(HL)
	dc.w	CB_6F-A_BAS	* CB 6F		BIT	5,A

	dc.w	CB_70-A_BAS	* CB 70		BIT	6,B
	dc.w	CB_71-A_BAS	* CB 71		BIT	6,C
	dc.w	CB_72-A_BAS	* CB 72		BIT	6,D
	dc.w	CB_73-A_BAS	* CB 73		BIT	6,E
	dc.w	CB_74-A_BAS	* CB 74		BIT	6,H
	dc.w	CB_75-A_BAS	* CB 75		BIT	6,L
	dc.w	CB_76-A_BAS	* CB 76		BIT	6,(HL)
	dc.w	CB_77-A_BAS	* CB 77		BIT	6,A
	dc.w	CB_78-A_BAS	* CB 78		BIT	7,B
	dc.w	CB_79-A_BAS	* CB 79		BIT	7,C
	dc.w	CB_7A-A_BAS	* CB 7A		BIT	7,D
	dc.w	CB_7B-A_BAS	* CB 7B		BIT	7,E
	dc.w	CB_7C-A_BAS	* CB 7C		BIT	7,H
	dc.w	CB_7D-A_BAS	* CB 7D		BIT	7,L
	dc.w	CB_7E-A_BAS	* CB 7E		BIT	7,(HL)
	dc.w	CB_7F-A_BAS	* CB 7F		BIT	7,A

	dc.w	CB_80-A_BAS	* CB 80		RES	0,B
	dc.w	CB_81-A_BAS	* CB 81		RES	0,C
	dc.w	CB_82-A_BAS	* CB 82		RES	0,D
	dc.w	CB_83-A_BAS	* CB 83		RES	0,E
	dc.w	CB_84-A_BAS	* CB 84		RES	0,H
	dc.w	CB_85-A_BAS	* CB 85		RES	0,L
	dc.w	CB_86-A_BAS	* CB 86		RES	0,(HL)
	dc.w	CB_87-A_BAS	* CB 87		RES	0,A
	dc.w	CB_88-A_BAS	* CB 88		RES	1,B
	dc.w	CB_89-A_BAS	* CB 89		RES	1,C
	dc.w	CB_8A-A_BAS	* CB 8A		RES	1,D
	dc.w	CB_8B-A_BAS	* CB 8B		RES	1,E
	dc.w	CB_8C-A_BAS	* CB 8C		RES	1,H
	dc.w	CB_8D-A_BAS	* CB 8D		RES	1,L
	dc.w	CB_8E-A_BAS	* CB 8E		RES	1,(HL)
	dc.w	CB_8F-A_BAS	* CB 8F		RES	1,A

	dc.w	CB_90-A_BAS	* CB 90		RES	2,B
	dc.w	CB_91-A_BAS	* CB 91		RES	2,C
	dc.w	CB_92-A_BAS	* CB 92		RES	2,D
	dc.w	CB_93-A_BAS	* CB 93		RES	2,E
	dc.w	CB_94-A_BAS	* CB 94		RES	2,H
	dc.w	CB_95-A_BAS	* CB 95		RES	2,L
	dc.w	CB_96-A_BAS	* CB 96		RES	2,(HL)
	dc.w	CB_97-A_BAS	* CB 97		RES	2,A
	dc.w	CB_98-A_BAS	* CB 98		RES	3,B
	dc.w	CB_99-A_BAS	* CB 99		RES	3,C
	dc.w	CB_9A-A_BAS	* CB 9A		RES	3,D
	dc.w	CB_9B-A_BAS	* CB 9B		RES	3,E
	dc.w	CB_9C-A_BAS	* CB 9C		RES	3,H
	dc.w	CB_9D-A_BAS	* CB 9D		RES	3,L
	dc.w	CB_9E-A_BAS	* CB 9E		RES	3,(HL)
	dc.w	CB_9F-A_BAS	* CB 9F		RES	3,A

	dc.w	CB_A0-A_BAS	* CB A0		RES	4,B
	dc.w	CB_A1-A_BAS	* CB A1		RES	4,C
	dc.w	CB_A2-A_BAS	* CB A2		RES	4,D
	dc.w	CB_A3-A_BAS	* CB A3		RES	4,E
	dc.w	CB_A4-A_BAS	* CB A4		RES	4,H
	dc.w	CB_A5-A_BAS	* CB A5		RES	4,L
	dc.w	CB_A6-A_BAS	* CB A6		RES	4,(HL)
	dc.w	CB_A7-A_BAS	* CB A7		RES	4,A
	dc.w	CB_A8-A_BAS	* CB A8		RES	5,B
	dc.w	CB_A9-A_BAS	* CB A9		RES	5,C
	dc.w	CB_AA-A_BAS	* CB AA		RES	5,D
	dc.w	CB_AB-A_BAS	* CB AB		RES	5,E
	dc.w	CB_AC-A_BAS	* CB AC		RES	5,H
	dc.w	CB_AD-A_BAS	* CB AD		RES	5,L
	dc.w	CB_AE-A_BAS	* CB AE		RES	5,(HL)
	dc.w	CB_AF-A_BAS	* CB AF		RES	5,A

	dc.w	CB_B0-A_BAS	* CB B0		RES	6,B
	dc.w	CB_B1-A_BAS	* CB B1		RES	6,C
	dc.w	CB_B2-A_BAS	* CB B2		RES	6,D
	dc.w	CB_B3-A_BAS	* CB B3		RES	6,E
	dc.w	CB_B4-A_BAS	* CB B4		RES	6,H
	dc.w	CB_B5-A_BAS	* CB B5		RES	6,L
	dc.w	CB_B6-A_BAS	* CB B6		RES	6,(HL)
	dc.w	CB_B7-A_BAS	* CB B7		RES	6,A
	dc.w	CB_B8-A_BAS	* CB B8		RES	7,B
	dc.w	CB_B9-A_BAS	* CB B9		RES	7,C
	dc.w	CB_BA-A_BAS	* CB BA		RES	7,D
	dc.w	CB_BB-A_BAS	* CB BB		RES	7,E
	dc.w	CB_BC-A_BAS	* CB BC		RES	7,H
	dc.w	CB_BD-A_BAS	* CB BD		RES	7,L
	dc.w	CB_BE-A_BAS	* CB BE		RES	7,(HL)
	dc.w	CB_BF-A_BAS	* CB BF		RES	7,A

	dc.w	CB_C0-A_BAS	* CB C0		SET	0,B
	dc.w	CB_C1-A_BAS	* CB C1		SET	0,C
	dc.w	CB_C2-A_BAS	* CB C2		SET	0,D
	dc.w	CB_C3-A_BAS	* CB C3		SET	0,E
	dc.w	CB_C4-A_BAS	* CB C4		SET	0,H
	dc.w	CB_C5-A_BAS	* CB C5		SET	0,L
	dc.w	CB_C6-A_BAS	* CB C6		SET	0,(HL)
	dc.w	CB_C7-A_BAS	* CB C7		SET	0,A
	dc.w	CB_C8-A_BAS	* CB C8		SET	1,B
	dc.w	CB_C9-A_BAS	* CB C9		SET	1,C
	dc.w	CB_CA-A_BAS	* CB CA		SET	1,D
	dc.w	CB_CB-A_BAS	* CB CB		SET	1,E
	dc.w	CB_CC-A_BAS	* CB CC		SET	1,H
	dc.w	CB_CD-A_BAS	* CB CD		SET	1,L
	dc.w	CB_CE-A_BAS	* CB CE		SET	1,(HL)
	dc.w	CB_CF-A_BAS	* CB CF		SET	1,A

	dc.w	CB_D0-A_BAS	* CB D0		SET	2,B
	dc.w	CB_D1-A_BAS	* CB D1		SET	2,C
	dc.w	CB_D2-A_BAS	* CB D2		SET	2,D
	dc.w	CB_D3-A_BAS	* CB D3		SET	2,E
	dc.w	CB_D4-A_BAS	* CB D4		SET	2,H
	dc.w	CB_D5-A_BAS	* CB D5		SET	2,L
	dc.w	CB_D6-A_BAS	* CB D6		SET	2,(HL)
	dc.w	CB_D7-A_BAS	* CB D7		SET	2,A
	dc.w	CB_D8-A_BAS	* CB D8		SET	3,B
	dc.w	CB_D9-A_BAS	* CB D9		SET	3,C
	dc.w	CB_DA-A_BAS	* CB DA		SET	3,D
	dc.w	CB_DB-A_BAS	* CB DB		SET	3,E
	dc.w	CB_DC-A_BAS	* CB DC		SET	3,H
	dc.w	CB_DD-A_BAS	* CB DD		SET	3,L
	dc.w	CB_DE-A_BAS	* CB DE		SET	3,(HL)
	dc.w	CB_DF-A_BAS	* CB DF		SET	3,A

	dc.w	CB_E0-A_BAS	* CB E0		SET	4,B
	dc.w	CB_E1-A_BAS	* CB E1		SET	4,C
	dc.w	CB_E2-A_BAS	* CB E2		SET	4,D
	dc.w	CB_E3-A_BAS	* CB E3		SET	4,E
	dc.w	CB_E4-A_BAS	* CB E4		SET	4,H
	dc.w	CB_E5-A_BAS	* CB E5		SET	4,L
	dc.w	CB_E6-A_BAS	* CB E6		SET	4,(HL)
	dc.w	CB_E7-A_BAS	* CB E7		SET	4,A
	dc.w	CB_E8-A_BAS	* CB E8		SET	5,B
	dc.w	CB_E9-A_BAS	* CB E9		SET	5,C
	dc.w	CB_EA-A_BAS	* CB EA		SET	5,D
	dc.w	CB_EB-A_BAS	* CB EB		SET	5,E
	dc.w	CB_EC-A_BAS	* CB EC		SET	5,H
	dc.w	CB_ED-A_BAS	* CB ED		SET	5,L
	dc.w	CB_EE-A_BAS	* CB EE		SET	5,(HL)
	dc.w	CB_EF-A_BAS	* CB EF		SET	5,A

	dc.w	CB_F0-A_BAS	* CB F0		SET	6,B
	dc.w	CB_F1-A_BAS	* CB F1		SET	6,C
	dc.w	CB_F2-A_BAS	* CB F2		SET	6,D
	dc.w	CB_F3-A_BAS	* CB F3		SET	6,E
	dc.w	CB_F4-A_BAS	* CB F4		SET	6,H
	dc.w	CB_F5-A_BAS	* CB F5		SET	6,L
	dc.w	CB_F6-A_BAS	* CB F6		SET	6,(HL)
	dc.w	CB_F7-A_BAS	* CB F7		SET	6,A
	dc.w	CB_F8-A_BAS	* CB F8		SET	7,B
	dc.w	CB_F9-A_BAS	* CB F9		SET	7,C
	dc.w	CB_FA-A_BAS	* CB FA		SET	7,D
	dc.w	CB_FB-A_BAS	* CB FB		SET	7,E
	dc.w	CB_FC-A_BAS	* CB FC		SET	7,H
	dc.w	CB_FD-A_BAS	* CB FD		SET	7,L
	dc.w	CB_FE-A_BAS	* CB FE		SET	7,(HL)
	dc.w	CB_FF-A_BAS	* CB FF		SET	7,A


*---------------------------------------*
*      jump table  OP CODE (DD xx)	*
*---------------------------------------*

T_DD:
	dcb.w	1-$00+$08,NEXT2A
	dc.w	DD_09-A_BAS	* DD 09		ADD	IX,BC
	dcb.w	1-$0A+$18,NEXT2A

	dc.w	DD_19-A_BAS	* DD 19		ADD	IX,DE
	dcb.w	1-$1A+$20,NEXT2A

	dc.w	DD_21-A_BAS	* DD 21		LD	IX,nn
	dc.w	DD_22-A_BAS	* DD 22		LD	(nn),IX
	dc.w	DD_23-A_BAS	* DD 23		INC	IX
	dc.w	DD_24-A_BAS	* DD 24		INC	IXH		*
	dc.w	DD_25-A_BAS	* DD 25		DEC	IXH		*
	dc.w	DD_26-A_BAS	* DD 26		LD	IXH,n		*
	dcb.w	1-$27+$28,NEXT2A
	dc.w	DD_29-A_BAS	* DD 29		ADD	IX,IX
	dc.w	DD_2A-A_BAS	* DD 2A		LD	IX,(nn)
	dc.w	DD_2B-A_BAS	* DD 2B		DEC	IX
	dc.w	DD_2C-A_BAS	* DD 2C		INC	IXL		*
	dc.w	DD_2D-A_BAS	* DD 2D		DEC	IXL		*
	dc.w	DD_2E-A_BAS	* DD 2E		LD	IXL,n		*
	dcb.w	1-$2F+$33,NEXT2A

	dc.w	DD_34-A_BAS	* DD 34		INC	(IX+d)
	dc.w	DD_35-A_BAS	* DD 35		DEC	(IX+d)
	dc.w	DD_36-A_BAS	* DD 36		LD	(IX+d),n
	dcb.w	1-$37+$38,NEXT2A
	dc.w	DD_39-A_BAS	* DD 39		ADD	IX,SP
	dcb.w	1-$3A+$43,NEXT2A

	dc.w	DD_44-A_BAS	* DD 44		LD	B,IXH		*
	dc.w	DD_45-A_BAS	* DD 45		LD	B,IXL		*
	dc.w	DD_46-A_BAS	* DD 46		LD	B,(IX+d)
	dcb.w	1-$47+$4B,NEXT2A
	dc.w	DD_4C-A_BAS	* DD 4C		LD	C,IXH		*
	dc.w	DD_4D-A_BAS	* DD 4D		LD	C,IXL		*
	dc.w	DD_4E-A_BAS	* DD 4E		LD	C,(IX+d)
	dcb.w	1-$4F+$53,NEXT2A

	dc.w	DD_54-A_BAS	* DD 54		LD	D,IXH		*
	dc.w	DD_55-A_BAS	* DD 55		LD	D,IXL		*
	dc.w	DD_56-A_BAS	* DD 56		LD	D,(IX+d)
	dcb.w	1-$57+$5B,NEXT2A
	dc.w	DD_5C-A_BAS	* DD 5C		LD	E,IXH		*
	dc.w	DD_5D-A_BAS	* DD 5D		LD	E,IXL		*
	dc.w	DD_5E-A_BAS	* DD 5E		LD	E,(IX+d)
	dcb.w	1-$5F+$63,NEXT2A

	dc.w	DD_64-A_BAS	* DD 64		LD	H,IXH		*
	dc.w	DD_65-A_BAS	* DD 65		LD	H,IXL		*
	dc.w	DD_66-A_BAS	* DD 66		LD	H,(IX+d)
	dcb.w	1-$67+$6B,NEXT2A
	dc.w	DD_6C-A_BAS	* DD 6C		LD	L,IXH		*
	dc.w	DD_6D-A_BAS	* DD 6D		LD	L,IXL		*
	dc.w	DD_6E-A_BAS	* DD 6E		LD	L,(IX+d)
	dcb.w	1-$6F+$6F,NEXT2A

	dc.w	DD_70-A_BAS	* DD 70		LD	(IX+d),B
	dc.w	DD_71-A_BAS	* DD 71		LD	(IX+d),C
	dc.w	DD_72-A_BAS	* DD 72		LD	(IX+d),D
	dc.w	DD_73-A_BAS	* DD 73		LD	(IX+d),E
	dc.w	DD_74-A_BAS	* DD 74		LD	(IX+d),H
	dc.w	DD_75-A_BAS	* DD 75		LD	(IX+d),L
	dcb.w	1-$76+$76,NEXT2A
	dc.w	DD_77-A_BAS	* DD 77		LD	(IX+d),A
	dcb.w	1-$78+$7B,NEXT2A
	dc.w	DD_7C-A_BAS	* DD 7C		LD	A,IXH		*
	dc.w	DD_7D-A_BAS	* DD 7D		LD	A,IXL		*
	dc.w	DD_7E-A_BAS	* DD 7E		LD	A,(IX+d)
	dcb.w	1-$7F+$7F,NEXT2A

	dcb.w	1-$80+$83,NEXTA
	dc.w	DD_84-A_BAS	* DD 84		ADD	A,IXH		*
	dc.w	DD_85-A_BAS	* DD 85		ADD	A,IXL		*
	dc.w	DD_86-A_BAS	* DD 86		ADD	A,(IX+d)
	dcb.w	1-$87+$8B,NEXTA
	dc.w	DD_8C-A_BAS	* DD 8C		ADC	A,IXH		*
	dc.w	DD_8D-A_BAS	* DD 8D		ADC	A,IXL		*
	dc.w	DD_8E-A_BAS	* DD 8E		ADC	A,(IX+d)
	dcb.w	1-$8F+$93,NEXTA

	dc.w	DD_94-A_BAS	* DD 94		SUB	IXH		*
	dc.w	DD_95-A_BAS	* DD 95		SUB	IXL		*
	dc.w	DD_96-A_BAS	* DD 96		SUB	(IX+d)
	dcb.w	1-$97+$9B,NEXTA
	dc.w	DD_9C-A_BAS	* DD 9C		SBC	A,IXH		*
	dc.w	DD_9D-A_BAS	* DD 9D		SBC	A,IXL		*
	dc.w	DD_9E-A_BAS	* DD 9E		SBC	A,(IX+d)
	dcb.w	1-$9F+$A3,NEXTA

	dc.w	DD_A4-A_BAS	* DD A4		AND	IXH		*
	dc.w	DD_A5-A_BAS	* DD A5		AND	IXL		*
	dc.w	DD_A6-A_BAS	* DD A6		AND	(IX+d)	
	dcb.w	1-$A7+$AB,NEXTA
	dc.w	DD_AC-A_BAS	* DD AC		XOR	IXH		*
	dc.w	DD_AD-A_BAS	* DD AD		XOR	IXL		*
	dc.w	DD_AE-A_BAS	* DD AE		XOR	(IX+d)
	dcb.w	1-$AF+$B3,NEXTA

	dc.w	DD_B4-A_BAS	* DD B4		OR	IXH		*
	dc.w	DD_B5-A_BAS	* DD B5		OR	IXL		*
	dc.w	DD_B6-A_BAS	* DD B6		OR	(IX+d)
	dcb.w	1-$B7+$BB,NEXTA
	dc.w	DD_BC-A_BAS	* DD BC		CP	IXH		*
	dc.w	DD_BD-A_BAS	* DD BD		CP	IXL		*
	dc.w	DD_BE-A_BAS	* DD BE		CP	(IX+d)
	dcb.w	1-$BF+$CA,NEXTA

	dc.w	DD_CB-A_BAS	* DD CB		$DD CB
	dcb.w	1-$CC+$E0,NEXTA

	dc.w	DD_E1-A_BAS	* DD E1		POP	IX
	dcb.w	1-$E2+$E2,NEXTA
	dc.w	DD_E3-A_BAS	* DD E3		EX	(SP),IX
	dcb.w	1-$E4+$E4,NEXTA
	dc.w	DD_E5-A_BAS	* DD E5		PUSH	IX
	dcb.w	1-$E6+$E8,NEXTA
	dc.w	DD_E9-A_BAS	* DD E9		JP	(IX)
	dcb.w	1-$EA+$F8,NEXTA

	dc.w	DD_F9-A_BAS	* DD F9		LD	SP,IX
	dcb.w	1-$FA+$FF,NEXTA

T_DDc:
	dcb.w	1-$00+$03,NEXTA
	dc.w	DDc04-A_BAS	* DD CB    04	RLC	IXH		*
	dc.w	DDc05-A_BAS	* DD CB    05	RLC	IXL		*
	dc.w	DDc06-A_BAS	* DD CB  d 06	RLC	(IX+d)
	dcb.w	1-$07+$0B,NEXTA
	dc.w	DDc0C-A_BAS	* DD CB    0C	RRC	IXH		*
	dc.w	DDc0D-A_BAS	* DD CB    0D	RRC	IXL		*
	dc.w	DDc0E-A_BAS	* DD CB  d 0E	RRC	(IX+d)
	dcb.w	1-$0F+$13,NEXTA

	dc.w	DDc14-A_BAS	* DD CB    14	RL	IXH		*
	dc.w	DDc15-A_BAS	* DD CB    15	RL	IXL		*
	dc.w	DDc16-A_BAS	* DD CB  d 16	RL	(IX+d)
	dcb.w	1-$17+$1B,NEXTA
	dc.w	DDc1C-A_BAS	* DD CB    1C	RR	IXH		*
	dc.w	DDc1D-A_BAS	* DD CB    1D	RR	IXL		*
	dc.w	DDc1E-A_BAS	* DD CB  d 1E	RR	(IX+d)
	dcb.w	1-$1F+$23,NEXTA

	dc.w	DDc24-A_BAS	* DD CB    24	SLA	IXH		*
	dc.w	DDc25-A_BAS	* DD CB    25	SLA	IXL		*
	dc.w	DDc26-A_BAS	* DD CB  d 26	SLA	(IX+d)
	dcb.w	1-$27+$2B,NEXTA
	dc.w	DDc2C-A_BAS	* DD CB    2C	SRA	IXH		*
	dc.w	DDc2D-A_BAS	* DD CB    2D	SRA	IXL		*
	dc.w	DDc2E-A_BAS	* DD CB  d 2E	SRA	(IX+d)
	dcb.w	1-$2F+$3B,NEXTA

	dc.w	DDc3C-A_BAS	* DD CB    3C	SRL	IXH		*
	dc.w	DDc3D-A_BAS	* DD CB    3D	SRL	IXL		*
	dc.w	DDc3E-A_BAS	* DD CB  d 3E	SRL	(IX+d)
	dcb.w	1-$3F+$43,NEXTA

	dc.w	DDc44-A_BAS	* DD CB    44	BIT	0,IXH		*
	dc.w	DDc45-A_BAS	* DD CB    45	BIT	0,IXL		*
	dc.w	DDc46-A_BAS	* DD CB  d 46	BIT	0,(IX+d)
	dcb.w	1-$47+$4B,NEXTA
	dc.w	DDc4C-A_BAS	* DD CB    4C	BIT	1,IXH		*
	dc.w	DDc4D-A_BAS	* DD CB    4D	BIT	1,IXL		*
	dc.w	DDc4E-A_BAS	* DD CB  d 4E	BIT	1,(IX+d)
	dcb.w	1-$4F+$53,NEXTA

	dc.w	DDc54-A_BAS	* DD CB    54	BIT	2,IXH		*
	dc.w	DDc55-A_BAS	* DD CB    55	BIT	2,IXL		*
	dc.w	DDc56-A_BAS	* DD CB  d 56	BIT	2,(IX+d)
	dcb.w	1-$57+$5B,NEXTA
	dc.w	DDc5C-A_BAS	* DD CB    5C	BIT	3,IXH		*
	dc.w	DDc5D-A_BAS	* DD CB    5D	BIT	3,IXL		*
	dc.w	DDc5E-A_BAS	* DD CB  d 5E	BIT	3,(IX+d)
	dcb.w	1-$5F+$63,NEXTA

	dc.w	DDc64-A_BAS	* DD CB    64	BIT	4,IXH		*
	dc.w	DDc65-A_BAS	* DD CB    65	BIT	4,IXL		*
	dc.w	DDc66-A_BAS	* DD CB  d 66	BIT	4,(IX+d)
	dcb.w	1-$67+$6B,NEXTA
	dc.w	DDc6C-A_BAS	* DD CB    6C	BIT	5,IXH		*
	dc.w	DDc6D-A_BAS	* DD CB    6D	BIT	5,IXL		*
	dc.w	DDc6E-A_BAS	* DD CB  d 6E	BIT	5,(IX+d)
	dcb.w	1-$6F+$73,NEXTA

	dc.w	DDc74-A_BAS	* DD CB    74	BIT	6,IXH		*
	dc.w	DDc75-A_BAS	* DD CB    75	BIT	6,IXL		*
	dc.w	DDc76-A_BAS	* DD CB  d 76	BIT	6,(IX+d)
	dcb.w	1-$77+$7B,NEXTA
	dc.w	DDc7C-A_BAS	* DD CB    7C	BIT	7,IXH		*
	dc.w	DDc7D-A_BAS	* DD CB    7D	BIT	7,IXL		*
	dc.w	DDc7E-A_BAS	* DD CB  d 7E	BIT	7,(IX+d)
	dcb.w	1-$7F+$7F,NEXTA

	dcb.w	1-$80+$83,NEXTA
	dc.w	DDc84-A_BAS	* DD CB    84	RES	0,IXH		*
	dc.w	DDc85-A_BAS	* DD CB    85	RES	0,IXL		*
	dc.w	DDc86-A_BAS	* DD CB  d 86	RES	0,(IX+d)
	dcb.w	1-$87+$8B,NEXTA
	dc.w	DDc8C-A_BAS	* DD CB    8C	RES	1,IXH		*
	dc.w	DDc8D-A_BAS	* DD CB    8D	RES	1,IXL		*
	dc.w	DDc8E-A_BAS	* DD CB  d 8E	RES	1,(IX+d)
	dcb.w	1-$8F+$93,NEXTA

	dc.w	DDc94-A_BAS	* DD CB    94	RES	2,IXH		*
	dc.w	DDc95-A_BAS	* DD CB    95	RES	2,IXL		*
	dc.w	DDc96-A_BAS	* DD CB  d 96	RES	2,(IX+d)
	dcb.w	1-$97+$9B,NEXTA
	dc.w	DDc9C-A_BAS	* DD CB    9C	RES	3,IXH		*
	dc.w	DDc9D-A_BAS	* DD CB    9D	RES	3,IXL		*
	dc.w	DDc9E-A_BAS	* DD CB  d 9E	RES	3,(IX+d)
	dcb.w	1-$9F+$A3,NEXTA

	dc.w	DDcA4-A_BAS	* DD CB    A4	RES	4,IXH		*
	dc.w	DDcA5-A_BAS	* DD CB    A5	RES	4,IXL		*
	dc.w	DDcA6-A_BAS	* DD CB  d A6	RES	4,(IX+d)
	dcb.w	1-$A7+$AB,NEXTA
	dc.w	DDcAC-A_BAS	* DD CB    AC	RES	5,IXH		*
	dc.w	DDcAD-A_BAS	* DD CB    AD	RES	5,IXL		*
	dc.w	DDcAE-A_BAS	* DD CB  d AE	RES	5,(IX+d)
	dcb.w	1-$AF+$B3,NEXTA

	dc.w	DDcB4-A_BAS	* DD CB    B4	RES	6,IXH		*
	dc.w	DDcB5-A_BAS	* DD CB    B5	RES	6,IXL		*
	dc.w	DDcB6-A_BAS	* DD CB  d B6	RES	6,(IX+d)
	dcb.w	1-$B7+$BB,NEXTA
	dc.w	DDcBC-A_BAS	* DD CB    BC	RES	7,IXH		*
	dc.w	DDcBD-A_BAS	* DD CB    BD	RES	7,IXL		*
	dc.w	DDcBE-A_BAS	* DD CB  d BE	RES	7,(IX+d)
	dcb.w	1-$BF+$C3,NEXTA

	dc.w	DDcC4-A_BAS	* DD CB    C4	SET	0,IXH		*
	dc.w	DDcC5-A_BAS	* DD CB    C5	SET	0,IXL		*
	dc.w	DDcC6-A_BAS	* DD CB  d C6	SET	0,(IX+d)
	dcb.w	1-$C7+$CB,NEXTA
	dc.w	DDcCC-A_BAS	* DD CB    CC	SET	1,IXH		*
	dc.w	DDcCD-A_BAS	* DD CB    CD	SET	1,IXL		*
	dc.w	DDcCE-A_BAS	* DD CB  d CE	SET	1,(IX+d)
	dcb.w	1-$CF+$D3,NEXTA

	dc.w	DDcD4-A_BAS	* DD CB    D4	SET	2,IXH		*
	dc.w	DDcD5-A_BAS	* DD CB    D5	SET	2,IXL		*
	dc.w	DDcD6-A_BAS	* DD CB  d D6	SET	2,(IX+d)
	dcb.w	1-$D7+$DB,NEXTA
	dc.w	DDcDC-A_BAS	* DD CB    DC	SET	3,IXH		*
	dc.w	DDcDD-A_BAS	* DD CB    DD	SET	3,IXL		*
	dc.w	DDcDE-A_BAS	* DD CB  d DE	SET	3,(IX+d)
	dcb.w	1-$DF+$E3,NEXTA

	dc.w	DDcE4-A_BAS	* DD CB    E4	SET	4,IXH		*
	dc.w	DDcE5-A_BAS	* DD CB    E5	SET	4,IXL		*
	dc.w	DDcE6-A_BAS	* DD CB  d E6	SET	4,(IX+d)
	dcb.w	1-$E7+$EB,NEXTA
	dc.w	DDcEC-A_BAS	* DD CB    EC	SET	5,IXH		*
	dc.w	DDcED-A_BAS	* DD CB    ED	SET	5,IXL		*
	dc.w	DDcEE-A_BAS	* DD CB  d EE	SET	5,(IX+d)
	dcb.w	1-$EF+$F3,NEXTA

	dc.w	DDcF4-A_BAS	* DD CB    F4	SET	6,IXH		*
	dc.w	DDcF5-A_BAS	* DD CB    F5	SET	6,IXL		*
	dc.w	DDcF6-A_BAS	* DD CB  d F6	SET	6,(IX+d)
	dcb.w	1-$F7+$FB,NEXTA
	dc.w	DDcFC-A_BAS	* DD CB    FC	SET	7,IXH		*
	dc.w	DDcFD-A_BAS	* DD CB    FD	SET	7,IXL		*
	dc.w	DDcFE-A_BAS	* DD CB  d FE	SET	7,(IX+d)
	dcb.w	1-$FF+$FF,NEXTA


*---------------------------------------*
*      jump table  OP CODE (FD xx)	*
*---------------------------------------*

T_FD:
	dcb.w	1-$00+$08,NEXT2Ay
	dc.w	FD_09-A_BAS	* FD 09		ADD	IY,BC
	dcb.w	1-$0A+$18,NEXT2Ay

	dc.w	FD_19-A_BAS	* FD 19		ADD	IY,DE
	dcb.w	1-$1A+$20,NEXT2Ay

	dc.w	FD_21-A_BAS	* FD 21		LD	IY,nn
	dc.w	FD_22-A_BAS	* FD 22		LD	(nn),IY
	dc.w	FD_23-A_BAS	* FD 23		INC	IY
	dc.w	FD_24-A_BAS	* FD 24		INC	IYH		*
	dc.w	FD_25-A_BAS	* FD 25		DEC	IYH		*
	dc.w	FD_26-A_BAS	* FD 26		LD	IYH,n		*
	dcb.w	1-$27+$28,NEXT2Ay
	dc.w	FD_29-A_BAS	* FD 29		ADD	IY,IY
	dc.w	FD_2A-A_BAS	* FD 2A		LD	IY,(nn)
	dc.w	FD_2B-A_BAS	* FD 2B		DEC	IY
	dc.w	FD_2C-A_BAS	* FD 2C		INC	IYL		*
	dc.w	FD_2D-A_BAS	* FD 2D		DEC	IYL		*
	dc.w	FD_2E-A_BAS	* FD 2E		LD	IYL,n		*
	dcb.w	1-$2F+$33,NEXT2Ay

	dc.w	FD_34-A_BAS	* FD 34		INC	(IY+d)
	dc.w	FD_35-A_BAS	* FD 35		DEC	(IY+d)
	dc.w	FD_36-A_BAS	* FD 36		LD	(IY+d),n
	dcb.w	1-$37+$38,NEXT2Ay
	dc.w	FD_39-A_BAS	* FD 39		ADD	IY,SP
	dcb.w	1-$3A+$43,NEXT2Ay

	dc.w	FD_44-A_BAS	* FD 44		LD	B,IYH		*
	dc.w	FD_45-A_BAS	* FD 45		LD	B,IYL		*
	dc.w	FD_46-A_BAS	* FD 46		LD	B,(IY+d)
	dcb.w	1-$47+$4B,NEXT2Ay
	dc.w	FD_4C-A_BAS	* FD 4C		LD	C,IYH		*
	dc.w	FD_4D-A_BAS	* FD 4D		LD	C,IYL		*
	dc.w	FD_4E-A_BAS	* FD 4E		LD	C,(IY+d)
	dcb.w	1-$4F+$53,NEXT2Ay

	dc.w	FD_54-A_BAS	* FD 54		LD	D,IYH		*
	dc.w	FD_55-A_BAS	* FD 55		LD	D,IYL		*
	dc.w	FD_56-A_BAS	* FD 56		LD	D,(IY+d)
	dcb.w	1-$57+$5B,NEXT2Ay
	dc.w	FD_5C-A_BAS	* FD 5C		LD	E,IYH		*
	dc.w	FD_5D-A_BAS	* FD 5D		LD	E,IYL		*
	dc.w	FD_5E-A_BAS	* FD 5E		LD	E,(IY+d)
	dcb.w	1-$5F+$63,NEXT2Ay

	dc.w	FD_64-A_BAS	* FD 64		LD	H,IYH		*
	dc.w	FD_65-A_BAS	* FD 65		LD	H,IYL		*
	dc.w	FD_66-A_BAS	* FD 66		LD	H,(IY+d)
	dcb.w	1-$67+$6B,NEXT2Ay
	dc.w	FD_6C-A_BAS	* FD 6C		LD	L,IYH		*
	dc.w	FD_6D-A_BAS	* FD 6D		LD	L,IYL		*
	dc.w	FD_6E-A_BAS	* FD 6E		LD	L,(IY+d)
	dcb.w	1-$6F+$6F,NEXT2Ay

	dc.w	FD_70-A_BAS	* FD 70		LD	(IY+d),B
	dc.w	FD_71-A_BAS	* FD 71		LD	(IY+d),C
	dc.w	FD_72-A_BAS	* FD 72		LD	(IY+d),D
	dc.w	FD_73-A_BAS	* FD 73		LD	(IY+d),E
	dc.w	FD_74-A_BAS	* FD 74		LD	(IY+d),H
	dc.w	FD_75-A_BAS	* FD 75		LD	(IY+d),L
	dcb.w	1-$76+$76,NEXT2Ay
	dc.w	FD_77-A_BAS	* FD 77		LD	(IY+d),A
	dcb.w	1-$78+$7B,NEXT2Ay
	dc.w	FD_7C-A_BAS	* FD 7C		LD	A,IYH		*
	dc.w	FD_7D-A_BAS	* FD 7D		LD	A,IYL		*
	dc.w	FD_7E-A_BAS	* FD 7E		LD	A,(IY+d)
	dcb.w	1-$7F+$7F,NEXT2Ay

	dcb.w	1-$80+$83,NEXTAy
	dc.w	FD_84-A_BAS	* FD 84		ADD	A,IYH		*
	dc.w	FD_85-A_BAS	* FD 85		ADD	A,IYL		*
	dc.w	FD_86-A_BAS	* FD 86		ADD	A,(IY+d)
	dcb.w	1-$87+$8B,NEXTAy
	dc.w	FD_8C-A_BAS	* FD 8C		ADC	A,IYH		*
	dc.w	FD_8D-A_BAS	* FD 8D		ADC	A,IYL		*
	dc.w	FD_8E-A_BAS	* FD 8E		ADC	A,(IY+d)
	dcb.w	1-$8F+$93,NEXTAy

	dc.w	FD_94-A_BAS	* FD 94		SUB	IYH		*
	dc.w	FD_95-A_BAS	* FD 95		SUB	IYL		*
	dc.w	FD_96-A_BAS	* FD 96		SUB	(IY+d)
	dcb.w	1-$97+$9B,NEXTAy
	dc.w	FD_9C-A_BAS	* FD 9C		SBC	A,IYH		*
	dc.w	FD_9D-A_BAS	* FD 9D		SBC	A,IYL		*
	dc.w	FD_9E-A_BAS	* FD 9E		SBC	A,(IY+d)
	dcb.w	1-$9F+$A3,NEXTAy

	dc.w	FD_A4-A_BAS	* FD A4		AND	IYH		*
	dc.w	FD_A5-A_BAS	* FD A5		AND	IYL		*
	dc.w	FD_A6-A_BAS	* FD A6		AND	(IY+d)	
	dcb.w	1-$A7+$AB,NEXTAy
	dc.w	FD_AC-A_BAS	* FD AC		XOR	IYH		*
	dc.w	FD_AD-A_BAS	* FD AD		XOR	IYL		*
	dc.w	FD_AE-A_BAS	* FD AE		XOR	(IY+d)
	dcb.w	1-$AF+$B3,NEXTAy

	dc.w	FD_B4-A_BAS	* FD B4		OR	IYH		*
	dc.w	FD_B5-A_BAS	* FD B5		OR	IYL		*
	dc.w	FD_B6-A_BAS	* FD B6		OR	(IY+d)
	dcb.w	1-$B7+$BB,NEXTAy
	dc.w	FD_BC-A_BAS	* FD BC		CP	IYH		*
	dc.w	FD_BD-A_BAS	* FD BD		CP	IYL		*
	dc.w	FD_BE-A_BAS	* FD BE		CP	(IY+d)
	dcb.w	1-$BF+$CA,NEXTAy

	dc.w	FD_CB-A_BAS	* FD CB		$FD CB
	dcb.w	1-$CC+$E0,NEXTAy

	dc.w	FD_E1-A_BAS	* FD E1		POP	IY
	dcb.w	1-$E2+$E2,NEXTAy
	dc.w	FD_E3-A_BAS	* FD E3		EX	(SP),IY
	dcb.w	1-$E4+$E4,NEXTAy
	dc.w	FD_E5-A_BAS	* FD E5		PUSH	IY
	dcb.w	1-$E6+$E8,NEXTAy
	dc.w	FD_E9-A_BAS	* FD E9		JP	(IY)
	dcb.w	1-$EA+$F8,NEXTAy

	dc.w	FD_F9-A_BAS	* FD F9		LD	SP,IY
	dcb.w	1-$FA+$FF,NEXTAy

T_FDc:
	dcb.w	1-$00+$03,NEXTAy
	dc.w	FDc04-A_BAS	* FD CB    04	RLC	IYH		*
	dc.w	FDc05-A_BAS	* FD CB    05	RLC	IYL		*
	dc.w	FDc06-A_BAS	* FD CB  d 06	RLC	(IY+d)
	dcb.w	1-$07+$0B,NEXTAy
	dc.w	FDc0C-A_BAS	* FD CB    0C	RRC	IYH		*
	dc.w	FDc0D-A_BAS	* FD CB    0D	RRC	IYL		*
	dc.w	FDc0E-A_BAS	* FD CB  d 0E	RRC	(IY+d)
	dcb.w	1-$0F+$13,NEXTAy

	dc.w	FDc14-A_BAS	* FD CB    14	RL	IYH		*
	dc.w	FDc15-A_BAS	* FD CB    15	RL	IYL		*
	dc.w	FDc16-A_BAS	* FD CB  d 16	RL	(IY+d)
	dcb.w	1-$17+$1B,NEXTAy
	dc.w	FDc1C-A_BAS	* FD CB    1C	RR	IYH		*
	dc.w	FDc1D-A_BAS	* FD CB    1D	RR	IYL		*
	dc.w	FDc1E-A_BAS	* FD CB  d 1E	RR	(IY+d)
	dcb.w	1-$1F+$23,NEXTAy

	dc.w	FDc24-A_BAS	* FD CB    24	SLA	IYH		*
	dc.w	FDc25-A_BAS	* FD CB    25	SLA	IYL		*
	dc.w	FDc26-A_BAS	* FD CB  d 26	SLA	(IY+d)
	dcb.w	1-$27+$2B,NEXTAy
	dc.w	FDc2C-A_BAS	* FD CB    2C	SRA	IYH		*
	dc.w	FDc2D-A_BAS	* FD CB    2D	SRA	IYL		*
	dc.w	FDc2E-A_BAS	* FD CB  d 2E	SRA	(IY+d)
	dcb.w	1-$2F+$3B,NEXTAy

	dc.w	FDc3C-A_BAS	* FD CB    3C	SRL	IYH		*
	dc.w	FDc3D-A_BAS	* FD CB    3D	SRL	IYL		*
	dc.w	FDc3E-A_BAS	* FD CB  d 3E	SRL	(IY+d)
	dcb.w	1-$3F+$43,NEXTAy

	dc.w	FDc44-A_BAS	* FD CB    44	BIT	0,IYH		*
	dc.w	FDc45-A_BAS	* FD CB    45	BIT	0,IYL		*
	dc.w	FDc46-A_BAS	* FD CB  d 46	BIT	0,(IY+d)
	dcb.w	1-$47+$4B,NEXTAy
	dc.w	FDc4C-A_BAS	* FD CB    4C	BIT	1,IYH		*
	dc.w	FDc4D-A_BAS	* FD CB    4D	BIT	1,IYL		*
	dc.w	FDc4E-A_BAS	* FD CB  d 4E	BIT	1,(IY+d)
	dcb.w	1-$4F+$53,NEXTAy

	dc.w	FDc54-A_BAS	* FD CB    54	BIT	2,IYH		*
	dc.w	FDc55-A_BAS	* FD CB    55	BIT	2,IYL		*
	dc.w	FDc56-A_BAS	* FD CB  d 56	BIT	2,(IY+d)
	dcb.w	1-$57+$5B,NEXTAy
	dc.w	FDc5C-A_BAS	* FD CB    5C	BIT	3,IYH		*
	dc.w	FDc5D-A_BAS	* FD CB    5D	BIT	3,IYL		*
	dc.w	FDc5E-A_BAS	* FD CB  d 5E	BIT	3,(IY+d)
	dcb.w	1-$5F+$63,NEXTAy

	dc.w	FDc64-A_BAS	* FD CB    64	BIT	4,IYH		*
	dc.w	FDc65-A_BAS	* FD CB    65	BIT	4,IYL		*
	dc.w	FDc66-A_BAS	* FD CB  d 66	BIT	4,(IY+d)
	dcb.w	1-$67+$6B,NEXTAy
	dc.w	FDc6C-A_BAS	* FD CB    6C	BIT	5,IYH		*
	dc.w	FDc6D-A_BAS	* FD CB    6D	BIT	5,IYL		*
	dc.w	FDc6E-A_BAS	* FD CB  d 6E	BIT	5,(IY+d)
	dcb.w	1-$6F+$73,NEXTAy

	dc.w	FDc74-A_BAS	* FD CB    74	BIT	6,IYH		*
	dc.w	FDc75-A_BAS	* FD CB    75	BIT	6,IYL		*
	dc.w	FDc76-A_BAS	* FD CB  d 76	BIT	6,(IY+d)
	dcb.w	1-$77+$7B,NEXTAy
	dc.w	FDc7C-A_BAS	* FD CB    7C	BIT	7,IYH		*
	dc.w	FDc7D-A_BAS	* FD CB    7D	BIT	7,IYL		*
	dc.w	FDc7E-A_BAS	* FD CB  d 7E	BIT	7,(IY+d)
	dcb.w	1-$7F+$7F,NEXTAy

	dcb.w	1-$80+$83,NEXTAy
	dc.w	FDc84-A_BAS	* FD CB    84	RES	0,IYH		*
	dc.w	FDc85-A_BAS	* FD CB    85	RES	0,IYL		*
	dc.w	FDc86-A_BAS	* FD CB  d 86	RES	0,(IY+d)
	dcb.w	1-$87+$8B,NEXTAy
	dc.w	FDc8C-A_BAS	* FD CB    8C	RES	1,IYH		*
	dc.w	FDc8D-A_BAS	* FD CB    8D	RES	1,IYL		*
	dc.w	FDc8E-A_BAS	* FD CB  d 8E	RES	1,(IY+d)
	dcb.w	1-$8F+$93,NEXTAy

	dc.w	FDc94-A_BAS	* FD CB    94	RES	2,IYH		*
	dc.w	FDc95-A_BAS	* FD CB    95	RES	2,IYL		*
	dc.w	FDc96-A_BAS	* FD CB  d 96	RES	2,(IY+d)
	dcb.w	1-$97+$9B,NEXTAy
	dc.w	FDc9C-A_BAS	* FD CB    9C	RES	3,IYH		*
	dc.w	FDc9D-A_BAS	* FD CB    9D	RES	3,IYL		*
	dc.w	FDc9E-A_BAS	* FD CB  d 9E	RES	3,(IY+d)
	dcb.w	1-$9F+$A3,NEXTAy

	dc.w	FDcA4-A_BAS	* FD CB    A4	RES	4,IYH		*
	dc.w	FDcA5-A_BAS	* FD CB    A5	RES	4,IYL		*
	dc.w	FDcA6-A_BAS	* FD CB  d A6	RES	4,(IY+d)
	dcb.w	1-$A7+$AB,NEXTAy
	dc.w	FDcAC-A_BAS	* FD CB    AC	RES	5,IYH		*
	dc.w	FDcAD-A_BAS	* FD CB    AD	RES	5,IYL		*
	dc.w	FDcAE-A_BAS	* FD CB  d AE	RES	5,(IY+d)
	dcb.w	1-$AF+$B3,NEXTAy

	dc.w	FDcB4-A_BAS	* FD CB    B4	RES	6,IYH		*
	dc.w	FDcB5-A_BAS	* FD CB    B5	RES	6,IYL		*
	dc.w	FDcB6-A_BAS	* FD CB  d B6	RES	6,(IY+d)
	dcb.w	1-$B7+$BB,NEXTAy
	dc.w	FDcBC-A_BAS	* FD CB    BC	RES	7,IYH		*
	dc.w	FDcBD-A_BAS	* FD CB    BD	RES	7,IYL		*
	dc.w	FDcBE-A_BAS	* FD CB  d BE	RES	7,(IY+d)
	dcb.w	1-$BF+$C3,NEXTAy

	dc.w	FDcC4-A_BAS	* FD CB    C4	SET	0,IYH		*
	dc.w	FDcC5-A_BAS	* FD CB    C5	SET	0,IYL		*
	dc.w	FDcC6-A_BAS	* FD CB  d C6	SET	0,(IY+d)
	dcb.w	1-$C7+$CB,NEXTAy
	dc.w	FDcCC-A_BAS	* FD CB    CC	SET	1,IYH		*
	dc.w	FDcCD-A_BAS	* FD CB    CD	SET	1,IYL		*
	dc.w	FDcCE-A_BAS	* FD CB  d CE	SET	1,(IY+d)
	dcb.w	1-$CF+$D3,NEXTAy

	dc.w	FDcD4-A_BAS	* FD CB    D4	SET	2,IYH		*
	dc.w	FDcD5-A_BAS	* FD CB    D5	SET	2,IYL		*
	dc.w	FDcD6-A_BAS	* FD CB  d D6	SET	2,(IY+d)
	dcb.w	1-$D7+$DB,NEXTAy
	dc.w	FDcDC-A_BAS	* FD CB    DC	SET	3,IYH		*
	dc.w	FDcDD-A_BAS	* FD CB    DD	SET	3,IYL		*
	dc.w	FDcDE-A_BAS	* FD CB  d DE	SET	3,(IY+d)
	dcb.w	1-$DF+$E3,NEXTAy

	dc.w	FDcE4-A_BAS	* FD CB    E4	SET	4,IYH		*
	dc.w	FDcE5-A_BAS	* FD CB    E5	SET	4,IYL		*
	dc.w	FDcE6-A_BAS	* FD CB  d E6	SET	4,(IY+d)
	dcb.w	1-$E7+$EB,NEXTAy
	dc.w	FDcEC-A_BAS	* FD CB    EC	SET	5,IYH		*
	dc.w	FDcED-A_BAS	* FD CB    ED	SET	5,IYL		*
	dc.w	FDcEE-A_BAS	* FD CB  d EE	SET	5,(IY+d)
	dcb.w	1-$EF+$F3,NEXTAy

	dc.w	FDcF4-A_BAS	* FD CB    F4	SET	6,IYH		*
	dc.w	FDcF5-A_BAS	* FD CB    F5	SET	6,IYL		*
	dc.w	FDcF6-A_BAS	* FD CB  d F6	SET	6,(IY+d)
	dcb.w	1-$F7+$FB,NEXTAy
	dc.w	FDcFC-A_BAS	* FD CB    FC	SET	7,IYH		*
	dc.w	FDcFD-A_BAS	* FD CB    FD	SET	7,IYL		*
	dc.w	FDcFE-A_BAS	* FD CB  d FE	SET	7,(IY+d)
	dcb.w	1-$FF+$FF,NEXTAy


*---------------------------------------*
*      jump table  OP CODE (ED xx)	*
*---------------------------------------*

T_ED:
	dc.w	ED_00-A_BAS	* ED 00
	dcb.w	1-$01+$3F,NEXT2A

	dc.w	ED_40-A_BAS	* ED 40		IN	B,(C)
	dc.w	ED_41-A_BAS	* ED 41		OUT	(C),B
	dc.w	ED_42-A_BAS	* ED 42		SBC	HL,BC
	dc.w	ED_43-A_BAS	* ED 43		LD	(nn),BC
	dc.w	ED_44-A_BAS	* ED 44		NEG
	dc.w	ED_45-A_BAS	* ED 45		RETN
	dc.w	ED_46-A_BAS	* ED 46		IM	0
	dc.w	ED_47-A_BAS	* ED 47		LD	I,A
	dc.w	ED_48-A_BAS	* ED 48		IN	C,(C)
	dc.w	ED_49-A_BAS	* ED 49		OUT	(C),C
	dc.w	ED_4A-A_BAS	* ED 4A		ADC	HL,BC
	dc.w	ED_4B-A_BAS	* ED 4B		LD	BC,(nn)
	dcb.w	1-$4C+$4C,NEXT2A
	dc.w	ED_4D-A_BAS	* ED 4D		RETI
	dcb.w	1-$4E+$4E,NEXT2A
	dc.w	ED_4F-A_BAS	* ED 4F		LD	R,A

	dc.w	ED_50-A_BAS	* ED 50		IN	D,(C)
	dc.w	ED_51-A_BAS	* ED 51		OUT	(C),D
	dc.w	ED_52-A_BAS	* ED 52		SBC	HL,DE
	dc.w	ED_53-A_BAS	* ED 53		LD	(nn),DE
	dcb.w	1-$54+$55,NEXT2A
	dc.w	ED_56-A_BAS	* ED 56		IM	1
	dc.w	ED_57-A_BAS	* ED 57		LD	A,I
	dc.w	ED_58-A_BAS	* ED 58		IN	E,(C)
	dc.w	ED_59-A_BAS	* ED 59		OUT	(C),E
	dc.w	ED_5A-A_BAS	* ED 5A		ADC	HL,DE
	dc.w	ED_5B-A_BAS	* ED 5B		LD	DE,(nn)
	dcb.w	1-$5C+$5D,NEXT2A
	dc.w	ED_5E-A_BAS	* ED 5E		IM	2
	dc.w	ED_5F-A_BAS	* ED 5F		LD	A,R

	dc.w	ED_60-A_BAS	* ED 60		IN	H,(C)
	dc.w	ED_61-A_BAS	* ED 61		OUT	(C),H
	dc.w	ED_62-A_BAS	* ED 62		SBC	HL,HL
	dcb.w	1-$63+$66,NEXT2A
	dc.w	ED_67-A_BAS	* ED 67		RRD
	dc.w	ED_68-A_BAS	* ED 68		IN	L,(C)
	dc.w	ED_69-A_BAS	* ED 69		OUT	(C),L
	dc.w	ED_6A-A_BAS	* ED 6A		ADC	HL,HL
	dcb.w	1-$6B+$6E,NEXT2A
	dc.w	ED_6F-A_BAS	* ED 6F		RLD

	dcb.w	1-$70+$71,NEXT2A
	dc.w	ED_72-A_BAS	* ED 72		SBC	HL,SP
	dc.w	ED_73-A_BAS	* ED 73		LD	(nn),SP
	dcb.w	1-$74+$77,NEXT2A
	dc.w	ED_78-A_BAS	* ED 78		IN	A,(C)
	dc.w	ED_79-A_BAS	* ED 79		OUT	(C),A
	dc.w	ED_7A-A_BAS	* ED 7A		ADC	HL,SP
	dc.w	ED_7B-A_BAS	* ED 7B		LD	SP,(nn)
	dcb.w	1-$7C+$7F,NEXT2A

	dcb.w	1-$80+$9F,NEXTA

	dc.w	ED_A0-A_BAS	* ED A0		LDI
	dc.w	ED_A1-A_BAS	* ED A1		CPI
	dc.w	ED_A2-A_BAS	* ED A2		INI
	dc.w	ED_A3-A_BAS	* ED A3		OUTI
	dcb.w	1-$A4+$A7,NEXTA
	dc.w	ED_A8-A_BAS	* ED A8		LDD
	dc.w	ED_A9-A_BAS	* ED A9		CPD
	dc.w	ED_AA-A_BAS	* ED AA		IND
	dc.w	ED_AB-A_BAS	* ED AB		OUTD
	dcb.w	1-$AC+$AF,NEXTA

	dc.w	ED_B0-A_BAS	* ED B0		LDIR
	dc.w	ED_B1-A_BAS	* ED B1		CPIR
	dc.w	ED_B2-A_BAS	* ED B2		INIR
	dc.w	ED_B3-A_BAS	* ED B3		OTIR
	dcb.w	1-$B4+$B7,NEXTA
	dc.w	ED_B8-A_BAS	* ED B8		LDDR
	dc.w	ED_B9-A_BAS	* ED B9		CPDR
	dc.w	ED_BA-A_BAS	* ED BA		INDR
	dc.w	ED_BB-A_BAS	* ED BB		OTDR
	dcb.w	1-$BC+$EC,NEXTA

	dc.w	ED_ED-A_BAS	* ED ED
	dcb.w	1-$EE+$FF,NEXTA
				endif

*---------------------------------------*
*	     jump table  ROM		*
*---------------------------------------*
if F_ROM=1
T_ROM:
	dc.w	$0002,z02-A_BAS		* 02		LD	(BC),A
	dc.w	$0012,z12-A_BAS		* 12		LD	(DE),A
	dc.w	$0022,z22-A_BAS		* 22		LD	(nn),HL
	dc.w	$0032,z32-A_BAS		* 32		LD	(nn),A
	dc.w	$0034,z34-A_BAS		* 34		INC	(HL)
	dc.w	$0035,z35-A_BAS		* 35		DEC	(HL)
	dc.w	$0036,z36-A_BAS		* 36		LD	(HL),n
	dc.w	$0070,z70-A_BAS		* 70		LD	(HL),B
	dc.w	$0071,z71-A_BAS		* 71		LD	(HL),C
	dc.w	$0072,z72-A_BAS		* 72		LD	(HL),D
	dc.w	$0073,z73-A_BAS		* 73		LD	(HL),E
	dc.w	$0074,z74-A_BAS		* 74		LD	(HL),H
	dc.w	$0075,z75-A_BAS		* 75		LD	(HL),L
	dc.w	$0077,z77-A_BAS		* 77		LD	(HL),A
	dc.w	$00C4,zC4-A_BAS		* C4		CALL	NZ,nn
	dc.w	$00C5,zC5-A_BAS		* C5		PUSH	BC
	dc.w	$00C7,zC7-A_BAS		* C7		RST	00H
	dc.w	$00CC,zCC-A_BAS		* CC		CALL	Z,nn
	dc.w	$00CD,zCD-A_BAS		* CD		CALL	nn
	dc.w	$00CF,zCF-A_BAS		* CF		RST	08H
	dc.w	$00D4,zD4-A_BAS		* D4		CALL	NC,nn
	dc.w	$00D5,zD5-A_BAS		* D5		PUSH	DE
	dc.w	$00D7,zD7-A_BAS		* D7		RST	10H
	dc.w	$00DC,zDC-A_BAS		* DC		CALL	C,nn
	dc.w	$00DF,zDF-A_BAS		* DF		RST	18H
	dc.w	$00E3,zE3-A_BAS		* E3		EX	(SP),HL
	dc.w	$00E4,zE4-A_BAS		* E4		CALL	PO,nn
	dc.w	$00E5,zE5-A_BAS		* E5		PUSH	HL
	dc.w	$00E7,zE7-A_BAS		* E7		RST	20H
	dc.w	$00EC,zEC-A_BAS		* EC		CALL	PE,nn
	dc.w	$00EF,zEF-A_BAS		* EF		RST	28H
	dc.w	$00F4,zF4-A_BAS		* F4		CALL	P,nn
	dc.w	$00F5,zF5-A_BAS		* F5		PUSH	AF
	dc.w	$00F7,zF7-A_BAS		* F7		RST	30H
	dc.w	$00FC,zFC-A_BAS		* FC		CALL	M,nn
	dc.w	$00FF,zFF-A_BAS		* FF		RST	38H
	dc.w	$0106,CB_06-A_BAS	* CB 06		RLC	(HL)
	dc.w	$010E,CB_0E-A_BAS	* CB 0E		RRC	(HL)
	dc.w	$0116,CB_16-A_BAS	* CB 16		RL	(HL)
	dc.w	$011E,CB_1E-A_BAS	* CB 1E		RR	(HL)
	dc.w	$0126,CB_26-A_BAS	* CB 26		SLA	(HL)
	dc.w	$012E,CB_2E-A_BAS	* CB 2E		SRA	(HL)
	dc.w	$013E,CB_3E-A_BAS	* CB 3E		SRL	(HL)
	dc.w	$0186,CB_86-A_BAS	* CB 86		RES	0,(HL)
	dc.w	$018E,CB_8E-A_BAS	* CB 8E		RES	1,(HL)
	dc.w	$0196,CB_96-A_BAS	* CB 96		RES	2,(HL)
	dc.w	$019E,CB_9E-A_BAS	* CB 9E		RES	3,(HL)
	dc.w	$01A6,CB_A6-A_BAS	* CB A6		RES	4,(HL)
	dc.w	$01AE,CB_AE-A_BAS	* CB AE		RES	5,(HL)
	dc.w	$01B6,CB_B6-A_BAS	* CB B6		RES	6,(HL)
	dc.w	$01BE,CB_BE-A_BAS	* CB BE		RES	7,(HL)
	dc.w	$01C6,CB_C6-A_BAS	* CB C6		SET	0,(HL)
	dc.w	$01CE,CB_CE-A_BAS	* CB CE		SET	1,(HL)
	dc.w	$01D6,CB_D6-A_BAS	* CB D6		SET	2,(HL)
	dc.w	$01DE,CB_DE-A_BAS	* CB DE		SET	3,(HL)
	dc.w	$01E6,CB_E6-A_BAS	* CB E6		SET	4,(HL)
	dc.w	$01EE,CB_EE-A_BAS	* CB EE		SET	5,(HL)
	dc.w	$01F6,CB_F6-A_BAS	* CB F6		SET	6,(HL)
	dc.w	$01FE,CB_FE-A_BAS	* CB FE		SET	7,(HL)
	dc.w	$0222,DD_22-A_BAS	* DD 22		LD	(nn),IX
	dc.w	$0234,DD_34-A_BAS	* DD 34		INC	(IX+d)
	dc.w	$0235,DD_35-A_BAS	* DD 35		DEC	(IX+d)
	dc.w	$0236,DD_36-A_BAS	* DD 36		LD	(IX+d),n
	dc.w	$0270,DD_70-A_BAS	* DD 70		LD	(IX+d),B
	dc.w	$0271,DD_71-A_BAS	* DD 71		LD	(IX+d),C
	dc.w	$0272,DD_72-A_BAS	* DD 72		LD	(IX+d),D
	dc.w	$0273,DD_73-A_BAS	* DD 73		LD	(IX+d),E
	dc.w	$0274,DD_74-A_BAS	* DD 74		LD	(IX+d),H
	dc.w	$0275,DD_75-A_BAS	* DD 75		LD	(IX+d),L
	dc.w	$0277,DD_77-A_BAS	* DD 77		LD	(IX+d),A
	dc.w	$02E3,DD_E3-A_BAS	* DD E3		EX	(SP),IX
	dc.w	$02E5,DD_E5-A_BAS	* DD E5		PUSH	IX
	dc.w	$0306,DDc06-A_BAS	* DD CB  d 06	RLC	(IX+d)
	dc.w	$030E,DDc0E-A_BAS	* DD CB  d 0E	RRC	(IX+d)
	dc.w	$0316,DDc16-A_BAS	* DD CB  d 16	RL	(IX+d)
	dc.w	$031E,DDc1E-A_BAS	* DD CB  d 1E	RR	(IX+d)
	dc.w	$0326,DDc26-A_BAS	* DD CB  d 26	SLA	(IX+d)
	dc.w	$032E,DDc2E-A_BAS	* DD CB  d 2E	SRA	(IX+d)
	dc.w	$033E,DDc3E-A_BAS	* DD CB  d 3E	SRL	(IX+d)
	dc.w	$0386,DDc86-A_BAS	* DD CB  d 86	RES	0,(IX+d)
	dc.w	$038E,DDc8E-A_BAS	* DD CB  d 8E	RES	1,(IX+d)
	dc.w	$0396,DDc96-A_BAS	* DD CB  d 96	RES	2,(IX+d)
	dc.w	$039E,DDc9E-A_BAS	* DD CB  d 9E	RES	3,(IX+d)
	dc.w	$03A6,DDcA6-A_BAS	* DD CB  d A6	RES	4,(IX+d)
	dc.w	$03AE,DDcAE-A_BAS	* DD CB  d AE	RES	5,(IX+d)
	dc.w	$03B6,DDcB6-A_BAS	* DD CB  d B6	RES	6,(IX+d)
	dc.w	$03BE,DDcBE-A_BAS	* DD CB  d BE	RES	7,(IX+d)
	dc.w	$03C6,DDcC6-A_BAS	* DD CB  d C6	SET	0,(IX+d)
	dc.w	$03CE,DDcCE-A_BAS	* DD CB  d CE	SET	1,(IX+d)
	dc.w	$03D6,DDcD6-A_BAS	* DD CB  d D6	SET	2,(IX+d)
	dc.w	$03DE,DDcDE-A_BAS	* DD CB  d DE	SET	3,(IX+d)
	dc.w	$03E6,DDcE6-A_BAS	* DD CB  d E6	SET	4,(IX+d)
	dc.w	$03EE,DDcEE-A_BAS	* DD CB  d EE	SET	5,(IX+d)
	dc.w	$03F6,DDcF6-A_BAS	* DD CB  d F6	SET	6,(IX+d)
	dc.w	$03FE,DDcFE-A_BAS	* DD CB  d FE	SET	7,(IX+d)
	dc.w	$0422,FD_22-A_BAS	* FD 22		LD	(nn),IY
	dc.w	$0434,FD_34-A_BAS	* FD 34		INC	(IY+d)
	dc.w	$0435,FD_35-A_BAS	* FD 35		DEC	(IY+d)
	dc.w	$0436,FD_36-A_BAS	* FD 36		LD	(IY+d),n
	dc.w	$0470,FD_70-A_BAS	* FD 70		LD	(IY+d),B
	dc.w	$0471,FD_71-A_BAS	* FD 71		LD	(IY+d),C
	dc.w	$0472,FD_72-A_BAS	* FD 72		LD	(IY+d),D
	dc.w	$0473,FD_73-A_BAS	* FD 73		LD	(IY+d),E
	dc.w	$0474,FD_74-A_BAS	* FD 74		LD	(IY+d),H
	dc.w	$0475,FD_75-A_BAS	* FD 75		LD	(IY+d),L
	dc.w	$0477,FD_77-A_BAS	* FD 77		LD	(IY+d),A
	dc.w	$04E3,FD_E3-A_BAS	* FD E3		EX	(SP),IY
	dc.w	$04E5,FD_E5-A_BAS	* FD E5		PUSH	IY
	dc.w	$0506,FDc06-A_BAS	* FD CB  d 06	RLC	(IY+d)
	dc.w	$050E,FDc0E-A_BAS	* FD CB  d 0E	RRC	(IY+d)
	dc.w	$0516,FDc16-A_BAS	* FD CB  d 16	RL	(IY+d)
	dc.w	$051E,FDc1E-A_BAS	* FD CB  d 1E	RR	(IY+d)
	dc.w	$0526,FDc26-A_BAS	* FD CB  d 26	SLA	(IY+d)
	dc.w	$052E,FDc2E-A_BAS	* FD CB  d 2E	SRA	(IY+d)
	dc.w	$053E,FDc3E-A_BAS	* FD CB  d 3E	SRL	(IY+d)
	dc.w	$0586,FDc86-A_BAS	* FD CB  d 86	RES	0,(IY+d)
	dc.w	$058E,FDc8E-A_BAS	* FD CB  d 8E	RES	1,(IY+d)
	dc.w	$0596,FDc96-A_BAS	* FD CB  d 96	RES	2,(IY+d)
	dc.w	$059E,FDc9E-A_BAS	* FD CB  d 9E	RES	3,(IY+d)
	dc.w	$05A6,FDcA6-A_BAS	* FD CB  d A6	RES	4,(IY+d)
	dc.w	$05AE,FDcAE-A_BAS	* FD CB  d AE	RES	5,(IY+d)
	dc.w	$05B6,FDcB6-A_BAS	* FD CB  d B6	RES	6,(IY+d)
	dc.w	$05BE,FDcBE-A_BAS	* FD CB  d BE	RES	7,(IY+d)
	dc.w	$05C6,FDcC6-A_BAS	* FD CB  d C6	SET	0,(IY+d)
	dc.w	$05CE,FDcCE-A_BAS	* FD CB  d CE	SET	1,(IY+d)
	dc.w	$05D6,FDcD6-A_BAS	* FD CB  d D6	SET	2,(IY+d)
	dc.w	$05DE,FDcDE-A_BAS	* FD CB  d DE	SET	3,(IY+d)
	dc.w	$05E6,FDcE6-A_BAS	* FD CB  d E6	SET	4,(IY+d)
	dc.w	$05EE,FDcEE-A_BAS	* FD CB  d EE	SET	5,(IY+d)
	dc.w	$05F6,FDcF6-A_BAS	* FD CB  d F6	SET	6,(IY+d)
	dc.w	$05FE,FDcFE-A_BAS	* FD CB  d FE	SET	7,(IY+d)
	dc.w	$0643,ED_43-A_BAS	* ED 43		LD	(nn),BC
	dc.w	$0653,ED_53-A_BAS	* ED 53		LD	(nn),DE
	dc.w	$0667,ED_67-A_BAS	* ED 67		RRD
	dc.w	$066F,ED_6F-A_BAS	* ED 6F		RLD
	dc.w	$0673,ED_73-A_BAS	* ED 73		LD	(nn),SP
	dc.w	$06A0,ED_A0-A_BAS	* ED A0		LDI
	dc.w	$06A2,ED_A2-A_BAS	* ED A2		INI
	dc.w	$06A8,ED_A8-A_BAS	* ED A8		LDD
	dc.w	$06AA,ED_AA-A_BAS	* ED AA		IND
	dc.w	$06B0,ED_B0-A_BAS	* ED B0		LDIR
	dc.w	$06B2,ED_B2-A_BAS	* ED B2		INIR
	dc.w	$06B8,ED_B8-A_BAS	* ED B8		LDDR
	dc.w	$06BA,ED_BA-A_BAS	* ED BA		INDR

	dc.w	$FFFF
endif

*---------------------------------------*
*      jump table  NEI/INT/NMI/RES	*
*---------------------------------------*
				if F_ROM=0
T_NEI:	dcb.w	$100,.loww.(NEI-A_BAS)

T_INT:	ds.w	$100,0

T_NMI:	dcb.w	     $75,.loww.(NMI-A_BAS)
	dcb.w	     $01,.loww.(NMI_76-A_BAS)
	dcb.w	$100-$76,.loww.(NMI-A_BAS)

T_RES:	dcb.w	$100,.loww.(RESET-A_BAS)
				endif

*---------------------------------------*
* main memory & WOM (Write Only Memory)	*
*---------------------------------------*

	.bss
				if F_ROM=0
	.even
	ds.b	$90
A_MEM:	ds.b	$10000
	ds.b	$90
				endif

if F_ROM=1
	.even
A_WOM:	ds.b	$8000
	ds.b	1
	.even
endif


	.end
