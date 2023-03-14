# docker-with-limits

Coder template that provisions Docker images with limits for:

- Balanced CPU usage (1024 CPU shares)
- RAM (2 GB max)
- Disk (10GB max for overlayfs, for 10GB max for home volume)

## Requirements

- Sysbox container runtime
- Secondary XFS block storage device mounted on `/var/lib/docker`
- Linux Kernel 5.19+

> See below for instructions to meet these requirements.

## Sysbox container runtime

This template assumes you have the [sysbox container runtime](https://coder.com/docs/v2/latest/templates/docker-in-docker#sysbox-container-runtime) installed.

- Follow this documentation to [install Sysbox as a system package](https://github.com/nestybox/sysbox/blob/master/docs/user-guide/install-package.md)

## Set up XFS volume + quotas

This template will not work unless Docker is configured to work with overlay2/XFs, as Docker's default storage driver is not capable of disk quotas per-container. Keep reading to learn how to use Docker with overlay2/XFS.

> This was tested on an Ubuntu 22.04 virtual machine with a secondary disk attached as `/dev/sdb`. I referenced [this blog post](https://reece.tech/posts/docker-container-size-quota/) from reece.tech.


1. Attach an secondary block disk to your VM, dedicated to Docker volumes. 

1. Format the secondary as an XFS filesystem

    ```sh
    sudo mkfs.xfs /dev/sdb
    ```

1. Modify `/etc/fstab` to mount the disk with support for quotas:

    ```sh
    # /etc/fstab

    # ... other disks

    /dev/sdb /var/lib/docker xfs defaults,quota,prjquota,pquota,gquota 0 0
    ```

1. You may also need to enable uquota,pquota in your GRUB config:

    ```sh
    # /etc/default/grub

    GRUB_CMDLINE_LINUX_DEFAULT="rootflags=uquota,pquota"

1. Stop all containers. If you have existing Docker volumes, back up `/var/lib/docker`

    ```sh
    docker stop $(docker ps -a -q)
    sudo cp -r /var/lib/docker /var/lib/docker.bk
    ```

1. Empty the `/var/lib/docker` folder, for mounting

    ```sh
    sudo rm -r /var/lib/docker
    sudo mkdir -p /var/lib/docker
    ```

1. Install a newer version of the Linux kernel (5.19+)

    ```sh
    uname -r
    # 5.15.0-67-generic


    wget https://raw.githubusercontent.com/pimlie/ubuntu-mainline-kernel.sh/master/ubuntu-mainline-kernel.sh
    sudo install ubuntu-mainline-kernel.sh /usr/local/bin/
    sudo ubuntu-mainline-kernel.sh -c
    sudo ubuntu-mainline-kernel.sh -i
    ```

    > This uses [ubuntu-mainline-kernel](https://github.com/pimlie/ubuntu-mainline-kernel.sh) to safely update.

1. Restart your machine

    ```sh
    sudo reboot
    ```

1. Ensure Docker is using overlay2/xfs:

    ```sh
    mount | grep '/dev/sdb on /var/lib/docker'
    # /dev/sdb on /var/lib/docker type xfs
    # (rw,relatime,attr2,inode64,logbufs=8,logbsize=32k,usrquota,prjquota,grpquota)

    docker info | egrep "Backing Filesystem|Storage Driver"
    # Storage Driver: overlay2
    # Backing Filesystem: xfs
    ```

1. Check your Kernel version

    ```sh
    uname -r
    # Must be 5.19+
    ```

1. Import this template into Coder and create a workspace. Confirm the quota works:

    ```sh
    dd if=/dev/zero of=out bs=4096k
    # dd: error writing 'out': No space left on device
    # 2535+0 records in
    # 2534+0 records out
    # 10628366336 bytes (11 GB, 9.9 GiB) copied, 8.64555 s, 1.2 GB/s
    ```

    > This may be slightly different depending on system. Adjust your quota in the template to compensate

1. Measure all quotas on the host with the following command.

    ```sh
    sudo xfs_quota -x -c 'report -h' /var/lib/docker
    ```