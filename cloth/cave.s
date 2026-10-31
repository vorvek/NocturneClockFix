# Nocturne cloth fix. Runs in the free bytes at the end of the AUTO section (0x574c20).
# Fixed step: CCloth::simulate does the dynamics at 30 Hz at every frame rate.
# Rest threshold: a free particle that moves slower than REST ft/s in a step stops.
# Interpolation: the frames between two steps draw free particles between the two results.
#
# In CCloth::simulate: edi = this, ebp + 0x20 = dt.
# The particle array has 800 slots. No cloth uses slot 799, so it holds the state.
.intel_syntax noprefix

.set MAGIC_OFS,  0x379fc              # slot 799 + 0x00: state marker
.set ACC_OFS,    0x37a00              # slot 799 + 0x04: time since last step
.set MAGIC,      0x31544c43           # "CLT1"
.set P_COUNT,    0x104
.set P_OUT,      0x10c
.set P_ARRAY,    0x398
.set P_SIZE,     0x11c
.set P_LOCKED,   0x74
.set P_PREV,     0xcc
.set INV_DT,     0x3ab00
.set FIXED_MUL,  0x59b360             # float 256.0

.text
.globl _start
_start:
    .byte   0xe9                      # 0x437183 jumps here
    .long   step_gate - . - 4
    .byte   0xe9                      # 0x43774c jumps here
    .long   rest_pass - . - 4

# After the locked particles and bones update, before the dynamics.
step_gate:
    cmp     dword ptr [edi + MAGIC_OFS], MAGIC
    je      1f
    mov     dword ptr [edi + MAGIC_OFS], MAGIC
    mov     eax, dword ptr [step_near]
    mov     dword ptr [edi + ACC_OFS], eax    # first call: step now, draw the result
    jmp     run_step
1:  fld     dword ptr [edi + ACC_OFS]
    fadd    dword ptr [ebp + 0x20]
    fcom    dword ptr [step_len]
    fnstsw  ax
    sahf
    jae     2f
    fstp    dword ptr [edi + ACC_OFS]
    jmp     write_out                 # no step in this frame
2:  fsub    dword ptr [step_len]
    fld     dword ptr [ebp + 0x20]
    fcomp   dword ptr [step_len]
    fnstsw  ax
    sahf
    jae     3f
    fstp    dword ptr [edi + ACC_OFS]
    mov     eax, dword ptr [step_len]
    mov     dword ptr [ebp + 0x20], eax
    mov     eax, dword ptr [step_inv]
    mov     dword ptr [edi + INV_DT], eax
    jmp     run_step
3:  fstp    st(0)                     # frame longer than a step: keep its dt
    mov     eax, dword ptr [step_near]
    mov     dword ptr [edi + ACC_OFS], eax
run_step:
    mov     edx, dword ptr [ebp + 0x1c]       # bytes replaced at 0x437183
    push    edx
    lea     eax, [esp + 0xc]
    push    eax
    mov     eax, 0x43718c
    jmp     eax

# After the friction pass of a step.
rest_pass:
    mov     ecx, dword ptr [edi + P_COUNT]
    lea     esi, [edi + P_ARRAY]
    fld     dword ptr [ebp + 0x20]
    fmul    dword ptr [rest_speed]
    fmul    st(0), st(0)              # limit for squared movement in this step
4:  test    ecx, ecx
    jle     6f
    cmp     dword ptr [esi + P_LOCKED], 0
    jne     5f
    fld     dword ptr [esi]
    fsub    dword ptr [esi + P_PREV]
    fmul    st(0), st(0)
    fld     dword ptr [esi + 4]
    fsub    dword ptr [esi + P_PREV + 4]
    fmul    st(0), st(0)
    faddp   st(1), st(0)
    fld     dword ptr [esi + 8]
    fsub    dword ptr [esi + P_PREV + 8]
    fmul    st(0), st(0)
    faddp   st(1), st(0)
    fcomp   st(1)
    fnstsw  ax
    sahf
    jae     5f
    mov     eax, dword ptr [esi + P_PREV]
    mov     dword ptr [esi], eax
    mov     eax, dword ptr [esi + P_PREV + 4]
    mov     dword ptr [esi + 4], eax
    mov     eax, dword ptr [esi + P_PREV + 8]
    mov     dword ptr [esi + 8], eax
    xor     eax, eax
    mov     dword ptr [esi + 0x24], eax
    mov     dword ptr [esi + 0x28], eax
    mov     dword ptr [esi + 0x2c], eax
5:  add     esi, P_SIZE
    dec     ecx
    jmp     4b
6:  fstp    st(0)

# Replaces the output loop at 0x437758. Locked particles draw as they are.
write_out:
    mov     ecx, dword ptr [edi + P_COUNT]
    mov     ebx, dword ptr [edi + P_OUT]
    lea     esi, [edi + P_ARRAY]
    fld     dword ptr [edi + ACC_OFS]
    fmul    dword ptr [step_inv]      # st(0) = blend from previous to current
7:  test    ecx, ecx
    jle     9f
    xor     edx, edx
8:  fld     dword ptr [esi + edx]
    cmp     dword ptr [esi + P_LOCKED], 0
    jne     81f
    fsub    dword ptr [esi + edx + P_PREV]
    fmul    st(0), st(1)
    fadd    dword ptr [esi + edx + P_PREV]
81: fmul    dword ptr [FIXED_MUL]
    fistp   dword ptr [ebx + edx]
    add     edx, 4
    cmp     edx, 12
    jl      8b
    add     esi, P_SIZE
    add     ebx, 12
    dec     ecx
    jmp     7b
9:  fstp    st(0)
    mov     eax, 0x4377a0
    jmp     eax

.p2align 2
step_len:   .long 0x3d088889          # 1/30 s
step_near:  .long 0x3d08745f          # 0.999 of a step: blend near 1, step in the next frame
step_inv:   .long 0x41f00000          # 30.0
rest_speed: .long 0x3f400000          # 0.75 ft/s, under gravity * step (1.07 ft/s)
