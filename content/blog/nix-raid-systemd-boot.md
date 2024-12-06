+++
title = "Workaround md raid boot issue in NixOS 22.11"
date = 2023-01-10
[taxonomies]
tags = ["nix"]
+++

For about a year now I've been running [NixOS](https://nixos.org/ "NixOS") on my personal machines. Yesterday I decided to go ahead and upgrade my NAS from NixOS 22.05 to [22.11](https://nixos.org/blog/announcements.html#nixos-22.11). On that machine, all the disks are encrypted, and there are two RAID0 devices. To unlock the drives, I log into the [SSH daemon running in `initrd`](https://nixos.wiki/wiki/Remote_LUKS_Unlocking), where I can type my passphrase. This time however, instead of a prompt to unlock the disk, I see the following message:

```
waiting for device /dev/disk/by-uuid/66c58a92-45fe-4b03-9be0-214ff67c177c to appear...
```

followed by a timeout and then I'm asked if I want to reboot the machine. I do reboot the machine, and same thing happens.

Now, and this is something really great about NixOS, I can boot to the previous generation (on 22.05), and this time I'm prompted for my password, the disks are unlocked, and I can log into my machine. This eliminates the possibility of a hardware failure! I also have a way to get a working machine to do more build if needed. Knowing that I can easily switch from a broken generation to a working one gives me more confidence in making changes to my system.

I then reboot again in the broken build, and drop into a `busybox` shell. I look to see what `blkid` reports, and I confirm that my disks are all present and they have a **UUID** set. Next I check what's listed under `/dev/disk/by-uuid` and, surprise, the disks are not there. They are however under `/dev/disk`. Now, looking at `/nix/store` I only see a few things, and one of them is a script named `stage-1-init.sh`. I read quickly the script, checked it does, and confirmed that it was blocking on the disks. I looked at what was reported by `udevadm info </path/to/disk>` and I could see that the `DEVLINKS` was missing the path for `by-uuid`.

My laptop has a similar setup, but without RAID devices. I had already updated to 22.11, and had rebooted the laptop without issues. To be sure, I ran another update and rebooted, and I was able to unlock the drive and log into the machine without problem.

From here I have enough information to start searching for an issue similar to this. I got pretty lucky and two issues I found were:

- [Since systemd-251.3 mdadm doesn't start at boot time #196800 ](https://github.com/nixoS/nixpkgs/issues/196800)
- [Won't boot when root on raid0 with boot.initrd.systemd=true #199551 ](https://github.com/nixoS/nixpkgs/issues/199551)

The proposed solution was easy:

```diff
@@ -43,7 +43,7 @@
   };

   boot.initrd.luks.devices."raid-fast".device =
-    "/dev/disk/by-uuid/66c58a92-45fe-4b03-9be0-214ff67c177c";
+    "/dev/disk/by-id/md-name-nixos:fast";

   fileSystems."/data/slow" = {
     device = "/dev/disk/by-uuid/0f16db51-0ee7-48d8-9e48-653b85ecbf0a";
@@ -51,7 +51,7 @@
   };

   boot.initrd.luks.devices."raid-slow".device =
-    "/dev/disk/by-uuid/d8b21267-d457-4522-91d9-5481b44dd0a5";
+    "/dev/disk/by-id/md-name-nixos:slow";
```

I rebuild, rebooted, and success, I was able to get access to the machine.

## Takeaways

I now have a mitigation to the problem, however I still don't have a root cause. Since it's only the `by-uuid` path that is missing, and this is managed by `udev`, I'm guessing that some rules for `udev` have changed, but so far I can't find anything about that.

It's really great to be able to easily switch back to a previous generation of my system, so I can debug and experiment different solutions. If this had happen with another distribution, getting out of this mess would have been more tedious.
