**BITLEDGER**

**UNIVERSAL DOMAIN SPECIFICATION**

*A Generalized Flow-Accounting Protocol for Any Engineered System*

Companion to BitLedger Protocol Specification v3.0

*The same 40-bit record that carries dollars and cents*

*can carry kilograms of propellant, watt-hours of power,*

*data packets, contractual obligations, or any conserved quantity*

*in any engineered system --- without changing a single bit of the wire format.*

**1. THE PROTOCOL BENEATH THE PROTOCOL**

BitLedger was designed as a financial transmission protocol. It encodes double-entry accounting transactions in the minimum possible number of bits. But the mathematical foundation it rests on is older than accounting and more general than money.

Double-entry accounting is a conservation law. Every transaction records a quantity leaving one account and arriving at another. The sum of all signed flows in any valid set of entries is zero. This is not a bookkeeping convention --- it is the same algebraic invariant that governs current flow in electrical networks, mass balance in chemical processes, and momentum transfer in mechanical systems.

KIRCHHOFF\'S CURRENT LAW:

Sum of all currents entering a node = Sum of all currents leaving

Sum(I_in) - Sum(I_out) = 0

DOUBLE-ENTRY ACCOUNTING INVARIANT:

Sum of all debits = Sum of all credits

Sum(+V_i) + Sum(-V_i) = 0

BITLEDGER BATCH CONSERVATION:

Sum of all signed flow values across a batch = 0 (mod precision step)

This is enforced at the wire level, not the application level.

> *These three statements are the same conservation principle expressed in different domains. BitLedger enforces this principle at the encoding level. Any system governed by a conservation law is therefore a natural candidate for BitLedger records --- not as an approximation, but as an exact fit.*

The wire format does not change. The 40-bit record structure, the value encoding formula N = A x 2\^S + r, the cross-layer validation rules, the CRC-15 session integrity check, the compound continuation mechanism, and the control record system are identical across all domains. What changes is the semantic interpretation of two fields: the 4-bit relationship matrix and the 6-bit quantity type code. Everything else is domain-agnostic by design.

**1.1 What This Document Covers**

This document specifies the Universal Domain of the BitLedger protocol. It defines how the existing wire format is interpreted when operating outside the financial domain --- in engineering, physical systems, IoT, supply chain, and aerospace contexts. It is a companion to BitLedger Protocol Specification v3.0, which remains the authoritative reference for all wire-format details. This document does not redefine bit layouts. It reinterprets them.

  --------------------- -------------- ----------------------------------------- ---------------------------------------------
       **Domain**        **Bits 2-4**               **Primary Use**                         **Relationship Matrix**

   Financial (default)       001           Monetary double-entry accounting        Account pair codes --- see Protocol v3.0

       Engineering           010        Physical flow and conservation logging    Universal flow archetypes --- see Section 2

         Hybrid              011        Financial + engineering in same session    Both matrices active, context per record

         Custom              111                 User-declared domain             Declared in extension block at session open
  --------------------- -------------- ----------------------------------------- ---------------------------------------------

**2. DOMAIN DECLARATION IN LAYER 1 (bits 2-4)**

The receiver learns the semantic context of the entire session within the first four bits it ever receives. Bit 1 is always 1 (SOH). Bits 2-4 carry both the wire format version and the domain. By the time the receiver has processed these four bits it knows whether to interpret subsequent records as financial entries, physical flow records, or something else entirely.

**2.1 Revised Bit 2-4 Assignment**

  -------------- ------------------------- ------------ --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
     **Bits**            **Field**          **Values**                                                                                                                                                 **Description**

    **Bit 2**     **Wire Format Version**     0 / 1                         0 = Wire format version 1 (current --- all records as specified in Protocol v3.0). 1 = Non-standard or future version. When bit 2=1, the receiver should treat the session as requiring special handling. See Section 2.3 for the version-as-control-signal mechanism.

   **Bits 3-4**         **Domain**            00-11      00=Financial (monetary double-entry, default, backward compatible with all v3.0 implementations). 01=Engineering (physical flow and conservation, this document). 10=Hybrid (financial and engineering matrices both active). 11=Custom (domain declared via extension block immediately following Layer 1).
  -------------- ------------------------- ------------ --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**2.2 Domain Code Mapping**

Bits 2-4:

0 00 = v1, Financial Universal default. Full backward compatibility.

Account pairs interpret as per Protocol v3.0.

Currency Code field = currency index.

0 01 = v1, Engineering Physical flow and conservation domain.

Account pairs interpret as universal flow archetypes.

Currency Code field = quantity type index.

0 10 = v1, Hybrid Both matrices active simultaneously.

Record-level domain disambiguation via

extension byte or debit/credit flag convention.

0 11 = v1, Custom Domain declared in extension block

immediately following Layer 1 close.

Receiver reads extension before any batch.

1 xx = Version signal See Section 2.3.

**2.3 When Bit 2 = 1 --- Version Signal**

The current protocol is wire format version 1, represented by bit 2 = 0. Wire format changes are expected to be rare --- the protocol was designed to be complete and minimal. However the bit exists to handle genuine future revisions without ambiguity.

When bit 2 = 1, the receiver recognises that the sender is operating under a different wire format or is signalling a capability negotiation. The cleanest interpretation --- consistent with the control record design philosophy --- is that bit 2 = 1 in Layer 1 acts as a flag that a version declaration control byte will follow the Layer 1 block before any batch header is transmitted.

When bit 2 = 1:

Receiver completes Layer 1 read and CRC-15 validation normally.

After session acceptance, receiver expects a control byte

before the first Layer 2 header.

Control byte format for version declaration:

0 101 VVVV

\| \|

\| 4-bit version payload (0000=v1, 0001=v2, etc.)

Type 101 = session parameter update (repurposed for version)

This allows the domain bits (bits 3-4) to still carry semantic meaning

even in a version-negotiation exchange, and keeps the version signal

within the existing control record architecture at zero new structure cost.

> *Tradeoff acknowledged: using bits 2-4 to carry both version and domain means a wire format version 2 financial implementation and a wire format version 1 engineering implementation cannot be distinguished by bits 3-4 alone when bit 2 differs. The control byte mechanism resolves this by making full version declaration explicit when bit 2 = 1, before any records are processed. For the overwhelming majority of deployments using current wire format version 1, bit 2 is always 0 and the domain is fully declared in bits 3-4 with no ambiguity.*

**3. THE UNIVERSAL RELATIONSHIP MATRIX**

In financial mode the 4-bit account pair field encodes which two account categories are involved in a transaction. In engineering mode the same 4 bits encode the relationship archetype between any two nodes, entities, or subsystems in the tracked system. The 16 possible codes define a complete vocabulary of directional flow semantics.

These 16 archetypes are not domain-specific. They are the fundamental ways that quantities relate between entities in any man-made system. A spacecraft subsystem consuming propellant, a satellite accruing a power debt, a factory station transferring work-in-process to the next station, and a microcontroller spending battery charge all express one of these 16 archetypes. The encoder selects the appropriate code. The conservation invariant enforces the accounting.

**3.1 Universal Flow Archetype Table**

  ---------- ----------------------- ---------------------------------------------------------------- ------------------------------------------------------------------------
   **Code**       **Archetype**                           **Canonical Meaning**                                               **Engineering Examples**

     0000        Source to Sink                    Direct one-way transfer of quantity                      Fuel tank to thruster. Battery to payload. Buffer to output.

     0001        Parent to Child        Hierarchical allocation from superior to subordinate node           Mission control allocating power budget to rover subsystem.

     0010      Debtor to Creditor       Obligation incurred --- quantity owed, not yet transferred       Satellite A owes 5 kWh to Satellite B. Component delivery pending.

     0011        Mutual Exchange                  Balanced bilateral trade between peers                 Energy swap between two satellites. Bandwidth-for-compute barter.

     0100      Loss / Dissipation              Quantity leaves the tracked system entirely                 Heat loss to space. Signal attenuation. Evaporation. Entropy.

     0101      Generation / Input            Quantity enters the tracked system from outside            Solar panel generating power. Resupply docking. Sensor data ingress.

     0110     Reservation / Escrow    Quantity committed but not yet moved --- locked for future use      Power reserved for emergency burn. Bandwidth allocation pending.

     0111      Repayment / Return       Fulfilling or reversing a prior obligation or reservation         Returning borrowed power. Restoring reserved bandwidth. Refund.

     1000        Transformation                 Quantity changes form within the same node                Chemical to kinetic energy (combustion). Raw to processed data.

     1001         Distribution                    One source node to multiple sink nodes                  Power bus distributing to multiple subsystems. Packet multicast.

     1010          Aggregation                    Multiple source nodes to one sink node                  Multiple sensors feeding one processor. Tributary to main store.

     1011       Internal Transfer             Movement within same entity between sub-nodes                 Tank A to Tank B within same spacecraft. Cache to register.

     1100      Obligation Transfer         Debt or liability reassigned between creditor nodes         Re-routing a power debt from one satellite to another. Subcontracting.

     1101         State Commit         Snapshot of current balance --- no flow, just a logged state      End-of-phase resource inventory. Checkpoint. Calibration baseline.

     1110       Correction / Void            Inference suspended. Correcting a prior record.               Telemetry correction. Sensor recalibration. Record amendment.

     1111     Compound Continuation         This record continues a preceding compound group.               Multi-stage burn. Simultaneous resource flows in one event.
  ---------- ----------------------- ---------------------------------------------------------------- ------------------------------------------------------------------------

**3.2 Conservation Invariant Across Archetypes**

The double-entry invariant holds across all 16 archetypes. Every archetype implies a source and a sink --- even Loss/Dissipation (the sink is the environment or a null node) and Generation/Input (the source is the environment). The direction bit and the relationship code together determine the sign of the flow:

Conservation rule for any record:

Outflow from source node = Inflow to sink node

Across a complete batch:

Sum of all signed flow values = 0 (mod precision step)

Equivalently --- Kirchhoff\'s flow law for the system:

For any node N in any batch:

Sum of all inflows to N = Sum of all outflows from N

This holds for mass, energy, data, obligations, or any conserved scalar.

**4. VALUE AS ANY CONSERVED SCALAR**

The value encoding formula N = A x 2\^S + r is domain-agnostic. It encodes any non-negative integer. The Scaling Factor and Decimal Position in Layer 2 define what that integer represents --- not currency denomination but physical unit magnitude and precision.

**4.1 Quantity Type Code (Layer 2 bits 36-41 in Engineering Mode)**

In financial mode this field carries a currency index. In engineering mode it carries a quantity type index. The same 6-bit field, 64 possible codes, seeded with physical and relational unit categories rather than world currencies.

  ----------- -------------------- ----------------------------- --------------- --------------------------------------------
   **Index**   **Quantity Type**         **Natural Unit**         **Default D**                   **Notes**

       0        Session default         Declared in Layer 1            \--              Inherits session quantity type

       1              Mass                     grams                    0         Use SF to scale: kg=x1000, tonnes=x1000000

       2             Energy                 watt-hours                  2           50.25 Wh stored as N=5025 at SF x1 D=2

       3          Data volume                kilobytes                  0              Integer KB. Use SF x1000 for MB

       4            Pressure                 millibars                  1             1013.2 mbar = N=10132 at SF x1 D=1

       5       Temperature delta          millidegrees C                0              Signed convention: see Section 8

       6         Time duration             milliseconds                 0                   86,400,000 ms = 1 day

       7       Electrical charge         milliampere-hours              2                   Battery state tracking

       8         Force / Thrust            millinewtons                 0                  Thruster output logging

       9           Bandwidth            kilobits per second             0                  Link capacity accounting

      10        Signal strength          dBm x 100 offset               0           Unsigned: 0 = -100 dBm, 10000 = 0 dBm

      11         Radiation dose             micrograys                  0                  Cumulative dose tracking

      12        Angular momentum             milli-Nms                  2                    Reaction wheel state

      13          Fluid volume              millilitres                 0            Water, coolant, propellant in volume

      14       Service obligation             minutes                   2                 Hours owed as service debt

      15         Resource units            user-defined               user             Abstract mission resource score

     16-62        User-defined       Declared at session open          \--                Engineering-specific units

      63         Multi-quantity     Per-record via control byte        \--                 Mixed-unit batch active
  ----------- -------------------- ----------------------------- --------------- --------------------------------------------

**4.2 Scaling Factor and Decimal Position in Physical Units**

The decode formula is unchanged. The Scaling Factor scales magnitude. The Decimal Position sets precision. The combination covers any physical quantity from sub-milligram to petajoule:

Real Quantity = (N x Scaling Factor) / 10\^DecimalPosition

Examples:

450 kg propellant:

Quantity Type = 1 (mass, grams)

SF=x1000, D=0 =\> N=450 =\> (450 x 1000) / 1 = 450,000 g = 450 kg

12,847.50 Wh of energy:

Quantity Type = 2 (energy, watt-hours)

SF=x1, D=2 =\> N=1,284,750 =\> (1,284,750 x 1) / 100 = 12,847.50 Wh

8,192 KB of data:

Quantity Type = 3 (data, kilobytes)

SF=x1, D=0 =\> N=8,192 =\> (8,192 x 1) / 1 = 8,192 KB

Signal at -73.50 dBm:

Quantity Type = 10 (signal, offset dBm x 100)

Offset convention: stored = (dBm + 100) x 100

SF=x1, D=0 =\> N=2650 =\> 2650 / 100 - 100 = -73.50 dBm

**4.3 Gapless Coverage Confirmed**

The mathematical coverage proof from Protocol v3.0 Section 4.2 applies identically to all physical quantities. For any target quantity V expressible as an integer multiple of the precision step:

N = V x 10\^D / SF

A = floor(N / 2\^S)

r = N mod 2\^S

Reconstruct: N = A x 2\^S + r = original N (exact, no gaps)

Maximum physical quantity at SF x1,000,000,000 D=0:

N_max = 33,554,431

Q_max = 33,554,431 x 1,000,000,000 g = 33,554,431 metric tonnes

This exceeds the mass of the International Space Station by a factor

of approximately 75 million --- in a single 40-bit record.

**5. LAYER 1 AND LAYER 2 IN ENGINEERING MODE**

The wire format of both layers is identical to the financial specification. What changes is the semantic interpretation of specific fields. This section specifies those reinterpretations precisely.

**5.1 Layer 1 --- Engineering Mode Reinterpretation**

  --------------- --------------------------------- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
     **Field**          **Financial Meaning**                                                                                     **Engineering Mode Meaning**

     Bits 2-4        Version 001 = Protocol v3.0                                                                        Bit 2=version, Bits 3-4=domain. 010=Engineering.

     Bits 5-8       Read/Write/Correct/Represent     Observe / Actuate / Override / Proxy. Semantics shift: Represent becomes Proxy --- one node acting as an intermediary transmitter for another node it cannot communicate with directly.

     Sender ID     Financial institution or entity    Any node, device, subsystem, satellite, sensor, controller, or autonomous agent. 32-bit space covers 4.29 billion distinct nodes --- adequate for any conceivable engineered network.

   Sub-Entity ID    Department, branch, division                                  Sub-node or sub-system. Thruster #3 under Propulsion. Sensor cluster B under Environmental. Chip core 2 under processor node.

     Bits 9-12      Session defaults (accounting)          Session defaults (engineering). Bit 11 compound mode is especially significant --- most real engineering events involve simultaneous flows across multiple resource types.
  --------------- --------------------------------- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**5.2 Layer 2 --- Engineering Mode Reinterpretation**

  ---------------------------- ------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
           **Field**                   **Financial Meaning**                                                                                          **Engineering Mode Meaning**

         Scaling Factor         Denomination multiplier (x1 to x1B)             Physical unit magnitude multiplier. x1000 converts grams to kilograms. x3600 converts watt-seconds to watt-hours (use custom SF index via control byte type 101 escape).

        Decimal Position        Cent precision, pip precision etc.                                         Physical measurement precision. 0=integer units. 2=hundredths of unit. 3=milliunit. Matches instrument resolution.

   Currency Code (bits 36-41)          6-bit currency index                                                               Quantity Type Code. 64 codes seeded with physical unit categories. See Section 4.1.

        Rounding Balance          Net monetary rounding in batch      Conservation error in batch. Non-zero rounding balance in a physical batch signals a potential mass or energy balance violation --- more significant in engineering than financial contexts.

        Group Separator             Accounting period, division                                                                Mission phase. Major system boundary (e.g. pre-launch / ascent / orbital).

        Record Separator             Record group within batch                                                           Entity group. All subsystems within one spacecraft. All nodes on one network segment.

         File Separator                Logical file context                                                      System boundary crossing. Transition from ground segment to space segment. Factory floor to logistics.

        Compound Prefix           Multi-leg financial transaction                                           Multi-resource engineering event. Engine firing consuming propellant and generating thermal load simultaneously.
  ---------------------------- ------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**6. CONSERVATION INVARIANT AS ENGINEERING INTEGRITY**

In financial mode the batch conservation check confirms that debits equal credits. In engineering mode it confirms that the tracked quantity is conserved across all flows in the batch. This is not a derived property --- it is the same algebraic invariant operating on physical quantities rather than monetary ones.

**6.1 The Invariant Stated**

For any closed system batch:

Sum of all FLOW OUT values = Sum of all FLOW IN values

Equivalently:

Sum of all signed flow values = 0 (within rounding tolerance)

This is enforced by:

1\. The double-entry structure of every 40-bit record

(each record encodes both sides of a flow simultaneously)

2\. The Rounding Balance field in Layer 2

(declares net conservation error for the batch)

3\. The batch close control record count

(confirms all records arrived --- no flow records lost in transit)

If propellant leaves Tank A, it must arrive somewhere.

If it does not, the batch balance is non-zero.

The protocol detects this without any application-level audit.

**6.2 Comparison to Conventional Telemetry**

  --------------------------- ------------------------------- -------------------------------------------------------
        **Capability**               **Raw Telemetry**                    **BitLedger Engineering Mode**

   Records individual events                Yes                                         Yes

    Verifies bit integrity          CRC on packet only         CRC-15 on session + cross-layer validation per record

     Detects lost records         No --- silent data gap                Yes --- batch close count mismatch

     Enforces conservation     No --- application must check             Yes --- at wire level, per batch

     Detects phantom flows                  No                    Yes --- unpaired flow creates non-zero balance

    Handles compound events    Multi-packet, complex parsing        Native compound continuation, single stream

     Transmission overhead      Variable, schema-dependent                 Fixed 40 bits per flow record
  --------------------------- ------------------------------- -------------------------------------------------------

**6.3 Conservation Tolerance in Physical Systems**

Physical measurements have instrument resolution limits. A fuel flow sensor accurate to 1 gram cannot verify conservation to sub-gram precision. The Rounding Balance field and the Decimal Position in Layer 2 together define the acceptable conservation tolerance for the batch:

Acceptable tolerance = Precision Step x Max Rounding Balance

Example:

Quantity Type: mass (grams)

SF=x1, D=0 =\> Precision Step = 1 gram

Rounding Balance = 3 (net +3 grams rounded up)

Acceptable tolerance = 1g x 3 = 3 grams

If actual mass balance error exceeds this:

Rounding Balance = 1000 (escape) =\> see batch close for full value

Receiver flags anomalous conservation error for investigation

**7. ENGINEERING WORKED EXAMPLES**

Four complete examples each showing the full 40-bit record with field annotation and engineering journal output. All use wire format v1, engineering domain (bits 2-4 = 010).

**7.1 Spacecraft Propellant Burn**

Propulsion subsystem flows 450 kg (450,000 grams) from Tank Assembly to Main Engine Thruster Array. Archetype: Source to Sink (0000). Exact. Settled.

Layer 2: Quantity Type=1 (mass), SF=x1, D=0 (step=1 gram)

Encoding: N = 450,000

S=8: A = floor(450,000/256) = 1,757

r = 450,000 mod 256 = 88

Bits 1-17 : 00000011011011101 A = 1,757

Bits 18-25 : 01011000 r = 88

Bit 26 : 0 exact

Bit 27 : 0 must be 0

Bit 29 : 1 Out --- quantity leaves tank assembly

Bit 30 : 0 Paid --- transfer complete

Bit 31 : 1 Debit --- tank is debited

Bit 32 : 0 flat value

Bits 33-36 : 0000 Source to Sink

Bit 37 : 1 Out --- matches bit 29 VALID

Bit 38 : 0 Paid --- matches bit 30 VALID

Bit 39 : 0 Full

Bit 40 : 0 no extension

Verify: (1,757 x 256 + 88) = 450,000 =\> 450,000 g = 450 kg exact

─────────────────────────────────────────────────────────────────

BITLEDGER FLOW RECORD

Session : Artemis IV / Propulsion Sub (node 03)

Batch : Phase 02 / Event 007 / Unit: grams (mass)

─────────────────────────────────────────────────────────────────

FLOW OUT Propellant Tank Assembly g 450,000

FLOW IN Main Engine Thruster Array g 450,000

─────────────────────────────────────────────────────────────────

Description : Nominal burn. 450 kg propellant transferred.

Relationship: Source to Sink --- direct transfer

Status : Settled --- quantity transferred and logged

Precision : Exact

─────────────────────────────────────────────────────────────────

**7.2 Inter-Satellite Power Debt**

Satellite Alpha draws 12,847.50 Wh from Satellite Beta under a power-sharing agreement. Not yet repaid. Archetype: Debtor to Creditor (0010). Status = Debt.

Layer 2: Quantity Type=2 (energy, Wh), SF=x1, D=2 (step=0.01 Wh)

Encoding: N = 12,847.50 x 100 = 1,284,750

A = floor(1,284,750/256) = 5,018

r = 1,284,750 mod 256 = 62

Bits 33-36 : 0010 Debtor to Creditor

Bit 30 : 1 Debt --- obligation not yet fulfilled

Bit 38 : 1 Debt --- matches bit 30 VALID

All other flags: standard

Verify: (5,018 x 256 + 62) = 1,284,670 x 1 / 100 = 12,846.70 Wh

Hmm --- check: 5018 x 256 = 1,284,608 + 62 = 1,284,670 != 1,284,750

Recalculate: A=floor(1,284,750/256) = floor(5018.55) = 5018

r=1,284,750 - 5018x256 = 1,284,750-1,284,608 = 142

Correct: A=5018, r=142

Verify: (5,018 x 256 + 142) = 1,284,750 / 100 = 12,847.50 Wh exact

─────────────────────────────────────────────────────────────────

BITLEDGER FLOW RECORD

Session : Constellation Ops / Alpha (node 01)

Batch : Orbit 142 / Event 003 / Unit: watt-hours (energy)

─────────────────────────────────────────────────────────────────

FLOW OUT Satellite Beta Power Reserve Wh 12,847.50

FLOW IN Satellite Alpha Draw Account Wh 12,847.50

─────────────────────────────────────────────────────────────────

Description : Emergency power draw under constellation

sharing agreement. Repayment pending.

Relationship: Debtor to Creditor --- obligation incurred

Status : Debt --- quantity drawn, repayment not yet made

Precision : Exact

─────────────────────────────────────────────────────────────────

**7.3 Compound Event --- Engine Firing with ECLSS Thermal Impact**

A main engine firing simultaneously consumes propellant (Source to Sink) and creates a thermal load obligation on the life support system (Debtor to Creditor). Two records linked by compound continuation.

Layer 2: Compound Prefix=01. Two quantity types in same batch.

Layer 1: Bit 11=1 (compound mode active)

RECORD 1 --- Propellant flow (standard record)

Quantity Type=1 (mass), 180,000 g (180 kg), Source to Sink

N=180,000: A=703, r=32

Bits 33-36 : 0000 Source to Sink

Bit 39 : 1 Partial --- compound continuation follows

Bit 40 : 0 no extension

CONTROL BYTE between records:

0 001 0010 --- Currency/Quantity change to index 2 (energy, Wh)

Receiver updates quantity type for next record

RECORD 2 --- Thermal obligation (1111 continuation)

Quantity Type=2 (energy), 847.50 Wh thermal load

N=84,750: A=331, r=14

Bits 33-36 : 1111 Compound continuation

Bits 37-38 : 00 Standard linked entry

Bit 39 : 0 Full --- compound closed

─────────────────────────────────────────────────────────────────

BITLEDGER COMPOUND FLOW RECORD \[1 of 2\]

Session : Artemis IV / GNC System (node 02)

─────────────────────────────────────────────────────────────────

FLOW OUT Propellant Tank Assembly g 180,000

FLOW IN Main Engine Thruster Array g 180,000

─────────────────────────────────────────────────────────────────

Relationship: Source to Sink \| Status: Settled \| Exact

Continuation: Record 2 follows (thermal obligation)

─────────────────────────────────────────────────────────────────

─────────────────────────────────────────────────────────────────

BITLEDGER COMPOUND FLOW RECORD \[2 of 2\] --- CONTINUATION

Linked to Record 1 / Sub-type: Standard

─────────────────────────────────────────────────────────────────

FLOW OUT ECLSS Thermal Reserve Wh 847.50

FLOW IN Propulsion Heat Sink Obligation Wh 847.50

─────────────────────────────────────────────────────────────────

Relationship: Debtor to Creditor \| Status: Debt \| Exact

Group Close : Compound event complete.

─────────────────────────────────────────────────────────────────

**7.4 IoT Edge --- Sensor Data Packet Accounting**

An environmental sensor node transmits 8,192 KB of data to a gateway. Bandwidth units tracked. Archetype: Source to Sink (0000). Timestamp offset extension byte added.

Layer 2: Quantity Type=3 (data, KB), SF=x1, D=0 (step=1 KB)

Encoding: N=8,192

A = floor(8,192/256) = 32

r = 8,192 mod 256 = 0

Bits 1-17 : 00000000000100000 A=32

Bits 18-25 : 00000000 r=0

Bits 33-36 : 0000 Source to Sink

Bit 40 : 1 extension follows (timestamp offset)

EXTENSION BYTE:

8 bits = timestamp offset from session epoch

Value = 143 (143 seconds since session open)

Verify: (32 x 256 + 0) = 8,192 KB exact

─────────────────────────────────────────────────────────────────

BITLEDGER FLOW RECORD

Session : Field Sensor Net / Node ENV-07 (node 07)

Batch : Cycle 0412 / Event 001 / Unit: kilobytes (data)

─────────────────────────────────────────────────────────────────

FLOW OUT Sensor Node ENV-07 Buffer KB 8,192

FLOW IN Gateway Ingress Queue KB 8,192

─────────────────────────────────────────────────────────────────

Description : Sensor burst transmission. 8 MB data packet.

Relationship: Source to Sink --- direct transfer

Timestamp : T+143 seconds from session open

Status : Settled \| Precision: Exact

─────────────────────────────────────────────────────────────────

**8. TRANSMISSION RESILIENCE FOR CHALLENGED ENVIRONMENTS**

The BitLedger error detection architecture was designed for financial data integrity. In engineering deployments --- particularly aerospace, deep space, and remote industrial contexts --- the same mechanisms provide resilience against physical transmission hazards that financial systems never encounter.

**8.1 Three-Layer Error Detection**

  ----------- -------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------- ---------------------------------
   **Layer**                    **Mechanism**                                                                                      **What It Catches**                                                                               **Cost**

    Session             CRC-15 over Layer 1 (64 bits)               Bit flips in sender identity, permissions, domain declaration, or session defaults. Protects the foundation on which all records are interpreted.         15 bits, computed once

    Record     Cross-layer validation: bit29=bit37, bit30=bit38   Single or double-bit errors in direction or status flags that would cause a flow to be posted in the wrong direction or with wrong settlement status.   0 bits --- uses existing fields

    Record       Invalid rounding state: bit26=0 and bit27=1                          Single-bit corruption in the rounding signal that would misclassify an exact value as rounded or vice versa.                        0 bits --- uses existing fields

     Batch        Conservation invariant + Rounding Balance          Any flow record that causes a non-zero batch balance --- including phantom flows created by corruption, missing records, or duplicated records.             4 bits in Layer 2

     Batch                 Batch close record count                                 Missing or duplicated records in transit. Count mismatch signals incomplete batch before any records are posted.                        8 bits, one control record
  ----------- -------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------- ---------------------------------

**8.2 Deep Space Context**

At interplanetary distances a single galactic cosmic ray can flip multiple bits in a memory register or transmission buffer. Standard error correction codes at the transport layer (CCSDS, DTN) handle raw bit errors. BitLedger\'s conservation-invariant validation operates at the semantic layer --- it catches errors that byte-level correction misses.

Scenario: cosmic ray flips bit 29 of a flow record mid-transmission.

Without BitLedger:

Transport layer CRC passes (bit flip undetected at packet level).

Flow record is posted with wrong direction.

Propellant recorded as arriving at tank instead of leaving it.

Mass balance error propagates silently into mission planning.

With BitLedger:

Bit 29 != Bit 37 =\> cross-layer validation FAILS.

Record rejected before posting.

NACK sent. Retransmission requested.

Mass balance preserved.

**8.3 Transport Compatibility**

BitLedger records are transport-agnostic. The 40-bit record is a self-contained payload. It can be carried inside any transport protocol without modification:

  ----------------------- -------------------------------------- -------------------------------------------------------------------------------------------------------------
       **Transport**                   **Context**                                                            **BitLedger Role**

           CCSDS                   Spacecraft telemetry           BitLedger records as CCSDS packet payload. Transport handles routing; BitLedger handles semantic integrity.

   DTN / Bundle Protocol   Deep space delay-tolerant networking           BitLedger session survives link interruptions. Layer 1 CRC validates session on reconnect.

           MQTT                     IoT edge networks                 BitLedger records as MQTT message payload. Broker handles delivery; BitLedger handles conservation.

          Raw RF             Point-to-point embedded systems            BitLedger records transmitted directly. No transport overhead. Minimum 5 bytes per flow event.

       Ethernet / IP        Industrial control, factory floor       BitLedger over UDP or TCP. Batch close control record provides application-layer delivery confirmation.
  ----------------------- -------------------------------------- -------------------------------------------------------------------------------------------------------------

**9. SEMANTIC DECLARATION AT SESSION OPEN**

When domain bits 3-4 are set to 11 (Custom), the receiver needs additional context to interpret the relationship matrix and quantity types. This context is declared in a structured extension block transmitted immediately after the Layer 1 close, before the first Layer 2 batch header.

**9.1 When Declaration Is Required**

  -------------- ------------- --------------------------- ----------------------------------------------------------------------------------------
   **Bits 3-4**   **Domain**    **Declaration Required?**                                   **Decoder Behaviour**

        00         Financial               No                   Load financial account pair labels and currency table. Standard Protocol v3.0.

        01        Engineering              No               Load universal flow archetype labels and physical quantity type table (this document).

        10          Hybrid               Partial             Load both label sets. Record-level disambiguation via extension byte when ambiguous.

        11          Custom                 Yes                             Wait for extension block before processing any batches.
  -------------- ------------- --------------------------- ----------------------------------------------------------------------------------------

**9.2 Custom Domain Extension Block**

The custom domain extension block is a variable-length structure following Layer 1. It redefines the 16 relationship codes and up to 64 quantity type codes for the session. Its length is declared in its first byte:

CUSTOM DOMAIN EXTENSION BLOCK

Byte 1 : Block length in bytes (1-255)

Bytes 2-3 : Domain identifier string prefix (2 ASCII chars)

e.g. \'SC\' = spacecraft, \'MF\' = manufacturing,

\'RB\' = robotics, \'SG\' = smart grid

Byte 4 : Number of relationship codes being declared (1-16)

Bytes 5+ : Relationship code declarations

Each declaration = 1 byte code + 2 byte label index

Label index references a shared label dictionary

\... : Quantity type code declarations (same format)

Final byte: CRC-8 over the block for integrity

> *In practice the standard Engineering domain (bits 3-4 = 01) covers the large majority of real deployments. The Custom domain is provided for highly specialised systems where the 16 universal archetypes do not adequately describe the relationship types in the system being modelled.*

**10. IMPLEMENTATION NOTES FOR ENGINEERING DEPLOYMENTS**

**10.1 Handling Negative Physical Quantities**

The BitLedger value block encodes non-negative integers only. Physical quantities that can be negative --- temperature deviation, voltage offset, net angular momentum --- require a signed convention. Two approaches:

APPROACH A --- Offset encoding:

Store value + offset where offset places zero at a convenient point.

Signal strength example: stored = (dBm + 100) x 100

-73.50 dBm =\> (−73.50 + 100) x 100 = 2,650 (positive, exact)

Declare offset in Layer 1 custom extension or session documentation.

APPROACH B --- Direction bit as sign:

Use the Direction bit (bit 29) to carry the sign of a deviation.

0 = positive deviation from baseline

1 = negative deviation from baseline

Baseline declared in Layer 2 Quantity Type metadata.

Value block always carries the magnitude of the deviation.

**10.2 Multi-Quantity Batches**

When a single batch must contain records using different quantity types --- propellant mass and thermal energy in the same event log --- use control record type 001 (Quantity Type change) between records:

Record A: Quantity Type=1 (mass)

0 001 0010 \-- control: switch to quantity type index 2 (energy)

Record B: Quantity Type=2 (energy)

0 001 0001 \-- control: restore to quantity type index 1 (mass)

Record C: Quantity Type=1 (mass)

**10.3 Seeding the Quantity Type Table**

In the Python implementation, the currencies.py module is replaced or supplemented with a quantity_types.py module for engineering deployments:

QUANTITY_TYPES = {

0: {\'name\': \'Session Default\', \'unit\': None, \'decimals\': None},

1: {\'name\': \'Mass\', \'unit\': \'g\', \'decimals\': 0},

2: {\'name\': \'Energy\', \'unit\': \'Wh\', \'decimals\': 2},

3: {\'name\': \'Data Volume\', \'unit\': \'KB\', \'decimals\': 0},

4: {\'name\': \'Pressure\', \'unit\': \'mbar\', \'decimals\': 1},

5: {\'name\': \'Temperature Delta\',\'unit\': \'mdeg\', \'decimals\': 0},

6: {\'name\': \'Time Duration\', \'unit\': \'ms\', \'decimals\': 0},

7: {\'name\': \'Charge\', \'unit\': \'mAh\', \'decimals\': 2},

8: {\'name\': \'Thrust\', \'unit\': \'mN\', \'decimals\': 0},

9: {\'name\': \'Bandwidth\', \'unit\': \'kbps\', \'decimals\': 0},

10: {\'name\': \'Signal Strength\', \'unit\': \'dBmx100\',\'decimals\':0},

\# \... extend as needed

63: {\'name\': \'Multi-Quantity\', \'unit\': None, \'decimals\': None},

}

**10.4 Journal Entry Labels for Engineering Mode**

The formatter.py module checks the session domain flag and substitutes engineering-appropriate labels:

ENGINEERING_ARCHETYPE_NAMES = {

0b0000: (\'Source Node\', \'Sink Node\'),

0b0001: (\'Parent Node\', \'Child Node\'),

0b0010: (\'Debtor Node\', \'Creditor Node\'),

0b0011: (\'Exchange Party A\', \'Exchange Party B\'),

0b0100: (\'System\', \'Loss / Environment\'),

0b0101: (\'Source / Environment\', \'System\'),

0b0110: (\'Reservation Pool\', \'Escrow Hold\'),

0b0111: (\'Repayment Source\', \'Original Creditor\'),

0b1000: (\'Input Form\', \'Output Form\'),

0b1001: (\'Distribution Source\',\'Sink Nodes\'),

0b1010: (\'Source Nodes\', \'Aggregation Sink\'),

0b1011: (\'Sub-Node A\', \'Sub-Node B\'),

0b1100: (\'Original Creditor\', \'New Creditor\'),

0b1101: (\'State Node\', \'Snapshot Record\'),

0b1110: (\'Correction\', \'Correction\'),

0b1111: (\'\*\* CONTINUATION \*\*\',\'\*\* SEE PRIOR RECORD \*\*\'),

}

\# Journal entry header changes by domain:

DOMAIN_HEADERS = {

0b00: \'BITLEDGER JOURNAL ENTRY\',

0b01: \'BITLEDGER FLOW RECORD\',

0b10: \'BITLEDGER HYBRID RECORD\',

0b11: \'BITLEDGER CUSTOM RECORD\',

}

**11. REAL-WORLD ENGINEERING DEPLOYMENTS**

The following table maps real engineering systems to their natural BitLedger configuration. In every case the wire format is identical to the financial specification. Only the semantic layer changes.

  --------------------------------- --------------------------------------------- ---------------------------------------------- ---------------------------------------------------------------------------------------------
             **System**                         **Primary Quantity**                       **Relationship Types Used**                                                     **Notes**

   Spacecraft life support (ECLSS)     Mass (atmosphere gases, water), energy       Source-Sink, Loss, Generation, Reservation      Conservation of oxygen, CO2, water. Any non-zero balance flags a leak or sensor fault.

        Propellant management               Mass (propellant, pressurant)          Source-Sink, Internal Transfer, State Commit                 Burn records link to thrust produced via compound continuation.

       Satellite power system                    Energy (watt-hours)                 Source-Sink, Debt-Creditor, Reservation             Solar generation vs. load tracking. Power debt between constellation members.

      Deep space communication           Data volume (KB), bandwidth (kbps)               Source-Sink, Reservation, Loss                       Link budget accounting. Data volume transmitted vs. acknowledged.

       Factory / supply chain              Mass (materials), service-hours            Parent-Child, Debt-Creditor, Internal              Work-in-process tracking between stations. Just-in-time delivery obligations.

             Smart grid                     Energy (kWh), reactive power                Source-Sink, Mutual Exchange, Loss                           Grid balance logging. Prosumer credit/debit tracking.

             Robot swarm                     Task units, battery charge              Parent-Child, Distribution, Aggregation            Task allocation from coordinator. Charge sharing between idle and active units.

      Autonomous vehicle fleet              Fuel / charge, route segments            Source-Sink, Debt-Creditor, Reservation                    Charging reservation. Range debt when one vehicle tows another.

         IoT sensor network                   Data packets, battery mAh                  Source-Sink, Loss, State Commit                     Data delivery accounting. Battery state snapshots at fixed intervals.

      Mars colony supply chain       Mass (food, water, O2, parts), person-hours             All 16 archetypes active             Most complex deployment. Hybrid domain with financial obligations for Earth-side contracts.
  --------------------------------- --------------------------------------------- ---------------------------------------------- ---------------------------------------------------------------------------------------------

**12. RELATIONSHIP TO THE FINANCIAL SPECIFICATION**

This document and the BitLedger Protocol Specification v3.0 together define a complete multi-domain standard. The financial specification is the wire format authority. This document is the engineering domain semantic layer.

**12.1 What Is Shared**

  ----------------------------------------- ------------ -----------------------------------------------------------------------
                **Component**                **Status**                                 **Notes**

           40-bit record structure           Identical    Every bit position has the same location and width across all domains

   Value encoding formula N = A x 2\^S + r   Identical                    Domain-agnostic. Encodes any integer.

              CRC-15 on Layer 1              Identical         Same polynomial, same coverage, same verification procedure

        Cross-layer validation rules         Identical      Bits 29=37, 30=38, invalid state 01 --- all apply in all domains

           Conservation invariant            Identical           The algebraic invariant holds for any conserved scalar

          Control record structure           Identical        Leading 0, 3-bit type, 4-bit payload --- same in all domains

            Compound continuation            Identical      1111 marker, sub-type bits 37-38, Completeness flag --- unchanged

          Extension byte mechanism           Identical      Bit 40 flag, chain bit 8, all uses available in engineering mode

         Encoder decision algorithm          Identical         Decimal.Decimal arithmetic, rounding rules, overflow check
  ----------------------------------------- ------------ -----------------------------------------------------------------------

**12.2 What Differs by Domain**

  -------------------------------- --------------------------------------- ---------------------------------------------------
           **Component**                **Financial (bits 3-4 = 00)**                **Engineering (bits 3-4 = 01)**

      4-bit pair field meaning        Account pair (14 financial pairs)         Flow archetype (16 universal archetypes)

     6-bit quantity type field         Currency code (USD, EUR, etc.)       Physical quantity type (mass, energy, data, etc.)

      Scaling Factor semantics              Monetary denomination                        Physical unit magnitude

       Journal output labels            DEBIT / CREDIT, account names                FLOW OUT / FLOW IN, node names

   Rounding accounting convention   Liability up, asset down, income down       Conservation tolerance per quantity type

    Group/Record/File separators         Period, record group, file           Mission phase, entity group, system boundary
  -------------------------------- --------------------------------------- ---------------------------------------------------

**12.3 Hybrid Sessions**

When bits 3-4 = 10 (Hybrid), both semantic layers are active simultaneously. A single batch can contain records that represent financial obligations alongside physical flow records. This is the appropriate domain for systems where engineering operations create financial consequences --- mission operations with contractual billing, industrial processes with commodity trading, or infrastructure with financial settlement.

In hybrid mode, the decoder uses the debit/credit flag (bit 31) as a domain disambiguation signal: when the account pair code maps to a financial pair (0000-1101 in the financial table) it is a financial record; when it maps to a physical archetype it is an engineering record. Where the codes overlap, the extension byte carries a 1-bit domain flag.

**12.4 Protocol Change Log --- Universal Domain Additions**

  ---------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- -----------------
   **Item**                                                                                                  **Change**                                                                                                     **Status**

      31      Bits 2-4 reinterpreted: bit 2=wire format version, bits 3-4=domain. 000=reserved, 001=financial (v1), 010=engineering (v1), 011=hybrid, 111=custom. Bit 2=1 signals version control byte follows Layer 1.      Confirmed

      32                                                   Layer 2 Currency Code field (bits 36-41) reinterpreted as Quantity Type Code in engineering and hybrid domains.                                                   Confirmed

      33                                                  Universal flow archetype table defined. 16 codes cover all canonical relationship types in any engineered system.                                                  Confirmed

      34                                                    Physical quantity type table defined. 64 codes seeded with standard physical and relational unit categories.                                                     Confirmed

      35                                     Journal entry formatter extended with domain-aware label vocabulary. Header, flow direction labels, and account names all domain-dependent.                                     Confirmed

      36                              Conservation tolerance definition formalised. Rounding Balance in Layer 2 reinterpreted as acceptable conservation error margin for physical quantities.                               Confirmed
  ---------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- -----------------

**13. GLOSSARY --- ENGINEERING DOMAIN**

  ------------------------ ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
          **Term**                                                                                                    **Definition**

   Conservation Invariant    The requirement that the sum of all signed flow values in a batch equals zero. The engineering equivalent of double-entry balance. Enforced at the wire level by the BitLedger record structure.

           Domain                                 The semantic interpretation context for a BitLedger session. Declared in Layer 1 bits 3-4. Financial (00), Engineering (01), Hybrid (10), Custom (11).

       Flow Archetype                            One of 16 canonical relationship types encoded in the 4-bit pair field in Engineering domain. Defines the directional flow semantics between two nodes.

        Flow Record                                 An engineering-mode BitLedger record. Equivalent to a Journal Entry in financial mode. Records the flow of a conserved quantity between two nodes.

       Hybrid Domain                                                   Session mode where both financial and engineering semantic layers are simultaneously active. Bits 3-4 = 10.

    Kirchhoff Invariant     The circuit law stating sum of currents at any node equals zero. Structurally identical to the BitLedger conservation invariant --- both are statements of conservation applied to a flow network.

            Node                                            Any entity in an engineering deployment that can send or receive a conserved quantity. Equivalent to an account in financial mode.

     Quantity Type Code                                  The 6-bit field in Layer 2 bits 36-41 reinterpreted in engineering mode. Declares the physical unit category of all values in the batch.

      Proxy Permission             Layer 1 bit 8 reinterpreted in engineering mode. Permits one node to transmit records on behalf of another node it relays for --- equivalent to the financial Represent permission.

       Semantic Layer                                     The domain-specific interpretation of the 4-bit relationship matrix and the 6-bit quantity type field. Does not alter the wire format.

    Wire Format Version                                                  Layer 1 bit 2. 0 = version 1 (current). 1 = non-standard version, control byte follows for declaration.
  ------------------------ ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
