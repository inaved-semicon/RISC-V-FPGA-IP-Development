volatile unsigned int * const GPIO = (volatile unsigned int *)0x20000000;
volatile unsigned int * const UART_DAT = (volatile unsigned int *)0x00400008;
volatile unsigned int * const UART_CNTL = (volatile unsigned int *)0x00400010;

static void uart_putc(char c) {
    *UART_DAT = (unsigned int)c;
    while ((*UART_CNTL & (1U << 9)) != 0) {
    }
}

static void uart_puts(const char *s) {
    for (const char *p = s; *p != '\0'; ++p) {
        uart_putc(*p);
    }
}

static void uart_put_hex(unsigned int value) {
    static const char hex[] = "0123456789ABCDEF";
    for (int shift = 28; shift >= 0; shift -= 4) {
        uart_putc(hex[(value >> shift) & 0xF]);
    }
}

static void uart_put_dec(unsigned int value) {
    char buf[16];
    int i = 0;

    if (value == 0) {
        uart_putc('0');
        return;
    }

    while (value != 0) {
        buf[i++] = (char)('0' + (value % 10));
        value /= 10;
    }

    while (i > 0) {
        uart_putc(buf[--i]);
    }
}

int main(void) {
    const unsigned int values[] = {
        0x00000000u,
        0x0000000Au,
        0x00000055u,
        0x00000F0Fu,
        0x12345678u,
        0xA5A5A5A5u
    };
   uart_puts ("************************************************************\n");
   uart_puts ("*                                                          *\n");
   uart_puts ("*        I N N O V A T E   •   B U I L D   •   L E A R N   *\n");
   uart_puts ("*                                                          *\n");
   uart_puts ("*                  I N A V E D   S E M I C O N             *\n");
   uart_puts ("*                                                          *\n");
   uart_puts ("*      R I S C - V - F P G A - I P - D e v e l o p m e n t *\n");
   uart_puts ("*                                                          *\n");
   uart_puts ("*                     C R E A T E D   B Y                  *\n");
   uart_puts ("*                K E Y U R   D O B A R I Y A               *\n");
   uart_puts ("*                                                          *\n");
   uart_puts ("************************************************************\n\n");  

    uart_puts("\r\n[ TASK : GPIO IP Validation ]\r\n");
    uart_puts("\r\n[ DATA FLOW ]\r\n");
    uart_puts("GPIO Write -> GPIO Readback -> UART Print\r\n");
    uart_puts("\r\n[ RESULTS ]\r\n");

    for (unsigned int i = 0; i < 7; ++i) {
        *GPIO = values[i];
        unsigned int readback = *GPIO;

        uart_puts("  [");
        uart_put_dec(i + 1u);
        uart_puts("] ");
        uart_put_hex(values[i]);
        uart_puts(" -> ");
        uart_put_hex(readback);
        uart_puts("\r\n");
    }

    uart_puts("\r\nValidation complete.\r\n");
    uart_puts("Enjoy the glow of GPIO!\r\n");

    for (;;) {
    }
    return 0;
}
