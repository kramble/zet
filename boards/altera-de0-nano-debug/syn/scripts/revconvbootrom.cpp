// revconvbootrom.cpp

// Converts bootnano.dat from raw binary back to text for quartus build

// A VERY QUICK HACK!

#include "stdio.h"
#include "ctype.h"
#include "string.h"

int main()
{
	FILE *ifile = fopen("bootnano.bin","rb");
	FILE *ofile = fopen("bootnano.dat","wb");	// want unix line endings

	if (!ifile || !ofile)
	{
		printf("ERROR opening file\n");
		return 1;
	}
	
	unsigned int ch, c1;
	int phase = 0;
	
	while ((ch=fgetc(ifile))!=EOF)
	{
		if (1 != phase++)
		{
			c1 = ch;
			continue;	// Since 2 bytes per line, in reverse order
		}
		
		// Mangle the byte order
		fprintf(ofile, "%02x%02x\n", ch, c1);
		phase = 0;
	}
	
	fclose(ifile);
	fclose(ofile);
	return 0;
}