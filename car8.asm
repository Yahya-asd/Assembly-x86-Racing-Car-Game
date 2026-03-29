[org 0x100]
jmp start

;================================================================;
; DATA SEGMENT
;================================================================;

; --- User Info ---
player_name     times 21 db '$'
roll_number     times 21 db '$'
score           dw 0

score_str       times 10 db 0   ; Changed to 0-fill, no '$' needed

; --- Game Settings ---
current_lane    db 1    ; 0=Left, 1=Center, 2=Right
player_row      dw 18
player_col      dw 37   
game_active     db 0
difficulty      dw 0    ; Difficulty counter for scaling

; --- Timers ---
tick_count      dw 0
speed_counter   dw 0
game_timer      dw 0    ; Game elapsed time in seconds
timer_second    dw 0    ; Counter for 1-second intervals

; Adjusted timers
timer_obstacle  dw 0
timer_coin      dw 0    
timer_fuel_spawn dw 0  
timer_fuel_dec  dw 0     
fuel_level      dw 5000 

; --- Input Flags ---
key_up          db 0
key_down        db 0
key_left        db 0
key_right       db 0
key_esc         db 0
prev_left       db 0
prev_right      db 0

; --- ISR Storage ---
oldkb           dd 0 
oldtimer        dd 0 
rand_seed       dw 0

; --- Object Management (Max 10 objects on screen) ---
MAX_OBJECTS     equ 10
obj_active      times 10 db 0   ; 1=active, 0=inactive
obj_type        times 10 db 0   ; 0=obstacle, 1=coin, 2=fuel
obj_row         times 10 dw 0   ; Current row position
obj_col         times 10 dw 0   ; Column position (22, 37, or 52)

; --- Strings ---
str_title       db '==== SUPER NASM RACING ====', 0
str_devs        db 'Devs: Student A & Student B', 0
str_loading     db 'Loading Game Assets...', 0

str_enter_name  db 'Enter Name: ', 0
str_enter_roll  db 'Enter Roll #: ', 0

str_inst_t      db 'INSTRUCTIONS', 0
str_inst_1      db 'Use ARROW KEYS to switch lanes.', 0
str_inst_2      db 'Collect $ for +10 Score.', 0
str_inst_3      db 'Collect F for Fuel.', 0
str_inst_4      db 'Avoid Blue Cars!', 0
str_press_ent   db 'Press ENTER to continue...', 0

str_start_msg   db 'PRESS ANY KEY TO START ENGINE', 0
str_pause       db '    PAUSED - EXIT? (Y/N)    ', 0

str_gameover    db '      GAME OVER      ', 0
str_cause_fuel  db 'Reason: Out of Fuel  ', 0
str_cause_crash db 'Reason: Car Crash    ', 0
str_cause_user  db 'Reason: User Quit    ', 0
str_final_sc    db 'Final Score: ', 0
str_time_label  db 'Time: ', 0
str_restart     db 'Space: Main Menu | Esc: Exit', 0

cause_ptr       dw 0

;================================================================;
; INTERRUPT SERVICE ROUTINES
;================================================================;
kbisr:
    push ax
    in al, 0x60
    
    cmp al, 0x48 ; Up
    je .ku
    cmp al, 0x50 ; Down
    je .kd
    cmp al, 0x4B ; Left
    je .kl
    cmp al, 0x4D ; Right
    je .kr
    cmp al, 0x01 ; Esc
    je .ke

    cmp al, 0xC8 ; Up Rel
    je .ru
    cmp al, 0xD0 ; Down Rel
    je .rd
    cmp al, 0xCB ; Left Rel
    je .rl
    cmp al, 0xCD ; Right Rel
    je .rr
    cmp al, 0x81 ; Esc Rel
    je .re
    jmp .chain

.ku: mov byte [cs:key_up], 1
     jmp .ack
.kd: mov byte [cs:key_down], 1
     jmp .ack
.kl: mov byte [cs:key_left], 1
     jmp .ack
.kr: mov byte [cs:key_right], 1
     jmp .ack
.ke: mov byte [cs:key_esc], 1
     jmp .ack

.ru: mov byte [cs:key_up], 0
     jmp .ack
.rd: mov byte [cs:key_down], 0
     jmp .ack
.rl: mov byte [cs:key_left], 0
     jmp .ack
.rr: mov byte [cs:key_right], 0
     jmp .ack
.re: mov byte [cs:key_esc], 0
     jmp .ack

.ack:
    mov al, 0x20
    out 0x20, al
    pop ax
    iret
.chain:
    pop ax
    jmp far [cs:oldkb]

timerisr:
    push ax
    inc word [cs:tick_count]
    mov al, 0x20
    out 0x20, al
    pop ax
    iret

;================================================================;
; SCREEN PROCEDURES
;================================================================;

clrscr:
    mov ax, 0xb800
    mov es, ax
    xor di, di
    mov ax, 0x0720
    mov cx, 2000
    rep stosw
    ret

print_str:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    mov ax, 0xb800
    mov es, ax
    mov al, dh
    mov bl, 80
    mul bl
    xor dh, dh
    add ax, dx
    shl ax, 1
    mov di, ax
    mov ah, 0x0F
.loop:
    lodsb
    cmp al, 0
    je .done
    stosw
    jmp .loop
.done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; FIX: Completely rewritten num_to_str to eliminate garbage output
num_to_str:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov di, score_str   ; Point DI to buffer start
    mov bx, 10          ; Divisor
    xor cx, cx          ; Digit count

    test ax, ax         ; Handle 0 specifically
    jnz .process_digits
    mov byte [di], '0'
    inc di
    jmp .terminate

.process_digits:
    xor dx, dx
    div bx              ; AX / 10, DX = digit
    push dx             ; Save digit on stack
    inc cx              ; Count digits
    test ax, ax         ; Are we done?
    jnz .process_digits

.pop_digits:
    pop dx              ; Restore digit
    add dl, '0'         ; Convert to ASCII
    mov [di], dl        ; Write to buffer
    inc di
    loop .pop_digits

.terminate:
    mov byte [di], 0    ; Null-terminate

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

wait_retrace:
    mov dx, 0x3DA
.vr:
    in al, dx
    test al, 8
    jz .vr
    ret

screen_intro:
    call clrscr
    mov dh, 6
    mov dl, 25
    mov si, str_title
    call print_str
    
    mov dh, 8
    mov dl, 25
    mov si, str_devs
    call print_str
    
    mov dh, 15
    mov dl, 30
    mov si, str_loading
    call print_str
    
    mov ax, 0xb800
    mov es, ax
    mov di, (16 * 80 + 30) * 2
    mov cx, 20
    mov ax, 0x1020 
.load_loop:
    stosw
    push cx
    call delay_medium
    pop cx
    loop .load_loop
    
    call delay_medium
    ret

screen_input:
    call clrscr
    
    mov dh, 10
    mov dl, 20
    mov si, str_enter_name
    call print_str
    mov di, player_name
    call get_input_string

    mov dh, 12
    mov dl, 20
    mov si, str_enter_roll
    call print_str
    mov di, roll_number
    call get_input_string
    ret

get_input_string:
    push cx
    xor cx, cx
.wait_key:
    mov ah, 0
    int 0x16
    cmp al, 0x0D
    je .done_inp
    cmp al, 0x08
    je .backspace
    
    cmp cx, 15
    jae .wait_key
    
    stosb
    inc cx
    mov ah, 0x0E
    int 0x10
    jmp .wait_key

.backspace:
    cmp cx, 0
    je .wait_key
    dec di
    dec cx
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, 0x20
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .wait_key

.done_inp:
    mov byte [di], 0   ; Null-terminate input
    pop cx
    ret

screen_instructions:
    call clrscr
    mov dh, 5
    mov dl, 30
    mov si, str_inst_t
    call print_str
    
    mov dh, 8
    mov dl, 20
    mov si, str_inst_1
    call print_str
    mov dh, 10
    mov dl, 20
    mov si, str_inst_2
    call print_str
    mov dh, 12
    mov dl, 20
    mov si, str_inst_3
    call print_str
    mov dh, 14
    mov dl, 20
    mov si, str_inst_4
    call print_str
    
    mov dh, 20
    mov dl, 20
    mov si, str_press_ent
    call print_str
    
.wait_i:
    mov ah, 0
    int 0x16
    cmp al, 0x0D
    jne .wait_i
    ret

screen_game_over:
    call unhook_interrupts
    call clrscr
    
    mov dh, 5
    mov dl, 30
    mov si, str_gameover
    call print_str
    
    mov dh, 8
    mov dl, 30
    mov si, [cause_ptr]
    call print_str
    
    mov dh, 10
    mov dl, 30
    mov si, player_name
    call print_str
    
    mov dh, 11
    mov dl, 30
    mov si, roll_number
    call print_str
    
    ; Display final score
    mov dh, 13
    mov dl, 30
    mov si, str_final_sc
    call print_str
    
    mov ax, [score]
    call num_to_str
    mov dh, 13
    mov dl, 43
    mov si, score_str
    call print_str
    
    ; Display time
    mov dh, 15
    mov dl, 30
    mov si, str_time_label
    call print_str
    
    mov ax, [game_timer]
    call num_to_str
    mov dh, 15
    mov dl, 36
    mov si, score_str
    call print_str
    
    mov dh, 18
    mov dl, 25
    mov si, str_restart
    call print_str

.wait_end:
    mov ah, 0
    int 0x16
    cmp al, 0x1B ; Esc
    je .do_exit
    cmp al, 0x20 ; Space
    je .do_restart
    jmp .wait_end

.do_exit:
    mov ax, 0x4c00
    int 0x21
.do_restart:
    jmp start

;================================================================;
; GAME LOGIC
;================================================================;

hook_interrupts:
    cli
    xor ax, ax
    mov es, ax
    mov ax, [es:8*4]
    mov [oldtimer], ax
    mov ax, [es:8*4+2]
    mov [oldtimer+2], ax
    mov ax, [es:9*4]
    mov [oldkb], ax
    mov ax, [es:9*4+2]
    mov [oldkb+2], ax
    mov word [es:8*4], timerisr
    mov [es:8*4+2], cs
    mov word [es:9*4], kbisr
    mov [es:9*4+2], cs
    sti
    ret

unhook_interrupts:
    cli
    xor ax, ax
    mov es, ax
    mov ax, [oldtimer]
    mov [es:8*4], ax
    mov ax, [oldtimer+2]
    mov [es:8*4+2], ax
    mov ax, [oldkb]
    mov [es:9*4], ax
    mov ax, [oldkb+2]
    mov [es:9*4+2], ax
    sti
    ret

rand_num:
    push dx
    push cx
    mov ax, [rand_seed]
    add ax, [tick_count]
    add ax, 0x1357
    rol ax, 3
    xor ax, [score]
    mov [rand_seed], ax
    pop cx
    pop dx
    ret

draw_background_static:
    mov ax, 0xb800
    mov es, ax
    xor di, di
    mov cx, 25
.bg_l:
    push cx
    mov ax, 0x6020      ; FIX: Brown background (6) for grass area
    mov cx, 15
    rep stosw
    mov ax, 0x4020
    mov cx, 1
    rep stosw
    mov ax, 0x0720
    mov cx, 48
    rep stosw
    mov ax, 0x4020 
    mov cx, 1
    rep stosw
    mov ax, 0x6020      ; FIX: Brown background (6) for grass area
    mov cx, 15
    rep stosw
    pop cx
    loop .bg_l
    ret

scroll_road:
    mov ah, 0x07
    mov al, 0x01
    mov bh, 0x07
    mov ch, 0
    mov cl, 16
    mov dh, 24
    mov dl, 63
    int 0x10
    ret

draw_strip:
    mov ax, 0xb800
    mov es, ax
    mov di, (0 * 80 + 16) * 2
    mov cx, 48
    mov ax, 0x0720
    rep stosw
    
    inc word [tick_count] 
    test byte [tick_count], 4
    jz .skip
    mov ax, 0x7020
    mov di, (0 * 80 + 31) * 2
    mov [es:di], ax
    mov [es:di+2], ax
    mov di, (0 * 80 + 47) * 2
    mov [es:di], ax
    mov [es:di+2], ax
.skip:
    ret

draw_car:
    ; DI=Pos, BL=Attr (Color)
    ; USES: AX, CX, DI.
    ; NOTE: ES must be set to 0xB800 by caller.
    
    push di
    ; ROW 1: Tire-Body-Tire
    mov ax, 0x08DB      ; Dark Grey Tire (0x08)
    mov [es:di], ax
    add di, 2
    
    mov ah, bl          ; Car Color
    mov al, 0xDB        ; Solid Block
    mov cx, 4
    rep stosw
    
    mov ax, 0x08DB      ; Tire
    mov [es:di], ax
    
    pop di
    add di, 160
    
    ; ROW 2: Body
    push di
    mov ah, bl
    mov al, 0xDB
    mov cx, 6
    rep stosw
    pop di
    add di, 160
    
    ; ROW 3: Body
    push di
    mov ah, bl
    mov al, 0xDB
    mov cx, 6
    rep stosw
    pop di
    add di, 160
    
    ; ROW 4: Tire-Body-Tire
    push di
    mov ax, 0x08DB      ; Tire
    mov [es:di], ax
    add di, 2
    
    mov ah, bl          ; Car Color
    mov al, 0xDB
    mov cx, 4
    rep stosw
    
    mov ax, 0x08DB      ; Tire
    mov [es:di], ax
    pop di
    ret

move_player_logic:
    ; Clear Old Position
    mov ax, 0xb800
    mov es, ax
    mov ax, [player_row]
    mov bx, 80
    mul bx
    add ax, [player_col]
    shl ax, 1
    mov di, ax
    sub di, 4
    mov cx, 10
    mov dx, 5
    mov ax, 0x0720
.cl_loop:
    push di
    push cx
    rep stosw
    pop cx
    pop di
    add di, 160
    dec dx
    jnz .cl_loop

    ; Handle Right
    cmp byte [key_right], 1
    jne .rst_r
    cmp byte [prev_right], 1
    je .done_r
    
    cmp byte [current_lane], 2
    jae .mark_r
    inc byte [current_lane]
.mark_r:
    mov byte [prev_right], 1
    jmp .done_r
    
.rst_r:
    mov byte [prev_right], 0
.done_r:

    ; Handle Left
    cmp byte [key_left], 1
    jne .rst_l
    cmp byte [prev_left], 1
    je .done_l
    
    cmp byte [current_lane], 0
    jbe .mark_l
    dec byte [current_lane]
.mark_l:
    mov byte [prev_left], 1
    jmp .done_l

.rst_l:
    mov byte [prev_left], 0
.done_l:

    ; Handle Up/Down
.chk_u:
    cmp byte [key_up], 1
    jne .chk_d
    cmp word [player_row], 1
    jbe .chk_d
    dec word [player_row]
.chk_d:
    cmp byte [key_down], 1
    jne .calc
    cmp word [player_row], 20
    jae .calc
    inc word [player_row]

.calc:
    cmp byte [current_lane], 0
    je .l0
    cmp byte [current_lane], 1
    je .l1
    mov word [player_col], 52
    jmp .done_m
.l0:
    mov word [player_col], 22
    jmp .done_m
.l1:
    mov word [player_col], 37
.done_m:
    ret

; NEW: Proper collision detection
check_collision:
    push bx
    push cx
    push si
    
    xor bx, bx ; Object index
.check_loop:
    cmp bx, MAX_OBJECTS
    jb .loop_ok        ; FIX: Jump trampoline
    jmp .no_collision
.loop_ok:
    
    ; Check if active
    mov si, obj_active
    add si, bx
    cmp byte [si], 0
    jne .is_active_obj ; FIX: Jump trampoline
    jmp .next_obj
.is_active_obj:
    
    ; Get object row and col
    mov si, obj_row
    shl bx, 1 ; *2 for word access
    add si, bx
    mov ax, [si]
    
    ; Check row collision (player is rows 18-21, check if object in range)
    mov cx, [player_row]
    sub cx, 2
    
    ; FIX: Inverse Logic for Long Jump
    cmp ax, cx
    jge .check_row_upper
    jmp .next_obj_restore
.check_row_upper:
    add cx, 6
    cmp ax, cx
    jle .check_cols
    jmp .next_obj_restore
.check_cols:
    
    ; Check column collision
    shr bx, 1 ; Back to byte index
    mov si, obj_col
    shl bx, 1
    add si, bx
    mov ax, [si]
    
    mov cx, [player_col]
    sub cx, 3
    
    ; FIX: Inverse Logic for Long Jump
    cmp ax, cx
    jge .check_col_upper
    jmp .next_obj_restore
.check_col_upper:
    add cx, 9
    cmp ax, cx
    jle .collision_confirmed
    jmp .next_obj_restore
    
.collision_confirmed:
    ; COLLISION DETECTED!
    shr bx, 1
    mov si, obj_type
    add si, bx
    mov al, [si]
    
    cmp al, 0 ; Obstacle
    je .hit_obstacle
    cmp al, 1 ; Coin
    je .hit_coin
    cmp al, 2 ; Fuel
    je .hit_fuel
    
.hit_obstacle:
    ; Deactivate object
    mov si, obj_active
    add si, bx
    mov byte [si], 0
    
    pop si
    pop cx
    pop bx
    
    mov word [cause_ptr], str_cause_crash
    jmp game_over_trigger
    
.hit_coin:
    ; Add 10 to score
    add word [score], 10
    
    ; Deactivate object
    mov si, obj_active
    add si, bx
    mov byte [si], 0
    jmp .next_obj
    
.hit_fuel:
    ; Add 1000 fuel
    add word [fuel_level], 1000
    cmp word [fuel_level], 6000
    jbe .fuel_ok
    mov word [fuel_level], 6000
.fuel_ok:
    ; Deactivate object
    mov si, obj_active
    add si, bx
    mov byte [si], 0
    jmp .next_obj

.next_obj_restore:
    shr bx, 1
.next_obj:
    inc bx
    jmp .check_loop
    
.no_collision:
    pop si
    pop cx
    pop bx
    ret

; NEW: Move and draw all objects
move_objects:
    push bx
    push cx
    push si
    push di
    
    mov ax, 0xb800
    mov es, ax
    
    xor bx, bx
.obj_loop:
    cmp bx, MAX_OBJECTS
    jb .proc_move       ; FIX: Jump trampoline
    jmp .done_objs
.proc_move:
    
    ; Check if active
    mov si, obj_active
    add si, bx
    cmp byte [si], 0
    jne .active_move    ; FIX: Jump trampoline
    jmp .next_o
.active_move:
    
    ; Clear old position
    push bx
    mov si, obj_row
    shl bx, 1
    add si, bx
    mov ax, [si]
    
    mov cx, 80
    mul cx
    
    shr bx, 1
    mov si, obj_col
    shl bx, 1
    add si, bx
    add ax, [si]
    
    shl ax, 1
    mov di, ax
    
    ; Get object type for size
    shr bx, 1
    mov si, obj_type
    add si, bx
    mov cl, [si]
    
    cmp cl, 0 ; Obstacle (car - 4 rows)
    je .clear_car
    
    ; Coin or Fuel (1 char)
    mov ax, 0x0720
    mov [es:di], ax
    jmp .cleared
    
.clear_car:
    mov cx, 4
.clear_car_loop:
    push cx          ; <--- SAVE OUTER LOOP COUNTER
    push di
    mov ax, 0x0720
    mov cx, 6
    rep stosw        ; <--- CLOBBERS CX (Sets it to 0)
    pop di
    add di, 160
    pop cx           ; <--- RESTORE OUTER LOOP COUNTER
    loop .clear_car_loop
    
.cleared:
    pop bx
    
    ; Move down
    mov si, obj_row
    push bx
    shl bx, 1
    add si, bx
    inc word [si]
    
    ; Check if off screen
    cmp word [si], 24
    jl .still_on
    
    ; Deactivate
    shr bx, 1
    mov si, obj_active
    add si, bx
    mov byte [si], 0
    pop bx
    jmp .next_o
    
.still_on:
    pop bx
    
    ; Draw at new position
    push bx
    mov si, obj_row
    shl bx, 1
    add si, bx
    mov ax, [si]
    
    mov cx, 80
    mul cx
    
    shr bx, 1
    mov si, obj_col
    shl bx, 1
    add si, bx
    add ax, [si]
    
    shl ax, 1
    mov di, ax
    
    ; Get type and draw
    shr bx, 1
    mov si, obj_type
    add si, bx
    mov cl, [si]
    
    cmp cl, 0
    je .draw_obstacle
    cmp cl, 1
    je .draw_coin
    
    ; Draw fuel
    mov ax, 0x0F46
    mov [es:di], ax
    jmp .drawn
    
.draw_coin:
    mov ax, 0x0E24
    mov [es:di], ax
    jmp .drawn
    
.draw_obstacle:
    mov bl, 0x09        ; FIX: Set obstacle color to Bright Blue
    call draw_car
    jmp .drawn          ; FIX: Skip other draw calls
    
.drawn:
    pop bx
    
.next_o:
    inc bx
    jmp .obj_loop
    
.done_objs:
    pop di
    pop si
    pop cx
    pop bx
    ret

; NEW: Spawn objects with difficulty scaling
spawn_objects:
    ; Calculate spawn rates based on difficulty
    mov ax, [difficulty]
    mov bx, 100
    xor dx, dx
    div bx
    
    ; Base intervals (get faster with difficulty)
    mov bx, 20          ; FIX: Increased base interval from 10 to 20 (half frequency)
    sub bx, ax
    cmp bx, 3
    jge .rates_ok
    mov bx, 3
.rates_ok:
    
    ; Check obstacle spawn timer
    inc word [timer_obstacle]
    mov ax, [timer_obstacle]
    
    ; FIX: Inverse Logic for Long Jump
    cmp ax, bx
    jge .do_spawn_obs
    jmp .check_coin
.do_spawn_obs:
    mov word [timer_obstacle], 0
    call spawn_obstacle
    
.check_coin:
    ; Coin spawn (slightly faster than obstacles)
    mov cx, bx
    shr cx, 1
    inc cx
    inc word [timer_coin]
    mov ax, [timer_coin]
    
    ; FIX: Inverse Logic for Long Jump
    cmp ax, cx
    jge .do_spawn_coin
    jmp .check_fuel
.do_spawn_coin:
    mov word [timer_coin], 0
    call spawn_coin
    
.check_fuel:
    ; Fuel spawn (less frequent)
    mov cx, bx
    shl cx, 1
    add cx, 5
    inc word [timer_fuel_spawn]
    mov ax, [timer_fuel_spawn]
    
    ; FIX: Inverse Logic for Long Jump
    cmp ax, cx
    jge .do_spawn_fuel
    jmp .done_spawn
.do_spawn_fuel:
    mov word [timer_fuel_spawn], 0
    call spawn_fuel
    
.done_spawn:
    ret

spawn_obstacle:
    push bx
    push cx
    
    ; Find free slot
    xor bx, bx
.find_slot:
    cmp bx, MAX_OBJECTS
    jae .no_slot
    
    mov si, obj_active
    add si, bx
    cmp byte [si], 0
    je .found_slot
    inc bx
    jmp .find_slot
    
.found_slot:
    ; Activate object
    mov byte [si], 1
    
    ; Set type to obstacle
    mov si, obj_type
    add si, bx
    mov byte [si], 0
    
    ; Set row to 0
    mov si, obj_row
    shl bx, 1
    add si, bx
    mov word [si], 0
    
    ; Random lane
    call rand_num
    mov dx, 0
    mov cx, 3
    div cx
    
    ; DX = 0, 1, or 2
    cmp dx, 0
    je .obs_lane0
    cmp dx, 1
    je .obs_lane1
    
    mov ax, 52
    jmp .set_obs_col
.obs_lane0:
    mov ax, 22
    jmp .set_obs_col
.obs_lane1:
    mov ax, 37
    
.set_obs_col:
    shr bx, 1
    mov si, obj_col
    shl bx, 1
    add si, bx
    mov [si], ax
    
.no_slot:
    pop cx
    pop bx
    ret

spawn_coin:
    push bx
    push cx
    
    xor bx, bx
.find_slot_c:
    cmp bx, MAX_OBJECTS
    jae .no_slot_c
    
    mov si, obj_active
    add si, bx
    cmp byte [si], 0
    je .found_slot_c
    inc bx
    jmp .find_slot_c
    
.found_slot_c:
    mov byte [si], 1
    
    mov si, obj_type
    add si, bx
    mov byte [si], 1
    
    mov si, obj_row
    shl bx, 1
    add si, bx
    mov word [si], 0
    
    call rand_num
    mov dx, 0
    mov cx, 3
    div cx
    
    cmp dx, 0
    je .coin_lane0
    cmp dx, 1
    je .coin_lane1
    
    mov ax, 52
    jmp .set_coin_col
.coin_lane0:
    mov ax, 22
    jmp .set_coin_col
.coin_lane1:
    mov ax, 37
    
.set_coin_col:
    shr bx, 1
    mov si, obj_col
    shl bx, 1
    add si, bx
    mov [si], ax
    
.no_slot_c:
    pop cx
    pop bx
    ret

spawn_fuel:
    push bx
    push cx
    
    xor bx, bx
.find_slot_f:
    cmp bx, MAX_OBJECTS
    jae .no_slot_f
    
    mov si, obj_active
    add si, bx
    cmp byte [si], 0
    je .found_slot_f
    inc bx
    jmp .find_slot_f
    
.found_slot_f:
    mov byte [si], 1
    
    mov si, obj_type
    add si, bx
    mov byte [si], 2
    
    mov si, obj_row
    shl bx, 1
    add si, bx
    mov word [si], 0
    
    call rand_num
    mov dx, 0
    mov cx, 3
    div cx
    
    cmp dx, 0
    je .fuel_lane0
    cmp dx, 1
    je .fuel_lane1
    
    mov ax, 52
    jmp .set_fuel_col
.fuel_lane0:
    mov ax, 22
    jmp .set_fuel_col
.fuel_lane1:
    mov ax, 37
    
.set_fuel_col:
    shr bx, 1
    mov si, obj_col
    shl bx, 1
    add si, bx
    mov [si], ax
    
.no_slot_f:
    pop cx
    pop bx
    ret

draw_hud:
    push ax
    push bx
    push dx
    push si
    
    ; Draw Score
    mov ax, 0xb800
    mov es, ax
    mov di, (0 * 80 + 1) * 2
    mov si, .str_score
    mov ah, 0x6F        ; FIX: White on Brown attribute for visibility
.print_score:
    lodsb
    cmp al, 0
    je .score_val
    stosw
    jmp .print_score
    
.score_val:
    mov ax, [score]
    call num_to_str
    mov si, score_str
.print_val:
    lodsb
    cmp al, 0           ; FIX: Check for null terminator, not '$'
    je .fuel_hud
    mov ah, 0x0E
    stosw
    jmp .print_val
    
.fuel_hud:
    ; Draw Fuel Bar Label
    mov di, (0 * 80 + 67) * 2
    mov si, .str_fuel
    mov ah, 0x6F        ; White on Brown
.print_fuel:
    lodsb
    cmp al, 0
    je .clear_bar_area
    stosw
    jmp .print_fuel

.clear_bar_area:
    ; 1. CLEAR the entire bar area first (overwrite with brown spaces)
    mov di, (1 * 80 + 67) * 2
    mov cx, 10          ; Max width of bar
    mov ax, 0x6F20      ; Brown background (6F), Space char (20)
    rep stosw           ; Wipe the area clean

    ; 2. Calculate active fuel length
    mov ax, [fuel_level]
    mov bx, 500         ; Divisor: 5000 / 500 = 10 blocks (Full Bar)
    xor dx, dx
    div bx
    
    cmp ax, 10
    jbe .limit_ok
    mov ax, 10
.limit_ok:
    mov cx, ax          ; CX = number of blocks to draw
    cmp cx, 0
    je .no_fuel_bar     ; If 0, we are done (area is already cleared)

    ; 3. Draw active blocks over the cleared area
    mov di, (1 * 80 + 67) * 2 ; Reset DI to start of bar
    mov ah, 0x6F        ; Brown background
    mov al, 0xDB        ; Solid block
.draw_bar:
    stosw
    loop .draw_bar
    
.no_fuel_bar:
    pop si
    pop dx
    pop bx
    pop ax
    ret

.str_score db 'Score: ', 0
.str_fuel  db 'Fuel:', 0

update_timers:
    ; Update game timer (seconds)
    inc word [timer_second]
    cmp word [timer_second], 18
    jl .fuel_check
    
    mov word [timer_second], 0
    inc word [game_timer]
    inc word [difficulty]
    
.fuel_check:
    ; Decrease fuel
    inc word [timer_fuel_dec]
    cmp word [timer_fuel_dec], 3
    jl .done_timer
    
    mov word [timer_fuel_dec], 0
    sub word [fuel_level],50; subracts 2 (Depletes twice as fast)
    cmp word [fuel_level], 0
    jle .out_of_fuel
    jmp .done_timer
    
.out_of_fuel:
    mov word [fuel_level], 0
    mov word [cause_ptr], str_cause_fuel
    jmp game_over_trigger
    
.done_timer:
    ret

game_loop:
    call draw_background_static
    
    mov byte [game_active], 1
    mov word [tick_count], 0
    
.main_loop:
    cmp byte [game_active], 0
    jne .check_pause
    jmp .exit_game
.check_pause:

    ; Check ESC for pause
    cmp byte [key_esc], 1
    jne .check_speed
    jmp .pause_game
.check_speed:
    
    ; Wait for speed
    mov ax, [tick_count]
    sub ax, [speed_counter]
    
    ; FIX: Inverse Logic for Long Jump backwards
    cmp ax, 2
    jge .do_update
    jmp .main_loop
    
.do_update:
    mov ax, [tick_count]
    mov [speed_counter], ax
    
    ; Game updates
    call scroll_road
    call draw_strip
    call update_timers
    call spawn_objects
    call move_objects
    call move_player_logic
    call check_collision
    
    ; Draw player
    mov ax, 0xb800
    mov es, ax
    mov ax, [player_row]
    mov bx, 80
    mul bx
    add ax, [player_col]
    shl ax, 1
    mov di, ax
    mov bl, 0x0C
    call draw_car
    
    call draw_hud
    call wait_retrace
    
    jmp .main_loop
    
.pause_game:
    mov ax, 0xb800
    mov es, ax
    mov di, (12 * 80 + 25) * 2
    mov si, str_pause
    mov ah, 0x4F
.print_pause:
    lodsb
    cmp al, 0
    je .wait_pause
    stosw
    jmp .print_pause
    
.wait_pause:
    mov byte [key_esc], 0
    mov ah, 0
    int 0x16
    
    cmp al, 'y'
    je .user_quit
    cmp al, 'Y'
    je .user_quit
    
    ; Redraw that area
    call draw_background_static
    jmp .main_loop
    
.user_quit:
    mov word [cause_ptr], str_cause_user
    jmp game_over_trigger
    
.exit_game:
    ret

game_over_trigger:
    mov byte [game_active], 0
    call screen_game_over
    ret

delay_medium:
    push cx
    mov cx, 0x2FFF      ; FIX: Reduced delay for faster loading
.d1:
    loop .d1
    pop cx
    ret

;================================================================;
; MAIN PROGRAM
;================================================================;
start:
    ; Initialize
    mov word [score], 0
    mov word [game_timer], 0
    mov word [difficulty], 0
    mov word [fuel_level], 5000
    mov byte [current_lane], 1
    mov word [player_row], 18
    mov word [player_col], 37
    
    ; Clear all objects
    xor bx, bx
.clear_objs:
    cmp bx, MAX_OBJECTS
    jae .objs_cleared
    mov si, obj_active
    add si, bx
    mov byte [si], 0
    inc bx
    jmp .clear_objs
    
.objs_cleared:
    ; Show screens
    call screen_intro
    call screen_input
    call screen_instructions
    
    ; Start screen
    call clrscr
    mov dh, 12
    mov dl, 25
    mov si, str_start_msg
    call print_str
    
    mov ah, 0
    int 0x16
    
    ; Hook interrupts and start game
    call hook_interrupts
    call game_loop
    
    ; Should not reach here (game_over handles exit)
    mov ax, 0x4c00
    int 0x21