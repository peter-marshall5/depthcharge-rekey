#!/bin/sh

# Generate RSA keys
openssl genrsa -F4 -out root_key.pem 8192
openssl genrsa -F4 -out rec_key.pem 8192
openssl genrsa -F4 -out firmware_key.pem 4096
openssl genrsa -F4 -out kern_key.pem 4096

# Create vb(pubk,privk) keypairs

futility --vb1 create --hash_alg 3 --version 1 root_key.pem

futility --vb1 create --hash_alg 2 --version 2 firmware_key.pem

futility --vb1 create --hash_alg 3 --version 3 kern_key.pem

# Create and sign keyblocks

futility --vb1 vbutil_keyblock --pack firmware_key.keyblock --datapubkey firmware_key.vbpubk --signprivate root_key.vbprivk --flags 7

futility --vb1 vbutil_keyblock --pack kern_key.keyblock --datapubkey kern_key.vbpubk --signprivate firmware_key.vbprivk --flags 7

# Create a new vblock with the new keys

futility --vb1 vbutil_firmware --vblock vb-new.a --keyblock firmware_key.keyblock --signprivate firmware_key.vbprivk --version 3 --fv fw-trimmed.a --kernelkey kern_key.vbpubk

# Replace master and recovery keys and set GBB flags

futility gbb -s -o bios_mod.bin -k root_key.vbpubk -r rec_key.vbpubk --flags 0 bios_orig.bin

# Replace rw firmware vblocks

futility load_fmap bios_mod.bin VBLOCK_A:vb-new.a VBLOCK_B:vb-new.a

# Dump stock rw firmware parts
#futility dump_fmap bios_orig.bin -x VBLOCK_A:vb.a VBLOCK_B:vb.b FW_MAIN_A:fw.a FW_MAIN_B:fw.b

# Verify stock rw firmware
# futility vbutil_firmware --verify vb.a --signpubkey rk.bin --fv fw.a

# Trim the rw firmware to its actual size (not necessary here)
# dd if=fw.a of=fw-trimmed.a bs=1 count=156220

# For recovery USB
#futility vbutil_kernel --repack /dev/sda2 --keyblock rec_key.keyblock --signprivate rec_key.vbprivk --oldblob /dev/sda2

# For Linux install
#futility vbutil_kernel --repack /dev/mmcblk0p4 --keyblock kern_key.keyblock --signprivate kern_key.vbprivk --oldblob /boot/5.19.kpart

# Using 100000khz spi speed dramatically speeds up flashing
#flashrom -p linux_spi:dev=/dev/spidev2.0,spispeed=100000khz -w bios_mod.bin
