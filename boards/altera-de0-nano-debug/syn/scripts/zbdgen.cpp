// zbdgen.cpp - converts binary file to zet bulk data sequence (dual-strobe version)
// NB The dual-strobe nono_flash.v module is backwards compatible with single-strobe data,
//    but dual-strobe data cannot be used with the old single-strobe nano_flash module

#include "stdio.h"
#include "stdlib.h"
#include "string.h"

int origin = 0;		// Hardcode origin (TODO pass as command line parameter)

int main(int argc, char **argv)
{

	if (argc!=2)
	{
		printf("usage: zbdgen infile.bin (NB output is to infile.zbd)\n");
		return 1;
	}
	
	// Strip file suffix and append .zet
	char *ifname = argv[1];
	if (!ifname || !*ifname)
		return 2;	// Sanity check
		
	char *ofname = (char*)malloc(strlen(ifname)+5);	// Allow room for ".zbd\0"
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
			strcpy(p,".zbd");
			dotflag = 1;
			break;
		}
		p--;
	}
	if (!dotflag)
	{
		printf("DEBUG: no suffix found\n");
		strcat(ofname,".zbd");
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
	unsigned char buf[32];		// Command is 32 bytes vis: flags (strobe + count), 31 bytes data
								// NB Byte ordering is reversed in verilog compared with C so here
								// index [0] is command, then data (FPGA reads [30] then shifts from [1] to [30])
	int byte;
	int addr = origin;			// NB used to determine the split between the vga and main bios and set flags (word count)
	int strobe = 0;				// Strobe A/B (A==false(0), B==true(!0))
	int count = 0;				// Byte count

	// Preamble - all zeros
	memset(buf, 0, sizeof(buf));

	if (fwrite(buf,1,32,ofile) != 32)
	{
		printf("ERROR writing to output file (preamble)\n");
		goto write_err;
	}
	
	// Load bytes (not words)

	while ((byte=fgetc(ifile))!=EOF)
	{

#if 0	// bios is MUCH bigger
		if (addr > 255)
		{
			printf("ERROR address > 255, aborting\n");
			break;
		}
#endif

		// Buffer data (shifting from buf[1] to buf[31])
		memmove(buf+2, buf+1, 30);
		buf[1] = byte;
		if (++count == 31)
		{
			// write buffer
			buf[0] = (strobe ? 0x40 : 0x80) | count;	// flags
			strobe = !strobe;
			count = 0;
		
			if (fwrite(buf,1,32,ofile) != 32)
			{
				printf("ERROR writing to output file (data)\n");
				goto write_err;
			}

			memset(buf, 0, sizeof(buf));	// all zeros
		}
		addr++;
	}

	// Write any remaining data
	
	printf("remainder %d\n", count);
	
	if (count)
	{
		// write buffer
		buf[0] = (strobe ? 0x40 : 0x80) | count;	// flags
		strobe = !strobe;
	
		// shift partial data to end (it's a bit crude)
		// NB the naive "memmove(buf+2, buf+1, 31-count);" will NOT do what I want here as
		//    the whole buffer needs to shift, not just 31-count bytes

		int i = 31-count;
		while (i--)
		{
			memmove(buf+2, buf+1, 30);
			buf[1] = 0;
		}

		if (fwrite(buf,1,32,ofile) != 32)
		{
			printf("ERROR writing to output file (data)\n");
			goto write_err;
		}
	}

	// postamble, clear strobes
	memset(buf, 0, sizeof(buf));	// all zeros

	if (fwrite(buf,1,32,ofile) != 32)
	{
		printf("ERROR writing to output file (data)\n");
		goto write_err;
	}
	
write_err:
	fclose(ifile);
	fclose(ofile);
	
	return 1;
}