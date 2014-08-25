// zetgen.cpp - converts binary file to zet boot command sequence

#include "stdio.h"
#include "stdlib.h"
#include "string.h"

int origin = 0;		// Hardcode origin (TODO pass as command line parameter)

int main(int argc, char **argv)
{

	if (argc!=2)
	{
		printf("usage: zetgengen infile.bin (NB output is to infile.zet)\n");
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
	int addr = origin;
	int phase = 0;
	
	// Preamble - halt cpu
	buf[0] = 0; buf[1] = 0; buf[2] = 0; buf[3] = 0;
	if (fwrite(buf,1,4,ofile) != 4)
	{
		printf("ERROR writing to output file (preamble)\n");
		goto write_err;
	}
	
	// Boot ROM is just 256 bytes, organized as 128 words
	
	while ((byte=fgetc(ifile))!=EOF)
	{
		if (addr > 255)
		{
			printf("ERROR address > 255, aborting\n");
			break;
		}

		if (0 == phase++)
		{
			lbyte = byte;
			continue;	// Writing two bytes at a time
		}
		
		phase = 0;
		
		// buf[0] = 1; buf[1] = addr; buf[2] = lbyte; buf[3] = byte;
		buf[0] = 1; buf[1] = addr; buf[2] = byte; buf[3] = lbyte;		// Swap bytes

		if (fwrite(buf,1,4,ofile) != 4)
		{
			printf("ERROR writing to output file (data)\n");
			goto write_err;
		}
		addr++;

		buf[0] = 0; buf[1] = 0; buf[2] = 0; buf[3] = 0;
		if (fwrite(buf,1,4,ofile) != 4)
		{
			printf("ERROR writing to output file (data)\n");
			goto write_err;
		}
	}
	
	// Postamble - cpu remains halted
	buf[0] = 0; buf[1] = 0; buf[2] = 0; buf[3] = 0;
	if (fwrite(buf,1,4,ofile) != 4)
		printf("ERROR writing to output file (postamble)\n");

write_err:
	fclose(ifile);
	fclose(ofile);
	
	return 1;
}