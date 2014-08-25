// convbootrom.cpp

// Converts bootrom.dat into raw binary (as a basis for new zet boot datafiles)

// A VERY QUICK HACK! Ignore the compile warnings about uninitialized variables.

#include "stdio.h"
#include "ctype.h"
#include "string.h"

int main()
{
	FILE *ifile = fopen("bootrom.dat","r");
	FILE *ofile = fopen("bootrom.bin","wb");

	if (!ifile || !ofile)
	{
		printf("ERROR opening file\n");
		return 1;
	}
	
	unsigned int ch, c1, c2, c3;
	int phase = 0;
	
	while ((ch=fgetc(ifile))!=EOF)
	{
	
		if (!isxdigit(ch))		// WHY BROKEN??
				continue;

		ch = toupper(ch);

		if (ch > '9')
			ch -= 'A' - 10;
		else
			ch -= '0';
	
		if (3 != phase++)
		{
			c1 = c2;
			c2 = c3;
			c3 = ch;
			continue;	// Since 2 bytes per line, in reverse order
		}
		
		// Mangle the byte order
		fprintf(ofile, "%c%c", (c3 << 4) | ch, (c1 << 4) | c2);
		phase = 0;
	}
	
	fclose(ifile);
	fclose(ofile);
	return 0;
}