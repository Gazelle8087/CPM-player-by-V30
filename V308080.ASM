;	CP/M 2.2 player for generic MS-DOS and V20/30 Rev. 1.00
;
;	Copyright (C) 2025 by Gazelle
;
;Permission is hereby granted, free of charge, to any person
;obtaining a copy of this software and associated documentation
;files (the "Software"), to deal in the Software without
;restriction, including without limitation the rights to use,
;copy, modify, merge, publish, distribute, sublicense, and/or sell
;copies of the Software, and to permit persons to whom the
;Software is furnished to do so, subject to the following
;conditions:
;
;The above copyright notice and this permission notice shall be
;included in all copies or substantial portions of the Software.
;
;THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
;OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
;HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
;WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
;FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
;OTHER DEALINGS IN THE SOFTWARE.

;Repository https://github.com/Gazelle8087
;2025/06/21 Rev. 1.00 Initial release

		page 0,150
		.model	tiny
		.186
		.code

		org	100h

		assume	ds:nothing,es:nothing,ss:nothing

start:		jmp	hajime
		align	2

int_no		equ	0ffh

save_al		label	byte
save_ax		dw	?
save_bx		dw	?
save_cx		dw	?
save_dx		dw	?
save_bp		dw	?
z80_seg		dw	?
cpm_file_handle	dw	?
cpm_arg_offset	dw	?
fcb_addr	dw	?
path_flag	db	0
env_flag	db	0
drv_flag	db	0
file_name_end	dw	?

com_str			db	'.COM',0
cpm_str			db	'.CPM',0
env_key			db	'Z_EM='
env_str			db	128 dup (0)
cpm_file_name		db	128 dup (?)
buffer_area		db	128 dup (?)

;---------------------------------------------

hajime:
		push	sp
		pop	ax
		cmp	ax,sp
		jne	using_v30_1	;V20/30 判定1
		jmp	need_v30
using_v30_1:
		mov	ax,100h
		db	0d5h,00h	;AAD 00
		jnz	using_v30	;V20/30 判定2
		jmp	need_v30
using_v30:
		mov	ax,cs
		mov	es,ax
		mov	ds,ax
		mov	dx,offset open_msg
		mov	ah,9
		int	21h
		mov	ah,4ah		;128KB 残してメモリ開放
		mov	bx,2000h
		int	21h
		jnc	main_read_emulator
		jmp	no_mem

main_read_emulator:
		mov	ax,cs
		mov	ss,ax
		mov	sp,0f000h
		add	ax,1000h
		mov	z80_seg,ax

		call	search_env		;環境変数 Z_EMをサーチ

		call	read_cpm_file		;CPM80実行ファイルを読み込み

		call	setup_cpm_area		;CPM80実行に必要なメモリエリアを設定

;--------------------------------------

		mov	bx,0
		mov	es,bx
		mov	bx,int_no*4
		mov	es:[bx],word ptr 100h	;割り込みベクトル下位に 100h(=PC)を設定
		mov	ds,z80_seg
		mov	es:[bx+2],ds

		mov	bp,CPM_BDOS-2		;SP設定
		mov	ds:[bp],word ptr 0
		mov	save_bp,bp

		mov	dx,80h			;DMAアドレスを80hに設定
		mov	ah,1ah
		int	21h
go_cpm:
no_op:		mov	bp,save_bp
		mov	ds,z80_seg

;		mov	ax,save_ax
;		mov	bx,save_bx
;		mov	cx,save_cx
;		mov	dx,save_dx

		db	0fh,0ffh,int_no		;BRKEM

;		mov	save_ax,ax
;		mov	save_bx,bx
;		mov	save_cx,cx
;		mov	save_dx,dx

		mov	si,ds:[bp]
		mov	es:[int_no*4],si	;戻り先アドレスを ベクトル下位に設定
		add	bp,2			;SP調整
		mov	save_bp,bp		;SP保存

		cmp	al,0			;BDOS模擬ルーチンでは AL=0を設定
		je	to_bdos

		cmp	al,10h			;BIOS1模擬ルーチンでは AL=BIOS番号を設定
		ja	bios_no_error
		mov	bl,al
		mov	bh,0
		add	bx,bx
		jmp	word ptr cs:[bx+bios_table]

to_bdos:	cmp	cl,28h
		ja	bdos_no_error
		mov	bl,cl
		mov	bh,0
		add	bx,bx
		jmp	word ptr cs:[bx+bdos_table]

;---------------------------------
bdos_no_error_msg	db	'Incompatible bdos no $'
bios_no_error_msg	db	'Incompatible bios no $'

BIOS_no_error:
		mov	cl,al
		mov	dx,offset bios_no_error_msg
		jmp	bdos_bios_em_err
BDOS_no_error:
		mov	dx,offset bdos_no_error_msg
bdos_bios_em_err:
		mov	ax,cs
		mov	ds,ax
		mov	ah,9
		int	21h
		mov	al,cl
		call	dsphex2
		mov	ax,4c00h
		int	21h

;---------------------------------
		even
bdos_table	dw	sonomama	;0  system reset
		dw	sonomama	;1  input from console
		dw	sonomama	;2  output to consple
		dw	sonomama	;3  input from reader
		dw	sonomama	;4  output to punch
		dw	sonomama	;5  output to printer
		dw	sonomama	;6  direct console I/O
		dw	get_io_byte	;7  get io byte
		dw	set_io_byte	;8  set io byte
		dw	sonomama	;9  output string to console
		dw	sonomama	;A  bufferd input from console
		dw	bdos_const	;B  check console status
		dw	get_version	;C  get version no
		dw	sonomama	;D  disk reset
		dw	sonomama	;E  disk select
		dw	sonomama	;F  open
		dw	sonomama	;10 close
		dw	file_search1	;11 search first
		dw	file_search2	;12 search next
		dw	sonomama	;13 delete
		dw	bdos_read	;14 read seaquential
		dw	sonomama	;15 write seaquential
		dw	sonomama	;16 create
		dw	sonomama	;17 rename
		dw	get_login_vect	;18 get login vector
		dw	sonomama	;19 get current drive
		dw	sonomama	;1A set DMA addr
		dw	get_alloc_addr	;1B get allocation addr
		dw	set_ro		;1C set R/O
		dw	get_ro_vect	;1D get R/O vector
		dw	set_file_attr	;1E set file attrib
		dw	get_DPB_addr	;1F get DPB addr
		dw	get_set_user	;20 get/set user code
		dw	sonomama	;21 read random
		dw	sonomama	;22 write random
		dw	sonomama	;23 get file size
		dw	sonomama	;24 set random record
		dw	reset_disk2	;25 reset disk by vector
		dw	no_op		;26
		dw	no_op		;27
		dw	sonomama	;28 write random w/zero fill

sonomama:	mov	ah,cl
		int	21h
		jmp	go_cpm

bdos_const:
		mov	ah,0bh
		int	21h
		cmp	al,0
		je	bdos_noready
		mov	al,1
bdos_noready:	jmp	go_cpm

get_io_byte:	mov	al,ds:[0003]
		jmp	go_cpm

set_io_byte:	mov	ds:[0003],dl
		jmp	go_cpm

get_version:	mov	bx,22h
		jmp	go_cpm

file_search1:	mov	fcb_addr,dx
		mov	ah,11h
		int	21h
		jmp	go_cpm

file_search2:	mov	dx,fcb_addr
		mov	ah,12h
		int	21h
		jmp	go_cpm

bdos_read:	mov	ah,14h
		int	21h
		cmp	al,3
		jne	bdos_read_exit
		mov	al,0
bdos_read_exit:	jmp	go_cpm

get_set_user:
		cmp	dl,0ffh
		jne	set_user_code
		mov	al,0
		jmp	go_cpm

set_user_code:	cmp	dl,0
		je	set_user_code_0
		jmp	bdos_no_error
set_user_code_0:jmp	go_cpm

bdos_reader:	;3  input from reader
bdos_punch:	;4  output to punch
get_login_vect:	;18 get login vector
get_alloc_addr:	;1B get allocation addr
set_ro:		;1C set R/O
get_ro_vect:	;1D get R/O vector
set_file_attr:	;1E set file attrib
get_DPB_addr:	;1F get DPB addr
reset_disk2:	;25 reset disk by vector

		jmp	bdos_no_error
;--------------------------------------
bios_table	dw	bios_boot
		dw	bios_wboot
		dw	bios_const
		dw	bios_conin
		dw	bios_conout
		dw	bios_list
		dw	bios_punch
		dw	bios_reader
		dw	bios_home
		dw	bios_seldsk
		dw	bios_settrk
		dw	bios_setsec
		dw	bios_setdma
		dw	bios_read
		dw	bios_write
		dw	bios_listst
		dw	bios_sectran

bios_boot:
bios_wboot:	mov	ax,4c00h
		int	21h

bios_const:	mov	ax,4406h
		mov	bx,1
		int	21h
		jmp	go_cpm

bios_conin:	mov	ah,7
		int	21h
		jmp	go_cpm

bios_conout:	mov	ah,6
		cmp	cl,0ffh
		je	bios_conout1
		mov	dl,cl
		int	21h
		jmp	go_cpm

bios_conout1:	mov	dl,00
		int	21h
		jmp	go_cpm

bios_list:
bios_punch:
bios_reader:
bios_listst:
bios_home:
bios_seldsk:
bios_settrk:
bios_setsec:
bios_setdma:
bios_read:
bios_write:
bios_sectran:
		jmp	bios_no_error
;======================================
open_msg		db	'CP/M 2.2 player for generic MS-DOS and V20/30 Rev. 1.00',0dh,0ah
			db	'Copyright (c) 2025 by Gazelle',0dh,0ah,0ah,24h
no_mem_msg		db	'No enough memory.$'
cpm_open_error_msg	db	'CPM file open error.$'
cpm_read_error_msg	db	'CPM file read error.$'
cpm_close_error_msg	db	'CPM file close error.$'
too_long_path_msg	db	'too long path.$'
too_large_com_msg	db	'too large COM file.$'
need_v30_msg		db	'Need for V20/30.$'

cpm_close_error:mov	dx,offset cpm_close_error_msg
		jmp	error_exit
cpm_open_error:	mov	dx,offset cpm_open_error_msg
		jmp	error_exit
cpm_read_error:	mov	dx,offset cpm_read_error_msg
		jmp	error_exit
no_mem:		mov	dx,offset no_mem_msg
		jmp	error_exit
too_long_path:	mov	dx,offset too_long_path_msg
		jmp	error_exit
too_large_com:	mov	dx,offset too_large_com_msg
		jmp	error_exit
need_v30:	mov	dx,offset need_v30_msg
		jmp	error_exit

error_exit:
		mov	ax,cs
		mov	ds,ax
		mov	ah,9
		int	21h
		mov	ax,4c00h
		int	21h
;======================================

search_env:	mov	ax,cs
		mov	es,ax
		mov	ax,cs:[002ch]
		mov	ds,ax
		mov	si,0
		cld

search_env_next_4:
		mov	bx,0ffffh
		mov	di,offset env_key
		mov	dl,es:[di]
		lodsb
search_env_next_2:
		cmp	al,dl
		je	search_env_match_1
search_env_next_3:
		cmp	al,0
		je	search_env_next_5
search_env_next_1:
		lodsb
		and	si,si
		je	search_env_exit_1
		cmp	al,0
		jne	search_env_next_1
search_env_next_5:
		lodsb
		and	si,si
		je	search_env_exit_1
		cmp	al,0
		je	search_env_exit
		jmp	search_env_next_2

search_env_match_1:
		mov	bx,si
		dec	bx

search_env_match_3:
		lodsb
		and	si,si
		je	search_env_exit_1
		inc	di
		mov	dl,es:[di]
		cmp	al,dl
		je	search_env_match_2
search_env_match_4:
		cmp	al,0
		je	search_env_next_4
		lodsb
		and	si,si
		je	search_env_exit_1
		jmp	search_env_match_4
search_env_match_2:
		cmp	al,'='
		jne	search_env_match_3

		mov	cx,128
		mov	di,offset env_str
search_env_get:
		lodsb
		stosb
		cmp	al,0
		je	search_env_exit
		loop	search_env_get
		jmp	search_env_exit_1

search_env_exit_1:
		mov	bx,0ffffh
search_env_exit:
		mov	ax,cs
		mov	ds,ax
		ret
;================================================
read_cpm_file:
read_cpm_00:
		mov	di,offset cpm_file_name
read_cpm_0:
		mov	si,81h
		mov	cl,ds:[80h]
		mov	ch,0
read_cpm_01:	lodsb
		cmp	al,' '
		je	read_cpm_01
		cmp	al,09h
		je	read_cpm_01
		dec	si

read_cpm_02:	lodsb
		cmp	al,' '
		je	read_cpm_03
		cmp	al,0dh
		je	read_cpm_03
		cmp	al,0
		je	read_cpm_03
		cmp	al,09h
		je	read_cpm_03
		cmp	al,':'
		jne	read_cpm_04
		cmp	ah,'A'
		jb	read_cpm_04
		cmp	ah,'Z'
		jbe	read_cpm_06
		cmp	ah,'z'
		ja	read_cpm_04
		cmp	ah,'a'
		jb	read_cpm_04
read_cpm_06:	mov	drv_flag,1
read_cpm_04:	cmp	al,'\'
		jne	read_cpm_05
		mov	path_flag,1
read_cpm_05:	stosb
		mov	ah,al
		loop	read_cpm_02

read_cpm_03:	dec	si
		mov	cpm_arg_offset,si
		mov	file_name_end,di

		dec	si
		mov	cx,4
read_cpm_08:	std
		lodsb
		cmp	al,'.'
		je	read_cpm_09
		loop	read_cpm_08

		mov	di,file_name_end
		mov	si,offset cpm_str
		cld
		movsw
		movsw
		movsb

		mov	ax,3d00h
		mov	dx,offset cpm_file_name
;		call	disp_file_name
		int	21h
		jc	read_cpm_10
		jmp	read_cpm_6

read_cpm_10:	mov	di,file_name_end
		mov	si,offset com_str
		cld
		movsw
		movsw
read_cpm_09:
		mov	al,0
		stosb
		mov	ax,3d00h
		mov	dx,offset cpm_file_name
;		call	disp_file_name
		int	21h
		jc	read_cpm_11
		jmp	read_cpm_6
read_cpm_11:
		cmp	env_flag,1
		je	read_cpm_111
		cmp	drv_flag,1
		je	read_cpm_111
		cmp	path_flag,1
		je	read_cpm_111
		jmp	read_cpm_12
read_cpm_111:
		jmp	cpm_open_error

read_cpm_12:	mov	env_flag,1
		mov	si,offset env_str
		mov	di,offset cpm_file_name
		cld
		lodsb
		and	al,al
		jz	read_cpm_111
		stosb
		mov	cx,127
read_cpm_1:
		lodsb
		and	al,al
		jz	read_cpm_2
		stosb
		loop	read_cpm_1
		jmp	too_long_path
read_cpm_2:
		mov	al,'\'
		stosb
read_cpm_3:
		jmp	read_cpm_0

read_cpm_6:
		mov	cpm_file_handle,ax
		mov	bx,ax
		mov	ah,3fh
		mov	cx,0fe00h
		mov	ds,z80_seg
		mov	dx,100h
		int	21h
		jnc	read_cpm_7
		jmp	cpm_read_error
read_cpm_7:
		and	ax,ax
		jnz	read_cpm_71
		jmp	cpm_read_error
read_cpm_71:
		cmp	ax,0fe00h
		jne	read_cpm_8
		jmp	too_large_com
read_cpm_8:
		mov	ax,cs
		mov	ds,ax
		mov	ah,3eh
		mov	bx,cpm_file_handle
		int	21h
		jnc	read_cpm_exit
		jmp	cpm_close_error
read_cpm_exit:
		ret
;================================================
setup_cpm_area:
		mov	es,z80_seg
		mov	di,0
		mov	cx,80h
		mov	ax,0
		rep	stosw

		mov	si,cpm_arg_offset
		mov	di,80h
		mov	cl,ds:[di]
		mov	ch,0
		add	cx,81h
		sub	cx,si
		jbe	set_cpm_11

		mov	al,cl
		cld
		stosb
		and	cx,7fh

set_cpm_loop:	lodsb
		cmp	al,60h
		jbe	set_cpm_10
		cmp	al,7bh
		jae	set_cpm_10
		sub	al,20h
set_cpm_10:	stosb
		loop	set_cpm_loop
		mov	al,0
		stosb
set_cpm_11:
		mov	si,cpm_arg_offset

		mov	di,5ch
		mov	ax,2901h
		int	21h

		mov	di,6ch
		mov	ax,2901h
		int	21h

		mov	ax,cs
		mov	ds,ax
		mov	es,z80_seg
		mov	si,OFFSET CPM_zero_page_0
		mov	di,0
		movsw
		movsw
		movsw
		movsw

		mov	di,CPM_BDOS
		mov	si,offset CPM_BDOS_code
		mov	cx,CPM_BDOS_end - CPM_BDOS_code
		rep	movsb

		mov	di,CPM_BIOS
		mov	si,offset CPM_BIOS_code
		mov	cx,CPM_BIOS_end - CPM_BIOS_code
		rep	movsb

		mov	es:[10h],es
		mov	es:[14h],cs

		ret
;------------------------------------------------
;	CPM	memory image

CPM_BDOS	equ	0ff84h
CPM_BIOS	equ	0ff88h

JP80		macro	addr
		db	0c3h		;JP instruction for Z80
		dw	addr - CPM_BIOS_code + CPM_BIOS
		endm

BIOS80		macro	bios_code
		db	03eh,bios_code	;LD A,bios_code
		db	0edh,0fdh	;RETEM
		endm

CPM_zero_page_0	db	0c3h
		dw	CPM_BIOS+3
io_byte		db	0
login_disk	db	2
jmp_bdos	db	0c3h
		dw	CPM_BDOS

CPM_BDOS_code:
		db	03eh,00		;LD A,0
		db	0edh,0fdh	;RETEM
CPM_BDOS_end:

CPM_BIOS_code:
		JP80	bios80_1
		JP80	bios80_1
		JP80	bios80_2
		JP80	bios80_3
		JP80	bios80_4
		JP80	bios80_5
		JP80	bios80_6
		JP80	bios80_7
		JP80	bios80_8
		JP80	bios80_9
		JP80	bios80_10
		JP80	bios80_11
		JP80	bios80_12
		JP80	bios80_13
		JP80	bios80_14
		JP80	bios80_15
		JP80	bios80_16

bios80_1:	BIOS80	1
bios80_2:	BIOS80	2
bios80_3:	BIOS80	3
bios80_4:	BIOS80	4
bios80_5:	BIOS80	5
bios80_6:	BIOS80	6
bios80_7:	BIOS80	7
bios80_8:	BIOS80	8
bios80_9:	BIOS80	9
bios80_10:	BIOS80	10
bios80_11:	BIOS80	11
bios80_12:	BIOS80	12
bios80_13:	BIOS80	13
bios80_14:	BIOS80	14
bios80_15:	BIOS80	15
bios80_16:	BIOS80	16

CPM_bios_end:
;======================================
dsphex4:	push	dx
		mov	dx,ax
		mov	al,ah
		call	dsphex2
		mov	ax,dx
		pop	dx

dsphex2:	push	dx
		mov	dl,al
		shr	al,1
		shr	al,1
		shr	al,1
		shr	al,1
		call	dsphex1
		mov	al,dl
		pop	dx

dsphex1:	push	dx
		and	al,0fh
		cmp	al,9
		jbe	dsphex1_1
		add	al,'@'-'9'
dsphex1_1:	add	al,'0'
		mov	dl,al
		mov	ah,2
		int	21h
		pop	dx
		ret
;======================================
disp_file_name:
		pusha
		mov	si,dx
		cld
		mov	cx,128
disp_file_name_loop:
		lodsb
		cmp	al,0
		je	disp_file_name_exit
		mov	dl,al
		mov	ah,2
		int	21h
		loop	disp_file_name_loop
disp_file_name_exit:
		mov	dl,0dh
		mov	ah,02
		int	21h
		mov	dl,0ah
		mov	ah,2
		int	21h
		popa
		ret
;======================================
	end	start
