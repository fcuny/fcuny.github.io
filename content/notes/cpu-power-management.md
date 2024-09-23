---
title: CPU power management
date: 2023-01-22
---

## Maximum power consumption of a processor

Our Intel CPU has a thermal design power (TDP) of 120W. The AMD CPU has a TDP of 200W.

The Intel CPU has 80 cores while the AMD one has 128 cores. For Intel, this gives us 1.5W per core, while for AMD, 1.56W.

The TDP is the average value the processor can sustain forever, and this is the power the cooling solution needs to be designed at for reliability. The TDP is measured under worst case load, with all cores running at 1.8Ghz (the base frequency).

## C-State vs. P-State

We have two ways to control the power consumption:

- disabling a subsystem
- decrease the voltage

This is done by using

- _C-State_ is for optimization of power consumption
- _P-State_ is for optimization of the voltage and CPU frequency

_C-State_ means that one or more subsystem are executing nothing, one or more subsystem of the CPU is at idle, powered down.

_P-State_ the subsystem is actually running, but it does not require full performance, so the voltage and/or frequency it operates is decreased.

The states are numbered starting from 0. The higher the number, the more power is saved. `C0` means no power saving. `P0` means maximum performance (thus maximum frequency, voltage and power used).

### C-state

A timeline of power saving using C states is as follow:

1. normal operation is at c0
2. the clock of idle core is stopped (C1)
3. the local caches (L1/L2) of the core are flushed and the core is powered down (C3)
4. when all the cores are powered down, the shared cache of the package (L3/LLC) are flushed and the whole package/CPU can be powered down

| state | description                                                                                                                 |
| ----- | --------------------------------------------------------------------------------------------------------------------------- |
| C0    | operating state                                                                                                             |
| C1    | a state where the processor is not executing instructions, but can return to an executing state essentially instantaneously |
| C2    | a state where the processor maintains all software-visible state, but may take longer to wake up                            |
| C3    | a state where the processor does not need to keep its cache coherent, but maintains other state                             |

Running `cpuid` we can find all the supported C-states for a processor (Intel(R) Xeon(R) Gold 6122 CPU @ 1.80GHz):

```
   MONITOR/MWAIT (5):
      smallest monitor-line size (bytes)       = 0x40 (64)
      largest monitor-line size (bytes)        = 0x40 (64)
      enum of Monitor-MWAIT exts supported     = true
      supports intrs as break-event for MWAIT  = true
      number of C0 sub C-states using MWAIT    = 0x0 (0)
      number of C1 sub C-states using MWAIT    = 0x2 (2)
      number of C2 sub C-states using MWAIT    = 0x0 (0)
      number of C3 sub C-states using MWAIT    = 0x2 (2)
      number of C4 sub C-states using MWAIT    = 0x0 (0)
      number of C5 sub C-states using MWAIT    = 0x0 (0)
      number of C6 sub C-states using MWAIT    = 0x0 (0)
      number of C7 sub C-states using MWAIT    = 0x0 (0)
```

If I interpret this correctly:

- there's one `C0`
- there's two sub C-states for `C1`
- there's two sub C-states for `C3`

### P-state

Being in P-states means the CPU core is also in `C0`, since it has to be powered to execute some code.

P-states allow to change the voltage and frequency of the CPU core to decrease the power consumption.

A P-state refers to different frequency-voltage pairs. The highest operating point is the maximum state which is `P0`.

| state | description                                |
| ----- | ------------------------------------------ |
| P0    | maximum power and frequency                |
| P1    | less than P0, voltage and frequency scaled |
| P2    | less than P1, voltage and frequency scaled |

## ACPI power state

The ACPI Specification defines the following four global "Gx" states and six sleep "Sx" states

| GX   | name           | Sx   | description                                                                       |
| ---- | -------------- | ---- | --------------------------------------------------------------------------------- |
| `G0` | working        | `S0` | The computer is running and executing instructions                                |
| `G1` | sleeping       | `S1` | Processor caches are flushed and the CPU stop executing instructions              |
| `G1` | sleeping       | `S2` | CPU powered off, dirty caches flushed to RAM                                      |
| `G1` | sleeping       | `S3` | Suspend to RAM                                                                    |
| `G1` | sleeping       | `S4` | Suspend to disk, all content of the main memory is flushed to non volatile memory |
| `G2` | soft off       | `S5` | PSU still supplies power, a full reboot is required                               |
| `G3` | mechanical off | `S6` | The system is safe for disassembly                                                |

When we are in any C-states, we are in `G0`.

## Speed Select Technology

[Speed Select Technology](https://en.wikichip.org/wiki/intel/speed_select_technology) is a set of power management controls that allows a system administrator to customize per-core performance. By configuring the performance of specific cores and affinitizing workloads to those cores, higher software performance can be achieved. SST supports multiple types of customization:

- Frequency Prioritization (SST-CP) - allows specific cores to clock higher by reducing the frequency of cores running lower-priority software.
- Speed Select Base Freq (SST-BF) - allows specific cores to run higher base frequency (P1) by reducing the base frequencies (P1) of other cores.

## Turbo Boost

TDP is the maximum power consumption the CPU can sustain. When the power consumption is low (e.g. many cores are in P1+ states), the CPU frequency can be increased beyond base frequency to take advantage of the headroom, since this condition does not increase the power consumption beyond TDP.

Modern CPUs are heavily reliant on "Turbo(Intel)" or "boost (AMD)" ([TBT](https://en.wikichip.org/wiki/intel/turbo_boost_technology) and [TBTM](https://en.wikichip.org/wiki/intel/turbo_boost_max_technology)).

In our case, the Intel 6122 is rated at 1.8GHz, A.K.A "stamp speed". If we want to run the CPU at a consistent frequency, we'd have to choose 1.8GHz or below, and we'd lose significant performance if we were to disable turbo/boost.

### Turbo boost max

During the manufacturing process, Intel is able to test each die and determine which cores possess the best overclocking capabilities. That information is then stored in the CPU in order from best to worst.
