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

DOS6.22 now boots from diskette emulation (read-only) via console

You will need a 1.44MB floppy disk image for the DOS6.22 boot disk (available on
the web), ensure it is named Dos6.22.img

It is advisable to REM out any devices loaded by config.sys or autoexec.bat (winimage
is a useful utility to mount and modify disk images http://www.winimage.com/).

Convert the image into the upload format: zpack Dos6.22.img
You should now have a file Dos6.22.img.zpk

Load the SOF configuration into the DE0-Nano via program-fpga-board.bat

Start the console via console.bat

Just enter "b" and the console will upload the bios, switch to VGA video and boot DOS.

The console is now running in a loop. To abort, press CONTROL-C. You can restart it
and type "b" to continue floppy emulation (the boot will be skipped), or to reboot
just type "h" to halt (and reset) the CPU, "v" to switch back to the simple VGA display
(if neccessary), then "b".

Note that the bios file (biosfd_v04.zbd) and disk image file (Dos6.22.img.zpk) are
currently hard-coded in console.tcl (edit to change). The bios has been patched to
support the console bios upload and floppy disk emulation (read-only).

Console commands
a : print bulk load address (nano_flash.v port 0238,023A)
b : boot and run diskette emulator (zpk file)
d : print gpio led data
h : halt (reset)
k : select bulk data file and upload (zbd file)
q : quit console
r : run (deasserts reset)
s : select bootrom data file and upload (zet file)
v : toggle VGA display adapter
x : exit console (synonym for quit)

There are utilities for generating the .zet .zbd and .zpk files, zetgen.cpp, zbdgen.cpp
and zpack.cpp (these are generic C programs which should compile easily, I have supplied
windows .exe versions compiled under MSVC 2008 Express). They take a binary file and
convert it to the various upload formats.

Upcoming features...
Fix bug where requesting the same sector twice hangs the console. This will require a
request counter which can be implemented in the bios, or perhaps better, in hardware.
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
