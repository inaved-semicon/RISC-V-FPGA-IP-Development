#include <stdio.h>

#define DELAY 700000

// Software delay for bare-metal RISC-V
void wait_cycles(volatile int count) {
    while (count-- > 0) {
        __asm__ volatile("nop");
    }
}

// Clear screen using ANSI escape codes
void clear_screen() {
    printf("\033[2J\033[H");  // Clear terminal and move cursor to top
}

// Print the ASCII banner
void print_banner() {
    printf("************************************************************\n");
    printf("*                                                          *\n");
    printf("*        I N N O V A T E   •   B U I L D   •   L E A R N   *\n");
    printf("*                                                          *\n");
    printf("*                  I N A V E D   S E M I C O N             *\n");
    printf("*                                                          *\n");
    printf("*               P O W E R E D   B Y   R I S C - V          *\n");
    printf("*                                                          *\n");
    printf("*                     C R E A T E D   B Y                  *\n");
    printf("*                K E Y U R   D O B A R I Y A               *\n");
    printf("*                                                          *\n");
    printf("************************************************************\n\n");
}

int main() {
    while (1) {
        print_banner();      // Show banner
        wait_cycles(DELAY);  // Pause
        clear_screen();      // Clear banner (unprint)
        wait_cycles(DELAY);  // Pause again
    }

    return 0;
}

