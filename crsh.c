#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

void usage(char *progname)
{
	printf("%s /dev/dsk /tmp/file\n",progname);
	exit(1);
}

int main(int argc, char *argv[])
{
	FILE *fp, *fo;
	char buf[512];
	char devpath[1024];
	char tmpfile[1024];

	if (argc!=3) {
		usage(argv[0]);
	}

	strcpy(devpath,argv[1]);
	strcpy(tmpfile,argv[2]);

	fp=fopen(devpath,"r");

	if (!fp) {
		printf("Unable to open %s\n",devpath);
		exit(1);
	}

	memset(buf,0,sizeof(buf));
	fgets(buf,2,fp);
	if ( (buf[0]!='#')&&(buf[1]!='!')) {
		printf("No #! signature in %s\n",devpath);
		exit(1);
	}

	fo=fopen(tmpfile,"w");

	if (!fo) {
		printf("Unable to open %s\n",tmpfile);
		exit(1);
	}

	fputs(buf,fo);

	while (!feof(fp)) {
		memset(buf,0,sizeof(buf));
		fgets(buf,512,fp);
		if (feof(fp)) break;
		fputs(buf,fo);
	}

	fclose(fp);
	fclose(fo);

	execlp("/bin/sh", "/bin/sh", tmpfile, (char *)NULL);
	perror ("Error: exec failed\n");
}
