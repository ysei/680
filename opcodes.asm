;;; ========================================================================
;;; ========================================================================
;;;      ___   ___                    ======= ==============================
;;;  ___( _ ) / _ \   emulation core    ====================================
;;; |_  / _ \| | | |  emulation core     ===================================
;;;  / ( (_) | |_| |  emulation core      ==================================
;;; /___\___/ \___/   emulation core       =================================
;;;                                   ======= ==============================
;;; ========================================================================
;;; ========================================================================

;;; http://z80.info/z80oplist.txt

	;; == Memory Macros ================================================

	;; Macro to read a byte from main memory at register \1.  Puts
	;; the byte read in \2.
FETCHB	MACRO
	move.w	\1,d1
	bsr	deref
	move.b	(a0),\2
	ENDM

	;; Macro to write a byte in \1 to main memory at \2
PUTB	MACRO
	move.w	\2,d1
	bsr	deref
	move.b	\1,(a0)
	ENDM

	;; Macro to read a word from main memory at register \1
	;; (unaligned).  Puts the word read in \2.
FETCHW	MACRO			;  ?/16
	move.w	\1,d1		;  4/2
	bsr	deref		;  ?/4
	;; XXX SPEED
	move.b	(a0)+,d2
	move.b	(a0),\2
	rol.w	#8,\2
	move.b	d2,\2
	ENDM

	;; Macro to write a word in \1 to main memory at \2 (regs only)
PUTW	MACRO			; 
	move.w	\2,d1
	bsr	deref
	move.w	\1,d0
	move.b	d0,(a0)+
	LOHI	d0
	move.b	d0,(a0)
	ENDM

	;; Push the word in \1 (register) using stack register a4.
	;; Sadly, I can't trust the stack register to be aligned.
	;; Destroys d2.

	;;   (SP-2) <- \1_l
	;;   (SP-1) <- \1_h
	;;   SP <- SP - 2
PUSHW	MACRO
	move.w	\1,d2
	LOHI	d2		;slow
	move.b	d2,-(a4)	; high byte
	move.b	\1,-(a4)	; low byte
	ENDM

	;; Pop the word at the top of stack a4 into \1.
	;; Destroys d0.

	;;   \1_h <- (SP+1)
	;;   \1_l <- (SP)
	;;   SP <- SP + 2
POPW	MACRO
	move.b	(esp)+,\1
	LOHI	\1		;slow
	move.b	(esp)+,\1	; high byte
	HILO	\1		;slow
	ENDM

	;; == Immediate Memory Macros ==

	;; Macro to read an immediate byte into \1.
FETCHBI	MACRO			; 8 cycles, 2 bytes
	move.b	(epc)+,\1	; 8/2
	ENDM

	;; Macro to read an immediate word (unaligned) into \1.
FETCHWI	MACRO			; 42 cycles, 8 bytes
	;; XXX SPEED
	move.b	(epc)+,d2
	move.b	(epc)+,\1
	rol.w	#8,\1
	move.b	d2,\1
	ENDM

	;; == Common Opcode Macros =========================================

	;; To align opcode routines.
_align	SET	0

START	MACRO
	ORG	emu_plain_op+_align
_align	SET	_align+$40
	ENDM

	;; LOHI/HILO are hideously slow for instructions used often.
	;; Interleave registers instead:
	;;
	;; d4 = [B' B  C' C]
	;;
	;; Thus access to B is fast (swap d4) while access to BC is
	;; slow.

	;; When you want to use the high reg of a pair, use this first
LOHI	MACRO			; 22 cycles, 2 bytes
	ror.w	#8,\1		; 22/2
	ENDM

	;; Then do your shit and finish with this
HILO	MACRO			; 22 cycles, 2 bytes
	rol.w	#8,\1
	ENDM

	;; Rearrange a register: ABCD -> ACBD.
WORD	MACRO
	move.l	\1,-(sp)	;12 cycles / 2 bytes
	movep.w	0(sp),\1	;16 cycles / 4 bytes
	swap	\1		; 4 cycles / 2 bytes
	movep.w	1(sp),\1	;16 cycles / 4 bytes
	addq	#4,sp		; 4 cycles / 2 bytes
	;; overhead:		 52 cycles /14 bytes
	ENDM

	;; == Special Opcode Macros ========================================

	;; Do an ADD \1,\2
F_ADD_W	MACRO
	ENDM
	;; Do an SUB \1,\2
F_SUB_W	MACRO
	ENDM

	;; INC and DEC macros
F_INC_B	MACRO
	move.b	#1,f_tmp_byte-flag_storage(a3)
	move.b	#1,f_tmp_src_b-flag_storage(a3)
	move.b	\1,f_tmp_dst_b-flag_storage(a3)
	addq	#1,\1
	moveq	#2,d0
	F_CLEAR	d0
	F_OVFL
	ENDM

F_DEC_B	MACRO
	move.b	#1,f_tmp_byte-flag_storage(a3)
	st	f_tmp_src_b-flag_storage(a3) ;; why did I do this?
	move.b	\1,f_tmp_dst_b-flag_storage(a3)
	subq	#1,\1
	F_SET	#2
	ENDM

F_INC_W	MACRO
	addq.w	#1,\1
	ENDM

F_DEC_W	MACRO
	subq.w	#1,\1
	ENDM

	;; I might be able to unify rotation flags or maybe use a
	;; lookup table


	;; This is run at the end of every instruction routine.
done:
	clr.w	d0		; 4 cycles / 2 bytes
	move.b	(epc)+,d0	; 8 cycles / 2 bytes
	move.b	d0,$4c00+32*(128/8)
	rol.w	#6,d0		;18 cycles / 2 bytes
	jmp	0(a5,d0.w)	;14 cycles / 4 bytes
	;; overhead:		 42 cycles /10 bytes


DONE	MACRO
	bra	done
	ENDM

	;; Timing correction for more precise emulation
	;;
	;; \1 is number of tstates the current instruction should take
	;; \2 is number of cycles taken already
TIME	MACRO
	ENDM

	CNOP	0,32

emu_plain_op:			; Size(bytes) Time(cycles)
	START
emu_op_00:			; S0 T0
	;; NOP
	TIME	4,0
	DONE

	START
emu_op_01:			; S12 T36
	;; LD	BC,immed.w
	;; Read a word and put it in BC
	;; No flags
	HOLD_INTS
	FETCHWI	ebc
	CONTINUE_INTS
	DONE

	START
emu_op_02:			; S4 T14
	;; LD	(BC),A
	;; (BC) <- A
	;; No flags
	PUTB	eaf,ebc
	DONE

	START
emu_op_03:			; S2 T4
	;; INC	BC
	;; BC <- BC+1
	;; No flags
	F_INC_W	ebc
	DONE

	START
emu_op_04:
	;; INC	B
	;; B <- B+1
	LOHI	ebc
	F_INC_B	ebc
	HILO	ebc
	DONE

	START
emu_op_05:
	;; DEC	B
	;; B <- B-1
	LOHI	ebc
	F_DEC_B	ebc
	HILO	ebc
	DONE			;nok

	START
emu_op_06:			; S10 T26
	;; LD	B,immed.b
	;; Read a byte and put it in B
	;; B <- immed.b
	;; No flags
	HOLD_INTS
	LOHI	ebc
	FETCHBI	ebc
	CONTINUE_INTS
	HILO	ebc
	DONE			;nok

	START
emu_op_07:			; S2 T4
	;; RLCA
	;; Rotate A left, carry bit gets top bit
	;; Flags: H,N=0; C aff.
	;; XXX flags
	rol.b	#1,eaf
	DONE			;nok

	START
emu_op_08:			; S2 T4
	;; EX	AF,AF'
	;; No flags
	;; XXX AF
	swap	eaf
	DONE			;nok

	START
emu_op_09:
	;; ADD	HL,BC
	;; HL <- HL+BC
	;; Flags: H, C aff.; N=0
	F_ADD_W	ebc,ehl
	DONE			;nok

	START
emu_op_0a:			; S4 T14
	;; LD	A,(BC)
	;; A <- (BC)
	;; No flags
	FETCHB	ebc,eaf
	DONE

	START
emu_op_0b:			; S2 T4
	;; DEC	BC
	;; BC <- BC-1
	;; No flags
	F_DEC_W	ebc
	DONE			;nok

	START
emu_op_0c:
	;; INC	C
	;; C <- C+1
	;; Flags: S,Z,H aff.; P=overflow, N=0
	F_INC_B	ebc
	DONE			;nok

	START
emu_op_0d:
	;; DEC	C
	;; C <- C-1
	;; Flags: S,Z,H aff., P=overflow, N=1
	F_DEC_B	ebc
	DONE			;nok

	START
emu_op_0e:			; S6 T18
	;; LD	C,immed.b
	;; No flags
	HOLD_INTS
	FETCHBI	ebc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_0f:
	;; RRCA
	;; Rotate A right, carry bit gets top bit
	;; Flags: H,N=0; C aff.
	;; XXX FLAGS
	ror.b	#1,eaf
	DONE			;nok

	START
emu_op_10:			; S32
	;; DJNZ	immed.w
	;; Decrement B
	;;  and branch by immed.b
	;;  if B not zero
	;; No flags
	HOLD_INTS
	LOHI	ebc
	subq.b	#1,ebc
	beq.s	end_10	; slooooow
	FETCHBI	d1
	move.l	epc,a0
	bsr	underef
	add.w	d1,d0		; ??? Can I avoid underef/deref cycle?
	bsr	deref
	move.l	a0,epc
end_10:
	HILO	ebc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_11:			; S
	;; LD	DE,immed.w
	;; No flags
	HOLD_INTS
	FETCHWI	ede
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_12:
	;; LD	(DE),A
	;; No flags
	move.w	ede,d0
	rol.w	#8,d0
	FETCHB	d0,eaf
	DONE			;nok

	START
emu_op_13:
	;; INC	DE
	;; No flags
	F_INC_W	ede
	DONE			;nok

	START
emu_op_14:
	;; INC	D
	;; Flags: S,Z,H aff.; P=overflow, N=0
	LOHI	ede
	F_INC_B	ede
	HILO	ede
	DONE			;nok

	START
emu_op_15:
	;; DEC	D
	;; Flags: S,Z,H aff.; P=overflow, N=1
	LOHI	ede
	F_DEC_B	ede
	HILO	ede
	DONE			;nok

	START
emu_op_16:
	;; LD D,immed.b
	;; No flags
	HOLD_INTS
	LOHI	ede
	FETCHBI	ede
	CONTINUE_INTS
	HILO	ede
	DONE			;nok

	START
emu_op_17:
	;; RLA
	;; Flags: P,N=0; C aff.
	;; XXX flags
	roxl.b	#1,eaf
	DONE			;nok

	START
emu_op_18:
	;; JR	immed.b
	;; PC <- immed.b
	;; Branch relative by a signed immediate byte
	;; No flags
	HOLD_INTS
	clr.w	d1
	FETCHBI	d1
	move.l	epc,a0
	bsr	underef
	add.w	d0,d1		; ??? Can I avoid underef/deref cycle?
	bsr	deref
	move.l	a0,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_19:
	;; ADD	HL,DE
	;; HL <- HL+DE
	;; Flags: H,C aff,; N=0
	F_ADD_W	ede,ehl
	DONE			;nok

	START
emu_op_1a:
	;; LD	A,(DE)
	;; A <- (DE)
	;; No flags
	FETCHB	ede,eaf
	DONE			;nok

	START
emu_op_1b:
	;; DEC	DE
	;; No flags
	subq.w	#1,ede
	DONE			;nok

	START
emu_op_1c:
	;; INC	E
	;; Flags: S,Z,H aff.; P=overflow; N=0
	F_INC_B	ede
	DONE			;nok

	START
emu_op_1d:
	;; DEC	E
	;; Flags: S,Z,H aff.; P=overflow, N=1
	F_DEC_B	ede
	DONE			;nok

	START
emu_op_1e:
	;; LD	E,immed.b
	;; No flags
	HOLD_INTS
	FETCHBI	ede
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_1f:
	;; RRA
	;; Flags: H,N=0; C aff.
	;; XXX FLAGS
	roxr.b	#1,eaf
	DONE			;nok

	START
emu_op_20:
	;; JR	NZ,immed.b
	;; if ~Z,
	;;  PC <- PC+immed.b
	;; No flags
	HOLD_INTS
	bsr	f_norm_z
	;; if the emulated Z flag is set, this will be clear
	beq	emu_op_18	; branch taken: Z reset -> eq (zero set)
	add.l	#1,epc		; skip over the immediate byte
	CONTINUE_INTS
	DONE

	START
emu_op_21:
	;; LD	HL,immed.w
	;; No flags
	HOLD_INTS
	FETCHWI	ehl
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_22:
	;; LD	immed.w,HL
	;; (address) <- HL
	;; No flags
	HOLD_INTS
	FETCHWI	d1
	CONTINUE_INTS
	PUTW	ehl,d1
	DONE			;nok

	START
emu_op_23:
	;; INC	HL
	;; No flags
	addq.w	#1,ehl
	DONE			;nok

	START
emu_op_24:
	;; INC	H
	;; Flags: S,Z,H aff.; P=overflow, N=0
	LOHI	ehl
	F_INC_B	ehl
	HILO	ehl
	DONE			;nok

	START
emu_op_25:
	;; DEC	H
	;; Flags: S,Z,H aff.; P=overflow, N=1
	LOHI	ehl
	F_DEC_B	ehl
	HILO	ehl
	DONE			;nok

	START
emu_op_26:
	;; LD	H,immed.b
	;; No flags
	HOLD_INTS
	LOHI	ehl
	FETCHBI	ehl
	CONTINUE_INTS
	HILO	ehl
	DONE			;nok

	START
emu_op_27:
	;; DAA
	;; Decrement, adjust accum
	;; http://www.z80.info/z80syntx.htm#DAA
	;; Flags: oh lord they're fucked up
	;; XXX DO THIS

	F_PAR	eaf
	DONE			;nok

	START
emu_op_28:
	;; JR Z,immed.b
	;; If zero
	;;  PC <- PC+immed.b
	;; SPEED can be made faster
	;; No flags
	HOLD_INTS
	bsr	f_norm_z
	bne	emu_op_18
	add.l	#1,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_29:
	;; ADD	HL,HL
	;; No flags
	F_ADD_W	ehl,ehl
	DONE			;nok

	START
emu_op_2a:
	;; LD	HL,(immed.w)
	;; address is absolute
	HOLD_INTS
	FETCHWI	d1
	CONTINUE_INTS
	FETCHW	d1,ehl
	DONE			;nok

	;; XXX TOO LONG

	START
emu_op_2b:
	;; DEC	HL
	F_DEC_W	ehl
	DONE			;nok

	START
emu_op_2c:
	;; INC	L
	F_INC_B	ehl
	DONE			;nok

	START
emu_op_2d:
	;; DEC	L
	F_DEC_B	ehl
	DONE			;nok

	START
emu_op_2e:
	;; LD	L,immed.b
	HOLD_INTS
	FETCHBI	ehl
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_2f:
	;; CPL
	;; A <- NOT A
	;; XXX flags
	not.b	eaf
	DONE			;nok

	START
emu_op_30:
	;; JR	NC,immed.b
	;; If carry clear
	;;  PC <- PC+immed.b
	bsr	f_norm_c
	beq	emu_op_18	; branch taken: carry clear
	add.l	#1,epc
	DONE

	START
emu_op_31:
	;; LD	SP,immed.w
	HOLD_INTS
	FETCHWI	d1
	bsr	deref
	movea.l	a0,esp
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_32:
	;; LD	(immed.w),A
	;; store indirect
	HOLD_INTS
	FETCHWI	d1
	CONTINUE_INTS
	rol.w	#8,d1
	PUTB	eaf,d1
	DONE			;nok

	START
emu_op_33:
	;; INC	SP
	;; No flags
	;;
	;; FYI:  Do not have to deref because this will never cross a
	;; page boundary.  So sayeth BrandonW.
	HOLD_INTS
	addq.w	#1,esp
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_34:
	;; INC	(HL)
	;; Increment byte
	;; SPEED can be made faster
	FETCHB	ehl,d1
	F_INC_B	d1
	PUTB	d1,ehl
	DONE			;nok

	START
emu_op_35:
	;; DEC	(HL)
	;; Decrement byte
	;; SPEED can be made faster
	FETCHB	ehl,d1
	F_DEC_B	d1
	PUTB	d1,ehl
	DONE			;nok

	START
emu_op_36:
	;; LD	(HL),immed.b
	HOLD_INTS
	FETCHBI	d1
	CONTINUE_INTS
	PUTB	ehl,d1
	DONE			;nok

	START
emu_op_37:
	;; SCF
	;; Set Carry Flag
	;; XXX flags are more complicated than this :(
	ori.b	#%00111011,flag_valid-flag_storage(a3)
	move.b	eaf,d1
	ori.b	#%00000001,d1
	andi.b	#%11101101,d1
	or.b	d1,flag_byte-flag_storage(a3)
	DONE			;nok

	START
emu_op_38:
	;; JR	C,immed.b
	;; If carry set
	;;  PC <- PC+immed.b
	HOLD_INTS
	bsr	f_norm_c
	bne	emu_op_18
	add.l	#1,epc
	CONTINUE_INTS
	DONE

	START
emu_op_39:
	;; ADD	HL,SP
	;; HL <- HL+SP
	HOLD_INTS
	move.l	esp,a0
	bsr	underef
	F_ADD_W	ehl,d0		; ??? Can I avoid underef/deref cycle?
	bsr	deref
	move.l	a0,esp
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_3a:
	;; LD	A,(immed.w)
	HOLD_INTS
	FETCHWI	d1
	CONTINUE_INTS
	FETCHB	d1,eaf
	DONE			;nok

	START
emu_op_3b:
	;; DEC	SP
	;; No flags
	subq.l	#1,esp
	DONE			;nok

	START
emu_op_3c:
	;; INC	A
	F_INC_B	eaf
	DONE

	START
emu_op_3d:
	;; DEC	A
	F_DEC_B	eaf
	DONE			;nok

	START
emu_op_3e:
	;; LD	A,immed.b
	HOLD_INTS
	FETCHBI	eaf
	CONTINUE_INTS
	DONE

	START
emu_op_3f:
	;; CCF
	;; Clear carry flag
	;; XXX fuck flags
	bsr	flags_normalize
	;; 	  SZ5H3PNC
	ori.b	#%00000001,flag_valid-flag_storage(a3)
	andi.b	#%11111110,flag_byte-flag_storage(a3)
	DONE			;nok

	START
emu_op_40:
	;; LD	B,B
	;; SPEED
	LOHI	ebc
	move.b	ebc,ebc
	HILO	ebc
	DONE			;nok

	START
emu_op_41:
	;; LD	B,C
	move.w	ebc,d1
	LOHI	d1
	move.b	d1,ebc
	DONE			;nok

	START
emu_op_42:
	;; LD	B,D
	;; B <- D
	;; SPEED
	LOHI	ebc
	LOHI	ede
	move.b	ede,ebc
	HILO	ebc
	HILO	ede
	DONE			;nok

	START
emu_op_43:
	;; LD	B,E
	;; B <- E
	LOHI	ebc
	move.b	ebc,ede		; 4
	HILO	ebc
	DONE			;nok

	START
emu_op_44:
	;; LD	B,H
	;; B <- H
	;; SPEED
	LOHI	ebc
	LOHI	ehl
	move.b	ehl,ebc
	HILO	ebc
	HILO	ehl
	DONE			;nok

	START
emu_op_45:
	;; LD	B,L
	;; B <- L
	LOHI	ebc
	move.b	ehl,ebc
	HILO	ebc
	DONE			;nok

	START
emu_op_46:
	;; LD	B,(HL)
	;; B <- (HL)
	LOHI	ebc
	FETCHB	ehl,ebc
	HILO	ebc
	DONE			;nok

	START
emu_op_47:
	;; LD	B,A
	;; B <- A
	LOHI	ebc
	move.b	eaf,ebc
	HILO	ebc
	DONE			;nok

	START
emu_op_48:
	;; LD	C,B
	;; C <- B
	move.w	ebc,-(sp)
	move.b	(sp),ebc
	;; XXX emfasten?
	addq.l #2,sp
	DONE			;nok
				;14 cycles
	START
emu_op_49:
	;; LD	C,C
	move.b	ebc,ebc
	DONE			;nok

	START
emu_op_4a:
	;; LD	C,D
	move.w	ede,-(sp)
	move.b	(sp),ebc
	;; XXX emfasten?
	addq.l #2,sp
	DONE			;nok

	START
emu_op_4b:
	;; LD	C,E
	move.b	ebc,ede
	DONE			;nok

	START
emu_op_4c:
	;; LD	C,H
	LOHI	ehl
	move.b	ebc,ehl
	HILO	ehl
	DONE			;nok

	START
emu_op_4d:
	;; LD	C,L
	move.b	ebc,ehl
	DONE			;nok

	START
emu_op_4e:
	;; LD	C,(HL)
	;; C <- (HL)
	FETCHB	ehl,ebc
	DONE			;nok

	START
emu_op_4f:
	;; LD	C,A
	move.b	eaf,ebc
	DONE			;nok

	START
emu_op_50:
; faster (slightly bigger) if we abuse sp again, something along the lines of (UNTESTED)
; move.w ebc,-(sp)   ; 8, 2
; move.w ede,-(sp)   ; 8, 2
; move.b 2(sp),(sp) ; 16, 4
; move.w (sp)+,ede   ; 8, 2
; addq.l #2,sp      ; 8, 2
	;; LD	D,B
	LOHI	ebc
	LOHI	ede
	move.b	ebc,ede
	HILO	ebc
	HILO	ede
	DONE			;nok

	START
emu_op_51:
	;; LD	D,C
	LOHI	ede
	move.b	ebc,ede
	HILO	ede
	DONE			;nok

	START
emu_op_52:
	;; LD	D,D
	DONE			;nok

	START
emu_op_53:
	;; LD	D,E
	andi.w	#$00ff,ede
	move.b	ede,d1
	lsl	#8,d1
	or.w	d1,ede
	DONE			;nok

	START
emu_op_54:
	;; LD	D,H
	LOHI	ede		; 4
	LOHI	ehl		; 4
	move.b	ehl,ede		; 4
	HILO	ede		; 4
	HILO	ehl		; 4
	DONE			;nok
				;20 cycles

	START
emu_op_55:
	;; LD	D,L
	LOHI	ede
	move.b	ehl,ede
	HILO	ede
	DONE			;nok

	START
emu_op_56:
	;; LD	D,(HL)
	;; D <- (HL)
	LOHI	ede
	FETCHB	ehl,ede
	HILO	ede
	DONE			;nok

	START
emu_op_57:
	;; LD	D,A
	LOHI	ede
	move.b	eaf,ede
	HILO	ede
	DONE			;nok

	START
emu_op_58:
	;; LD	E,B
	LOHI	ebc
	move.b	ebc,ede
	HILO	ebc
	DONE			;nok

	START
emu_op_59:
	;; LD	E,C
	move.b	ebc,ede
	DONE			;nok

	START
emu_op_5a:
	;; LD	E,D
	andi.w	#$ff00,ede	; 8/4
	move.b	ede,d1		; 4/2
	lsr.w	#8,d1		;22/2
	or.w	d1,ede		; 4/2
	DONE			;nok
				;38/2

	START
emu_op_5b:
	;; LD	E,E
	move.b	ede,ede
	DONE			;nok

	START
emu_op_5c:
	;; LD	E,H
	LOHI	ehl
	move.b	ede,ehl
	HILO	ehl
	DONE			;nok

	START
emu_op_5d:
	;; LD	E,L
	move.b	ede,ehl
	DONE			;nok

	START
emu_op_5e:
	;; LD	E,(HL)
	FETCHB	ehl,d1
	DONE			;nok

	START
emu_op_5f:
	;; LD	E,A
	move.b	ede,eaf
	DONE			;nok

	START
emu_op_60:
	;; LD	H,B
	LOHI	ebc
	LOHI	ehl
	move.b	ehl,ebc
	HILO	ebc
	HILO	ehl
	DONE			;nok

	START
emu_op_61:
	;; LD	H,C
	LOHI	ehl
	move.b	ebc,ehl
	HILO	ehl
	DONE			;nok

	START
emu_op_62:
	;; LD	H,D
	LOHI	ede
	LOHI	ehl
	move.b	ede,ehl
	HILO	ede
	HILO	ehl
	DONE			;nok

	START
emu_op_63:
	;; LD	H,E
	LOHI	ehl
	move.b	ede,ehl
	HILO	ehl
	DONE			;nok

	START
emu_op_64:
	;; LD	H,H
	LOHI	ehl
	move.b	ehl,ehl
	HILO	ehl
	DONE			;nok

	START
emu_op_65:
	;; LD	H,L
	;; H <- L
	move.b	ehl,d1
	LOHI	ehl
	move.b	d1,ehl
	HILO	ehl
	DONE			;nok

	START
emu_op_66:
	;; LD	H,(HL)
	FETCHB	ehl,d1
	LOHI	ehl
	move.b	d1,ehl
	HILO	ehl
	DONE			;nok

	START
emu_op_67:
	;; LD	H,A
	LOHI	ehl
	move.b	eaf,ehl
	HILO	ehl
	DONE			;nok

	START
emu_op_68:
	;; LD	L,B
	LOHI	ebc
	move.b	ebc,ehl
	HILO	ebc
	DONE			;nok

	START
emu_op_69:
	;; LD	L,C
	move.b	ebc,ehl
	DONE			;nok

	START
emu_op_6a:
	;; LD	L,D
	LOHI	ede
	move.b	ede,ehl
	HILO	ede
	DONE			;nok

	START
emu_op_6b:
	;; LD	L,E
	move.b	ede,ehl
	DONE			;nok

	START
emu_op_6c:
	;; LD	L,H
	move.b	ehl,d1
	LOHI	d1
	move.b	d1,ehl
	DONE			;nok

	START
emu_op_6d:
	;; LD	L,L
	move.b	ehl,ehl
	DONE			;nok

	START
emu_op_6e:
	;; LD	L,(HL)
	;; L <- (HL)
	FETCHB	ehl,ehl
	DONE			;nok

	START
emu_op_6f:
	;; LD	L,A
	move.b	eaf,ehl
	DONE			;nok

	START
emu_op_70:
	;; LD	(HL),B
	LOHI	ebc
	PUTB	ehl,ebc
	HILO	ebc
	DONE			;nok

	START
emu_op_71:
	;; LD	(HL),C
	PUTB	ehl,ebc
	DONE			;nok

	START
emu_op_72:
	;; LD	(HL),D
	LOHI	ede
	PUTB	ehl,ede
	HILO	ede
	DONE			;nok

	START
emu_op_73:
	;; LD	(HL),E
	PUTB	ehl,ede
	DONE			;nok

	START
emu_op_74:
	;; LD	(HL),H
	move.w	ehl,d1
	HILO	d1
	PUTB	d1,ehl
	DONE			;nok

	START
emu_op_75:
	;; LD	(HL),L
	move.b	ehl,d1
	PUTB	d1,ehl
	DONE			;nok

	START
emu_op_76:
	;; HALT
	;; XXX do this
	bra	emu_op_76
	DONE			;nok

	START
emu_op_77:
	;; LD	(HL),A
	PUTB	eaf,ehl
	DONE			;nok

	START
emu_op_78:
	;; LD	A,B
	move.w	ebc,d1
	LOHI	d1
	move.b	d1,eaf
	DONE			;nok

	START
emu_op_79:
	;; LD	A,C
	move.b	ebc,eaf
	DONE			;nok

	START
emu_op_7a:
	;; LD	A,D
	move.w	ede,d1
	LOHI	d1
	move.b	d1,eaf
	DONE			;nok

	START
emu_op_7b:
	;; LD	A,E
	move.b	ede,eaf
	DONE			;nok

	START
emu_op_7c:
	;; LD	A,H
	move.w	ehl,d1
	LOHI	d1
	move.b	d1,eaf
	DONE			;nok

	START
emu_op_7d:
	;; LD	A,L
	move.b	ehl,eaf
	DONE			;nok

	START
emu_op_7e:
	;; LD	A,(HL)
	;; A <- (HL)
	FETCHB	ehl,eaf
	DONE			;nok

	START
emu_op_7f:
	;; LD	A,A
	DONE			;nok



	;; Do an ADD \2,\1
F_ADD_B	MACRO			; 14 bytes?
	move.b	\2,d1
	move.b	\1,d0
	bsr	alu_add
	move.b	d1,\2
	ENDM

	START
emu_op_80:
	;; ADD	A,B
	LOHI	ebc
	F_ADD_B	ebc,eaf
	HILO	ebc
	DONE			;nok

	START
emu_op_81:
	;; ADD	A,C
	F_ADD_B	ebc,eaf
	DONE			;nok

	START
emu_op_82:
	;; ADD	A,D
	LOHI	ede
	F_ADD_B	ede,eaf
	HILO	ede
	DONE			;nok

	START
emu_op_83:
	;; ADD	A,E
	F_ADD_B	ede,eaf
	DONE			;nok

	START
emu_op_84:
	;; ADD	A,H
	LOHI	ehl
	F_ADD_B	ehl,eaf
	HILO	ehl
	DONE			;nok

	START
emu_op_85:
	;; ADD	A,L
	F_ADD_B	ehl,eaf
	DONE			;nok

	START
emu_op_86:
	;; ADD	A,(HL)
	;; XXX size?
	FETCHB	ehl,d2
	F_ADD_B	d2,eaf
	PUTB	d2,ehl
	DONE			;nok

	START
emu_op_87:
	;; ADD	A,A
	F_ADD_B	eaf,eaf
	DONE			;nok



	;; Do an ADC \2,\1
F_ADC_B	MACRO			; S34
	move.b	\2,d1
	move.b	\1,d0
	bsr	alu_adc
	move.b	d1,\2
	ENDM

	START
emu_op_88:
	;; ADC	A,B
	;; A <- A + B + (carry)
	LOHI	ebc
	F_ADC_B	ebc,eaf
	HILO	ebc
	DONE			;nok

	START
emu_op_89:
	;; ADC	A,C
	;; A <- A + C + (carry)
	F_ADC_B	ebc,eaf
	DONE			;nok

	START
emu_op_8a:
	;; ADC	A,D
	LOHI	ede
	F_ADC_B	ede,eaf
	HILO	ede
	DONE			;nok

	START
emu_op_8b:
	;; ADC	A,E
	;; A <- A + E + carry
	F_ADC_B	ede,eaf
	DONE			;nok

	START
emu_op_8c:
	;; ADC	A,H
	LOHI	eaf
	F_ADC_B	ehl,eaf
	HILO	eaf
	DONE			;nok

	START
emu_op_8d:
	;; ADC	A,L
	F_ADC_B	ehl,eaf
	DONE			;nok

	START
emu_op_8e:
	;; ADC	A,(HL)
	FETCHB	ehl,d2
	F_ADC_B	d2,eaf
	PUTB	d2,ehl
	DONE			;nok

	START
emu_op_8f:
	;; ADC	A,A
	F_ADC_B	eaf,eaf
	DONE			;nok





	;; Do a SUB \2,\1
F_SUB_B	MACRO
	move.b	\2,d1
	move.b	\1,d0
	bsr	alu_sub
	move.b	d1,\2
	ENDM

	START
emu_op_90:
	;; SUB	A,B
	LOHI	ebc
	F_SUB_B	ebc,eaf
	HILO	ebc
	DONE			;nok

	START
emu_op_91:
	;; SUB	A,C
	F_SUB_B	ebc,eaf
	DONE			;nok

	START
emu_op_92:
	;; SUB	A,D
	LOHI	ede
	F_SUB_B	ede,eaf
	HILO	ede
	DONE			;nok

	START
emu_op_93:
	;; SUB	A,E
	F_SUB_B	ede,eaf
	DONE			;nok

	START
emu_op_94:
	;; SUB	A,H
	LOHI	ehl
	F_SUB_B	ehl,eaf
	HILO	ehl
	DONE			;nok

	START
emu_op_95:
	;; SUB	A,L
	F_SUB_B	ehl,eaf

	START
emu_op_96:
	;; SUB	A,(HL)
	FETCHB	ehl,d2
	F_SUB_B	d2,eaf
	PUTB	d2,ehl
	DONE			;nok

	START
emu_op_97:
	;; SUB	A,A
	F_SUB_B	eaf,eaf
	DONE			;nok




	;; Do a SBC \2,\1
F_SBC_B	MACRO
	move.b	\2,d1
	move.b	\1,d0
	bsr	alu_sbc
	move.b	d1,\2
	ENDM

	START
emu_op_98:
	;; SBC	A,B
	LOHI	ebc
	F_SBC_B	ebc,eaf
	HILO	ebc
	DONE			;nok

	START
emu_op_99:
	;; SBC	A,C
	F_SBC_B	ebc,eaf
	DONE			;nok

	START
emu_op_9a:
	;; SBC	A,D
	LOHI	ede
	F_SBC_B	ede,eaf
	HILO	ede
	DONE			;nok

	START
emu_op_9b:
	;; SBC	A,E
	F_SBC_B	ede,eaf
	DONE			;nok

	START
emu_op_9c:
	;; SBC	A,H
	LOHI	ehl
	F_SBC_B	ehl,eaf
	HILO	ehl
	DONE			;nok

	START
emu_op_9d:
	;; SBC	A,L
	F_SBC_B	ehl,eaf
	DONE			;nok

	START
emu_op_9e:
	;; SBC	A,(HL)
	FETCHB	ehl,d2
	F_SBC_B	d2,eaf
	PUTB	d2,ehl
	DONE			;nok

	START
emu_op_9f:
	;; SBC	A,A
	F_SBC_B	eaf,eaf
	DONE			;nok





F_AND_B	MACRO
	move.b	\2,d1
	move.b	\1,d0
	bsr	alu_and
	move.b	d1,\2
	ENDM

	START
emu_op_a0:
	;; AND	B
	LOHI	ebc
	F_AND_B	ebc,eaf
	HILO	ebc
	DONE			;nok

	START
emu_op_a1:
	;; AND	C
	F_AND_B	ebc,eaf

	START
emu_op_a2:
	;; AND	D
	LOHI	ede
	F_AND_B	ede,eaf
	HILO	ede
	DONE			;nok

	START
emu_op_a3:
	;; AND	E
	F_AND_B	ede,eaf
	DONE			;nok

	START
emu_op_a4:
	;; AND	H
	LOHI	ehl
	F_AND_B	ehl,eaf
	HILO	ehl
	DONE			;nok

	START
emu_op_a5:
	;; AND	L
	F_AND_B	ehl,eaf
	DONE			;nok

	START
emu_op_a6:
	;; AND	(HL)
	FETCHB	ehl,d2
	F_AND_B	d2,eaf
	PUTB	d2,ehl
	DONE			;nok

	START
emu_op_a7:
	;; AND	A
	;; SPEED ... It's probably not necessary to run this faster.
	F_AND_B	eaf,eaf
	DONE			;nok





F_XOR_B	MACRO
	move.b	\2,d1
	move.b	\1,d0
	bsr	alu_xor
	move.b	d1,\2
	ENDM

	START
emu_op_a8:
	;; XOR	B
	LOHI	ebc
	F_XOR_B	ebc,eaf
	HILO	ebc
	DONE			;nok

	START
emu_op_a9:
	;; XOR	C
	F_XOR_B	ebc,eaf
	DONE			;nok

	START
emu_op_aa:
	;; XOR	D
	LOHI	ede
	F_XOR_B	ede,eaf
	HILO	ede
	DONE			;nok

	START
emu_op_ab:
	;; XOR	E
	F_XOR_B	ede,eaf
	DONE			;nok

	START
emu_op_ac:
	;; XOR	H
	LOHI	ehl
	F_XOR_B	ehl,eaf
	HILO	ehl
	DONE			;nok

	START
emu_op_ad:
	;; XOR	L
	F_XOR_B	ehl,eaf
	DONE			;nok

	START
emu_op_ae:
	;; XOR	(HL)
	FETCHB	ehl,d2
	F_XOR_B	d2,eaf
	PUTB	d2,ehl
	DONE			;nok

	START
emu_op_af:
	;; XOR	A
	F_XOR_B	eaf,eaf
	;; XXX
	DONE			;nok





F_OR_B	MACRO
	move.b	\2,d1
	move.b	\1,d0
	bsr	alu_or
	move.b	d1,\2
	ENDM

	START
emu_op_b0:
	;; OR	B
	LOHI	ebc
	F_OR_B	ebc,eaf
	HILO	ebc
	DONE			;nok

	START
emu_op_b1:
	;; OR	C
	F_OR_B	ebc,eaf
	DONE			;nok

	START
emu_op_b2:
	;; OR	D
	LOHI	ede
	F_OR_B	ede,eaf
	HILO	ede
	DONE			;nok

	START
emu_op_b3:
	;; OR	E
	F_OR_B	ede,eaf
	DONE			;nok

	START
emu_op_b4:
	;; OR	H
	LOHI	ehl
	F_OR_B	ehl,eaf
	HILO	ehl
	DONE			;nok

	START
emu_op_b5:
	;; OR	L
	F_OR_B	ehl,eaf
	DONE			;nok

	START
emu_op_b6:
	;; OR	(HL)
	FETCHB	ehl,d2
	F_OR_B	d2,eaf
	PUTB	d2,ehl
	DONE			;nok

	START
emu_op_b7:
	;; OR	A
	F_OR_B	eaf,eaf
	DONE			;nok





	;; COMPARE instruction
F_CP_B	MACRO
	;; XXX deal with \2 or \1 being d1 or d0
	move.b	\2,d1
	move.b	\1,d0
	bsr	alu_cp
	;; no result to save
	ENDM

	START
emu_op_b8:
	;; CP	B
	move.w	ebc,d2
	LOHI	d2
	F_CP_B	d2,eaf
	DONE			;nok

	START
emu_op_b9:
	;; CP	C
	F_CP_B	ebc,eaf
	DONE			;nok

	START
emu_op_ba:
	;; CP	D
	move.w	ede,d2
	LOHI	d2
	F_CP_B	d2,eaf
	DONE			;nok

	START
emu_op_bb:
	;; CP	E
	F_CP_B	ede,eaf
	DONE			;nok

	START
emu_op_bc:
	;; CP	H
	move.w	ehl,d2
	LOHI	d2
	F_CP_B	d2,eaf
	DONE			;nok

	START
emu_op_bd:
	;; CP	L
	F_CP_B	ehl,eaf
	DONE			;nok

	START
emu_op_be:
	;; CP	(HL)
	FETCHB	ehl,d2
	F_CP_B	d2,eaf
	;; no result to store
	DONE			;nok

	START
emu_op_bf:
	;; CP	A
	F_CP_B	eaf,eaf
	DONE

	START
emu_op_c0:
	;; RET	NZ
	;; if ~Z
	;;   PCl <- (SP)
	;;   PCh <- (SP+1)
	;;   SP <- (SP+2)
	HOLD_INTS
	bsr	f_norm_z
	;; SPEED inline RET
	beq	emu_op_c9	; RET
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_c1:			; S10 T
	;; POP	BC
	;; Pops a word into BC
	HOLD_INTS
	POPW	ebc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_c2:
	;; JP	NZ,immed.w
	;; if ~Z
	;;   PC <- immed.w
	HOLD_INTS
	bsr	f_norm_z
	bne.s	emu_op_c3
	add.l	#2,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_c3:			; S12 T36
	;; JP	immed.w
	;; PC <- immed.w
	HOLD_INTS
	FETCHWI	d1
	bsr	deref
	movea.l	a0,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_c4:
	;; CALL	NZ,immed.w
	;; If ~Z, CALL immed.w
	HOLD_INTS
	bsr	f_norm_z
	;; CALL (emu_op_cd) will run HOLD_INTS again. This doesn't
	;; matter with the current implementation because HOLD_INTS
	;; simply sets a bit.
	bne	emu_op_cd
	add.l	#2,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_c5:
	;; PUSH	BC
	HOLD_INTS
	PUSHW	ebc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_c6:
	;; ADD	A,immed.b
	HOLD_INTS
	FETCHBI	d1
	CONTINUE_INTS
	F_ADD_B	d1,eaf
	DONE			;nok

	START
emu_op_c7:
	;; RST	&0
	;;  == CALL 0
	;; XXX check
	HOLD_INTS
	move.l	epc,a0
	bsr	underef
	PUSHW	d0
	move.w	#$00,d0
	bsr	deref
	move.l	a0,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_c8:
	;; RET	Z
	HOLD_INTS
	bsr	f_norm_z
	beq.s	emu_op_c9
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_c9:
	;; RET
	;; PCl <- (SP)
	;; PCh <- (SP+1)	POPW
	;; SP <- (SP+2)
	HOLD_INTS
	POPW	d1
	bsr	deref
	movea.l	a0,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_ca:
	;; JP	Z,immed.w
	;; If Z, jump
	HOLD_INTS
	bsr	f_norm_z
	beq	emu_op_c3
	add.l	#2,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_cb:			; prefix
	movea.w	emu_op_undo_cb(pc),a2
	;; nok

	START
emu_op_cc:
	;; CALL	Z,immed.w
	HOLD_INTS
	bsr	f_norm_z
	beq.s	emu_op_cd
	add.l	#2,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_cd:
	;; CALL	immed.w
	;; (Like JSR on 68k)
	;;  (SP-1) <- PCh
	;;  (SP-2) <- PCl
	;;  SP <- SP - 2
	;;  PC <- address
	HOLD_INTS		; released in JP routine
	move.l	epc,a0
	bsr	underef		; d0 has PC
	add.w	#2,d0
	PUSHW	d0
	bra	emu_op_c3	; JP

	START
emu_op_ce:
	;; ADC	A,immed.b
	HOLD_INTS
	FETCHWI	d1
	CONTINUE_INTS
	F_ADC_B	d1,eaf
	DONE			;nok

	START
emu_op_cf:
	;; RST	&08
	;;  == CALL 8
	HOLD_INTS
	move.l	epc,a0
	bsr	underef		; d0 has PC
	PUSHW	d0
	move.w	#$08,d0
	bsr	deref
	move.l	a0,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_d0:
	;; RET	NC
	HOLD_INTS
	bsr	f_norm_c
	beq	emu_op_c9
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_d1:
	;; POP	DE
	HOLD_INTS
	POPW	ede
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_d2:
	;; JP	NC,immed.w
	HOLD_INTS
	bsr	f_norm_c
	beq	emu_op_c3
	add.l	#2,epc
	CONTINUE_INTS
	DONE

	START
emu_op_d3:
	;; OUT	immed.b,A
	HOLD_INTS
	move.b	eaf,d1
	FETCHBI	d0
	bsr	port_out
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_d4:
	;; CALL	NC,immed.w
	HOLD_INTS
	bsr	f_norm_c
	beq	emu_op_cd
	add.l	#2,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_d5:
	;; PUSH	DE
	HOLD_INTS
	PUSHW	ede
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_d6:
	;; SUB	A,immed.b
	HOLD_INTS
	FETCHBI	d1
	CONTINUE_INTS
	F_SUB_B	eaf,d1
	DONE			;nok

	START
emu_op_d7:
	;; RST	&10
	;;  == CALL 10
	HOLD_INTS
	move.l	epc,a0
	bsr	underef
	PUSHW	d0
	move.w	#$10,d0
	bsr	deref
	move.l	a0,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_d8:
	;; RET	C
	HOLD_INTS
	bsr	f_norm_c
	bne	emu_op_c9
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_d9:
	;; EXX
	swap	ebc
	swap	ede
	swap	ehl
	DONE			;nok

	START
emu_op_da:
	;; JP	C,immed.w
	HOLD_INTS
	bsr	f_norm_c
	bne	emu_op_c3
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_db:
	;; IN	A,immed.b
	HOLD_INTS
	move.b	eaf,d1
	FETCHBI	d0
	CONTINUE_INTS
	bsr	port_in
	DONE			;nok

	START
emu_op_dc:
	;; CALL	C,immed.w
	HOLD_INTS
	bsr	f_norm_c
	bne	emu_op_cd
	add.l	#2,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_dd:			; prefix
	movea.w		emu_op_undo_dd(pc),a2

	START
emu_op_de:
	;; SBC	A,immed.b
	HOLD_INTS
	FETCHWI	d1
	CONTINUE_INTS
	F_SBC_B	d1,eaf
	DONE			;nok

	START
emu_op_df:
	;; RST	&18
	;;  == CALL 18
	HOLD_INTS
	move.l	epc,a0
	bsr	underef
	PUSHW	d0
	move.w	#$18,d0
	bsr	deref
	move.l	a0,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_e0:
	;; RET	PO
	;; If parity odd (P zero), return
	HOLD_INTS
	bsr	f_norm_pv
	beq	emu_op_c9
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_e1:
	;; POP	HL
	POPW	ehl
	DONE			;nok

	START
emu_op_e2:
	;; JP	PO,immed.w
	HOLD_INTS
	bsr	f_norm_pv
	beq	emu_op_c3
	add.l	#2,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_e3:
	;; EX	(SP),HL
	;; Exchange
	HOLD_INTS
	POPW	d1
	PUSHW	ehl
	CONTINUE_INTS
	move.w	d1,ehl
	DONE			;nok

	START
emu_op_e4:
	;; CALL	PO,immed.w
	;; if parity odd (P=0), call
	HOLD_INTS
	bsr	f_norm_pv
	beq	emu_op_cd
	add.l	#2,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_e5:
	;; PUSH	HL
	HOLD_INTS
	PUSHW	ehl
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_e6:
	;; AND	immed.b
	HOLD_INTS
	FETCHBI	d1
	CONTINUE_INTS
	F_AND_B	d1,eaf
	DONE			;nok

	START
emu_op_e7:
	;; RST	&20
	;;  == CALL 20
	HOLD_INTS
	move.l	epc,a0
	bsr	underef
	PUSHW	d0
	move.w	#$20,d0
	bsr	deref
	move.l	a0,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_e8:
	;; RET	PE
	;; If parity odd (P zero), return
	HOLD_INTS
	bsr	f_norm_pv
	bne	emu_op_c9
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_e9:
	;; JP	(HL)
	HOLD_INTS
	FETCHB	ehl,d1
	bsr	deref
	movea.l	a0,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_ea:
	;; JP	PE,immed.w
	HOLD_INTS
	bsr	f_norm_pv
	bne	emu_op_c3
	add.l	#2,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_eb:
	;; EX	DE,HL
	exg.w	ede,ehl
	DONE			;nok

	START
emu_op_ec:
	;; CALL	PE,immed.w
	;; If parity even (P=1), call
	HOLD_INTS
	bsr	f_norm_c
	bne	emu_op_cd
	add.l	#2,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_ed:			; prefix
	;; XXX this probably ought to hold interrupts too
	movea.w	emu_op_undo_ed(pc),a2
	DONE			;nok

	START
emu_op_ee:
	;; XOR	immed.b
	HOLD_INTS
	FETCHBI	d1
	CONTINUE_INTS
	F_XOR_B	d1,eaf
	DONE			;nok

	START
emu_op_ef:
	;; RST	&28
	;;  == CALL 28
	HOLD_INTS
	move.l	epc,a0
	bsr	underef
	PUSHW	d0
	move.w	#$28,d0
	bsr	deref
	move.l	a0,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_f0:
	;; RET	P
	;; Return if Positive
	HOLD_INTS
	bsr	f_norm_sign
	beq	emu_op_c9	; RET
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_f1:
	;; POP	AF
	;; SPEED this can be made faster ...
	;; XXX AF
	POPW	eaf
	move.w	eaf,(flag_byte-flag_storage)(a3)
	move.b	#$ff,(flag_valid-flag_storage)(a3)
	DONE			;nok

	START
emu_op_f2:
	;; JP	P,immed.w
	HOLD_INTS
	bsr	f_norm_sign
	beq	emu_op_c3	; JP
	add.l	#2,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_f3:
	;; DI
	bsr	ints_stop

	START
emu_op_f4:
	;; CALL	P,&0000
	;; Call if positive (S=0)
	HOLD_INTS
	bsr	f_norm_sign
	beq	emu_op_cd
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_f5:
	;; PUSH	AF
	HOLD_INTS
	bsr	flags_normalize
	LOHI	eaf
	move.b	flag_byte(pc),eaf
	;; XXX wrong, af isn't normalized by flags_normalize?
	CONTINUE_INTS
	HILO	eaf
	PUSHW	eaf
	DONE			;nok

	START
emu_op_f6:
	;; OR	immed.b
	HOLD_INTS
	FETCHBI	d1
	CONTINUE_INTS
	F_OR_B	d1,eaf
	DONE			;nok

	START
emu_op_f7:
	;; RST	&30
	;;  == CALL 30
	HOLD_INTS
	move.l	epc,a0
	bsr	underef
	PUSHW	d0
	move.w	#$08,d0
	bsr	deref
	move.l	a0,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_f8:
	;; RET	M
	;; Return if Sign == 1, minus
	HOLD_INTS
	bsr	f_norm_sign
	bne	emu_op_c9	; RET
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_f9:
	;; LD	SP,HL
	;; SP <- HL
	HOLD_INTS
	move.w	ehl,d1
	bsr	deref
	movea.l	a0,esp
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_fa:
	;; JP	M,immed.w
	HOLD_INTS
	bsr	f_norm_sign
	bne	emu_op_c3	; JP
	add.l	#2,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_fb:
	;; EI
	bsr	ints_start
	DONE			;nok

	START
emu_op_fc:
	;; CALL	M,immed.w
	;; Call if minus (S=1)
	HOLD_INTS
	bsr	f_norm_sign
	bne	emu_op_cd
	add.l	#2,epc
	CONTINUE_INTS
	DONE			;nok

	START
emu_op_fd:			; prefix
	;; swap IY, HL
	movea.w	emu_op_undo_fd(pc),a2

	START
emu_op_fe:
	;; CP	immed.b
	HOLD_INTS
	FETCHBI	d1
	CONTINUE_INTS
	F_CP_B	d1,eaf
	DONE			;nok

	START
emu_op_ff:
	;; RST	&38
	;;  == CALL 38
	HOLD_INTS
	move.l	epc,a0
	bsr	underef
	PUSHW	d0
	move.w	#$08,d0
	bsr	deref
	move.l	a0,epc
	CONTINUE_INTS
	DONE			;nok
