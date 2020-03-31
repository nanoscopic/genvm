#!/usr/bin/perl -w
use strict;
use Data::Dumper;

# brew cask install virtualbox

my $vmName = new_vm_with_unique( 'ios' );
my $mac = vm_get_mac( $vmName );
print "Mac: $mac\n";
run_server();
gen_pxe( $vmName, $mac );
get_pxelinux();
get_ubuntu();

wait_all();

sub get_pxelinux {
    if( ! -e "syslinux.tgz" ) {
        print "Downloading syslinux...\n";
        #`wget wget -O - https://www.kernel.org/pub/linux/utils/boot/syslinux/6.xx/syslinux-6.03.tar.gz`;
        `curl -L -o syslinux.tgz https://www.kernel.org/pub/linux/utils/boot/syslinux/6.xx/syslinux-6.03.tar.gz`;
        print "Done\n";
    }
    my $tftp_folder = $ENV{"HOME"}  . "/Library/Virtualbox/TFTP";
    my $gpxe_file = "$tftp_folder/gpxelinux.0";
    if( ! $gpxe_file ) {
        my @files = split( /\s+/, "syslinux-6.03/utils/pxelinux-options 2
          syslinux-6.03/bios/core/lpxelinux.0 3
          syslinux-6.03/bios/gpxe/gpxelinux.0 3
          syslinux-6.03/bios/com32/menu/menu.c32 4
          syslinux-6.03/bios/com32/menu/vesamenu.c32 4
          syslinux-6.03/bios/com32/libutil/libutil.c32 4
          syslinux-6.03/bios/com32/elflink/ldlinux/ldlinux.c32 5
          syslinux-6.03/bios/com32/chain/chain.c32 4
          syslinux-6.03/bios/com32/lib/libcom32.c32 4" );
          
        while ( @files ) {
            my $file = shift @files;
            my $pathcount = shift @files;
            my $cmd = "tar -xf syslinux.tgz -C $tftp_folder/ --strip=$pathcount $file 2>&1";
            print `tar -xf syslinux.tgz -C $tftp_folder/ --strip=$pathcount $file 2>&1`;
        }
        
        # manually copy $tftp_folder/ldlinux.c32 to web/
        
        # Run pxelinux-options, --after path-prefix http://[ip address]:8001/ lpxelinux.0
    }
}

sub get_ubuntu {
    if( ! -e "ubuntu18.iso" ) {
        #`curl -L -o ubuntu18.iso http://releases.ubuntu.com/18.04.2/ubuntu-18.04.2-server-amd64.iso`;
        `curl -L -o ubuntu18.iso http://cdimage.ubuntu.com/ubuntu/releases/18.04/release/ubuntu-18.04.2-server-amd64.iso`;
        # Do the following manually also:
        # hdiutil attach -nomount ubuntu18.iso
        # mkdir mnt
        # mount_cd9660 /dev/disk2 ./mnt
        
        # cp mnt/install/netboot/ubuntu-installer/amd64/initrd.gz web/boot/ubuntu18/
        # cp mnt/install/netboot/ubuntu-installer/amd64/linux web/boot/ubuntu18/
        # cp web/boot/ubuntu18/linux web/boot/ubuntu18/vmlinuz
        # cp mnt/install/filesysten.squashfs web/boot/ubuntu18/
    }
}

sub run_server {
    my $pid = fork();
    die if not defined $pid;
    if (not $pid) {
       print "Child  - PID $$ ($pid) - starting server\n";
       `./server`;
       exit;
    }
}

sub wait_all {
    my $pid = wait();
    print "Parent saw $pid exiting";
}

sub new_vm_with_unique {
    my ( $baseName ) = @_;
    my $vmName;
    for( 1..20 ) {
        my $tryName = "$baseName-" . base64_str( 5 );
        next if( vm_exists( $tryName ) );
        $vmName = $tryName;
        last;
    }
    die "Could not find unique name for new VM" if( !$vmName );
    
    print `vboxmanage createvm \\
      --name "$vmName" \\
      --ostype "Linux_64" \\
      --register`;
      
    modvm( $vmName, {
        memory => 1500,
        vram => 32,
        cpus => 1,
        boot1 => "net",
        nic1 => "nat",
        nic2 => "hostonly",
        hostonlyadapter2 => "vboxnet0",
        nattftpfile1 => "lpxelinux.0"
    } );
      
    print `vboxmanage createhd \\
      --filename "$vmName.vdi" \\
      --size 16384`;
      
    print `vboxmanage storagectl "$vmName" \\
      --name "SATA Controller" \\
      --add sata \\
      --controller IntelAHCI \\
      --portcount 1`;
      
    print `vboxmanage storageattach "$vmName" \\
      --storagectl "SATA Controller" \\
      --port 0 \\
      --device 0 \\
      --type hdd \\
      --medium "$vmName.vdi"`;
    
    return $vmName;
}

sub modvm {
    my ( $vm, $ops ) = @_;
    my $opstr = "";
    for my $key ( keys %$ops ) {
        my $val = $ops->{ $key };
        $opstr .= " --$key $val";
    }
    print `vboxmanage modifyvm "$vm" $opstr`;
}

sub gen_pxe {
    my ( $vmName, $mac ) = @_;
    my $tftp_folder = $ENV{"HOME"}  . "/Library/Virtualbox/TFTP";
    if( ! -e $tftp_folder ) {
        `sudo mkdir $tftp_folder`;
        my $user = $<;
        my @gps = split( ' ', $) );
        my $gp = $gps[0];
        `sudo chown $user:$gp $tftp_folder`; 
        #mkdir $tftp_folder or die "Could not create $tftp_folder";
    }
    my $pxe_folder = "$tftp_folder/pxelinux.cfg";
    if( ! -e $pxe_folder ) {
        mkdir $pxe_folder;
    }
    my $macDashed = lc( $mac );
    $macDashed =~ s/([a-z0-9]{2})/$1-/g;
    $macDashed =~ s/-$//;
    print "dashed: $macDashed\n";
    my $pxe_file = "web/pxelinux.cfg/01-$macDashed";
    
    my $kernel = "boot/ubuntu18/linux";
    
    my $initrd = "boot/ubuntu18/initrd.gz";
    
    my $ksUrl = "http://10.0.2.2:8001/kickstart/ubuntu18.cfg";
    
    my $psUrl = "http://10.0.2.2:8001/kickstart/ubuntu18.preseed";
    
    my $root = "http://10.0.2.2:8001/boot/ubuntu18/filesystem.squashfs";
    
    my $append = "root=$root initrd=$initrd ks=$ksUrl preseed/url=$psUrl ip=dhcp ksdevice=eth0 net.ifnames=0 ipv6.disable=1 VMNAME=$vmName --- quiet";
    
    open( my $fh, ">$pxe_file" );
    print $fh "DEFAULT scripted
label scripted
menu label Scripted Installation
kernel $kernel
APPEND $append";
    close( $fh );
}

sub vm_exists {
    my $vmName = shift;
    my $vms = vb_list_vms();
    for my $vm ( @$vms ) {
        return $vm->{uuid} if( $vm->{name} eq $vmName );
    }
    return 0;
}

sub vm_get_mac {
    my $vmName = shift;
    my $lines = vb_showvminfo( $vmName );
    for my $line ( @$lines ) {
        if( $line =~ m/macaddress1="(.+)"/ ) {
            return $1;
        }
    }
    return 0;
}

sub vb_list_vms {
    my @lines = `vboxmanage list vms`;
    my @vms;
    for my $line ( @lines ) {
        $line =~ m/^"(.+)" {(.+)}\n$/;
        push( @vms, { name => $1, uuid => $2 } );
    }
    return \@vms;
}

sub vb_showvminfo {
    my $vmName = shift;
    my @lines = `vboxmanage showvminfo "$vmName" --machinereadable`;
    return \@lines;
}


sub random_str {
    my $str;
    for( 1 .. shift ) {
        $str .= @_[ rand @_ ];
    }
    return $str;
}

sub base64_str {
	  return random_str( shift, 'A'..'Z', 'a'..'z', '0'..'9' );
}
