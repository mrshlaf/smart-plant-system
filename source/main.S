#include <avr/io.h>

#define BME280_ADDR         0x76
#define LCD_ADDR            0x27

#define PIN_LED_HIJAU       4
#define PIN_LED_MERAH       5
#define PIN_POMPA           6
#define PIN_BUZZER          7
#define PIN_BTN_MANUAL      2
#define PIN_BTN_THRESHOLD   3

#define PWM_POMPA_MAX       120
#define PWM_POMPA_MID       100
#define PWM_POMPA_LOW       80
#define SOIL_KRITIS         20

#define EEPROM_ADDR_THR     0

#define BAUD_UBRR           103

#define DEBOUNCE_TICKS      300

#define SENSOR_INTERVAL     1000

.section .bss

threshold_pct:      .space 1
pompa_paksa:        .space 1
pump_state:         .space 1
soil_pct:           .space 1
last_soil:          .space 1
suhu_int:           .space 1
humidity_int:       .space 1
pwm_val:            .space 1

millis_cnt:         .space 4
waktu_baca:         .space 4

lastBtn0:           .space 1
lastBtn1:           .space 1

lastDebounce0:      .space 4
lastDebounce1:      .space 4

bme_raw:            .space 8

bme_T1:             .space 2
bme_T2:             .space 2
bme_T3:             .space 2
bme_H1:             .space 1
bme_H2:             .space 2
bme_H3:             .space 1
bme_H4:             .space 2
bme_H5:             .space 2
bme_H6:             .space 1

.section .progmem.data, "a", @progbits

str_banner1:        .ascii "=================================\r\n\0"
str_banner2:        .ascii " SMART PLANT SYSTEM READY \r\n\0"
str_soil:           .ascii "SOIL       : \0"
str_pct:            .ascii "%\r\n\0"
str_temp:           .ascii "TEMP       : \0"
str_degc:           .ascii " C\r\n\0"
str_hum:            .ascii "HUMIDITY   : \0"
str_thr:            .ascii "THRESHOLD  : \0"
str_pwm:            .ascii "PWM POMPA  : \0"
str_pstate:         .ascii "PUMP STATE : \0"
str_manual_lbl:     .ascii "MANUAL     : \0"
str_on:             .ascii "ON\r\n\0"
str_off:            .ascii "OFF\r\n\0"
str_raw:            .ascii "RAW: \0"
str_pipe_soil:      .ascii " | SOIL: \0"
str_crlf:           .ascii "\r\n\0"
str_manual_on:      .ascii "MANUAL OVERRIDE: ON\r\n\0"
str_manual_off:     .ascii "MANUAL OVERRIDE: OFF\r\n\0"
str_thr_new:        .ascii "THRESHOLD BARU: \0"
str_bme_ok:         .ascii "BME280 OK\0"
str_bme_err:        .ascii "BME ERROR\0"
str_boot:           .ascii "SMART PLANT\0"
str_booting:        .ascii "BOOTING...\0"
str_lcd_s:          .ascii "S:\0"
str_lcd_t:          .ascii "T:\0"
str_lcd_h:          .ascii "H:\0"
str_lcd_c:          .ascii "C \0"
str_lcd_pct:        .ascii "% \0"
str_lcd_manual:     .ascii "MANUAL \0"
str_lcd_dry:        .ascii "DRY \0"
str_lcd_ok:         .ascii "OK  \0"
str_ready:          .ascii "=================================\r\n\0"

.section .text

.global __vector_11
__vector_11:
    push    r24
    in      r24, _SFR_IO_ADDR(SREG)
    push    r24

    lds     r24, millis_cnt+0
    inc     r24
    sts     millis_cnt+0, r24
    brne    isr_millis_done
    lds     r24, millis_cnt+1
    inc     r24
    sts     millis_cnt+1, r24
    brne    isr_millis_done
    lds     r24, millis_cnt+2
    inc     r24
    sts     millis_cnt+2, r24
    brne    isr_millis_done
    lds     r24, millis_cnt+3
    inc     r24
    sts     millis_cnt+3, r24

isr_millis_done:
    pop     r24
    out     _SFR_IO_ADDR(SREG), r24
    pop     r24
    reti

millis_get:
    cli
    lds     r22, millis_cnt+0
    lds     r23, millis_cnt+1
    lds     r24, millis_cnt+2
    lds     r25, millis_cnt+3
    sei
    ret

delay_ms:
    push    r18
    push    r19
    push    r20
    push    r21
    push    r26
    push    r27

    mov     r26, r24
    mov     r27, r25

    call    millis_get
    mov     r18, r22
    mov     r19, r23

delay_ms_loop:
    call    millis_get
    sub     r22, r18
    sbc     r23, r19
    cp      r22, r26
    cpc     r23, r27
    brlo    delay_ms_loop

    pop     r27
    pop     r26
    pop     r21
    pop     r20
    pop     r19
    pop     r18
    ret

usart_init:
    ldi     r24, 0
    sts     UBRR0H, r24
    ldi     r24, BAUD_UBRR
    sts     UBRR0L, r24
    ldi     r24, (1<<TXEN0)
    sts     UCSR0B, r24
    ldi     r24, (1<<UCSZ01)|(1<<UCSZ00)
    sts     UCSR0C, r24
    ret

usart_send:
usart_send_wait:
    lds     r25, UCSR0A
    sbrs    r25, UDRE0
    rjmp    usart_send_wait
    sts     UDR0, r24
    ret

usart_print_pgm:
    push    r24
usart_pgm_loop:
    lpm     r24, Z+
    tst     r24
    breq    usart_pgm_done
    call    usart_send
    rjmp    usart_pgm_loop
usart_pgm_done:
    pop     r24
    ret

usart_print_u8:
    push    r25
    push    r26
    push    r27

    ldi     r25, 0
    ldi     r26, 0
    mov     r27, r24

udec_h:
    cpi     r27, 100
    brlo    udec_tens
    subi    r27, 100
    inc     r25
    rjmp    udec_h

udec_tens:
    cpi     r27, 10
    brlo    udec_ones
    subi    r27, 10
    inc     r26
    rjmp    udec_tens

udec_ones:
    tst     r25
    breq    udec_skip_h
    ldi     r24, '0'
    add     r24, r25
    call    usart_send
udec_skip_h:
    tst     r25
    brne    udec_force_t
    tst     r26
    breq    udec_print_o
udec_force_t:
    ldi     r24, '0'
    add     r24, r26
    call    usart_send
udec_print_o:
    ldi     r24, '0'
    add     r24, r27
    call    usart_send

    pop     r27
    pop     r26
    pop     r25
    ret

twi_init:
    ldi     r24, 72
    sts     TWBR, r24
    ldi     r24, 0
    sts     TWSR, r24
    ldi     r24, (1<<TWEN)
    sts     TWCR, r24
    ret

twi_start:
    ldi     r24, (1<<TWINT)|(1<<TWSTA)|(1<<TWEN)
    sts     TWCR, r24
twi_start_wait:
    lds     r24, TWCR
    sbrs    r24, TWINT
    rjmp    twi_start_wait
    ret

twi_stop:
    ldi     r24, (1<<TWINT)|(1<<TWSTO)|(1<<TWEN)
    sts     TWCR, r24
    ret

twi_write:
    sts     TWDR, r24
    ldi     r24, (1<<TWINT)|(1<<TWEN)
    sts     TWCR, r24
twi_write_wait:
    lds     r24, TWCR
    sbrs    r24, TWINT
    rjmp    twi_write_wait
    lds     r25, TWSR
    andi    r25, 0xF8
    ret

twi_read_ack:
    ldi     r24, (1<<TWINT)|(1<<TWEN)|(1<<TWEA)
    sts     TWCR, r24
twi_ack_wait:
    lds     r24, TWCR
    sbrs    r24, TWINT
    rjmp    twi_ack_wait
    lds     r24, TWDR
    ret

twi_read_nack:
    ldi     r24, (1<<TWINT)|(1<<TWEN)
    sts     TWCR, r24
twi_nack_wait:
    lds     r24, TWCR
    sbrs    r24, TWINT
    rjmp    twi_nack_wait
    lds     r24, TWDR
    ret

twi_write_reg:
    push    r18
    push    r19
    mov     r18, r24
    mov     r19, r22

    call    twi_start
    mov     r24, r18
    lsl     r24
    call    twi_write
    mov     r24, r19
    call    twi_write
    mov     r24, r20
    call    twi_write
    call    twi_stop

    pop     r19
    pop     r18
    ret

twi_read_bytes:
    push    r18
    push    r19
    push    r20
    mov     r18, r24
    mov     r19, r22

    call    twi_start
    mov     r24, r18
    lsl     r24
    call    twi_write
    mov     r24, r19
    call    twi_write

    call    twi_start
    mov     r24, r18
    lsl     r24
    ori     r24, 0x01
    call    twi_write

    pop     r20
twi_rb_loop:
    cpi     r20, 1
    breq    twi_rb_last
    call    twi_read_ack
    st      X+, r24
    dec     r20
    rjmp    twi_rb_loop
twi_rb_last:
    call    twi_read_nack
    st      X+, r24
    call    twi_stop

    pop     r19
    pop     r18
    ret

bme280_init:
    ldi     r24, BME280_ADDR
    ldi     r22, 0xE0
    ldi     r20, 0xB6
    call    twi_write_reg

    ldi     r25, 0
    ldi     r24, 100
    call    delay_ms

    ldi     r24, BME280_ADDR
    ldi     r22, 0xD0
    ldi     r20, 1
    ldi     XL, lo8(bme_raw)
    ldi     XH, hi8(bme_raw)
    call    twi_read_bytes

    lds     r24, bme_raw

    cpi     r24, 0x60
    breq    bme_id_ok
    cpi     r24, 0x58
    brne    bme_init_err
bme_id_ok:

    ldi     r24, BME280_ADDR
    ldi     r22, 0xF2
    ldi     r20, 0x01
    call    twi_write_reg

    ldi     r24, BME280_ADDR
    ldi     r22, 0xF4
    ldi     r20, 0x27
    call    twi_write_reg

    ldi     r24, BME280_ADDR
    ldi     r22, 0xF5
    ldi     r20, 0xA0
    call    twi_write_reg

    ldi     r25, 0
    ldi     r24, 100
    call    delay_ms

    call    bme280_read_calib

    ldi     r24, 0
    ret

bme_init_err:
    ldi     r24, 1
    ret

bme280_read_calib:
    ldi     r24, BME280_ADDR
    ldi     r22, 0x88
    ldi     r20, 6
    ldi     XL, lo8(bme_T1)
    ldi     XH, hi8(bme_T1)
    call    twi_read_bytes

    call    twi_start
    ldi     r24, (BME280_ADDR << 1)
    call    twi_write
    ldi     r24, 0xA1
    call    twi_write
    call    twi_start
    ldi     r24, (BME280_ADDR << 1)|1
    call    twi_write
    call    twi_read_nack
    call    twi_stop
    sts     bme_H1, r24

    ldi     r24, BME280_ADDR
    ldi     r22, 0xE1
    ldi     r20, 7
    ldi     XL, lo8(bme_H2)
    ldi     XH, hi8(bme_H2)
    call    twi_read_bytes
    ret

bme280_read:
    ldi     r24, BME280_ADDR
    ldi     r22, 0xF7
    ldi     r20, 8
    ldi     XL, lo8(bme_raw)
    ldi     XH, hi8(bme_raw)
    call    twi_read_bytes

    lds     r18, bme_raw+3
    lds     r19, bme_raw+4
    lds     r20, bme_raw+5

    mov     r24, r19
    mov     r25, r18
    lsl     r24
    rol     r25
    lsl     r24
    rol     r25
    lsl     r24
    rol     r25
    lsl     r24
    rol     r25
    mov     r22, r20
    swap    r22
    andi    r22, 0x0F
    or      r24, r22

    lsr     r25
    ror     r24
    lsr     r25
    ror     r24
    lsr     r25
    ror     r24
    lsr     r25
    ror     r24
    lsr     r25
    ror     r24

    lds     r22, bme_T1+1
    lsr     r22
    lsr     r22
    sub     r24, r22

    lds     r22, bme_T2+1
    mul     r24, r22
    mov     r24, r1
    ldi     r22, 10
    call    div8u
    sts     suhu_int, r24

    lds     r25, bme_raw+6
    lds     r24, bme_raw+7

    lsr     r25
    ror     r24
    lsr     r25
    ror     r24
    lsr     r25
    ror     r24
    lsr     r25
    ror     r24
    lsr     r25
    ror     r24
    lsr     r25
    ror     r24
    lsr     r25
    ror     r24
    lsr     r25
    ror     r24
    lsr     r25
    ror     r24

    ldi     r22, 100
    mul     r24, r22
    mov     r24, r1
    lsl     r24

    cpi     r24, 100
    brlo    hum_ok
    ldi     r24, 100
hum_ok:
    sts     humidity_int, r24
    clr     r1
    ret

div8u:
    push    r25
    push    r18
    clr     r25
    ldi     r18, 8
div8u_loop:
    lsl     r24
    rol     r25
    cp      r25, r22
    brlo    div8u_skip
    sub     r25, r22
    inc     r24
div8u_skip:
    dec     r18
    brne    div8u_loop
    pop     r18
    pop     r25
    ret

adc_init:
    ldi     r24, (1<<REFS0)
    sts     ADMUX, r24
    ldi     r24, (1<<ADEN)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)
    sts     ADCSRA, r24
    ret

adc_read:
    push    r22
    andi    r24, 0x07
    ori     r24, (1<<REFS0)
    sts     ADMUX, r24
    nop
    nop
    nop
    nop
    lds     r22, ADCSRA
    ori     r22, (1<<ADSC)
    sts     ADCSRA, r22
adc_read_wait:
    lds     r22, ADCSRA
    sbrc    r22, ADSC
    rjmp    adc_read_wait
    lds     r24, ADCL
    lds     r25, ADCH
    pop     r22
    ret

baca_soil:
    push    r26
    push    r27
    push    r28
    push    r29
    push    r18
    push    r19

    clr     r26
    clr     r27
    clr     r28
    ldi     r18, 10

soil_loop:
    ldi     r24, 0
    call    adc_read
    add     r26, r24
    adc     r27, r25
    clr     r24
    adc     r28, r24
    ldi     r25, 0
    ldi     r24, 2
    call    delay_ms
    dec     r18
    brne    soil_loop

    ldi     r19, 10
    mov     r24, r27
    mov     r25, r28
    call    div16u8

    push    r24
    push    r25
    ldi     ZL, lo8(str_raw)
    ldi     ZH, hi8(str_raw)
    call    usart_print_pgm
    pop     r25
    pop     r24
    push    r24
    push    r25
    call    usart_print_u8
    pop     r25
    pop     r24

    ldi     r27, 0x03
    cpi     r24, 0xFF
    cpc     r25, r27
    brlo    soil_not_max
    ldi     r24, 0xFF
    ldi     r25, 0x03
soil_not_max:
    ldi     r26, 0xFF
    ldi     r27, 0x03
    sub     r26, r24
    sbc     r27, r25

    ldi     r18, 100
    mul     r26, r18
    mov     r28, r0
    mov     r29, r1
    mul     r27, r18
    add     r29, r0

    call    div_by_643

    cpi     r24, 100
    brlo    soil_pct_ok
    ldi     r24, 100
soil_pct_ok:
    lds     r22, last_soil
    add     r24, r22
    lsr     r24
    sts     last_soil, r24

    push    r24
    ldi     ZL, lo8(str_pipe_soil)
    ldi     ZH, hi8(str_pipe_soil)
    call    usart_print_pgm
    pop     r24
    push    r24
    call    usart_print_u8
    ldi     ZL, lo8(str_crlf)
    ldi     ZH, hi8(str_crlf)
    call    usart_print_pgm
    pop     r24

    pop     r19
    pop     r18
    pop     r29
    pop     r28
    pop     r27
    pop     r26
    ret

div16u8:
    push    r18
    push    r26
    push    r27
    clr     r26
    ldi     r27, 16
d16u8_loop:
    lsl     r24
    rol     r25
    rol     r26
    cp      r26, r19
    brlo    d16u8_skip
    sub     r26, r19
    inc     r24
d16u8_skip:
    dec     r27
    brne    d16u8_loop
    pop     r27
    pop     r26
    pop     r18
    ret

div_by_643:
    push    r25
    push    r26
    push    r27
    clr     r24
div643_loop:
    ldi     r25, lo8(643)
    ldi     r26, hi8(643)
    cp      r28, r25
    cpc     r29, r26
    brlo    div643_done
    sub     r28, r25
    sbc     r29, r26
    inc     r24
    rjmp    div643_loop
div643_done:
    pop     r27
    pop     r26
    pop     r25
    ret

baca_threshold_dari_pot:
    ldi     r24, 1
    call    adc_read
    ldi     r18, 60
    mul     r24, r18
    mov     r26, r0
    mov     r27, r1
    mul     r25, r18
    add     r27, r0
    lsr     r27
    ror     r26
    lsr     r27
    ror     r26
    lsr     r27
    ror     r26
    lsr     r27
    ror     r26
    lsr     r27
    ror     r26
    lsr     r27
    ror     r26
    lsr     r27
    ror     r26
    lsr     r27
    ror     r26
    lsr     r27
    ror     r26
    lsr     r27
    ror     r26
    mov     r24, r26
    subi    r24, -20
    cpi     r24, 20
    brsh    pot_not_low
    ldi     r24, 20
pot_not_low:
    cpi     r24, 80
    brlo    pot_done
    ldi     r24, 80
pot_done:
    ret

eeprom_write:
    sbic    _SFR_IO_ADDR(EECR), EEPE
    rjmp    eeprom_write
    out     _SFR_IO_ADDR(EEARL), r24
    ldi     r25, 0
    out     _SFR_IO_ADDR(EEARH), r25
    out     _SFR_IO_ADDR(EEDR), r22
    sbi     _SFR_IO_ADDR(EECR), EEMPE
    sbi     _SFR_IO_ADDR(EECR), EEPE
    ret

eeprom_read:
    sbic    _SFR_IO_ADDR(EECR), EEPE
    rjmp    eeprom_read
    out     _SFR_IO_ADDR(EEARL), r24
    ldi     r25, 0
    out     _SFR_IO_ADDR(EEARH), r25
    sbi     _SFR_IO_ADDR(EECR), EERE
    in      r24, _SFR_IO_ADDR(EEDR)
    ret

simpan_threshold_eeprom:
    push    r22
    mov     r22, r24
    ldi     r24, EEPROM_ADDR_THR
    call    eeprom_write
    pop     r22
    ret

muat_threshold_eeprom:
    ldi     r24, EEPROM_ADDR_THR
    call    eeprom_read
    cpi     r24, 10
    brsh    eep_not_low
    ldi     r24, 40
    ret
eep_not_low:
    cpi     r24, 90
    brlo    eep_valid
    ldi     r24, 40
    ret
eep_valid:
    ret

set_led:
    sbrc    r24, 0
    sbi     _SFR_IO_ADDR(PORTD), PIN_LED_HIJAU
    sbrs    r24, 0
    cbi     _SFR_IO_ADDR(PORTD), PIN_LED_HIJAU
    sbrc    r22, 0
    sbi     _SFR_IO_ADDR(PORTD), PIN_LED_MERAH
    sbrs    r22, 0
    cbi     _SFR_IO_ADDR(PORTD), PIN_LED_MERAH
    ret

buzzer_beep:
    push    r26
    push    r18
    push    r19
    lsl     r24
    lsl     r24
    mov     r26, r24
buzz_loop:
    tst     r26
    breq    buzz_done
    sbi     _SFR_IO_ADDR(PORTD), PIN_BUZZER
    ldi     r18, lo8(1333)
    ldi     r19, hi8(1333)
buzz_hi:
    subi    r18, 1
    sbci    r19, 0
    brne    buzz_hi
    cbi     _SFR_IO_ADDR(PORTD), PIN_BUZZER
    ldi     r18, lo8(1333)
    ldi     r19, hi8(1333)
buzz_lo:
    subi    r18, 1
    sbci    r19, 0
    brne    buzz_lo
    dec     r26
    rjmp    buzz_loop
buzz_done:
    pop     r19
    pop     r18
    pop     r26
    ret

buzzer_beep_n:
    push    r18
    push    r22
    mov     r18, r24
beep_n_loop:
    tst     r18
    breq    beep_n_done
    push    r18
    push    r22
    mov     r24, r22
    call    buzzer_beep
    pop     r22
    pop     r18
    dec     r18
    tst     r18
    breq    beep_n_done
    push    r18
    push    r22
    ldi     r25, 0
    ldi     r24, 100
    call    delay_ms
    pop     r22
    pop     r18
    rjmp    beep_n_loop
beep_n_done:
    pop     r22
    pop     r18
    ret

hitung_pwm_pompa:
    push    r22
    push    r20
    push    r18
    mov     r18, r24

    lds     r25, threshold_pct
    cp      r18, r25
    brsh    check_hysteresis_off
    ldi     r24, 1
    sts     pump_state, r24
    rjmp    eval_pwm

check_hysteresis_off:
    lds     r25, threshold_pct
    ldi     r24, 3
    add     r25, r24
    cp      r18, r25
    brlo    eval_pwm
    clr     r24
    sts     pump_state, r24

eval_pwm:
    lds     r24, pump_state
    tst     r24
    brne    calc_pwm
    ldi     r24, 0
    rjmp    pwm_done

calc_pwm:
    cpi     r18, 20
    brsh    soil_mid_check
    ldi     r24, PWM_POMPA_MAX
    rjmp    apply_boost
soil_mid_check:
    cpi     r18, 35
    brsh    soil_low_check
    ldi     r24, PWM_POMPA_MID
    rjmp    apply_boost
soil_low_check:
    ldi     r24, PWM_POMPA_LOW

apply_boost:
    pop     r18
    pop     r20
    pop     r22
    push    r22
    push    r20
    push    r18
    cpi     r22, 31
    brsh    do_boost
    cpi     r20, 40
    brsh    no_boost
do_boost:
    subi    r24, -10
no_boost:
    cpi     r24, 120
    brlo    pwm_done
    ldi     r24, 120
pwm_done:
    pop     r18
    pop     r20
    pop     r22
    ret

print_status:
    push    r24

    ldi     ZL, lo8(str_banner1)
    ldi     ZH, hi8(str_banner1)
    call    usart_print_pgm

    ldi     ZL, lo8(str_soil)
    ldi     ZH, hi8(str_soil)
    call    usart_print_pgm
    lds     r24, soil_pct
    call    usart_print_u8
    ldi     ZL, lo8(str_pct)
    ldi     ZH, hi8(str_pct)
    call    usart_print_pgm

    ldi     ZL, lo8(str_temp)
    ldi     ZH, hi8(str_temp)
    call    usart_print_pgm
    lds     r24, suhu_int
    call    usart_print_u8
    ldi     ZL, lo8(str_degc)
    ldi     ZH, hi8(str_degc)
    call    usart_print_pgm

    ldi     ZL, lo8(str_hum)
    ldi     ZH, hi8(str_hum)
    call    usart_print_pgm
    lds     r24, humidity_int
    call    usart_print_u8
    ldi     ZL, lo8(str_pct)
    ldi     ZH, hi8(str_pct)
    call    usart_print_pgm

    ldi     ZL, lo8(str_thr)
    ldi     ZH, hi8(str_thr)
    call    usart_print_pgm
    lds     r24, threshold_pct
    call    usart_print_u8
    ldi     ZL, lo8(str_pct)
    ldi     ZH, hi8(str_pct)
    call    usart_print_pgm

    ldi     ZL, lo8(str_pwm)
    ldi     ZH, hi8(str_pwm)
    call    usart_print_pgm
    pop     r24
    push    r24
    call    usart_print_u8
    ldi     ZL, lo8(str_crlf)
    ldi     ZH, hi8(str_crlf)
    call    usart_print_pgm

    ldi     ZL, lo8(str_pstate)
    ldi     ZH, hi8(str_pstate)
    call    usart_print_pgm
    lds     r24, pump_state
    tst     r24
    breq    ps_off
    ldi     ZL, lo8(str_on)
    ldi     ZH, hi8(str_on)
    rjmp    ps_print
ps_off:
    ldi     ZL, lo8(str_off)
    ldi     ZH, hi8(str_off)
ps_print:
    call    usart_print_pgm

    ldi     ZL, lo8(str_manual_lbl)
    ldi     ZH, hi8(str_manual_lbl)
    call    usart_print_pgm
    lds     r24, pompa_paksa
    tst     r24
    breq    man_off
    ldi     ZL, lo8(str_on)
    ldi     ZH, hi8(str_on)
    rjmp    man_print
man_off:
    ldi     ZL, lo8(str_off)
    ldi     ZH, hi8(str_off)
man_print:
    call    usart_print_pgm

    ldi     ZL, lo8(str_banner1)
    ldi     ZH, hi8(str_banner1)
    call    usart_print_pgm

    pop     r24
    ret

#define LCD_BL   0x08
#define LCD_EN   0x04
#define LCD_RW   0x02
#define LCD_RS   0x01

lcd_i2c_write:
    push    r24
    call    twi_start
    ldi     r24, (LCD_ADDR << 1)
    call    twi_write
    pop     r24
    call    twi_write
    call    twi_stop
    ret

lcd_send_nibble:
    push    r24
    push    r22
    andi    r24, 0xF0
    ori     r24, LCD_BL
    or      r24, r22
    push    r24
    ori     r24, LCD_EN
    call    lcd_i2c_write
    ldi     r25, 0
    ldi     r24, 1
    call    delay_ms
    pop     r24
    andi    r24, ~LCD_EN
    call    lcd_i2c_write
    pop     r22
    pop     r24
    ret

lcd_send_byte:
    push    r24
    push    r22
    call    lcd_send_nibble
    pop     r22
    pop     r24
    push    r22
    swap    r24
    call    lcd_send_nibble
    pop     r22
    ret

lcd_cmd:
    clr     r22
    call    lcd_send_byte
    ret

lcd_data:
    ldi     r22, LCD_RS
    call    lcd_send_byte
    ret

lcd_init_hw:
    ldi     r25, 0
    ldi     r24, 50
    call    delay_ms

    ldi     r24, 0x30
    clr     r22
    call    lcd_send_nibble
    ldi     r25, 0
    ldi     r24, 5
    call    delay_ms

    ldi     r24, 0x30
    clr     r22
    call    lcd_send_nibble
    ldi     r25, 0
    ldi     r24, 1
    call    delay_ms

    ldi     r24, 0x30
    clr     r22
    call    lcd_send_nibble
    ldi     r25, 0
    ldi     r24, 1
    call    delay_ms

    ldi     r24, 0x20
    clr     r22
    call    lcd_send_nibble

    ldi     r24, 0x28
    call    lcd_cmd
    ldi     r24, 0x0C
    call    lcd_cmd
    ldi     r24, 0x01
    call    lcd_cmd
    ldi     r25, 0
    ldi     r24, 2
    call    delay_ms
    ldi     r24, 0x06
    call    lcd_cmd
    ret

lcd_clear:
    ldi     r24, 0x01
    call    lcd_cmd
    ldi     r25, 0
    ldi     r24, 2
    call    delay_ms
    ret

lcd_set_cursor:
    tst     r22
    breq    lcd_row0
    subi    r24, -0x40
lcd_row0:
    ori     r24, 0x80
    call    lcd_cmd
    ret

lcd_print_pgm:
    push    r24
lcd_pgm_loop:
    lpm     r24, Z+
    tst     r24
    breq    lcd_pgm_done
    call    lcd_data
    rjmp    lcd_pgm_loop
lcd_pgm_done:
    pop     r24
    ret

lcd_print_u8:
    push    r25
    push    r26
    push    r27
    ldi     r25, 0
    ldi     r26, 0
    mov     r27, r24
lcd_h:
    cpi     r27, 100
    brlo    lcd_tens
    subi    r27, 100
    inc     r25
    rjmp    lcd_h
lcd_tens:
    cpi     r27, 10
    brlo    lcd_ones
    subi    r27, 10
    inc     r26
    rjmp    lcd_tens
lcd_ones:
    tst     r25
    breq    lcd_skip_h
    ldi     r24, '0'
    add     r24, r25
    call    lcd_data
lcd_skip_h:
    tst     r25
    brne    lcd_force_t
    tst     r26
    breq    lcd_print_o
lcd_force_t:
    ldi     r24, '0'
    add     r24, r26
    call    lcd_data
lcd_print_o:
    ldi     r24, '0'
    add     r24, r27
    call    lcd_data
    pop     r27
    pop     r26
    pop     r25
    ret

timer1_init:
    ldi     r24, 0
    sts     TCCR1A, r24
    ldi     r24, (1<<WGM12)|(1<<CS11)|(1<<CS10)
    sts     TCCR1B, r24
    ldi     r24, 249
    sts     OCR1AL, r24
    ldi     r24, 0
    sts     OCR1AH, r24
    ldi     r24, (1<<OCIE1A)
    sts     TIMSK1, r24
    ret

timer0_init:
    ldi     r24, (1<<COM0A1)|(1<<WGM01)|(1<<WGM00)
    out     _SFR_IO_ADDR(TCCR0A), r24
    ldi     r24, (1<<CS01)|(1<<CS00)
    out     _SFR_IO_ADDR(TCCR0B), r24
    ldi     r24, 0
    out     _SFR_IO_ADDR(OCR0A), r24
    ret

set_pwm_pompa:
    out     _SFR_IO_ADDR(OCR0A), r24
    ret

setup:
    clr     r1

    in      r24, _SFR_IO_ADDR(DDRD)
    ori     r24, (1<<PD4)|(1<<PD5)|(1<<PD6)|(1<<PD7)
    andi    r24, ~((1<<PD2)|(1<<PD3))
    out     _SFR_IO_ADDR(DDRD), r24

    in      r24, _SFR_IO_ADDR(PORTD)
    ori     r24, (1<<PD2)|(1<<PD3)
    out     _SFR_IO_ADDR(PORTD), r24

    ldi     r24, 50
    sts     last_soil, r24
    ldi     r24, 1
    sts     lastBtn0, r24
    sts     lastBtn1, r24

    ldi     XL, lo8(millis_cnt)
    ldi     XH, hi8(millis_cnt)
    ldi     r18, 16
    clr     r22
clr_loop:
    st      X+, r22
    dec     r18
    brne    clr_loop

    call    usart_init
    call    twi_init
    call    adc_init
    call    timer0_init
    call    timer1_init

    sei

    call    lcd_init_hw

    ldi     r24, 0
    ldi     r22, 0
    call    lcd_set_cursor
    ldi     ZL, lo8(str_boot)
    ldi     ZH, hi8(str_boot)
    call    lcd_print_pgm

    ldi     r24, 0
    ldi     r22, 1
    call    lcd_set_cursor
    ldi     ZL, lo8(str_booting)
    ldi     ZH, hi8(str_booting)
    call    lcd_print_pgm

    ldi     r25, hi8(2000)
    ldi     r24, lo8(2000)
    call    delay_ms

    call    lcd_clear

    call    muat_threshold_eeprom
    sts     threshold_pct, r24

    call    bme280_init
    tst     r24
    breq    bme_ok

    ldi     r24, 0
    ldi     r22, 0
    call    lcd_set_cursor
    ldi     ZL, lo8(str_bme_err)
    ldi     ZH, hi8(str_bme_err)
    call    lcd_print_pgm
bme_halt:
    rjmp    bme_halt

bme_ok:
    ldi     r24, 0
    ldi     r22, 0
    call    lcd_set_cursor
    ldi     ZL, lo8(str_bme_ok)
    ldi     ZH, hi8(str_bme_ok)
    call    lcd_print_pgm

    ldi     r25, 0
    ldi     r24, 255
    call    delay_ms

    call    lcd_clear

    ldi     ZL, lo8(str_banner1)
    ldi     ZH, hi8(str_banner1)
    call    usart_print_pgm
    ldi     ZL, lo8(str_banner2)
    ldi     ZH, hi8(str_banner2)
    call    usart_print_pgm
    ldi     ZL, lo8(str_ready)
    ldi     ZH, hi8(str_ready)
    call    usart_print_pgm

    ldi     r24, 2
    ldi     r22, 80
    call    buzzer_beep_n

    ret

loop:

    in      r24, _SFR_IO_ADDR(PIND)
    bst     r24, PIN_BTN_MANUAL
    bld     r24, 0
    andi    r24, 0x01

    lds     r25, lastBtn0
    cp      r24, r25
    brne    btn0_changed
    jmp     btn0_no_change
btn0_changed:

    call    millis_get
    lds     r18, lastDebounce0+0
    lds     r19, lastDebounce0+1
    sub     r22, r18
    sbc     r23, r19
    ldi     r26, lo8(DEBOUNCE_TICKS)
    ldi     r27, hi8(DEBOUNCE_TICKS)
    cp      r22, r26
    cpc     r23, r27
    brsh    btn0_debounce_ok
    jmp     btn0_no_change
btn0_debounce_ok:

    call    millis_get
    sts     lastDebounce0+0, r22
    sts     lastDebounce0+1, r23
    sts     lastDebounce0+2, r24
    sts     lastDebounce0+3, r25

    in      r24, _SFR_IO_ADDR(PIND)
    bst     r24, PIN_BTN_MANUAL
    bld     r24, 0
    andi    r24, 0x01
    tst     r24
    breq    btn0_pressed
    jmp     btn0_no_change
btn0_pressed:

    lds     r24, pompa_paksa
    ldi     r25, 1
    eor     r24, r25
    sts     pompa_paksa, r24

    tst     r24
    breq    print_man_off
    ldi     ZL, lo8(str_manual_on)
    ldi     ZH, hi8(str_manual_on)
    rjmp    print_man
print_man_off:
    ldi     ZL, lo8(str_manual_off)
    ldi     ZH, hi8(str_manual_off)
print_man:
    call    usart_print_pgm

    ldi     r24, 50
    call    buzzer_beep

btn0_no_change:
    in      r24, _SFR_IO_ADDR(PIND)
    bst     r24, PIN_BTN_MANUAL
    bld     r24, 0
    andi    r24, 0x01
    sts     lastBtn0, r24

    in      r24, _SFR_IO_ADDR(PIND)
    bst     r24, PIN_BTN_THRESHOLD
    bld     r24, 0
    andi    r24, 0x01

    lds     r25, lastBtn1
    cp      r24, r25
    brne    btn1_changed
    jmp     btn1_no_change
btn1_changed:

    call    millis_get
    lds     r18, lastDebounce1+0
    lds     r19, lastDebounce1+1
    sub     r22, r18
    sbc     r23, r19
    ldi     r26, lo8(DEBOUNCE_TICKS)
    ldi     r27, hi8(DEBOUNCE_TICKS)
    cp      r22, r26
    cpc     r23, r27
    brsh    btn1_debounce_ok
    jmp     btn1_no_change
btn1_debounce_ok:

    call    millis_get
    sts     lastDebounce1+0, r22
    sts     lastDebounce1+1, r23
    sts     lastDebounce1+2, r24
    sts     lastDebounce1+3, r25

    in      r24, _SFR_IO_ADDR(PIND)
    bst     r24, PIN_BTN_THRESHOLD
    bld     r24, 0
    andi    r24, 0x01
    tst     r24
    breq    btn1_pressed
    jmp     btn1_no_change
btn1_pressed:

    call    baca_threshold_dari_pot
    sts     threshold_pct, r24
    call    simpan_threshold_eeprom

    ldi     ZL, lo8(str_thr_new)
    ldi     ZH, hi8(str_thr_new)
    call    usart_print_pgm
    lds     r24, threshold_pct
    call    usart_print_u8
    ldi     ZL, lo8(str_pct)
    ldi     ZH, hi8(str_pct)
    call    usart_print_pgm

    ldi     r24, 2
    ldi     r22, 50
    call    buzzer_beep_n

btn1_no_change:
    in      r24, _SFR_IO_ADDR(PIND)
    bst     r24, PIN_BTN_THRESHOLD
    bld     r24, 0
    andi    r24, 0x01
    sts     lastBtn1, r24

    call    millis_get
    lds     r18, waktu_baca+0
    lds     r19, waktu_baca+1
    sub     r22, r18
    sbc     r23, r19
    ldi     r26, lo8(SENSOR_INTERVAL)
    ldi     r27, hi8(SENSOR_INTERVAL)
    cp      r22, r26
    cpc     r23, r27
    brsh    sensor_update_now
    jmp     loop
sensor_update_now:

    call    millis_get
    sts     waktu_baca+0, r22
    sts     waktu_baca+1, r23
    sts     waktu_baca+2, r24
    sts     waktu_baca+3, r25

    call    baca_soil
    sts     soil_pct, r24

    call    bme280_read

    lds     r24, pompa_paksa
    tst     r24
    breq    auto_pwm
    ldi     r24, PWM_POMPA_MAX
    rjmp    pwm_output

auto_pwm:
    lds     r24, soil_pct
    lds     r22, suhu_int
    lds     r20, humidity_int
    call    hitung_pwm_pompa

pwm_output:
    sts     pwm_val, r24
    call    set_pwm_pompa

    lds     r24, pwm_val
    tst     r24
    breq    led_green
    ldi     r24, 0
    ldi     r22, 1
    call    set_led
    rjmp    led_done
led_green:
    ldi     r24, 1
    ldi     r22, 0
    call    set_led
led_done:

    lds     r24, soil_pct
    cpi     r24, SOIL_KRITIS
    brsh    no_alert
    ldi     r24, 50
    call    buzzer_beep
no_alert:

    lds     r24, pwm_val
    call    print_status

    ldi     r24, 0
    ldi     r22, 0
    call    lcd_set_cursor

    ldi     ZL, lo8(str_lcd_s)
    ldi     ZH, hi8(str_lcd_s)
    call    lcd_print_pgm
    lds     r24, soil_pct
    call    lcd_print_u8
    ldi     ZL, lo8(str_lcd_pct)
    ldi     ZH, hi8(str_lcd_pct)
    call    lcd_print_pgm

    ldi     r24, 8
    ldi     r22, 0
    call    lcd_set_cursor

    ldi     ZL, lo8(str_lcd_t)
    ldi     ZH, hi8(str_lcd_t)
    call    lcd_print_pgm
    lds     r24, suhu_int
    call    lcd_print_u8
    ldi     ZL, lo8(str_lcd_c)
    ldi     ZH, hi8(str_lcd_c)
    call    lcd_print_pgm

    ldi     r24, 0
    ldi     r22, 1
    call    lcd_set_cursor

    ldi     ZL, lo8(str_lcd_h)
    ldi     ZH, hi8(str_lcd_h)
    call    lcd_print_pgm
    lds     r24, humidity_int
    call    lcd_print_u8
    ldi     ZL, lo8(str_lcd_pct)
    ldi     ZH, hi8(str_lcd_pct)
    call    lcd_print_pgm

    lds     r24, pompa_paksa
    tst     r24
    breq    lcd_auto_status
    ldi     ZL, lo8(str_lcd_manual)
    ldi     ZH, hi8(str_lcd_manual)
    call    lcd_print_pgm
    rjmp    lcd_status_done

lcd_auto_status:
    lds     r24, pwm_val
    tst     r24
    breq    lcd_show_ok
    ldi     ZL, lo8(str_lcd_dry)
    ldi     ZH, hi8(str_lcd_dry)
    call    lcd_print_pgm
    rjmp    lcd_status_done
lcd_show_ok:
    ldi     ZL, lo8(str_lcd_ok)
    ldi     ZH, hi8(str_lcd_ok)
    call    lcd_print_pgm
lcd_status_done:
    ldi     r24, ' '
    call    lcd_data
    ldi     r24, ' '
    call    lcd_data
    ldi     r24, ' '
    call    lcd_data

    jmp     loop

.global main
main:
    call    setup
    jmp     loop