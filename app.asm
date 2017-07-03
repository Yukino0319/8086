con8279  equ 0492h
dat8279  equ 0490h
assume cs:code
code segment public
org 100h 

start:jmp start1
segcod db 3fh,06h,5bh,4fh,66h,6dh,7dh,07h,7fh,6fh,77h,7ch,39h,5eh,79h,71h 
cflag db 0
which db 0
dxx1 db 0
dxx2 db 0
an1 db 0
an2 db 0
an_addr dw 0
start1:
Cli
;8253初始化
mov dx,04a6h ;控制寄存器
mov ax,36h ;计数器0，方式3
out dx,ax 

mov dx,04a0h
mov ax,7Ch
out dx,ax
mov ax,92h
out dx,ax ;计数值927Ch 

mov dx,04a6h
mov ax,0b6h ;计数器2，方式3
out dx,ax 

mov dx,04a4h
mov ax,0ah
out dx,ax
mov ax,0 
out dx,ax;计数值0ah 


;8259初始化
mov dx,04c0h
mov ax,13h   ;ICW1, ICW4 NEEDED
out  dx,ax 

mov dx,04c2h
mov ax,80h      ;ICW2 中断类型80h
out  dx,ax 

mov ax,03H
out  dx,ax      ;ICW4 

mov ax,00h      ;OCW1, 开放所有中断
out  dx,ax 

;安装中断向量
mov ax,0
mov ds,ax   ;中断向量表位于内存最开始的1KB，段地址为0
mov si,200h     ;初始化中断向量表，80H*4=200H
mov ax,offset hint
mov ds:[si],ax
add  si,2
mov ds:[si],100h ;代码段的内存起始地址为01100H,代码段段地址0100H 

; 8250初始化
    mov bx,0480h
    mov dx,bx
    add dx,6        ;LCR
    mov ax,80h
    out dx,ax
   

    mov dx,bx       
    mov ax,0ch      ;000ch---9600  12=1.8432MHz/(16*9600)
    out dx,ax       ;
    
    add dx,2   ;中断允许寄存器IER关中断
    mov ax,0
    out dx,ax 


    add dx,4            ;LCR again
    mov ax,07h           ;无校验位,8位数据位, 2位数据位的停止位
    out dx,ax 


    mov dx,bx
    add dx,2      ;IER address of the Interrupt Enable register
    mov ax,0   ;关闭所有中断 使用查询
    out dx,ax
;8255初始化
mov  dx,04d6h  ;控制寄存器地址
mov  ax,0B8h   ;设置为方式1,PA输入，PC上部输入，PC下部输出
out  dx,ax
mov  ax,09h    ;PC4置1
out  dx,ax 

repeat:
     call recv
     cmp al, '@'
     jne repeat  
     call recv
     cmp al, 's'
     jne j_t
     call recv
     mov which, al
     call recv
     cmp al, '.'
     jne repeat
     sti
     jmp repeat
  j_t:
     cmp al, 't'
     jne j_d
     call recv
     cmp al, '.'
     jne repeat
     cli
     jmp repeat
  j_d:
     cmp al, 'd'
     jne j_l
     call recv  
     mov dxx1, al    ;发送的@dx.命令每一位都是char
     call recv
     cmp al, '.'
     jne repeat
     mov al, dxx1
     call DAC
     jmp repeat
  j_l:
     cmp al, 'l'
     jne repeat
     call recv
     cmp al, '.'
     jne repeat
     call light
     jmp repeat 

  

;中断向量
hint:
    push ax
    push bx
    push dx
    pushf
    mov al, which
    cmp al, '0'
    jne j_mode1 
    mov ax,04e0h 
    mov an_addr, ax;0路模拟地址
    call an_sub 
    push ax 
    mov al, '@'
    call send
    mov al, '0'
    call send
    pop ax; an
    call send
    mov al, '.'
    call send
    jmp hint_iret
  j_mode1:
    cmp al, '1'
    jne hint_iret 
    mov ax,04e2h 
    mov an_addr, ax;1路模拟地址
    call an_sub 
    push ax 
    mov al, '@'
    call send
    mov al, '0'
    call send
    pop ax; an
    call send
    mov al, '.'
    call send
hint_iret: 
    
    popf  
    pop dx 
    pop bx
    pop ax 
iret 


DAC:
     MOV DX,0000H ;DAC0832芯片地址送DX
     out dx,al
     mov dx,0002h
     out dx,al

     
     ret      
light:
     push ax
     mov al,0ffh
     mov dx,04b0h         
     out dx,al
     pop  ax
     ret
     

recv:
    mov bx,0480h
    mov dx,bx
    add dx,0ah   ;指向线路通信状态寄存器     
waitr:     
    in   al,dx
    test al,01h ;检测是否收到字符
    jnz  recvok  ;如果收到
    jmp  waitr ;未收到字符跳回等待继续查询
    recvok:
    mov dx,bx  ;把接收到的字符读入CPU
    in al,dx
ret       


     
send: 
    push ax
    mov bx,0480h
    mov dx,bx
    add dx,0ah           ;LSR 指向通信线路状态寄存器
    waits:
    in   al,dx    ;检测发送保持寄存器是否空
    test al,20h
    jnz  sendok3    ;如果是空 既发送完毕
    jmp  waits    ;否则继续查询发送状态
    sendok3:
    pop ax     ;将第一个字符发送
    mov dx,bx
    out dx,ax 
ret 

  

;an_sub
an_sub:
;0809初始化
     mov ax,04e0h
     mov dx,ax
     mov ax,34h
     out dx,ax   ;启动通道 0   
     
wait1:  
    mov dx,04f0h     
    in ax,dx   ;读 EOC
    and ax,1
    cmp ax,1
    jne wait1
    mov ax, an_addr   ;如果EOC=0,waiting....
    mov dx, ax
    in ax,dx   ;读转换结果
    
    and ax,0ffh
    mov bx,ax
    push ax
     
disp: 
    mov di,offset segcod
 mov ax,08h   ;工作方式，16位，左入
 mov dx,con8279
 out dx,ax
 mov ax,90h   
 mov dx,con8279
 out dx,ax   ;写显示RAM命令，地址自增
 mov dx,dat8279
 push bx
 and bx,0f0h          ;取高4位
 mov cl,4
 shr bx,cl
 add di,bx
 mov al,cs:[di]
 mov ah,0
 out dx,ax    ;写RAM0
 nop
 nop
 mov di,offset segcod
 pop bx
 and bx,0fh            ;取低4位
 add di,bx
 mov al,cs:[di]
 mov ah,0
 out dx,ax     ;写RAM1
        pop ax
ret 
code ends
end start 
