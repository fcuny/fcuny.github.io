---
title: Making sense of Intel and AMD CPUs naming
date: 2021-12-29
tags:
  - amd
  - intel
  - cpu
---

## Intel

### Core

The line up for the core family is i3, i5, i7 and i9. As of December
2021, the current generation is Alder Lake (12th generation).

The brand modifiers are:

-   **i3**: laptops/low-end desktop
-   **i5**: mainstream users
-   **i7**: high-end users
-   **i9**: enthusiast users

How to read a SKU ? Let's use the
[i7-12700K](https://ark.intel.com/content/www/us/en/ark/products/134594/intel-core-i712700k-processor-25m-cache-up-to-5-00-ghz.html)
processor:

-   **i7**: high end users
-   **12**: 12th generation
-   **700**: SKU digits, usually assigned in the order the processors
    are developed
-   **K**: unlocked

List of suffixes:

| suffix | meaning                                |
|--------|----------------------------------------|
| G..    | integrated graphics                    |
| E      | embedded                               |
| F      | require discrete graphic card          |
| H      | high performance for mobile            |
| HK     | high performance for mobile / unlocked |
| K      | unlocked                               |
| S      | special edition                        |
| T      | power optimized lifestyle              |
| U      | mobile power efficient                 |
| Y      | mobile low power                       |
| X/XE   | unlocked, high end                     |

> **Unlocked,** what does that means ? A processor with the **K** suffix
> is made with the an unlocked clock multiplier. When used with some
> specific chipset, it's possible to overclock the processor.

#### Sockets/Chipsets

For the Alder Lake generation, the supported socket is the
[LGA<sub>1700</sub>](https://en.wikipedia.org/wiki/LGA_1700).

For now only supported chipset for Alder Lake are:

| feature                     | [z690](https://ark.intel.com/content/www/us/en/ark/products/218833/intel-z690-chipset.html) | [h670](https://www.intel.com/content/www/us/en/products/sku/218831/intel-h670-chipset/specifications.html) | [b660](https://ark.intel.com/content/www/us/en/ark/products/218832/intel-b660-chipset.html) | [h610](https://www.intel.com/content/www/us/en/products/sku/218829/intel-h610-chipset/specifications.html) |
|-----------------------------|---------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------|
| P and E cores over clocking | yes                                                                                         | no                                                                                                         | no                                                                                          | no                                                                                                         |
| memory over clocking        | yes                                                                                         | yes                                                                                                        | yes                                                                                         | no                                                                                                         |
| DMI 4 lanes                 | 8                                                                                           | 8                                                                                                          | 4                                                                                           | 4                                                                                                          |
| chipset PCIe 4.0 lanes      | up to 12                                                                                    | up to 12                                                                                                   | up to 6                                                                                     | none                                                                                                       |
| chipset PCIe 3.0 lanes      | up to 16                                                                                    | up to 12                                                                                                   | up to 8                                                                                     | 8                                                                                                          |
| SATA 3.0 ports              | up to 8                                                                                     | up to 8                                                                                                    | 4                                                                                           | 4                                                                                                          |

### Alder Lake (12th generation)

| model      | p-cores | e-cores | GHz (base) | GHz (boosted) | TDP  |
|------------|---------|---------|------------|---------------|------|
| i9-12900K  | 8 (16)  | 8       | 3.2/2.4    | 5.1/3.9       | 241W |
| i9-12900KF | 8 (16)  | 8       | 3.2/2.4    | 5.1/3.9       | 241W |
| i7-12700K  | 8 (16)  | 4       | 3.6/2.7    | 4.9/3.8       | 190W |
| i7-12700KF | 8 (16)  | 4       | 3.6/2.7    | 4.9/3.8       | 190W |
| i5-12600K  | 6 (12)  | 4       | 3.7/2.8    | 4.9/3.6       | 150W |
| i5-12600KF | 6 (12)  | 4       | 3.7/2.8    | 4.9/3.6       | 150W |

-   support DDR4 and DDR5 (up to DDR5-4800)
-   support PCIe 4.0 and 5.0 (16 PCIe 5.0 and 4 PCIe 4.0)

The socket used is the [LGA
1700](https://en.wikipedia.org/wiki/LGA_1700).

Alder lake is an hybrid architecture, featuring both P-cores
(performance cores) and E-cores (efficient cores). P-cores are based on
the [Golden Cove](https://en.wikipedia.org/wiki/Golden_Cove)
architecture, while the E-cores are based on the
[Gracemont](https://en.wikipedia.org/wiki/Gracemont_(microarchitecture))
architecture.

This is a [good
article](https://www.anandtech.com/show/16881/a-deep-dive-into-intels-alder-lake-microarchitectures/2)
to read about this model. Inside the processor there's a microcontroller
that monitors what each thread is doing. This can be used by the OS
scheduler to hint on which core a thread should be scheduled on (between
performance or efficiency).

As of December 2021 this is not yet properly supported by the Linux
kernel.

### Xeon

Xeon is the brand of Intel processor designed for non-consumer servers
and workstations. The most recent generations are:

-   Skylake (2017)
-   Cascade lake (2019)
-   Cooper lake (2020)

The following brand identifiers are used:

-   platinium
-   gold
-   silver
-   bronze

## AMD

### Ryzen

There are multiple generation for this brand of processors. They are
based on the [zen micro
architecture](https://en.wikipedia.org/wiki/Zen_(microarchitecture)).
The current (as of December 2021) generation is Ryzen 5000.

The brand modifiers are:

-   ryzen 3: entry level
-   ryzen 5: mainstream
-   ryzen 9: high end performance
-   ryzen 9:enthusiast

List of suffixes:

| suffix | meaning                                    |
|--------|--------------------------------------------|
| X      | high performance                           |
| G      | integrated graphics                        |
| T      | power optimized lifecycle                  |
| S      | low power desktop with integrated graphics |
| H      | high performance mobile                    |
| U      | standard mobile                            |
| M      | low power mobile                           |

### EPYC

EPYC is the AMD brand of processors for the server market, based on the
zen architecture. They use the
[SP3](https://en.wikipedia.org/wiki/Socket_SP3) socket. The EPYC
processor is chipset free.

### Threadripper

The threadripper is for high performance desktop. It uses the
[TR4](https://en.wikipedia.org/wiki/Socket_TR4) socket. At the moment
there's only one chipset that supports this process, the
[X399](https://en.wikipedia.org/wiki/List_of_AMD_chipsets#TR4_chipsets).

The threadripper based on zen3 architecture is not yet released, but
it's expected to hit the market in the first half of Q1 2022.

### Sockets/Chipsets

The majority of these processors use the [AM4
socket](https://en.wikipedia.org/wiki/Socket_AM4). The threadripper line
uses different sockets.

There are multiple
[chipset](https://en.wikipedia.org/wiki/Socket_AM4#Chipsets) for the AM4
socket. The more advanced ones are the B550 and the X570.

The threadripper processors use the TR4, sTRX4 and sWRX8 sockets.

### Zen 3

Zen 3 was released in November 2020.

| model         | cores   | GHz (base) | GHz (boosted) | PCIe lanes | TDP  |
|---------------|---------|------------|---------------|------------|------|
| ryzen 5 5600x | 6 (12)  | 3.7        | 4.6           | 24         | 65W  |
| ryzen 7 5800  | 8 (16)  | 3.4        | 4.6           | 24         | 65W  |
| ryzen 7 5800x | 8 (16)  | 3.8        | 4.7           | 24         | 105W |
| ryzen 9 5900  | 12 (24) | 3.0        | 4.7           | 24         | 65W  |
| ryzen 9 5900x | 12 (24) | 3.7        | 4.8           | 24         | 105W |
| ryzen 9 5950x | 16 (32) | 3.4        | 4.9           | 24         | 105W |

-   support PCIe 3.0 and PCIe 4.0 (except for the G series)
-   only support DDR4 (up to DDR4-3200)
