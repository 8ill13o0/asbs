/*  This program loads the two PRU programs into the PRU-ICSS transfers the configuration
*   to the PRU memory spaces and starts the execution of both PRU programs.  Additionally it 
*   reads the values in the memory shared by the PRU and the Linux Kernel and passes
*   those values to stdout.  
*
*   PRU code modified from similar work by Derek Molloy, for the book Exploring BeagleBone. Please see:
*        www.exploringbeaglebone.com/chapter13 for a full description of this code example and the associated programs.
*
*   Reading of memory uses a similar approach to that in devmem2.c by Jan-Derk Bakker.
*
*
*/

#include <stdio.h>
#include <stdlib.h>
#include <prussdrv.h>
#include <pruss_intc_mapping.h>

#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/mman.h>


// pru defines
#define ADC_PRU_NUM	   0   // using PRU0 for the ADC capture
#define CLK_PRU_NUM	   1   // using PRU1 for the sample clock
#define MMAP0_LOC   "/sys/class/uio/uio0/maps/map0/"
#define MMAP1_LOC   "/sys/class/uio/uio0/maps/map1/"

//mmap defines
#define MAP_SIZE 0x0FFFFFFF
#define MAP_MASK (MAP_SIZE - 1)

enum FREQUENCY {    // measured and calibrated, but can be calculated
	FREQ_12_5MHz =  1,
	FREQ_6_25MHz =  5,
	FREQ_5MHz    =  7,
	FREQ_3_85MHz = 10,
	FREQ_1MHz   =  45,
	FREQ_500kHz =  95,
	FREQ_250kHz = 245,
	FREQ_100kHz = 495,
   FREQ_40kHz = 1245,
	FREQ_25kHz = 1995,
	FREQ_10kHz = 4995,
	FREQ_5kHz =  9995,
	FREQ_2kHz = 24995,
	FREQ_1kHz = 49995
};

enum CONTROL {
	PAUSED = 0,
	RUNNING = 1,
	UPDATE = 3
};

// Short function to load a single unsigned int from a sysfs entry
unsigned int readFileValue(char filename[]){
   FILE* fp;
   unsigned int value = 0;
   fp = fopen(filename, "rt");
   fscanf(fp, "%x", &value);
   fclose(fp);
   return value;
}

int main (void)
{
   if(getuid()!=0){
      fprintf(stderr, "You must run this program as root. Exiting.\n");
      exit(EXIT_FAILURE);
   }
   // Initialize structure used by prussdrv_pruintc_intc
   // PRUSS_INTC_INITDATA is found in pruss_intc_mapping.h
   tpruss_intc_initdata pruss_intc_initdata = PRUSS_INTC_INITDATA;

   // Read in the location and address of the shared memory. This value changes
   // each time a new block of memory is allocated.
   unsigned int timerData[2];
   timerData[0] = FREQ_40kHz;
   timerData[1] = RUNNING;
   fprintf(stderr, "The PRU clock state is set as period: %d (0x%x) and state: %d\n", timerData[0], timerData[0], timerData[1]);
   unsigned int PRU_data_addr = readFileValue(MMAP0_LOC "addr");
   fprintf(stderr, "-> the PRUClock memory is mapped at the base address: %x\n", (PRU_data_addr + 0x2000));
   fprintf(stderr, "-> the PRUClock on/off state is mapped at address: %x\n", (PRU_data_addr + 0x10000));

   // data for PRU0 based on the MCPXXXX datasheet
   unsigned int spiData[3];
   //spiData[0] = 0x01800000; //for MCP3008 single-ended CH0
   //spiData[0] = 0x06000000; //for MCP3208 single-ended CH0 
   spiData[0] = 0x06400000; //for MCP3208 single-ended CH1, not used in PRUADC_12bit_8ch.bin
   spiData[1] = readFileValue(MMAP1_LOC "addr");
   spiData[2] = readFileValue(MMAP1_LOC "size");
  
   fprintf(stderr, "Sending the SPI Control Data: 0x%x\n", spiData[0]);
   fprintf(stderr, "The DDR External Memory pool has location: 0x%x and size: 0x%x bytes\n", spiData[1], spiData[2]);
   int numberSamples = spiData[2]/2;
   fprintf(stderr, "-> this space has capacity to store %d 16-bit samples (max)\n", numberSamples);

   // Allocate and initialize memory
   prussdrv_init ();
   prussdrv_open (PRU_EVTOUT_0);

   // Write the address and size into PRU0 Data RAM0. You can edit the value to
   // PRUSS0_PRU1_DATARAM if you wish to write to PRU1
   prussdrv_pru_write_memory(PRUSS0_PRU0_DATARAM, 0, spiData, 12);  // spi code
   prussdrv_pru_write_memory(PRUSS0_PRU1_DATARAM, 0, timerData, 8); // sample clock

   // Map the PRU's interrupts
   prussdrv_pruintc_init(&pruss_intc_initdata);

   // Load and execute the PRU program on the PRU
   prussdrv_exec_program (ADC_PRU_NUM, "./PRUADC_12bit_8ch.bin");
   prussdrv_exec_program (CLK_PRU_NUM, "./PRUClock.bin");
   fprintf(stderr, "EBBClock PRU1 program now running (%d)\n", timerData[0]);

   
   // Some memory reads:
   int i = 0;
   int iFlush = 0;
   int fd;
   void *map_base, *virt_addr;
   unsigned int last_write_addr; //was unsigned long
   unsigned int addr = readFileValue(MMAP1_LOC "addr");
   unsigned int size = readFileValue(MMAP1_LOC "size");
   off_t target = addr;
   unsigned int offsetStart = 4; //not zero, has to skip over first 4 bytes, value is next byte to read
   int samples_to_read = 0;
   int bytes_per_sample = 2;
   unsigned int offsetMax = size - bytes_per_sample; //offset of the first byte of the last sample
   unsigned long read_result;
   int totalSamples = 0;

   if((fd = open("/dev/mem", O_RDWR | O_SYNC)) == -1){
   fprintf(stderr, "Failed to open memory!");
   return -1;
   }

   map_base = mmap(0, MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, target & ~MAP_MASK);
   if(map_base == (void *) -1) {
      fprintf(stderr, "Failed to map base address");
      return -1;
   }

   fflush(stdout);
   

   for(iFlush = 1; iFlush <= 30; iFlush++) {

      virt_addr = map_base + (target & MAP_MASK);
      last_write_addr = *((uint32_t *) virt_addr); //4-byte address
      unsigned int offsetEnd = last_write_addr - addr; //difference in memory addresses, difference in bytes not samples

      fprintf(stderr, "Buffer Flush #%d, Memory address of last PRU write: 0x%X, offsetEnd:%d bytes, offsetStart:%d bytes\n",iFlush, last_write_addr, offsetEnd, offsetStart);

      if(offsetEnd > offsetStart){
         samples_to_read = (offsetEnd - offsetStart) / bytes_per_sample + 1; 
         fprintf(stderr, "    reading %d samples\n",samples_to_read);
         for( i = 1; i<=samples_to_read; i++){
            virt_addr = map_base + ((target+offsetStart) & MAP_MASK);
            read_result = *((uint16_t *) virt_addr); //2-byte value
            fwrite(&read_result, sizeof(uint16_t),1,stdout);
            offsetStart+=bytes_per_sample;  
         }
         fflush(stdout);
         totalSamples += samples_to_read;
         fprintf(stderr, "    just wrote flush to stdout\n");
      }else if(offsetEnd < offsetStart){
         //read from offsetStart to numberSamples
         samples_to_read = (offsetMax - offsetStart) / bytes_per_sample + 1;
         fprintf(stderr, "    reading %d samples (first partial)\n",samples_to_read); 
         for( i = 1; i<=samples_to_read; i++){
            virt_addr = map_base + ((target+offsetStart) & MAP_MASK);
            read_result = *((uint16_t *) virt_addr); //2-byte value
            fwrite(&read_result, sizeof(uint16_t),1,stdout);
            offsetStart+=bytes_per_sample;  
         }
         fflush(stdout);
         totalSamples += samples_to_read;
         fprintf(stderr, "    just wrote first partial flush to stdout\n");
         
         //read from offset=4 to offsetEnd
         offsetStart = 4;
         samples_to_read = (offsetEnd - offsetStart) / bytes_per_sample + 1; 
         fprintf(stderr, "    reading %d samples (last partial)\n",samples_to_read);
         for( i = 1; i<=samples_to_read; i++){
            virt_addr = map_base + ((target+offsetStart) & MAP_MASK);
            read_result = *((uint16_t *) virt_addr); //2-byte value
            fwrite(&read_result, sizeof(uint16_t),1,stdout);
            offsetStart+=2;  
         }
         fflush(stdout);
         totalSamples += samples_to_read;
         fprintf(stderr, "    just wrote last partial flush to stdout\n");
      }

      

      /*sleep time must be less than time to fill buffer, 
      for f=40kHz and 131070 samples in buffer, this must be less than 3.277s*/
      sleep(1); 

   }
   
   fprintf(stderr,"Finished reading/writing %d samples (%d bytes)\n",totalSamples,totalSamples*bytes_per_sample);

   // Wait for event completion from PRU, returns the PRU_EVTOUT_0 number
   //int n = prussdrv_pru_wait_event (PRU_EVTOUT_0);
   //printf("EBBADC PRU0 program completed, event number %d.\n", n);


   // Disable PRU and close memory mappings 
   prussdrv_pru_disable(ADC_PRU_NUM);
   prussdrv_pru_disable(CLK_PRU_NUM);
   prussdrv_exit ();
   if(munmap(map_base, MAP_SIZE) == -1) {
      printf("Failed to unmap memory");
      return -1;
   }
   close(fd);


 return EXIT_SUCCESS;
}
