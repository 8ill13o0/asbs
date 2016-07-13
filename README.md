# asbs

#Files:

EBB-PRU-ADC.dts               device tree overlay source
EBB-PRU-ADC-00A0.dtbo         device tree overlay blob object (compiled version of .dts file)

PRUADC.c                      source code for loading two PRU programs into PRU-ICSS
PRUClock.p                    PRU program to provide a variable frequency clock on p8_46
PRUADC.p                      PRU program to communicate wtih MCPXXXX family of SPI ADC ICs

mem2file.c                    source code for capturing data stored in memory

Compile PRUADC.c with:
$ gcc PRUADCmod.c -o PRUADCmod -lpthread -lprussdrv

Compile <name>.p files with:
$ pasm -b <name>.p
The "-b" command geneartes a little-endian binary file

#Install Steps:

###(1) Deactivate HDMI Overlay, done once:
see EBB pg 225

$ sudo nano /bood/uEnv.txt

Uncomment the following line, bu be careful not to uncomment the similar HDMI/eMMC line, or your BBB will not boot from the eMMC:

 ##Disable HDMI
optargs=capemgr.disable_partno=BB-BONELT-HDMI,BB-BONELT-HDMIN

$ sudo shutdown -r now

Check that HDMI has been disabled:

$ cat /sys/devices/bone_capemgr.9/slots
 4: ff:P-O-L Bone-LT-eMMC-2G,00A0,Texas Instrument,BB-BONE-EMMC-2G
 5: ff:P-O-- Bone-Black-HDMI,00A0,Texas Instrument,BB-BONELT-HDMI
 6: ff:P-O-- Bone-Black-HDMIN,00A0,Texas Instrument,BB-BONELT-HDMIN

The letter "L" means enabled.



###(2) Load Device Tree Overlay, done each reboot:

$ cp EBB-PRU-ADC-00A0.dtbo /lib/firmware/
$ cd /lib/firmware/
$ sudo sh -c "echo EBB-PRU-ADC > $SLOTS"
- or, if $SLOTS env variable not set up -
$ sudo sh -c "echo EBB-PRU-ADC > /sys/devices/bone_capemgr.9/slots"


