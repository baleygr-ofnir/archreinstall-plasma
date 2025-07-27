#!/bin/bash
# lib/partitioning.sh - Disk partitioning and filesystem setup functions
set -e

# Partition setup
setup_partitions() {
  echo "Partitioning disk $DISK..."

  # Set partition variables
  SYSVOL_PART=$(get_partition_name "$DISK" 2)

  wipefs -af "$SYSVOL_PART"
  sgdisk -d 2 "$DISK"
  sgdisk -n 2:0:+"$SYSVOL_SIZE" -t 2:8304 -c 2:"Linux root" "$DISK"

  # Inform kernel of changes
  partprobe "$DISK"
  sleep 5

  echo "Partitions created:"
  echo "  SYSVOL: $SYSVOL_PART"
}

# Create btrfs filesystems
create_filesystems() {
  echo "Creating filesystems..."

  # Create system subvolumes
  mount "$SYSVOL_PART" /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@root
  btrfs subvolume create /mnt/@var
  btrfs subvolume create /mnt/@var/cache
  btrfs subvolume create /mnt/@var/log
  btrfs subvolume create /mnt/@var/tmp
  btrfs subvolume create /mnt/@tmp
  btrfs subvolume create /mnt/@snapshots
  btrfs subvolume create /mnt/@swap
  btrfs subvolume sync /mnt
  sleep 2
  umount /mnt

}

# Mount all filesystems
mount_filesystems() {
  echo "Mounting filesystems..."

  # Mount root subvolume
  mount -t btrfs -o subvol=@,"$BTRFS_OPTS" "$SYSVOL_PART" /mnt

  # Create mount points
  mkdir -p /mnt/{boot,var,var/{cache,log,tmp},tmp,home,opt,root,.snapshots,.swapvol}

  # Mount system subvolumes
  mount -t btrfs -o subvol=@root,"$BTRFS_OPTS" "$SYSVOL_PART" /mnt/root
  mount -t btrfs -o subvol=@var,"$BTRFS_OPTS" "$SYSVOL_PART" /mnt/var
  mount -t btrfs -o subvol=@var/cache,"$BTRFS_OPTS" "$SYSVOL_PART" /mnt/var/cache
  mount -t btrfs -o subvol=@var/log,"$BTRFS_OPTS" "$SYSVOL_PART" /mnt/var/log
  mount -t btrfs -o subvol=@var/tmp,"$BTRFS_OPTS" "$SYSVOL_PART" /mnt/var/tmp
  mount -t btrfs -o subvol=@tmp,"$BTRFS_OPTS" "$SYSVOL_PART" /mnt/tmp
  mount -t btrfs -o subvol=@snapshots,"$BTRFS_OPTS" "$SYSVOL_PART" /mnt/.snapshots
  mount -t btrfs -o subvol=@swap,"$BTRFS_OPTS" "$SYSVOL_PART" /mnt/.swapvol

  USRVOL_PART=$(get_partition_name "$DISK" 3)
 
  # Mount user subvolumes
  cryptsetup --batch-mode open $USRVOL_PART usrvol <<< "$LUKS_PASSWORD"
  mount -t btrfs -o subvol=@home,"$BTRFS_OPTS" /dev/mapper/usrvol /mnt/home
  mount -t btrfs -o subvol=@opt,"$BTRFS_OPTS" /dev/mapper/usrvol /mnt/opt

  EFI_PART=$(get_partition_name "$DISK" 1)

  # Mount EFI partition
  mount "$EFI_PART" /mnt/boot

  echo "Filesystem layout:"
  lsblk
  sleep 2
}
