#include <stdint.h>
#include <stdio.h>

// Base address from Task 2
#define GPIO_BASE 0x20000000

// Register Offsets
#define GPIO_DATA (*(volatile uint32_t*)(GPIO_BASE + 0x00))
#define GPIO_DIR  (*(volatile uint32_t*)(GPIO_BASE + 0x04))
#define GPIO_READ (*(volatile uint32_t*)(GPIO_BASE + 0x08))

int main() {
    printf("Starting Task 3 GPIO Test...\n");

    // Step 1: Set lower 16 bits as OUTPUT (1), upper 16 bits as INPUT (0)
    GPIO_DIR = 0x0000FFFF;
    printf("Direction set to 0x0000FFFF\n");

    // Step 2: Write test data to the output pins
    GPIO_DATA = 0x12345678; 
    printf("Wrote 0x12345678 to GPIO_DATA\n");

    // Step 3: Read back the pin states
    // The lower 16 bits should match what we wrote (0x5678).
    // The upper 16 bits depend on the testbench inputs.
    uint32_t read_val = GPIO_READ;
    
    printf("Read value from GPIO_READ: 0x%x\n", read_val);

    printf("Test Complete.\n");
    
    while(1);
    return 0;
}