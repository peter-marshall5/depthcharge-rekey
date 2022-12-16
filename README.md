# Re-key guide and script for Depthcharge firmware on Chromebooks

This is a guide on how to replace the verified boot keys in your Chromebook's firmware.

# DISCLAIMER

I do not take ANY responsibility for potential damage to your device.

This guide is intended for people who are at least somewhat familiar with the Linux terminal and the Chrome OS verified boot system.

I can't guarantee that this will work for you. Ideally you shoud have an external programmer ready in case your chromebook gets bricked.

# Why would you want to do this?

Most sources say that you have to keep developer mode enabled to run a custom OS on Chromebooks with the stock firmware, since by default it will refuse to boot anything that isn't signed by Google.
However, it's possible to replace Google's built in verified boot keys with your own and run a custom OS in verified mode.

Doing so has numerous advantages:

- Gets rid of the developer mode warning for good.
- Protects your device from rootkits and some "evil maid" attacks.
- You can prevent Chrome OS from booting if you don't trust Google.
- Prevents someone from recovering your chromebook if it's stolen. (*)

On the other hand, it also has some disadvantages:

- Prevents Chrome OS from booting unless you re-sign it manually.
- Verified mode doesn't let you boot a legacy payload (SeaBIOS).
- Your chromebook is bricked if you can't boot and lose the signing keys. (*)

(*): Can be fixed / circumvented with an external programmer

In my case I'm using an ARM chromebook that doesn't have UEFI firmware available.
Besides, the UEFI firmware by mrchromebox doesn't support secure boot (yet) which can be bad for security.

# The Guide

First of all, you will need to dump the existing firmware from your chromebook.

After that, generate the new RSA keys:

```shell
openssl genrsa -F4 -out root_key.pem 8192
openssl genrsa -F4 -out rec_key.pem 8192
openssl genrsa -F4 -out firmware_key.pem 4096
openssl genrsa -F4 -out kern_key.pem 4096
```

Convert the keys into a format compaible with the vboot utilities:

```shell
futility --vb1 create --hash_alg 3 --version 1 root_key.pem
futility --vb1 create --hash_alg 2 --version 2 firmware_key.pem
futility --vb1 create --hash_alg 3 --version 3 kern_key.pem
```

Create and sign new keyblocks:

```shell
futility --vb1 vbutil_keyblock --pack firmware_key.keyblock --datapubkey firmware_key.vbpubk --signprivate root_key.vbprivk --flags 7
futility --vb1 vbutil_keyblock --pack kern_key.keyblock --datapubkey kern_key.vbpubk --signprivate firmware_key.vbprivk --flags 7
```

Dump the firmware parts for signing:

```shell
futility dump_fmap bios_orig.bin -x VBLOCK_A:vb.a VBLOCK_B:vb.b FW_MAIN_A:fw.a FW_MAIN_B:fw.b
```

Create new signed vblocks to verify the rw firmware:

```shell
futility --vb1 vbutil_firmware --vblock vb-new.a --keyblock firmware_key.keyblock --signprivate firmware_key.vbprivk --version 3 --fv fw.a --kernelkey kern_key.vbpubk
futility --vb1 vbutil_firmware --vblock vb-new.b --keyblock firmware_key.keyblock --signprivate firmware_key.vbprivk --version 3 --fv fw.b --kernelkey kern_key.vbpubk
```

Replace the master and recovery keys in the stock firmware with the ones we created:

```shell
futility gbb -s -o bios_mod.bin -k root_key.vbpubk -r rec_key.vbpubk --flags 0 bios_orig.bin
```

Replace the vblocks in the stock firmware with the newly signed ones:

```shell
futility load_fmap bios_mod.bin VBLOCK_A:vb-new.a VBLOCK_B:vb-new.b
```

MAKE SURE to backup all the vbpubk, vbprivk, and keyblock files!

Use kern_key.* to sign the kernel and write it to the kernel partition.

Finally, write the modified `bios_mod.bin` to the internal flash and reboot.
