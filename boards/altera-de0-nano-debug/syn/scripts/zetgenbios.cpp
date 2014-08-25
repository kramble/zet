// zetgenbios.cpp - converts binary file to zet boot command sequence
// special version for bios load, see notes in bootbulk.txt

#include "stdio.h"
#include "stdlib.h"
#include "string.h"

int origin = 0;		// Hardcode origin (TODO pass as command line parameter)

int main(int argc, char **argv)
{

	if (argc!=2)
	{
		printf("usage: zetgenbios infile.bin (NB output is to infile.zet)\n");
		return 1;
	}
	
	// Strip file suffix and append .zet
	char *ifname = argv[1];
	if (!ifname || !*ifname)
		return 2;	// Sanity check
		
	char *ofname = (char*)malloc(strlen(ifname)+5);	// Allow room for ".zet\0"
	if (!ofname)
		return 3;	// Malloc error
	
	strcpy(ofname, ifname);
	
	// Point at last char (assumes len>=1 which is sanity checked above)
	char *p = ofname + strlen(ofname) - 1;
	int dotflag = 0;
	while (p>=ofname)
	{
		if (*p == '.')
		{
			strcpy(p,".zet");
			dotflag = 1;
			break;
		}
		p--;
	}
	if (!dotflag)
	{
		printf("DEBUG: no suffix found\n");
		strcat(ofname,".zet");
	}
	
	FILE *ifile = fopen(ifname,"rb");
	if (!ifile)
	{
		printf("Could not open input file\n");
		return 4;
	}
	FILE *ofile = fopen(ofname,"wb");
	if (!ofile)
	{
		printf("Could not open output file\n");
		fclose(ifile);
		return 5;
	}

	// Convert
	unsigned char buf[4];		// Command is 4 bytes vis: flags, addrH, addrL, data
	int byte, lbyte;
	int addr = origin;			// NB used to determine the split between the vga and main bios and set flags (word count)
	int phase = 0;
	int flag = 1;				// Initial flag
	
	// Preamble - NB we do NOT halt cpu for bulk upload of bios
	buf[0] = 0x80; buf[1] = 0; buf[2] = 0; buf[3] = 0;
	if (fwrite(buf,1,4,ofile) != 4)
	{
		printf("ERROR writing to output file (preamble)\n");
		goto write_err;
	}
	
	// Load words (not bytes)

	// Addresses (in words) of transfer buffer
#define FLAGPTR 0
#define DATAPTR 1

	while ((byte=fgetc(ifile))!=EOF)
	{

#if 0	// bios is MUCH bigger
		if (addr > 255)
		{
			printf("ERROR address > 255, aborting\n");
			break;
		}
#endif

		if (0 == phase++)
		{
			lbyte = byte;
			continue;	// Writing two bytes at a time (NB addr is not incremented for this byte)
		}
		
		phase = 0;

		if (flag == 0x8000)	// Skip to start of main bios at address 0x8000 (in words)
		{
			if (addr < 0x8000)	// words
			{
				addr++;
				continue;
			}
		}
		
		// Write data

		buf[0] = 0x81; buf[1] = DATAPTR; buf[2] = byte; buf[3] = lbyte;		// Swap bytes

		if (fwrite(buf,1,4,ofile) != 4)
		{
			printf("ERROR writing to output file (data)\n");
			goto write_err;
		}

		buf[0] = 0x80; buf[1] = 0; buf[2] = 0; buf[3] = 0;
		if (fwrite(buf,1,4,ofile) != 4)
		{
			printf("ERROR writing to output file (data)\n");
			goto write_err;
		}

		// Write flag

		if (addr == 0x4000 -1)			// VGABIOSLENGTH in words (see entry.asm)
			flag = 0x8000;
		else if (addr == 0x8000 + 0x7F80 -1)	// ROMBIOSLENGTH in words
			flag = 0x5465;
		else
			flag ^= 8;				// toggle bit 4 (NOT LSB as we don't want it to go to zero)
			
		buf[0] = 0x81; buf[1] = FLAGPTR; buf[2] = (flag >> 8) & 0xff; buf[3] = flag & 0xff;

		if (fwrite(buf,1,4,ofile) != 4)
		{
			printf("ERROR writing to output file (data)\n");
			goto write_err;
		}

		buf[0] = 0x80; buf[1] = 0; buf[2] = 0; buf[3] = 0;
		if (fwrite(buf,1,4,ofile) != 4)
		{
			printf("ERROR writing to output file (data)\n");
			goto write_err;
		}
	
		// comment out for testing (to check the bootrom section which is not otherwise includes)
		if (addr == 0x8000 + 0x7F80 -1)		// The 0x8000 allows for the offset to start of main bios
			break;				// Don't write the remainder since we've set the end flag 0x5465

		addr++;
	}
	
	// Postamble - cpu remains RUNNING
	buf[0] = 0x80; buf[1] = 0; buf[2] = 0; buf[3] = 0;
	if (fwrite(buf,1,4,ofile) != 4)
		printf("ERROR writing to output file (postamble)\n");

write_err:
	fclose(ifile);
	fclose(ofile);
	
	return 1;
}