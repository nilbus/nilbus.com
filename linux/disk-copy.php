<!DOCTYPE html>
<html>
<head>
<!-- //////// Favicon ////////  -->
<link rel="shortcut icon" type="image/x-icon" href="favicon.ico"  />
<meta charset="utf-8" />
<!-- //////// Title ////////  -->
<meta name="description" content="This guide shows how to copy Windows onto another drive. This is a free and relatively easy method that will create a clone of your current hard disk, without buying any software.">
<meta name="keywords" content="qtparted,ntfsresize,copy windows,transfer windows,new disk,new drive,new hard drive,hard drive,hard disk,clone windows,partition,linux,knoppix,live CD,fdisk,clone,copy,duplicate,MBR,master boot record,partition table,resize">
<meta name="author" content="Edward Anderson">
<title>Copying Windows to a new drive, using linux - How-to/Guide</title>

<style type="text/css">
<!--
/* Quote & Code blocks */
article {
  font-size: 18px;
  line-height: 1.5;
}
article pre {
  background-color: #EEEEFF;
  border: 1px solid #aaa;
  color: #007700;
  display: block;
  font-family: Courier, Courier New, sans-serif;
}
article b {
  color: #000000;
}
article dt {
  font-weight: bold;
}
article h2 {
  font-size: 24px;
}
article h3 {
  border-bottom: 4px solid #777;
  line-height: 1.5;
}
-->
</style>
<!-- //////// Css StyleSheets ////////  -->
<link rel="stylesheet" href="/style/style.css" />
<!-- //////// HTML5 IE Fix ////////  -->
<!--[if IE]>
  <script src="http://html5shim.googlecode.com/svn/trunk/html5.js"></script>
<![endif]-->
<!-- //////// Cufon ////////  -->
<script src="js/cufon-yui.js"></script>
<script src="js/ChunkFive_400.font.js"></script>
<script>
  Cufon.replace('h1#logo', {
    textShadow: '#fff 1px 1px' 
});
  Cufon.replace('article h2', {
    textShadow: '#000 2px 2px'
});
</script>
</head>
<body>
		<!-- //////// Top Section ////////  -->
		<div class="container_12" id="bottom">
			<header class="grid_12">
				<!-- //////// Logo ////////  -->
				<h1 id="logo">Nilbus is love</h1>
				<!-- //////// Nav ////////  -->
				<nav>
					<ul id="links">
						<li><a href="/">Home</a></li>
						<li><a href="/#about">About</a></li>
						<li><a href="/#github">Github</a></li>
						<li><a href="/#portfolio">Portfolio</a></li>
						<li><a href="/#contact">Contact</a></li>
					</ul>
				</nav><!-- end nav -->
			</header><!-- end header -->

			<!-- //////// Heading Text ////////  -->
			<div class="grid_12 heading clear">
        <p>
          I am a <span class="emp">Ruby on Rails</span> &amp; <span class="emp">Javascript</span> web developer who loves making things better for people.
          I also study piano and play ultimate frisbee.
        </p>
			</div><!-- end heading -->

		</div><!-- end top -->

		<!-- //////// Bottom Section ////////  -->
		<div class="clear" id="top">

		<!-- //////// About Section ////////  -->
		<div class="container_12">
			<article>
<h2>Copying Windows to a new drive, using linux - How-to/Guide</h2>
<p>
Written 20 Mar 2005 by Edward Anderson. Updated 1 Nov 2013 (give an example using ntfsresize)
</p>
<p>
Another good resource: <a href="http://www.2pi.info/software/copying-windows-new-hard-drive.html" target="_blank">www.2pi.info/software/copying-windows-new-hard-drive.html</a>
<h3>Overview</h3>
This guide will show you how to copy an existing installation of Windows (or any other OS) from one drive to another - as long as the destination drive is the same size or larger.
</p>
<p>
This is a free and relatively easy method that will create a clone of your current hard disk, without having to buy any third party software.
</p>
<p><ol>
<li><a href="#tools">Gathering tools
<li><a href="#hardware">Physical Installation
<li><a href="#table">Preparing new partition table
<li><a href="#mbr">Copy the MBR
<li><a href="#copy">Copy the Partition
<li><a href="#resize">Resizing the Partition
</ol>
</p>

<script type="text/javascript"><!--
google_ad_client = "ca-pub-5974624498841092";
/* disk-copy */
google_ad_slot = "2333167650";
google_ad_width = 728;
google_ad_height = 90;
//-->
</script>
<script type="text/javascript"
src="http://pagead2.googlesyndication.com/pagead/show_ads.js">
</script>

<h3><a name="tools"></a>Gathering Tools</h3>
<p>
For this project, you will need a Linux Live CD that has dd, fdisk, parted/qtparted, and ntfsresize.<br>
<a href="http://www.knopper.net/knoppix/index-en.html" target="_blank">Knoppix</a> is a Live CD that has everything you'll need.
Many other Live CDs will work as well, such as an <a href="http://www.ubuntu.com/getubuntu/download" target="_blank">Ubuntu</a> install CD.<br>
Burn the contents of the ISO to CD to boot from later.<br>
</p>
<h3><a name="hardware"></a>Physical Installation</h3>
<p>
Install both hard drives in your computer. In this guide, I will use the following disk setup as an example:
<b>
</p>
<p>
/dev/sda (Primary Master) - New, empty 80G drive<br>
/dev/sdb (Primary Slave) - Old 10G drive with all data on one NTFS partition (/dev/sdb1)<br>
</p>
<p>
</b>
Your disk setup can vary, but in this guide, I will refer to the new drive as /dev/sda, and the old as /dev/sdb. Use device names according to your own setup.
</p>
<p><!-- If you're not familiar with this naming scheme for disks/partitions, read the <a href="http://www.linux.com/howtos/Partition/partition-2.shtml" target="_blank">Linux Partition HOWTO</a>.<br> -->
To sum it up, SCSI disks are referred to by /dev/sdX where X is corresponds to the disk order (a for the first disk, d for the last). Partitions are referred to as /dev/sdXY where Y is the partiton number. (eg. /dev/sdc2 is the 3rd disk, 2nd partition)  IDE disks are the same, but hdX instead of sdX.
</p>
<h3><a name="table"></a>Preparing new partition table</h3>
<p>
Before you start, you may want to run scandisk on your drive to verify that there are no errors on the disk.
</p>
<p>
Boot from the Live CD. Press enter at the boot: prompt.
</p>
<p>
Open a new terminal as root.  In knoppix 3.7, click on the Penguin icon, and click Root Shell.
Otherwise, just open a normal terminal and run <pre>$ <b>sudo su</b></pre> to switch to the root user.
</p>
<p>
View the partition table for the old disk:
<pre># <b>fdisk -l -u /dev/sdb</b>

Disk /dev/sdb: 10.2 GB, 10240000000 bytes
255 heads, 63 sectors/track, 1244 cylinders, total 20000000 sectors
Units = sectors of 1 * 512 = 512 bytes

   Device Boot      Start         End      Blocks   Id  System
/dev/sdb1   *          63    19968794     9984366    7  HPFS/NTFS</pre>

Note that I used the -u option on fdisk. This displays the start and end units in sectors, rather than cylinders, since the cylinder size varies from disk to disk.
</p>
<p>
Record the Start and End positions, and the Id for the existing partition.
</p>
<p>
Now run fdisk on the new disk.
<pre># <b>fdisk /dev/sda</b>
Device contains neither a valid DOS partition table, nor Sun, SGI or
OSF disklabel
Building a new DOS disklabel. Changes will remain in memory only,
until you decide to write them. After that, of course, the previous
content won't be recoverable.


The number of cylinders for this disk is set to 158730.
There is nothing wrong with that, but this is larger than 1024,
and could in certain setups cause problems with:
1) software that runs at boot time (e.g., old versions of LILO)
2) booting and partitioning software from other OSs
   (e.g., DOS FDISK, OS/2 FDISK)
Warning: invalid flag 0x0000 of partition table 4 will be corrected by
w(rite)

Command (m for help):</pre>
When you run fdisk on an emptry drive, it may tell you that there is no partition table, or that the disk is large. You may safely ignore these warnings.
</p>
<p>
Print the current partition table to verify that there are no partitions on the disk.
<pre>Command (m for help): <b>p</b>

Disk /dev/sda: 81.9 GB, 81920000000 bytes
16 heads, 63 sectors/track, 158730 cylinders
Units = cylinders of 1008 * 512 = 516096 bytes

   Device Boot      Start         End      Blocks   Id  System

</pre>
If there are partitions listed, and you were expecting none, make sure you ran fdisk on the correct device. You should delete the existing partitions on the new disk, only if you know that the data is not needed.
</p>
<p>
Create an identical partition, using the Start and End positions from the other disk.  Be sure to change the units to Sectors.
<pre>Command (m for help): <b>u</b>
Changing display/entry units to sectors

Command (m for help): <b>n</b>
Command action
   e   extended
   p   primary partition (1-4)
<b>p</b>

Partition number (1-4): <b>1</b>
First sector (63-159999999, default 63): <b>63</b>
Last sector or +size or +sizeM or +sizeK (63-159999999, default 159999999): <b>19968794</b>

Command (m for help): <b>p</b>

Disk /dev/sda: 81.9 GB, 81920000000 bytes
16 heads, 63 sectors/track, 158730 cylinders, total 160000000 sectors
Units = sectors of 1 * 512 = 512 bytes

   Device Boot      Start         End      Blocks   Id  System
/dev/sda1              63    19968794     9984366   83  Linux</pre>

Before we're done, we must set the Boot flag and System Id. Use the same Id that was listed on your old partition table.
<pre>Command (m for help): <b>a</b>
Partition number (1-4): <b>1</b>

Command (m for help): <b>t</b>
Selected partition 1
Hex code (type L to list codes): <b>7</b>
Changed system type of partition 1 to 7 (HPFS/NTFS)

Command (m for help): <b>p</b>
Disk /dev/sda: 81.9 GB, 81920000000 bytes
16 heads, 63 sectors/track, 158730 cylinders, total 160000000 sectors
Units = sectors of 1 * 512 = 512 bytes

   Device Boot      Start         End      Blocks   Id  System
/dev/sda1   *          63    19968794     9984366    7  HPFS/NTFS</pre>

The partition should now look identical to when you ran fdisk -l -u /dev/sdb
</p>
<p>
Now we must write the changes to disk.
<pre>Command (m for help): <b>w</b>
The partition table has been altered!

Calling ioctl() to re-read partition table.
Syncing disks.</pre>

</p>

<script type="text/javascript"><!--
google_ad_client = "ca-pub-5974624498841092";
/* disk-copy-mid */
google_ad_slot = "6763367257";
google_ad_width = 728;
google_ad_height = 90;
//-->
</script>
<script type="text/javascript"
src="http://pagead2.googlesyndication.com/pagead/show_ads.js">
</script>

<h3><a name="mbr"></a>Copy the MBR</h3>
<p>
For the new disk to boot, we must copy the boot code from the Master Boot Record (MBR) to the new disk.
</p>
<p>
The MBR is on the first sector of the disk, and is split into three parts:
<ul><li>Boot Code (446 bytes)
<li>Partition Table (64 bytes)
<li>Boot Code Signature = 55aa (2 bytes)
</ul>
We only want to copy the boot code - the first 446 bytes. We do this with dd:
<pre># <b>dd if=/dev/sdb of=/dev/sda bs=446 count=1</b>
1+0 records in
1+0 records out
446 bytes transferred in 0.026312 seconds (16950 bytes/sec)</pre>

</p>
<h3><a name="copy"></a>Copying the Partition</h3>
<p>
Optional: We should try to enable DMA on both disks, to increase the transfer speed.
<pre># <b>hdparm -d 1 /dev/sda</b>
/dev/sda:
 setting using_dma to 1 (on)
 using_dma    =  1 (on)

# <b>hdparm -d 1 /dev/sdb</b>
/dev/sdb:
 setting using_dma to 1 (on)
 using_dma    =  1 (on)</pre>
The next task is to copy the filesystem from one disk to the other.
This time, instead of working with the disk device (sda, sdb), we'll be using the partition device (sda1, sdb1).
</p>
<p>
If this is an NTFS filesystem, you can use <b>ntfsclone</b> to copy it very efficiently.
<pre># <b>ntfsclone --overwrite /dev/sda1 /dev/sdb1</b></pre>
Add the --rescue option if there are bad sectors on the source disk.
<pre># <b>ntfsclone --rescue --overwrite /dev/sda1 /dev/sdb1</b></pre>
</p>
<p>
If it's not NTFS, you can use dd, which will work with any filesystem type.
If your source disk has bad sectors, you should use ddrescue instead of dd.
<pre># <b>dd if=/dev/sdb1 of=/dev/sda1 bs=4096</b>
2496092+0 records in
2496092+0 records out
10223990784 bytes transferred in 355.312 seconds (28774684 bytes/sec)</pre>
This may take a long time, especially if the partition size is large.
You can view the progress at any time by sending SIGUSR1 to the dd process:
<pre># <b>pkill -SIGUSR1 ^dd$</b></pre>
The terminal running dd will output something like:
<pre>1261525+0 records in
1261525+0 records out
5167206400 bytes transferred, 152.312 seconds (33925143 bytes/sec)</pre>

</p>
<h3><a name="resize"></a>Resizing the Partition</h3>
<p>
Next, we resize the partition to fill the disk. You should only do this section if you are copying to a larger disk, and don't want to leave unpartitioned space.
</p>
<p>
By far, the easist way is with qtparted. It is a graphical front-end to parted and ntfsresize. If you are using a Live CD without a GUI, you'll have to use parted or ntfsresize.
</p>
<p>
If Windows was not shut down properly, the partition is dirty and cannot be resized. The resizing tools will tell you if the this is the case. If needed, boot into your new Windows partition and shut down cleanly before continuing.
</p>
<h4>Method 1: qtparted</h4>
This method should work with most filesystems, including NTFS and FAT32.
<ol>
<li>Start qtparted from the command line.
<li>Select the new disk (/dev/sda)
<li>Right click on the partition to rezise, and click Resize.
<li>Change "Free Space After" to 0, and press OK. The partition should now span the disk.
<li>Commit the changes to disk using the the Commit option in the File menu.
</ol>
After the commit operation finishes with your disk, you can reboot onto your new hard drive, and everything should work. Since you resized your partition, be sure to run scandisk (FAT32) or chkdsk (NTFS) to remove any errors in the newly created filesystem.
<pre><b>chkdsk C: /f /r</b></pre>
<h4>Method 2: ntfsresize</h4>
<p>
On the command line, ntfsresize works great for NTFS filesystems. First, delete the old partition and create a new one in its place that matches the new disk size. Deleting a partition does not erase the data that exists there. Just make sure the new partition is at the same start position. Finally, run ntfsresize to grow the filesystem to the size of the partition it's now in. 
</p>
<ol>
<li>
  Use fdisk to recreate the partition to be resized with the new size:
  <pre># <b>fdisk /dev/sda</b>
Command (m for help): <b>u</b>
Changing display/entry units to sectors

Command (m for help): <b>d</b>
Command (m for help): <b>n</b>
Command action
   e   extended
   p   primary partition (1-4)
<b>p</b>

Partition number (1-4): <b>1</b>
First sector (63-159999999, default 63): <b>63</b>
Last sector or +size or +sizeM or +sizeK (63-159999999, default 159999999): <b>159999999</b>
</pre></li>
<li>Resize the partition:<pre># <b>ntfsresize /dev/sda1</b></pre></li>
</ol>
<h4>Method 3: parted</h4>
For any non-NTFS filesystem, you can use parted. In this example, I'll resize a FAT32 partition to fill the drive.
</p>
<p>
Run parted. You may safely ignore errors about the partition alignment.
<pre># <b>parted /dev/sda</b>
GNU Parted 1.6.9
Copyright (C) 1998, 1999, 2000, 2001, 2002, 2003 Free Software Foundation, Inc.
This program is free software, covered by the GNU General Public License.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

Using /dev/sda
Warning: Unable to align partition properly.  This probably means that another
partitioning tool generated an incorrect partition table, because it didn't have
the correct BIOS geometry.  It is safe to ignore, but ignoring may cause
(fixable) problems with some boot loaders.
Ignore/Cancel? <b>i</b></pre>
Display the current partition table (p), and resize the partition to the size of the drive.
<pre>(parted) <b>p</b>
Disk geometry for /dev/sda: 0.000-78125.000 megabytes
Disk label type: msdos
Minor    Start       End     Type      Filesystem  Flags
1          0.031   9750.234  primary   fat32       boot, lba
(parted) <b>resize</b>
Partition number? <b>1</b>
Start?  [0.0308]? <b>0.0308</b>
End?  [9750.2339]? <b>78125.000</b>
(parted)</pre>
This may take some time, depending on the size of the partition. When it's done, you can reboot into windows. Since you modified the partition, be sure to run scandisk to remove any errors in the newly created filesystem.
</p>

<script type="text/javascript"><!--
google_ad_client = "ca-pub-5974624498841092";
/* disk-copy-low */
google_ad_slot = "9716833650";
google_ad_width = 728;
google_ad_height = 90;
//-->
</script>
<script type="text/javascript"
src="http://pagead2.googlesyndication.com/pagead/show_ads.js">
</script>

<h3><a name="contact"></a>Contact</h3>
<p>
I'm always glad to help if I can. Feel free to shoot me an email:
              <script type="text/javascript" language="javascript">
              <!--
              // Email obfuscator script 2.1 by Tim Williams, University of Arizona
              // Random encryption key feature by Andrew Moulden, Site Engineering Ltd
              // This code is freeware provided these four comment lines remain intact
              // A wizard to generate this code is at http://www.jottings.com/obfuscator/
              { coded = "m9tEbh@m9tEbh.XLa"
                key = "UmNzkfIP7v85DL2cTQauZSAwiYxjV1sOXlpyb3eqK90RdGnhJHtg6EF4WBoCMr"
                shift=coded.length
                link=""
                for (i=0; i<coded.length; i++) {
                  if (key.indexOf(coded.charAt(i))==-1) {
                    ltr = coded.charAt(i)
                    link += (ltr)
                  }
                  else {     
                    ltr = (key.indexOf(coded.charAt(i))-shift+key.length) % key.length
                    link += (key.charAt(ltr))
                  }
                }
              document.write(link)
              }
              //-->
              </script><noscript>Sorry, you need Javascript enabled to email me.</noscript>
</p>

    </article>
  </div>

<!-- //////// CUfon Helper For IE ////////  -->
<script>
  Cufon.now();
</script>

<!-- //////// Analytics Code Below ////////  -->
<script type="text/javascript">
var gaJsHost = (("https:" == document.location.protocol) ? "https://ssl." : "http://www.");
document.write(unescape("%3Cscript src='" + gaJsHost + "google-analytics.com/ga.js' type='text/javascript'%3E%3C/script%3E"));
</script>
<script type="text/javascript">
var pageTracker = _gat._getTracker("UA-3340860-1");
pageTracker._initData();
pageTracker._trackPageview();
</script>

</body>
</html>
