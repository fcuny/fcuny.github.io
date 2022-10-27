---
title: Stuff about PCIe
date: 2022-01-03
tags:
  - linux
  - harwdare
---

## Speed

The most common versions are 3 and 4, while 5 is starting to be
available with newer Intel processors.

| ver | encoding  | transfer rate | x1         | x2          | x4         | x8         | x16         |
|-----|-----------|---------------|------------|-------------|------------|------------|-------------|
| 1   | 8b/10b    | 2.5GT/s       | 250MB/s    | 500MB/s     | 1GB/s      | 2GB/s      | 4GB/s       |
| 2   | 8b/10b    | 5.0GT/s       | 500MB/s    | 1GB/s       | 2GB/s      | 4GB/s      | 8GB/s       |
| 3   | 128b/130b | 8.0GT/s       | 984.6 MB/s | 1.969 GB/s  | 3.94 GB/s  | 7.88 GB/s  | 15.75 GB/s  |
| 4   | 128b/130b | 16.0GT/s      | 1969 MB/s  | 3.938 GB/s  | 7.88 GB/s  | 15.75 GB/s | 31.51 GB/s  |
| 5   | 128b/130b | 32.0GT/s      | 3938 MB/s  | 7.877 GB/s  | 15.75 GB/s | 31.51 GB/s | 63.02 GB/s  |
| 6   | 128b/130  | 64.0 GT/s     | 7877 MB/s  | 15.754 GB/s | 31.51 GB/s | 63.02 GB/s | 126.03 GB/s |

This is a
[useful](https://community.mellanox.com/s/article/understanding-pcie-configuration-for-maximum-performance)
link to understand the formula:

    Maximum PCIe Bandwidth = SPEED * WIDTH * (1 - ENCODING) - 1Gb/s

We remove 1Gb/s for protocol overhead and error corrections. The main
difference between the generations besides the supported speed is the
encoding overhead of the packet. For generations 1 and 2, each packet
sent on the PCIe has 20% PCIe headers overhead. This was improved in
generation 3, where the overhead was reduced to 1.5% (2/130) - see
[8b/10b encoding](https://en.wikipedia.org/wiki/8b/10b_encoding) and
[128b/130b encoding](https://en.wikipedia.org/wiki/64b/66b_encoding).

If we apply the formula, for a PCIe version 3 device we can expect
3.7GB/s of data transfer rate:

    8GT/s * 4 lanes * (1 - 2/130) - 1G = 32G * 0.985 - 1G = ~30Gb/s -> 3750MB/s

## Topology

The easiest way to see the PCIe topology is with `lspci`:

    $ lspci -tv
    -[0000:00]-+-00.0  Advanced Micro Devices, Inc. [AMD] Family 17h (Models 00h-0fh) Root Complex
               +-01.0  Advanced Micro Devices, Inc. [AMD] Family 17h (Models 00h-1fh) PCIe Dummy Host Bridge
               +-01.1-[01]----00.0  OCZ Technology Group, Inc. RD400/400A SSD
               +-01.3-[02-03]----00.0-[03]----00.0  ASPEED Technology, Inc. ASPEED Graphics Family
               +-01.5-[04]--+-00.0  Intel Corporation I350 Gigabit Network Connection
               |            +-00.1  Intel Corporation I350 Gigabit Network Connection
               |            +-00.2  Intel Corporation I350 Gigabit Network Connection
               |            \-00.3  Intel Corporation I350 Gigabit Network Connection
               +-02.0  Advanced Micro Devices, Inc. [AMD] Family 17h (Models 00h-1fh) PCIe Dummy Host Bridge
               +-03.0  Advanced Micro Devices, Inc. [AMD] Family 17h (Models 00h-1fh) PCIe Dummy Host Bridge
               +-04.0  Advanced Micro Devices, Inc. [AMD] Family 17h (Models 00h-1fh) PCIe Dummy Host Bridge
               +-07.0  Advanced Micro Devices, Inc. [AMD] Family 17h (Models 00h-1fh) PCIe Dummy Host Bridge
               +-07.1-[05]--+-00.0  Advanced Micro Devices, Inc. [AMD] Zeppelin/Raven/Raven2 PCIe Dummy Function
               |            +-00.2  Advanced Micro Devices, Inc. [AMD] Family 17h (Models 00h-0fh) Platform Security Processor
               |            \-00.3  Advanced Micro Devices, Inc. [AMD] Zeppelin USB 3.0 Host controller
               +-08.0  Advanced Micro Devices, Inc. [AMD] Family 17h (Models 00h-1fh) PCIe Dummy Host Bridge
               +-08.1-[06]--+-00.0  Advanced Micro Devices, Inc. [AMD] Zeppelin/Renoir PCIe Dummy Function
               |            +-00.1  Advanced Micro Devices, Inc. [AMD] Zeppelin Cryptographic Coprocessor NTBCCP
               |            +-00.2  Advanced Micro Devices, Inc. [AMD] FCH SATA Controller [AHCI mode]
               |            \-00.3  Advanced Micro Devices, Inc. [AMD] Family 17h (Models 00h-0fh) HD Audio Controller
               +-14.0  Advanced Micro Devices, Inc. [AMD] FCH SMBus Controller
               +-14.3  Advanced Micro Devices, Inc. [AMD] FCH LPC Bridge
               +-18.0  Advanced Micro Devices, Inc. [AMD] Family 17h (Models 00h-0fh) Data Fabric: Device 18h; Function 0
               +-18.1  Advanced Micro Devices, Inc. [AMD] Family 17h (Models 00h-0fh) Data Fabric: Device 18h; Function 1
               +-18.2  Advanced Micro Devices, Inc. [AMD] Family 17h (Models 00h-0fh) Data Fabric: Device 18h; Function 2
               +-18.3  Advanced Micro Devices, Inc. [AMD] Family 17h (Models 00h-0fh) Data Fabric: Device 18h; Function 3
               +-18.4  Advanced Micro Devices, Inc. [AMD] Family 17h (Models 00h-0fh) Data Fabric: Device 18h; Function 4
               +-18.5  Advanced Micro Devices, Inc. [AMD] Family 17h (Models 00h-0fh) Data Fabric: Device 18h; Function 5
               +-18.6  Advanced Micro Devices, Inc. [AMD] Family 17h (Models 00h-0fh) Data Fabric: Device 18h; Function 6
               \-18.7  Advanced Micro Devices, Inc. [AMD] Family 17h (Models 00h-0fh) Data Fabric: Device 18h; Function 7

## View a single device

    $ lspci -s 0000:01:00.0
    01:00.0 Non-Volatile memory controller: OCZ Technology Group, Inc. RD400/400A SSD (rev 01)

## Reading `lspci` output

    $ sudo lspci -vvv -s 0000:01:00.0
    01:00.0 Non-Volatile memory controller: OCZ Technology Group, Inc. RD400/400A SSD (rev 01) (prog-if 02 [NVM Express])
        Subsystem: OCZ Technology Group, Inc. RD400/400A SSD
        Control: I/O- Mem+ BusMaster+ SpecCycle- MemWINV- VGASnoop- ParErr- Stepping- SERR- FastB2B- DisINTx+
        Status: Cap+ 66MHz- UDF- FastB2B- ParErr- DEVSEL=fast >TAbort- <TAbort- <MAbort- >SERR- <PERR- INTx-
        Latency: 0, Cache Line Size: 64 bytes
        Interrupt: pin A routed to IRQ 41
        NUMA node: 0
        Region 0: Memory at ef800000 (64-bit, non-prefetchable) [size=16K]
        Capabilities: [40] Power Management version 3
            Flags: PMEClk- DSI- D1- D2- AuxCurrent=0mA PME(D0-,D1-,D2-,D3hot-,D3cold-)
            Status: D0 NoSoftRst+ PME-Enable- DSel=0 DScale=0 PME-
        Capabilities: [50] MSI: Enable- Count=1/8 Maskable- 64bit+
            Address: 0000000000000000  Data: 0000
        Capabilities: [70] Express (v2) Endpoint, MSI 00
            DevCap: MaxPayload 128 bytes, PhantFunc 0, Latency L0s unlimited, L1 unlimited
                ExtTag+ AttnBtn- AttnInd- PwrInd- RBE+ FLReset+ SlotPowerLimit 0.000W
            DevCtl: CorrErr- NonFatalErr- FatalErr- UnsupReq-
                RlxdOrd+ ExtTag+ PhantFunc- AuxPwr- NoSnoop- FLReset-
                MaxPayload 128 bytes, MaxReadReq 512 bytes
            DevSta: CorrErr+ NonFatalErr- FatalErr- UnsupReq+ AuxPwr+ TransPend-
            LnkCap: Port #0, Speed 8GT/s, Width x4, ASPM L1, Exit Latency L1 <4us
                ClockPM- Surprise- LLActRep- BwNot- ASPMOptComp+
            LnkCtl: ASPM L1 Enabled; RCB 64 bytes, Disabled- CommClk+
                ExtSynch- ClockPM- AutWidDis- BWInt- AutBWInt-
            LnkSta: Speed 8GT/s (ok), Width x4 (ok)
                TrErr- Train- SlotClk+ DLActive- BWMgmt- ABWMgmt-
            DevCap2: Completion Timeout: Range ABCD, TimeoutDis+ NROPrPrP- LTR+
                 10BitTagComp- 10BitTagReq- OBFF Not Supported, ExtFmt- EETLPPrefix-
                 EmergencyPowerReduction Not Supported, EmergencyPowerReductionInit-
                 FRS- TPHComp- ExtTPHComp-
                 AtomicOpsCap: 32bit- 64bit- 128bitCAS-
            DevCtl2: Completion Timeout: 50us to 50ms, TimeoutDis- LTR- OBFF Disabled,
                 AtomicOpsCtl: ReqEn-
            LnkCap2: Supported Link Speeds: 2.5-8GT/s, Crosslink- Retimer- 2Retimers- DRS-
            LnkCtl2: Target Link Speed: 8GT/s, EnterCompliance- SpeedDis-
                 Transmit Margin: Normal Operating Range, EnterModifiedCompliance- ComplianceSOS-
                 Compliance De-emphasis: -6dB
            LnkSta2: Current De-emphasis Level: -3.5dB, EqualizationComplete+ EqualizationPhase1+
                 EqualizationPhase2+ EqualizationPhase3+ LinkEqualizationRequest-
                 Retimer- 2Retimers- CrosslinkRes: unsupported
        Capabilities: [b0] MSI-X: Enable+ Count=8 Masked-
            Vector table: BAR=0 offset=00002000
            PBA: BAR=0 offset=00003000
        Capabilities: [100 v2] Advanced Error Reporting
            UESta:  DLP- SDES- TLP- FCP- CmpltTO- CmpltAbrt- UnxCmplt- RxOF- MalfTLP- ECRC- UnsupReq+ ACSViol-
            UEMsk:  DLP- SDES- TLP- FCP- CmpltTO- CmpltAbrt- UnxCmplt- RxOF- MalfTLP- ECRC- UnsupReq- ACSViol-
            UESvrt: DLP+ SDES+ TLP- FCP+ CmpltTO- CmpltAbrt- UnxCmplt- RxOF+ MalfTLP+ ECRC- UnsupReq- ACSViol-
            CESta:  RxErr- BadTLP- BadDLLP- Rollover- Timeout- AdvNonFatalErr+
            CEMsk:  RxErr- BadTLP- BadDLLP- Rollover- Timeout- AdvNonFatalErr-
            AERCap: First Error Pointer: 14, ECRCGenCap+ ECRCGenEn- ECRCChkCap+ ECRCChkEn-
                MultHdrRecCap- MultHdrRecEn- TLPPfxPres- HdrLogCap-
            HeaderLog: 05000001 0000010f 02000010 0f86d1a0
        Capabilities: [178 v1] Secondary PCI Express
            LnkCtl3: LnkEquIntrruptEn- PerformEqu-
            LaneErrStat: 0
        Capabilities: [198 v1] Latency Tolerance Reporting
            Max snoop latency: 0ns
            Max no snoop latency: 0ns
        Capabilities: [1a0 v1] L1 PM Substates
            L1SubCap: PCI-PM_L1.2+ PCI-PM_L1.1- ASPM_L1.2+ ASPM_L1.1- L1_PM_Substates+
                  PortCommonModeRestoreTime=255us PortTPowerOnTime=400us
            L1SubCtl1: PCI-PM_L1.2- PCI-PM_L1.1- ASPM_L1.2- ASPM_L1.1-
                   T_CommonMode=0us LTR1.2_Threshold=0ns
            L1SubCtl2: T_PwrOn=10us
        Kernel driver in use: nvme
        Kernel modules: nvme

A few things to note from this output:

-   **GT/s** is the number of transactions supported (here, 8 billion
    transactions / second). This is gen3 controller (gen1 is 2.5 and
    gen2 is 5)xs
-   **LNKCAP** is the capabilities which were communicated, and
    **LNKSTAT** is the current status. You want them to report the same
    values. If they don't, you are not using the hardware as it is
    intended (here I'm assuming the hardware is intended to work as a
    gen3 controller). In case the device is downgraded, the output will
    be like this: `LnkSta: Speed 2.5GT/s (downgraded), Width x16 (ok)`
-   **width** is the number of lanes that can be used by the device
    (here, we can use 4 lanes)
-   **MaxPayload** is the maximum size of a PCIe packet

## Debugging

PCI configuration registers can be used to debug various PCI bus issues.

The various registers define bits that are either set (indicated with a
'+') or unset (indicated with a '-'). These bits typically have
attributes of 'RW1C' meaning you can read and write them and need to
write a '1' to clear them. Because these are status bits, if you wanted
to 'count' the occurrences of them you would need to write some software
that detected the bits getting set, incremented counters, and cleared
them over time.

The 'Device Status Register' (DevSta) shows at a high level if there
have been correctable errors detected (CorrErr), non-fatal errors
detected (UncorrErr), fata errors detected (FataErr), unsupported
requests detected (UnsuppReq), if the device requires auxillary power
(AuxPwr), and if there are transactions pending (non posted requests
that have not been completed).

    10000:01:00.0 Non-Volatile memory controller: Intel Corporation NVMe Datacenter SSD [3DNAND, Beta Rock Controller] (prog-if 02 [NVM Express])
    ...
            Capabilities: [100 v1] Advanced Error Reporting
                    UESta:  DLP- SDES- TLP- FCP- CmpltTO- CmpltAbrt- UnxCmplt- RxOF- MalfTLP- ECRC- UnsupReq- ACSViol-
                    UEMsk:  DLP- SDES- TLP- FCP- CmpltTO- CmpltAbrt- UnxCmplt- RxOF- MalfTLP- ECRC- UnsupReq- ACSViol-
                    UESvrt: DLP+ SDES+ TLP- FCP+ CmpltTO- CmpltAbrt- UnxCmplt- RxOF+ MalfTLP+ ECRC- UnsupReq- ACSViol-
                    CESta:  RxErr- BadTLP- BadDLLP- Rollover- Timeout- NonFatalErr-
                    CEMsk:  RxErr- BadTLP- BadDLLP- Rollover- Timeout- NonFatalErr+
                    AERCap: First Error Pointer: 00, GenCap+ CGenEn- ChkCap+ ChkEn-

-   The Uncorrectable Error Status (UESta) reports error status of
    individual uncorrectable error sources (no bits are set above):
    -   Data Link Protocol Error (DLP)
    -   Surprise Down Error (SDES)
    -   Poisoned TLP (TLP)
    -   Flow Control Protocol Error (FCP)
    -   Completion Timeout (CmpltTO)
    -   Completer Abort (CmpltAbrt)
    -   Unexpected Completion (UnxCmplt)
    -   Receiver Overflow (RxOF)
    -   Malformed TLP (MalfTLP)
    -   ECRC Error (ECRC)
    -   Unsupported Request Error (UnsupReq)
    -   ACS Violation (ACSViol)
-   The Uncorrectable Error Mask (UEMsk) controls reporting of
    individual errors by the device to the PCIe root complex. A masked
    error (bit set) is not recorded or reported. Above shows no errors
    are being masked)
-   The Uncorrectable Severity controls whether an individual error is
    reported as a Non-fatal (clear) or Fatal error (set).
-   The Correctable Error Status reports error status of individual
    correctable error sources: (no bits are set above)
    -   Receiver Error (RXErr)
    -   Bad TLP status (BadTLP)
    -   Bad DLLP status (BadDLLP)
    -   Replay Timer Timeout status (Timeout)
    -   REPLAY NUM Rollover status (Rollover)
    -   Advisory Non-Fatal Error (NonFatalIErr)
-   The Correctable Erro Mask (CEMsk) controls reporting of individual
    errors by the device to the PCIe root complex. A masked error (bit
    set) is not reported to the RC. Above shows that Advisory Non-Fatal
    Errors are being masked - this bit is set by default to enable
    compatibility with software that does not comprehend Role-Based
    error reporting.
-   The Advanced Error Capabilities and Control Register (AERCap)
    enables various capabilities (The above indicates the device capable
    of generating ECRC errors but they are not enabled):
    -   First Error Pointer identifies the bit position of the first
        error reported in the Uncorrectable Error Status register
    -   ECRC Generation Capable (GenCap) indicates if set that the
        function is capable of generating ECRC
    -   ECRC Generation Enable (GenEn) indicates if ECRC generation is
        enabled (set)
    -   ECRC Check Capable (ChkCap) indicates if set that the function
        is capable of checking ECRC
    -   ECRC Check Enable (ChkEn) indicates if ECRC checking is enabled
