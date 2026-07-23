// =============================================================================
// pwm_test.c
//   TASK_4: PWM IP demo firmware.
//   Runs on the VSDSquadron FPGA Mini RISC-V core.
//
//   * Prints status via UART (9600 baud, standard printf)
//   * Programs PERIOD = 1024, then sweeps DUTY from 0 -> PERIOD -> 0
//     to fade LED0 up and down repeatedly.
// =============================================================================
#include <stdint.h>
#include <stdio.h>

// PWM IP base address (from SoC address decoding: top nibble = 0x3)
#define PWM_BASE   0x30000000

// Register offsets
#define PWM_CTRL   (*(volatile uint32_t*)(PWM_BASE + 0x00))
#define PWM_PERIOD (*(volatile uint32_t*)(PWM_BASE + 0x04))
#define PWM_DUTY   (*(volatile uint32_t*)(PWM_BASE + 0x08))
#define PWM_STATUS (*(volatile uint32_t*)(PWM_BASE + 0x0C))

// CTRL bits
#define PWM_CTRL_EN   (1u << 0)   // Enable
#define PWM_CTRL_POL  (1u << 1)   // Polarity (0 = active-high)

// The system clock in the SoC is 12 MHz.
// With PERIOD = 1024, PWM frequency = 12e6 / 1024 ~= 11.7 kHz
// which is well above human eye flicker: dimming appears smooth.
#define PWM_PERIOD_TICKS 1024u

// Very small software delay (busy loop). Not exact - just for visible fading.
static void short_delay(volatile uint32_t n) {
    while (n--) { __asm__ volatile ("nop"); }
}

int main(void) {
    printf("Task 4 - PWM IP Test\n");
    printf("PWM_BASE = 0x%x\n", (unsigned)PWM_BASE);

    // 1) Program PERIOD and start with DUTY = 0
    PWM_PERIOD = PWM_PERIOD_TICKS;
    PWM_DUTY   = 0;

    // 2) Enable PWM, active-high polarity
    PWM_CTRL = PWM_CTRL_EN;

    // Read back for confirmation
    printf("Configured: PERIOD=%u DUTY=%u CTRL=0x%x\n",
           (unsigned)PWM_PERIOD, (unsigned)PWM_DUTY, (unsigned)PWM_CTRL);

    printf("Fading LED0 up and down. Watch the on-board LED.\n");

    while (1) {
        uint32_t d;

        // Fade up: 0 -> PERIOD
        for (d = 0; d < PWM_PERIOD_TICKS; d += 8) {
            PWM_DUTY = d;
            short_delay(2000);
        }

        // Fade down: PERIOD -> 0
        for (d = PWM_PERIOD_TICKS; d > 0; d -= 8) {
            PWM_DUTY = d;
            short_delay(2000);
        }

        printf("Cycle done. DUTY back to 0.\n");
    }

    return 0;
}
