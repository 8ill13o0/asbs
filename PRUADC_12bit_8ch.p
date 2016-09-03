// PRU program to communicate to the MCP3208 of SPI ADC ICs as part of ASBS. The program 
// generates the SPI signals that are required to receive samples. To use this 
// program as is, use the following wiring configuration:
//   Chip Select (CS):   P9_27    pr1_pru0_pru_r30_5  r30.t5
//   MOSI            :   P9_29    pr1_pru0_pru_r30_1  r30.t1
//   MISO            :   P9_28    pr1_pru0_pru_r31_3  r31.t3
//   CLK             :   P9_30    pr1_pru0_pru_r30_2  r30.t2
//   Sample Clock    :   P8_46    pr1_pru1_pru_r30_1  -- for testing only
// This program relies heavily on the similar code PRUADC.p writen by Derek Molloy to 
// align with the content of the book Exploring BeagleBone. See exploringbeaglebone.com/chapter13/
// rev.20160728
//
// registers list:
// r1 SPI command address
// r2 SPI command
// r3 output
// r4 stores 24 (bit) counter
// r5 address of clock
// r6 clock flag
// r7 bit mask
// r8 "addr" to write to next
// r9 "size"
// r10 channel counter, 0 to 7
// r11 "addr" not changed


.setcallreg  r29.w2		 // set a non-default CALL/RET register
.origin 0                        // start of program in PRU memory
.entrypoint START                // program entry point (for a debugger)

#define PRU0_R31_VEC_VALID 32    // allows notification of program completion
#define PRU_EVTOUT_0    3        // the event number that is sent back

// Constants from the MCP3208 datasheet 
#define TIME_CLOCK      24       // T_hi and t_lo = 250ns = 25 instructions (min)

START:
        // Enable the OCP master port -- allows transfer of data to Linux userspace
	LBCO    r0, C4, 4, 4     // load SYSCFG reg into r0 (use c4 const addr)
	CLR     r0, r0, 4        // clear bit 4 (STANDBY_INIT)
	SBCO    r0, C4, 4, 4     // store the modified r0 back at the load addr
	MOV	r1, 0x00000000	 // load the base address into r1
	MOV	r7, 0x00000FFF	 // the bit mask to use on the returned data (i.e., keep 12 LSBs only)
	LBBO    r8, r1, 4, 4     // "addr" load the Linux address that is passed into r8 -- to store sample values
	LBBO    r11,r1, 4, 4     // "addr" loaded again into r11
	LBBO	r9, r1, 8, 4	 // "size" load the size that is passed into r9 -- the number of samples to take
	MOV	r3, 0x00000000	 // clear r3 to receive the response from the MCP3XXX
	CLR	r30.t1		 // clear the data out line - MOSI
    MOV r10, 0 //initialize counter to count through channels 0 to 7
    MOV r2, 0x00000000 // clear r2 to recieve input
    ADD r8, r8, 4 //increment address to save output to by 4 bytes, bytes 0 to 3 are reserved for last written address
GET_SAMPLE:			 // load the send value on each sample, increments through channels
    MOV	r5, 0x00010000   // LSB of value at this address is the clock flag
	MOV r2.w2, 0x0600 // SPI command for CH0
	QBEQ SAMPLE_WAIT_HIGH, r10, 0 //check if channel 0
    MOV r2.w2, 0x0640 // SPI command for CH1
	QBEQ SAMPLE_WAIT_HIGH, r10, 1 //check if channel 1
	MOV r2.w2, 0x0680 // SPI command for CH2
	QBEQ SAMPLE_WAIT_HIGH, r10, 2 //check if channel 2
	MOV r2.w2, 0x06C0 // SPI command for CH3
	QBEQ SAMPLE_WAIT_HIGH, r10, 3 //check if channel 3
	MOV r2.w2, 0x0700 // SPI command for CH4
	QBEQ SAMPLE_WAIT_HIGH, r10, 4 //check if channel 4
	MOV r2.w2, 0x0740 // SPI command for CH5
	QBEQ SAMPLE_WAIT_HIGH, r10, 5 //check if channel 5
	MOV r2.w2, 0x0780 // SPI command for CH6
	QBEQ SAMPLE_WAIT_HIGH, r10, 6 //check if channel 6
	MOV r2.w2, 0x07C0 // SPI command for CH7
SAMPLE_WAIT_HIGH:		 // wait until the PRU1 sample clock goes high
	LBBO	r6, r5, 0, 4	 // load the value at address r5 into r6		
	QBNE	SAMPLE_WAIT_HIGH, r6, 1 // loop until r6 is low
	CLR	r30.t5		 // set the CS line low (active low)
	MOV	r4, 24		 // going to write/read 24 bits (3 bytes)
	ADD r10, r10, 1 //increment channel counter
	QBNE SPICLK_BIT, r10, 8 // if CH does not equal 8, don't reset
	MOV r10, 0 // reset channel counter after reaching last channel
SPICLK_BIT:                      // loop for each of the 24 bits
	SUB	r4, r4, 1        // count down through the bits
	CALL	SPICLK           // repeat call the SPICLK procedure until all 24-bits written/read
	QBNE	SPICLK_BIT, r4, 0
	SET	r30.t5		 // pull the CS line high (end of sample)
	LSR	r3, r3, 1        // SPICLK shifts left too many times left, shift right once
	AND	r3, r3, r7	 // AND the data with mask to give only the 12 LSBs
	//SBBO	r3, r1, 12, 4    // store the data for debugging only -- REMOVE
STORE_DATA:                      // store the sample value in memory
	SUB	r9, r9, 2	 // reducing the number of samples - 2 bytes per sample
	SBBO	r3.w0, r8, 0, 2	 // store the value r3 in memory
    SBBO r8, r11, 0, 4 // store r8 4 byte address value at r11 address
    ADD	r8, r8, 2	 // shifting by 2 bytes - 2 bytes per sample
    
    // use the following to end after filling buffer:
	//QBEQ	END, r9, 4       // have taken the full set of samples when r9 is equal to 4

    // use the following to write continuously:
	QBNE SAMPLE_WAIT_LOW, r9, 4 // r9 is equal to 4 when memory full
    ADD r8, r11, 4 // copy r11 to r8 and add 4 bytes to reset buffer
    LBBO r9, r1, 8, 4 // reset r9, same as line in START

SAMPLE_WAIT_LOW:                 // need to wait here if the sample clock has not gone low
	LBBO	r6, r5, 0, 4	 // load the value in PRU1 sample clock address r5 into r6
	QBNE	SAMPLE_WAIT_LOW, r6, 0 // wait until the sample clock goes low (just in case)
	QBA	GET_SAMPLE
END:
	MOV	r31.b0, PRU0_R31_VEC_VALID | PRU_EVTOUT_0	
	HALT                     // End of program -- below are the "procedures"


// This procedure applies an SPI clock cycle to the SPI clock and on the rising edge of the clock
// it writes the current MSB bit in r2 (i.e. r31) to the MOSI pin. On the falling edge, it reads
// the input from MISO and stores it in the LSB of r3. 
// The clock cycle is determined by the datasheet of the product where TIME_CLOCK is the
// time that the clock must remain low and the time it must remain high (assuming 50% duty cycle)
// The input and output data is shifted left on each clock cycle

SPICLK:
	MOV	r0, TIME_CLOCK	 // time for clock low -- assuming clock low before cycle
CLKLOW:	
	SUB	r0, r0, 1	 // decrement the counter by 1 and loop (next line)
	QBNE	CLKLOW, r0, 0	 // check if the count is still low				 
	QBBC	DATALOW, r2.t31  // The write state needs to be set right here -- bit 31 shifted left
	SET	r30.t1
	QBA	DATACONTD
DATALOW:
	CLR	r30.t1
DATACONTD:
	SET	r30.t2		 // set the clock high
	MOV	r0, TIME_CLOCK	 // time for clock high
CLKHIGH:
	SUB	r0, r0, 1	 // decrement the counter by 1 and loop (next line)
	QBNE	CLKHIGH, r0, 0	 // check the count
	LSL	r2, r2, 1
				 // clock goes low now -- read the response on MISO
	CLR	r30.t2		 // set the clock low
	QBBC	DATAINLOW, r31.t3
	OR	r3, r3, 0x00000001
DATAINLOW:	
	LSL	r3, r3, 1 
	RET
