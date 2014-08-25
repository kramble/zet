DE0-Nano with debug console for boot

This code is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

The DE0-Nano does not include VGA, PS2, SDCARD or flash memory so some hardware needs to
be added in order to use it. This is fairly minimal, just some connectors and a few
passive components. Details in SCHEMATIC.txt

The lack of flash is a significant issue for booting, this version uses a TCL script
running on a PC host (the "console") to control the boot process and upload the bios in
place of flash. [TODO... It can also emulate disk I/O in place of the SDCARD interface
(this is optional when a SDCARD adapter is physically attached to the DE0-Nano)].

The intent is to create a second version of the DE0-Nano branch which loads the bios
directly from the SDCARD, thus avoiding the need for a host PC.

ACKNOWLEDGEMENTS
The code is based on https://github.com/marmolejo/zet with additional code from
https://github.com/progranism/Open-Source-FPGA-Bitcoin-Miner and http://fpga4fun.com

LICENSE
GPL or LGPL as appropriate

Programming
A TCL script is supplied to upload the FPGA configuration SOF scripts/program-fpga-board.bat

Console
This version of the DE0-Nano port REQUIRES a host pc running a console program in order to
boot. Run scripts/console.bat for windows, or execute quartus_stp console.tcl for linux.

The initial VGA monitor display is a simple one-line status: 00 0FFF0 0000
The first field is the console command byte (00 = reset, 80 = running).
The second field is the program counter.
The third field is the gpio LED port (16 bits, compare 14 in the DE2-115), for debugging.
NB The 8 De0-Nano leds are assigned to bits [3:0] of this port, plus a few status signals
(currently the various reset lines).
Pushbuttons KEY0 and KEY1 are connected as reset and nmi.
The 4 dip switches are currently unused (on DE2-115 they selected sdcard or flash diskette).

The nano starts up held in the reset state. To run simply enter the "r" command and "h"
to halt (asserts reset). "v" switches between the simple vga display and the normal vga,
but this will not work until the bios is loaded.

The following may change as future features are implemented...
To load the bios, select "s" which uploads data for the bootrom (256 bytes), choose the
bootnano.zet file. NB this is a patched version of bootrom.dat which supports the
console bulk loader (the "s" loader is a hardware feature which writes to bootrom).
... and that step is no longer needed as bootnano is now compiled into the SOF.
Then select "r" to run (don't forget this step else nothing happens!).
Select "k" which sends bulk data, choose the biosfd_v02.zbd file, transfer takes around
10 seconds. NB this is a patched version of the bios to support the console bulk loader.
Select "v" to switch to the main vga, you should see the BIOS startup messages. It will
be paused at the "Booting device: Floppy flash image" message.
Select "k" and choose mos_v01.zbd (this is a boot sector implementing a simple monitor).
You should now have a "> " prompt. The available commands are M, P, and G for modify Memory,
set address Pointer and Goto (executes an in-segment call, return with ret C3).
Initial address is 0000:8000 (only segment 0000 is supported by the monitor, though you are
free to do what you like in the executed code). The R and W commands to read and write
diskette sectors are currently disabled as this is not yet supported for the console
bulk loader (which replaces the flash diskette code). The SDCARD HDD may work, but I
can't test it yet. And if you take a look at the code, the enigmatic B! command initiated
a boot of the full MOS Operating System (MyOS, one of my older projects, which is NOT the
same as this one http://sourceforge.net/projects/myos-os/). Unfortunately this probably
won't work as it uses some 80386 16-bit opcodes, not supported on the 8086/80186.

Console commands
a : print bulk load address (nano_flash.v port 0238,023A)
d : print gpio led data
h : halt (reset)
k : select bulk data file and upload
q : quit console
r : run (deasserts reset)
s : select bootrom data file and upload (NB different file format to bulk data)
v : toggle VGA display adapter
x : exit console (synonym for quit)

There are a couple of utilities for generating the .zet and .zbd files, genzet.cpp and
genzbd.cpp (these are generic C programs which should compile easily, I have supplied
windows .exe versions compiled under MSVC 2008 Express). They take a binary file and
convert it to the bootrom "s" and bulk loader "k" formats, respectively.

Upcoming features...
Replacement of the initial bootrom in the FPGA SOF, so that bootnano.zet does not need
to be loaded and we boot directly from the console bulk loader (DONE).
Implementation of disk I/O via console (using the bulk loader interface). This should allow
a normal DOS to boot rather than the mos_v01.zbd monitor.
Loading of the bios from SDCARD, which should fully automate the bootup process (I'm
awaiting delivery of the Arduino sdcard adapter, so no progress on this yet).

Build notes...
I originally built from http://zet.aluzina.org/images/3/32/Zet-1.3.1.zip
Compiling the github version, there are errors due to a couple of missing files...
cores\zet\rtl\rom_def.v
cores\zet\rtl\micro_rom.dat
I copied them from http://zet.aluzina.org/images/3/32/Zet-1.3.1.zip and it builds OK
Aha! It's explained here http://zet.aluzina.org/forums/viewtopic.php?f=5&t=4 (though
that thread is a bit out of date now).
