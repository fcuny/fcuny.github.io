---
title: containerd to firecracker
date: 2021-05-15
template: note.html
---

fly.io had an [interesting
article](https://fly.io/blog/docker-without-docker/) about how they use
docker images to create VMs for `firecracker`.

They describe the process as follow:

1.  Pull a container from a registry
2.  Create a loop device to store the container's filesystem on
3.  Unpack the container into the mounted loop device
4.  Create a second block device and inject init, kernel, configuration
    and other stuff
5.  Attach persistent volumes (if any)
6.  Create a TAP device and configure it
7.  Hand it off to Firecracker and boot that thing

That's pretty detailed, and I'm curious how difficult it is to implement
this. I've been meaning to look into Firecracker for a while and into
containers'd API, so this is a perfect opportunity to get started. The
code is available [here](https://git.fcuny.net/containerd-to-vm/).

## #1 Pull a container from a registry with `containerd`

`containerd` has a pretty [detailed
documentation](https://pkg.go.dev/github.com/containerd/containerd).
From the main page we can see the following example to create a client.

```go
import (
  "github.com/containerd/containerd"
  "github.com/containerd/containerd/cio"
)


func main() {
    client, err := containerd.New("/run/containerd/containerd.sock")
    defer client.Close()
}
```

And pulling an image is also pretty straightforward:

```go
image, err := client.Pull(context, "docker.io/library/redis:latest")
```

The `Pull` method returns an
[`Image`](https://pkg.go.dev/github.com/containerd/containerd@v1.4.4/images#Image)
and there's a few methods associated with it.

As `containerd` has namespaces, it's possible to specify the namespace
we want to use when working with the API:

```go
ctx := namespaces.WithNamespace(context.Background(), "c2vm")
image, err := client.Pull(ctx, "docker.io/library/redis:latest")
```

The image will now be stored in the `c2vm` namespace. We can verify this
with:

```bash
; sudo ctr -n c2vm images ls -q
docker.io/library/redis:latest
```

## #2 Create a loop device to store the container's filesystem on

This is going to be pretty straightforward. To create a loop device we
need to:

1.  pre-allocate space to a file
2.  convert that file to some format
3.  mount it to some destination

There's two commons ways to pre-allocate space to a file: `dd` and
`fallocate` (there's likely way more ways to do this). I'll go with
`fallocate` for this example.

First, to be safe, we create a temporary file, and use `renameio` to
handle the renaming (I recommend reading the doc of the module).

```go
f, err := renameio.TempFile("", rawFile)
if err != nil {
    return err
}
defer f.Cleanup()
```

Now to do the pre-allocation (we're making an assumption here that 2GB
is enough, we can likely check what's the size of the container before
doing this):

```go
command := exec.Command("fallocate", "-l", "2G", f.Name())
if err := command.Run(); err != nil {
    return fmt.Errorf("fallocate error: %s", err)
}
```

We can now convert that file to ext4:

```go
command = exec.Command("mkfs.ext4", "-F", f.Name())
if err := command.Run(); err != nil {
    return fmt.Errorf("mkfs.ext4 error: %s", err)
}
```

Now we can rename safely the temporary file to the proper file we want:

```go
f.CloseAtomicallyReplace()
```

And to mount that file

```go
command = exec.Command("mount", "-o", "loop", rawFile, mntDir)
if err := command.Run(); err != nil {
    return fmt.Errorf("mount error: %s", err)
}
```

## #3 Unpack the container into the mounted loop device

Extracting the container using `containerd` is pretty simple. Here's the
function that I use:

```go
func extract(ctx context.Context, client *containerd.Client, image containerd.Image, mntDir string) error {
    manifest, err := images.Manifest(ctx, client.ContentStore(), image.Target(), platform)
    if err != nil {
        log.Fatalf("failed to get the manifest: %v\n", err)
    }

    for _, desc := range manifest.Layers {
        log.Printf("extracting layer %s\n", desc.Digest.String())
        layer, err := client.ContentStore().ReaderAt(ctx, desc)
        if err != nil {
            return err
        }
        if err := archive.Untar(content.NewReader(layer), mntDir, &archive.TarOptions{NoLchown: true}); err != nil {
            return err
        }
    }

    return nil
}
```

Calling `images.Manifest` returns the
[manifest](https://github.com/opencontainers/image-spec/blob/master/manifest.md)
from the image. What we care here are the list of layers. Here I'm
making a number of assumptions regarding their type (we should be
checking the media type first). We read the layers and extract them to
the mounted path.

## #4 Create a second block device and inject other stuff

Here I'm going to deviate a bit. I will not create a second loop device,
and I will not inject a kernel. In their article, they provided a link
to a snapshot of their `init` process
(<https://github.com/superfly/init-snapshot>). In order to keep this
simple, our init is going to be a shell script composed of the content
of the entry point of the container. We're also going to add a few extra
files to container (`/etc/hosts` and `/etc/resolv.conf`).

Finally, since we've pre-allocated 2GB for that container, and we likely
don't need that much, we're also going to resize the image.

### Add init

Let's refer to the [specification for the
config](https://github.com/opencontainers/image-spec/blob/master/config.md).
The elements that are of interest to me are:

- `Env`, which is array of strings. They contain the environment
  variables that likely we need to run the program
- `Cmd`, which is also an array of strings. If there's no entry point
  provided, this is what is used.

At this point, for this experiment, I'm going to ignore exposed ports,
working directory, and the user.

First we need to read the config from the container. This is easily
done:

```go
config, err := images.Config(ctx, client.ContentStore(), image.Target(), platform)
if err != nil {
    return err
}
```

This needs to be read and decoded:

```go
configBlob, err := content.ReadBlob(ctx, client.ContentStore(), config)
var imageSpec ocispec.Image
json.Unmarshal(configBlob, &imageSpec)
```

`init` is the first process started by Linux during boot. On a regular
Linux desktop you likely have a symbolic link from `/usr/bin/init` to
`/usr/lib/systemd/systemd`, since most distributions have switched to
`systemd`. For my use case however, I want to run a single process, and
I want it to be the one from the container. For this we can create a
simple shell script inside the container (the location does not matter
for now) with the environment variables and the command.

Naively, this can be done like this:

```go
initPath := filepath.Join(mntDir, "init.sh")
f, err := renameio.TempFile("", initPath)
if err != nil {
    return err
}
defer f.Cleanup()

writer := bufio.NewWriter(f)
fmt.Fprintf(writer, "#!/bin/sh\n")
for _, env := range initEnvs {
    fmt.Fprintf(writer, "export %s\n", env)
}
fmt.Fprintf(writer, "%s\n", initCmd)
writer.Flush()

f.CloseAtomicallyReplace()

mode := int(0755)
os.Chmod(initPath, os.FileMode(mode))
```

We're once again creating a temporary file with `renamio`, and we're
writing our shell scripts, one line at a time. We only need to make sure
this executable.

### extra files

Once we have our init file, I also want to add a few extra files:
`/etc/hosts` and `/etc/resolv.conf`. This files are not always present,
since they can be injected by other systems. I also want to make sure
that DNS resolutions are done using my own DNS server.

### resize the image

We've pre-allocated 2GB for the image, and it's likely we don't need as
much space. We can do this by running `e2fsck` and `resize2fs` once
we're done manipulating the image.

Within a function, we can do the following:

```go
command := exec.Command("/usr/bin/e2fsck", "-p", "-f", rawFile)
if err := command.Run(); err != nil {
    return fmt.Errorf("e2fsck error: %s", err)
}

command = exec.Command("resize2fs", "-M", rawFile)
if err := command.Run(); err != nil {
    return fmt.Errorf("resize2fs error: %s", err)
}
```

I'm using `docker.io/library/redis:latest` for my test, and I end up
with the following size for the image:

```bash
-rw------- 1 root root 216M Apr 22 14:50 /tmp/fcuny.img
```

### Kernel

We're going to need a kernel to run that VM. In my case I've decided to
go with version 5.8, and build a custom kernel. If you are not familiar
with the process, the firecracker team has [documented how to do
this](https://github.com/firecracker-microvm/firecracker/blob/main/docs/rootfs-and-kernel-setup.md#creating-a-kernel-image).
In my case all I had to do was:

```bash
git clone https://github.com/torvalds/linux.git linux.git
cd linux.git
git checkout v5.8
curl -o .config -s https://github.com/firecracker-microvm/firecracker/blob/main/resources/microvm-kernel-x86_64.config
make menuconfig
make vmlinux -j8
```

Note that they also have a pretty [good documentation for
production](https://github.com/firecracker-microvm/firecracker/blob/main/docs/prod-host-setup.md).

## #5 Attach persistent volumes (if any)

I'm going to skip that step for now.

## #6 Create a TAP device and configure it

We're going to need a network for that VM (otherwise it might be a bit
boring). There's a few solutions that we can take:

1.  create the TAP device
2.  delegate all that work to a
    [CNI](https://github.com/containernetworking/cni)

I've decided to use the CNI approach [documented in the Go's
SDK](https://github.com/firecracker-microvm/firecracker-go-sdk#cni). For
this to work we need to install the `tc-redirect-tap` CNI plugin
(available at <https://github.com/awslabs/tc-redirect-tap>).

Based on that documentation, I'll start with the following configuration
in `etc/cni/conf.d/50-c2vm.conflist`:

```json
{
  "name": "c2vm",
  "cniVersion": "0.4.0",
  "plugins": [
    {
      "type": "bridge",
      "bridge": "c2vm-br",
      "isDefaultGateway": true,
      "forceAddress": false,
      "ipMasq": true,
      "hairpinMode": true,
      "mtu": 1500,
      "ipam": {
        "type": "host-local",
        "subnet": "192.168.128.0/24",
        "resolvConf": "/etc/resolv.conf"
      }
    },
    {
      "type": "firewall"
    },
    {
      "type": "tc-redirect-tap"
    }
  ]
}
```

## #7 Hand it off to Firecracker and boot that thing

Now that we have all the components, we need to boot that VM. Since I've
been working with Go so far, I'll also use the [Go
SDK](https://github.com/firecracker-microvm/firecracker-go-sdk) to
manage and start the VM.

For this we need the firecracker binary, which we can [find on
GitHub](https://github.com/firecracker-microvm/firecracker/releases).

The first thing is to configure the list of devices. In our case we will
have a single device, the boot drive that we've created in the previous
step.

```go
devices := make([]models.Drive, 1)
devices[0] = models.Drive{
    DriveID:      firecracker.String("1"),
    PathOnHost:   &rawImage,
    IsRootDevice: firecracker.Bool(true),
    IsReadOnly:   firecracker.Bool(false),
}
```

The next step is to configure the VM:

```go
fcCfg := firecracker.Config{
    LogLevel:        "debug",
    SocketPath:      firecrackerSock,
    KernelImagePath: linuxKernel,
    KernelArgs:      "console=ttyS0 reboot=k panic=1 acpi=off pci=off i8042.noaux i8042.nomux i8042.nopnp i8042.dumbkbd init=/init.sh random.trust_cpu=on",
    Drives:          devices,
    MachineCfg: models.MachineConfiguration{
        VcpuCount:   firecracker.Int64(1),
        CPUTemplate: models.CPUTemplate("C3"),
        HtEnabled:   firecracker.Bool(true),
        MemSizeMib:  firecracker.Int64(512),
    },
    NetworkInterfaces: []firecracker.NetworkInterface{
        {
            CNIConfiguration: &firecracker.CNIConfiguration{
                NetworkName: "c2vm",
                IfName:      "eth0",
            },
        },
    },
}
```

Finally we can create the command to start and run the VM:

```go
command := firecracker.VMCommandBuilder{}.
    WithBin(firecrackerBinary).
    WithSocketPath(fcCfg.SocketPath).
    WithStdin(os.Stdin).
    WithStdout(os.Stdout).
    WithStderr(os.Stderr).
    Build(ctx)
machineOpts = append(machineOpts, firecracker.WithProcessRunner(command))
m, err := firecracker.NewMachine(vmmCtx, fcCfg, machineOpts...)
if err != nil {
    panic(err)
}

if err := m.Start(vmmCtx); err != nil {
    panic(err)
}
defer m.StopVMM()

if err := m.Wait(vmmCtx); err != nil {
    panic(err)
}
```

The end result:

    ; sudo ./c2vm -container docker.io/library/redis:latest -firecracker-binary ./hack/firecracker/firecracker-v0.24.3-x86_64 -linux-kernel ./hack/linux/my-linux.bin -out /tmp/redis.img
    2021/05/15 14:12:59 pulled docker.io/library/redis:latest (38690247 bytes)
    2021/05/15 14:13:00 mounted /tmp/redis.img on /tmp/c2vm026771514
    2021/05/15 14:13:00 extracting layer sha256:69692152171afee1fd341febc390747cfca2ff302f2881d8b394e786af605696
    2021/05/15 14:13:00 extracting layer sha256:a4a46f2fd7e06fab84b4e78eb2d1b6d007351017f9b18dbeeef1a9e7cf194e00
    2021/05/15 14:13:00 extracting layer sha256:bcdf6fddc3bdaab696860eb0f4846895c53a3192c9d7bf8d2275770ea8073532
    2021/05/15 14:13:01 extracting layer sha256:b7e9b50900cc06838c44e0fc5cbebe5c0b3e7f70c02f32dd754e1aa6326ed566
    2021/05/15 14:13:01 extracting layer sha256:5f3030c50d85a9d2f70adb610b19b63290c6227c825639b227ddc586f86d1c76
    2021/05/15 14:13:01 extracting layer sha256:63dae8e0776cdbd63909fbd9c047c1615a01cb21b73efa87ae2feed680d3ffa1
    2021/05/15 14:13:01 init script created
    2021/05/15 14:13:01 umount /tmp/c2vm026771514
    INFO[0003] Called startVMM(), setting up a VMM on firecracker.sock
    INFO[0003] VMM logging disabled.
    INFO[0003] VMM metrics disabled.
    INFO[0003] refreshMachineConfiguration: [GET /machine-config][200] getMachineConfigurationOK  &{CPUTemplate:C3 HtEnabled:0xc0004e6753 MemSizeMib:0xc0004e6748 VcpuCount:0xc0004e6740}
    INFO[0003] PutGuestBootSource: [PUT /boot-source][204] putGuestBootSourceNoContent
    INFO[0003] Attaching drive /tmp/redis.img, slot 1, root true.
    INFO[0003] Attached drive /tmp/redis.img: [PUT /drives/{drive_id}][204] putGuestDriveByIdNoContent
    INFO[0003] Attaching NIC tap0 (hwaddr 9e:72:c7:04:6b:80) at index 1
    INFO[0003] startInstance successful: [PUT /actions][204] createSyncActionNoContent
    [    0.000000] Linux version 5.8.0 (fcuny@nas) (gcc (Debian 8.3.0-6) 8.3.0, GNU ld (GNU Binutils for Debian) 2.31.1) #1 SMP Mon Apr 12 20:07:40 PDT 2021
    [    0.000000] Command line: i8042.dumbkbd ip=192.168.128.9::192.168.128.1:255.255.255.0:::off::: console=ttyS0 reboot=k panic=1 acpi=off pci=off i8042.noaux i8042.nomux i8042.nopnp init=/init.sh random.trust_cpu=on root=/dev/vda rw virtio_mmio.device=4K@0xd0000000:5 virtio_mmio.device=4K@0xd0001000:6
    [    0.000000] x86/fpu: Supporting XSAVE feature 0x001: 'x87 floating point registers'
    [    0.000000] x86/fpu: Supporting XSAVE feature 0x002: 'SSE registers'
    [    0.000000] x86/fpu: Supporting XSAVE feature 0x004: 'AVX registers'
    [    0.000000] x86/fpu: xstate_offset[2]:  576, xstate_sizes[2]:  256
    [    0.000000] x86/fpu: Enabled xstate features 0x7, context size is 832 bytes, using 'standard' format.
    [    0.000000] BIOS-provided physical RAM map:
    [    0.000000] BIOS-e820: [mem 0x0000000000000000-0x000000000009fbff] usable
    [    0.000000] BIOS-e820: [mem 0x0000000000100000-0x000000001fffffff] usable
    [    0.000000] NX (Execute Disable) protection: active
    [    0.000000] DMI not present or invalid.
    [    0.000000] Hypervisor detected: KVM
    [    0.000000] kvm-clock: Using msrs 4b564d01 and 4b564d00
    [    0.000000] kvm-clock: cpu 0, msr 2401001, primary cpu clock
    [    0.000000] kvm-clock: using sched offset of 11918596 cycles
    [    0.000005] clocksource: kvm-clock: mask: 0xffffffffffffffff max_cycles: 0x1cd42e4dffb, max_idle_ns: 881590591483 ns
    [    0.000011] tsc: Detected 1190.400 MHz processor
    [    0.000108] last_pfn = 0x20000 max_arch_pfn = 0x400000000
    [    0.000151] Disabled
    [    0.000156] x86/PAT: MTRRs disabled, skipping PAT initialization too.
    [    0.000166] CPU MTRRs all blank - virtualized system.
    [    0.000170] x86/PAT: Configuration [0-7]: WB  WT  UC- UC  WB  WT  UC- UC
    [    0.000201] found SMP MP-table at [mem 0x0009fc00-0x0009fc0f]
    [    0.000257] check: Scanning 1 areas for low memory corruption
    [    0.000364] No NUMA configuration found
    [    0.000365] Faking a node at [mem 0x0000000000000000-0x000000001fffffff]
    [    0.000370] NODE_DATA(0) allocated [mem 0x1ffde000-0x1fffffff]
    [    0.000490] Zone ranges:
    [    0.000493]   DMA      [mem 0x0000000000001000-0x0000000000ffffff]
    [    0.000494]   DMA32    [mem 0x0000000001000000-0x000000001fffffff]
    [    0.000495]   Normal   empty
    [    0.000497] Movable zone start for each node
    [    0.000500] Early memory node ranges
    [    0.000501]   node   0: [mem 0x0000000000001000-0x000000000009efff]
    [    0.000502]   node   0: [mem 0x0000000000100000-0x000000001fffffff]
    [    0.000510] Zeroed struct page in unavailable ranges: 98 pages
    [    0.000511] Initmem setup node 0 [mem 0x0000000000001000-0x000000001fffffff]
    [    0.004990] Intel MultiProcessor Specification v1.4
    [    0.004995] MPTABLE: OEM ID: FC
    [    0.004995] MPTABLE: Product ID: 000000000000
    [    0.004996] MPTABLE: APIC at: 0xFEE00000
    [    0.005007] Processor #0 (Bootup-CPU)
    [    0.005039] IOAPIC[0]: apic_id 2, version 17, address 0xfec00000, GSI 0-23
    [    0.005041] Processors: 1
    [    0.005042] TSC deadline timer available
    [    0.005044] smpboot: Allowing 1 CPUs, 0 hotplug CPUs
    [    0.005060] KVM setup pv remote TLB flush
    [    0.005072] KVM setup pv sched yield
    [    0.005078] PM: hibernation: Registered nosave memory: [mem 0x00000000-0x00000fff]
    [    0.005079] PM: hibernation: Registered nosave memory: [mem 0x0009f000-0x000fffff]
    [    0.005081] [mem 0x20000000-0xffffffff] available for PCI devices
    [    0.005082] Booting paravirtualized kernel on KVM
    [    0.005084] clocksource: refined-jiffies: mask: 0xffffffff max_cycles: 0xffffffff, max_idle_ns: 7645519600211568 ns
    [    0.005087] setup_percpu: NR_CPUS:128 nr_cpumask_bits:128 nr_cpu_ids:1 nr_node_ids:1
    [    0.006381] percpu: Embedded 44 pages/cpu s143360 r8192 d28672 u2097152
    [    0.006404] KVM setup async PF for cpu 0
    [    0.006410] kvm-stealtime: cpu 0, msr 1f422080
    [    0.006420] Built 1 zonelists, mobility grouping on.  Total pages: 128905
    [    0.006420] Policy zone: DMA32
    [    0.006422] Kernel command line: i8042.dumbkbd ip=192.168.128.9::192.168.128.1:255.255.255.0:::off::: console=ttyS0 reboot=k panic=1 acpi=off pci=off i8042.noaux i8042.nomux i8042.nopnp init=/init.sh random.trust_cpu=on root=/dev/vda rw virtio_mmio.device=4K@0xd0000000:5 virtio_mmio.device=4K@0xd0001000:6
    [    0.006858] Dentry cache hash table entries: 65536 (order: 7, 524288 bytes, linear)
    [    0.007003] Inode-cache hash table entries: 32768 (order: 6, 262144 bytes, linear)
    [    0.007047] mem auto-init: stack:off, heap alloc:off, heap free:off
    [    0.007947] Memory: 491940K/523896K available (10243K kernel code, 629K rwdata, 1860K rodata, 1408K init, 6048K bss, 31956K reserved, 0K cma-reserved)
    [    0.007980] random: get_random_u64 called from __kmem_cache_create+0x3d/0x540 with crng_init=0
    [    0.008053] SLUB: HWalign=64, Order=0-3, MinObjects=0, CPUs=1, Nodes=1
    [    0.008146] rcu: Hierarchical RCU implementation.
    [    0.008147] rcu:     RCU restricting CPUs from NR_CPUS=128 to nr_cpu_ids=1.
    [    0.008151] rcu: RCU calculated value of scheduler-enlistment delay is 25 jiffies.
    [    0.008152] rcu: Adjusting geometry for rcu_fanout_leaf=16, nr_cpu_ids=1
    [    0.008170] NR_IRQS: 4352, nr_irqs: 48, preallocated irqs: 16
    [    0.008373] random: crng done (trusting CPU's manufacturer)
    [    0.008430] Console: colour dummy device 80x25
    [    0.052276] printk: console [ttyS0] enabled
    [    0.052685] APIC: Switch to symmetric I/O mode setup
    [    0.053288] x2apic enabled
    [    0.053705] Switched APIC routing to physical x2apic.
    [    0.054213] KVM setup pv IPIs
    [    0.055559] clocksource: tsc-early: mask: 0xffffffffffffffff max_cycles: 0x1128af0325d, max_idle_ns: 440795261011 ns
    [    0.056516] Calibrating delay loop (skipped) preset value.. 2380.80 BogoMIPS (lpj=4761600)
    [    0.057259] pid_max: default: 32768 minimum: 301
    [    0.057726] LSM: Security Framework initializing
    [    0.058176] SELinux:  Initializing.
    [    0.058556] Mount-cache hash table entries: 1024 (order: 1, 8192 bytes, linear)
    [    0.059221] Mountpoint-cache hash table entries: 1024 (order: 1, 8192 bytes, linear)
    [    0.060382] x86/cpu: User Mode Instruction Prevention (UMIP) activated
    [    0.060510] Last level iTLB entries: 4KB 0, 2MB 0, 4MB 0
    [    0.060510] Last level dTLB entries: 4KB 0, 2MB 0, 4MB 0, 1GB 0
    [    0.060510] Spectre V1 : Mitigation: usercopy/swapgs barriers and __user pointer sanitization
    [    0.060510] Spectre V2 : Mitigation: Enhanced IBRS
    [    0.060510] Spectre V2 : Spectre v2 / SpectreRSB mitigation: Filling RSB on context switch
    [    0.060510] Spectre V2 : mitigation: Enabling conditional Indirect Branch Prediction Barrier
    [    0.060510] Speculative Store Bypass: Mitigation: Speculative Store Bypass disabled via prctl and seccomp
    [    0.060510] Freeing SMP alternatives memory: 32K
    [    0.060510] smpboot: CPU0: Intel(R) Xeon(R) Processor @ 1.20GHz (family: 0x6, model: 0x3e, stepping: 0x4)
    [    0.060510] Performance Events: unsupported p6 CPU model 62 no PMU driver, software events only.
    [    0.060510] rcu: Hierarchical SRCU implementation.
    [    0.060510] smp: Bringing up secondary CPUs ...
    [    0.060510] smp: Brought up 1 node, 1 CPU
    [    0.060510] smpboot: Max logical packages: 1
    [    0.060523] smpboot: Total of 1 processors activated (2380.80 BogoMIPS)
    [    0.061338] devtmpfs: initialized
    [    0.061710] x86/mm: Memory block size: 128MB
    [    0.062341] clocksource: jiffies: mask: 0xffffffff max_cycles: 0xffffffff, max_idle_ns: 7645041785100000 ns
    [    0.063245] futex hash table entries: 256 (order: 2, 16384 bytes, linear)
    [    0.063946] thermal_sys: Registered thermal governor 'fair_share'
    [    0.063946] thermal_sys: Registered thermal governor 'step_wise'
    [    0.064522] thermal_sys: Registered thermal governor 'user_space'
    [    0.065313] NET: Registered protocol family 16
    [    0.066398] DMA: preallocated 128 KiB GFP_KERNEL pool for atomic allocations
    [    0.067057] DMA: preallocated 128 KiB GFP_KERNEL|GFP_DMA pool for atomic allocations
    [    0.067778] DMA: preallocated 128 KiB GFP_KERNEL|GFP_DMA32 pool for atomic allocations
    [    0.068506] audit: initializing netlink subsys (disabled)
    [    0.068708] cpuidle: using governor ladder
    [    0.069097] cpuidle: using governor menu
    [    0.070636] audit: type=2000 audit(1621113181.800:1): state=initialized audit_enabled=0 res=1
    [    0.076346] HugeTLB registered 2.00 MiB page size, pre-allocated 0 pages
    [    0.077007] ACPI: Interpreter disabled.
    [    0.077445] SCSI subsystem initialized
    [    0.077812] pps_core: LinuxPPS API ver. 1 registered
    [    0.078277] pps_core: Software ver. 5.3.6 - Copyright 2005-2007 Rodolfo Giometti <giometti@linux.it>
    [    0.079206] PTP clock support registered
    [    0.079741] NetLabel: Initializing
    [    0.080111] NetLabel:  domain hash size = 128
    [    0.080529] NetLabel:  protocols = UNLABELED CIPSOv4 CALIPSO
    [    0.081113] NetLabel:  unlabeled traffic allowed by default
    [    0.082072] clocksource: Switched to clocksource kvm-clock
    [    0.082715] VFS: Disk quotas dquot_6.6.0
    [    0.083123] VFS: Dquot-cache hash table entries: 512 (order 0, 4096 bytes)
    [    0.083855] pnp: PnP ACPI: disabled
    [    0.084510] NET: Registered protocol family 2
    [    0.084718] tcp_listen_portaddr_hash hash table entries: 256 (order: 0, 4096 bytes, linear)
    [    0.085602] TCP established hash table entries: 4096 (order: 3, 32768 bytes, linear)
    [    0.086365] TCP bind hash table entries: 4096 (order: 4, 65536 bytes, linear)
    [    0.087025] TCP: Hash tables configured (established 4096 bind 4096)
    [    0.087749] UDP hash table entries: 256 (order: 1, 8192 bytes, linear)
    [    0.088481] UDP-Lite hash table entries: 256 (order: 1, 8192 bytes, linear)
    [    0.089261] NET: Registered protocol family 1
    [    0.090395] virtio-mmio: Registering device virtio-mmio.0 at 0xd0000000-0xd0000fff, IRQ 5.
    [    0.091388] virtio-mmio: Registering device virtio-mmio.1 at 0xd0001000-0xd0001fff, IRQ 6.
    [    0.092222] clocksource: tsc: mask: 0xffffffffffffffff max_cycles: 0x1128af0325d, max_idle_ns: 440795261011 ns
    [    0.093322] clocksource: Switched to clocksource tsc
    [    0.093824] platform rtc_cmos: registered platform RTC device (no PNP device found)
    [    0.094618] check: Scanning for low memory corruption every 60 seconds
    [    0.095394] Initialise system trusted keyrings
    [    0.095836] Key type blacklist registered
    [    0.096427] workingset: timestamp_bits=36 max_order=17 bucket_order=0
    [    0.097849] squashfs: version 4.0 (2009/01/31) Phillip Lougher
    [    0.107488] Key type asymmetric registered
    [    0.107905] Asymmetric key parser 'x509' registered
    [    0.108409] Block layer SCSI generic (bsg) driver version 0.4 loaded (major 252)
    [    0.109435] Serial: 8250/16550 driver, 1 ports, IRQ sharing disabled
    [    0.110116] serial8250: ttyS0 at I/O 0x3f8 (irq = 4, base_baud = 115200) is a 16550A
    [    0.111877] loop: module loaded
    [    0.112426] virtio_blk virtio0: [vda] 441152 512-byte logical blocks (226 MB/215 MiB)
    [    0.113229] vda: detected capacity change from 0 to 225869824
    [    0.114143] Loading iSCSI transport class v2.0-870.
    [    0.114753] iscsi: registered transport (tcp)
    [    0.115162] tun: Universal TUN/TAP device driver, 1.6
    [    0.115955] i8042: PNP detection disabled
    [    0.116498] serio: i8042 KBD port at 0x60,0x64 irq 1
    [    0.117089] input: AT Raw Set 2 keyboard as /devices/platform/i8042/serio0/input/input0
    [    0.117932] intel_pstate: CPU model not supported
    [    0.118448] hid: raw HID events driver (C) Jiri Kosina
    [    0.119090] Initializing XFRM netlink socket
    [    0.119555] NET: Registered protocol family 10
    [    0.120285] Segment Routing with IPv6
    [    0.120812] NET: Registered protocol family 17
    [    0.121350] Bridge firewalling registered
    [    0.122026] NET: Registered protocol family 40
    [    0.122515] IPI shorthand broadcast: enabled
    [    0.122961] sched_clock: Marking stable (72512224, 48198862)->(137683636, -16972550)
    [    0.123796] registered taskstats version 1
    [    0.124203] Loading compiled-in X.509 certificates
    [    0.125355] Loaded X.509 cert 'Build time autogenerated kernel key: 6203e6adc37b712d3b220a26b38f3d31311d5966'
    [    0.126355] Key type ._fscrypt registered
    [    0.126736] Key type .fscrypt registered
    [    0.127109] Key type fscrypt-provisioning registered
    [    0.127657] Key type encrypted registered
    [    0.144629] IP-Config: Complete:
    [    0.144968]      device=eth0, hwaddr=9e:72:c7:04:6b:80, ipaddr=192.168.128.9, mask=255.255.255.0, gw=192.168.128.1
    [    0.146044]      host=192.168.128.9, domain=, nis-domain=(none)
    [    0.146604]      bootserver=255.255.255.255, rootserver=255.255.255.255, rootpath=
    [    0.148347] EXT4-fs (vda): mounted filesystem with ordered data mode. Opts: (null)
    [    0.149098] VFS: Mounted root (ext4 filesystem) on device 254:0.
    [    0.149761] devtmpfs: mounted
    [    0.150340] Freeing unused decrypted memory: 2040K
    [    0.151148] Freeing unused kernel image (initmem) memory: 1408K
    [    0.156621] Write protecting the kernel read-only data: 14336k
    [    0.158657] Freeing unused kernel image (text/rodata gap) memory: 2044K
    [    0.159490] Freeing unused kernel image (rodata/data gap) memory: 188K
    [    0.160150] Run /init.sh as init process
    462:C 15 May 2021 21:13:01.903 # oO0OoO0OoO0Oo Redis is starting oO0OoO0OoO0Oo
    462:C 15 May 2021 21:13:01.904 # Redis version=6.2.3, bits=64, commit=00000000, modified=0, pid=462, just started
    462:C 15 May 2021 21:13:01.905 # Warning: no config file specified, using the default config. In order to specify a config file use redis-server /path/to/redis.conf
    462:M 15 May 2021 21:13:01.907 * Increased maximum number of open files to 10032 (it was originally set to 1024).
    462:M 15 May 2021 21:13:01.909 * monotonic clock: POSIX clock_gettime
                    _._
               _.-``__ ''-._
          _.-``    `.  `_.  ''-._           Redis 6.2.3 (00000000/0) 64 bit
      .-`` .-```.  ```\/    _.,_ ''-._
     (    '      ,       .-`  | `,    )     Running in standalone mode
     |`-._`-...-` __...-.``-._|'` _.-'|     Port: 6379
     |    `-._   `._    /     _.-'    |     PID: 462
      `-._    `-._  `-./  _.-'    _.-'
     |`-._`-._    `-.__.-'    _.-'_.-'|
     |    `-._`-._        _.-'_.-'    |           https://redis.io
      `-._    `-._`-.__.-'_.-'    _.-'
     |`-._`-._    `-.__.-'    _.-'_.-'|
     |    `-._`-._        _.-'_.-'    |
      `-._    `-._`-.__.-'_.-'    _.-'
          `-._    `-.__.-'    _.-'
              `-._        _.-'
                  `-.__.-'

    462:M 15 May 2021 21:13:01.922 # Server initialized
    462:M 15 May 2021 21:13:01.923 * Ready to accept connections

We can do a quick test with the following:

```bash
; sudo docker run -it --rm redis redis-cli -h 192.168.128.9
192.168.128.9:6379> get foo
(nil)
192.168.128.9:6379> set foo 1
OK
192.168.128.9:6379> get foo
"1"
192.168.128.9:6379>
```
