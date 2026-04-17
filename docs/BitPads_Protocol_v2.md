**BITPADS**

**UNIVERSAL COMMUNICATION PROTOCOL**

*Specification v2.0 --- Updated for Enhancement Sub-Protocol Compatibility*

*From a single heartbeat byte to a fully identified,*

*timestamped, valued, tasked civilisational record ---*

*in as few as one byte.*

Companion to BitLedger Protocol Specification v3.0

and BitLedger Universal Domain Specification v1.0

**Read with: BitPads Enhancement Sub-Protocol v2.0**

> *v2.0 CHANGES: Meta byte 2 bit 8 reassigned. Layer 1 bit 12 reassigned as Session Enhancement Flag. Opposing Convention moved to extension byte. Categories 1100/1101/1110 formally assigned. Component ordering updated. Role A bit 6 corrected. Parser state machine updated for enhancement states. Transmission footprints include enhancement overhead. All changes marked with green shading throughout.*

**1. PHILOSOPHY AND FIRST PRINCIPLES**

BitPads is the outermost layer of the BitLedger protocol family. Where BitLedger defines how to encode a financial or physical transaction with perfect fidelity in 40 bits, and the Universal Domain extends that to any conserved quantity in any engineered system, BitPads defines the meta layer that wraps all of it --- the civilisational unit of communication.

The design draws its first principles from the oldest communication systems in human history. Sumerian accounting tokens, cuneiform clay tablets, and tally sticks all share a common architecture: a compact mark that carries expanded meaning at the receiver\'s end because both parties share a codebook. The mark itself is minimal. The meaning is rich. The codebook is held in shared context, not transmitted with every message.

> *BitPads formalises this ancient principle in binary: a Meta byte declares the type and shape of what follows. The receiver, knowing the type, knows exactly how to expand the meaning. The common case costs one byte. Complexity attaches on demand, as modules, at exact cost proportional to the complexity it expresses.*

**1.1 The Microservices Architecture Principle**

Every design decision in BitPads is governed by one architectural principle: the system bytes carry only invariant, load-bearing logic. Everything else is a module.

CORE INFRASTRUCTURE:

Meta byte 1 --- universal transmission header

Meta byte 2 --- extended context, Record mode only

Layer 1 --- session identity and integrity

Layer 2 --- batch context (inherited from BitLedger)

MODULES (present only when needed, zero cost when absent):

Signal Slot Presence byte --- C0 enhancement slot declaration

System Context Extension --- when identity needs triangulation

Setup byte --- when value context is non-default

Value block --- when a quantity is being transmitted

Time field --- when temporal context matters

Task block --- when an action is being requested

Note block --- when narrative content is needed

Extension bytes --- when any module needs more detail

BitLedger Context ctrl --- when full double-entry accounting

C0 Enhancement Module --- when industrial-strength signalling

**1.2 The Transmission Spectrum**

  ---------------- -------------- --------------------------------------------------------- -------------------------------------------------------------------
      **Type**      **Min Size**                       **Description**                                                 **Use Cases**

    Pure Signal        1 byte            Single Meta byte. The byte IS the message.                Heartbeat, ACK request, status flag, presence beacon

        Wave         2-6 bytes               Meta byte plus lightweight content.                       Simple value, status, command, short message

       Record       12-21 bytes       Meta bytes plus Layer 1 identity and components.               Identified transaction, logged event, measurement

   Full BitLedger    28+ bytes     Record with complete BitLedger double-entry accounting.   Financial transaction, resource flow, conservation-verified event
  ---------------- -------------- --------------------------------------------------------- -------------------------------------------------------------------

**2. META BYTE 1 --- THE UNIVERSAL HEADER**

Meta byte 1 is present at the start of every BitPads transmission without exception. It is the table of contents for everything that follows.

**2.1 Complete Bit Layout**

  -------------- ---------------------- ------------ ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
     **Bits**          **Field**         **Values**                                                                                **Description**

    **Bit 1**         BitPad Mode          0 / 1           0=Wave mode. Lightweight. No Layer 1 required unless category demands it. 1=Record mode. Full BitPad. Meta byte 2 follows immediately. Layer 1 always expected.

    **Bit 2**     ACK Request / SysCtx     0 / 1             DUAL ROLE. Wave (bit1=0): 1=ACK request. Single byte with only bit2=1 is the universal pulse. Record (bit1=1): 1=System Context Extension follows Layer 1.

    **Bit 3**         Continuation         0 / 1                                    0=Complete, self-contained. 1=Fragment. Receiver accumulates until bit3=0. Universal across Wave and Record.

    **Bit 4**       Treatment Switch       0 / 1      Wave mode only. 0=Basic treatment, bits 5-8 are Role A descriptors. 1=Category mode, bits 5-8 are Role B category code. Ignored in Record mode --- Role C always applies.

   **Bits 5-8**      Content Field         varies                    Role A: descriptor flags when bit1=0, bit4=0. Role B: 4-bit category code when bit1=0, bit4=1. Role C: component expect flags when bit1=1.
  -------------- ---------------------- ------------ ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**2.2 Bits 5-8 Role A --- Wave Basic Treatment (bit1=0, bit4=0)**

  ----------- ------------------- ------------ --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   **Bits**        **Field**       **Values**                                                                                                          **Description**

   **Bit 5**     Priority Flag        0/1                                                                           0=Normal priority. 1=Elevated. Receiver processes before lower-priority pending items.

   **Bit 6**   **Cipher Active**      0/1       UPDATED v2.0: 0=Plain stream. 1=Stream category obscuration active via rolling codebook. The active codebook has been shifted from session baseline. Not a cryptographic guarantee. See Enhancement Sub-Protocol Section 13.3.

   **Bit 7**    Extended Flags        0/1                                0=No extension. 1=Descriptor extension byte follows Meta byte 1 before content. Carries additional Wave-mode flags including Wave-layer signal slot declarations (P12/P13).

   **Bit 8**    Profile Defined       0/1                                                                  0=Standard protocol. 1=Profile-specific behaviour declared at session open applies to this transmission.
  ----------- ------------------- ------------ --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

> *v2.0: Bit 6 corrected from \'ACK Request\' to \'Cipher Active\'. ACK Request is carried by bit 2 in Wave mode. Cipher Active signals that the rolling codebook mechanism from the Enhancement Sub-Protocol is active for this stream.*

**2.3 Bits 5-8 Role B --- Wave Category Mode (bit1=0, bit4=1)**

  ---------- ------------------------- -------------- --------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------
   **Code**        **Category**         **Layer 1?**                                **Content Structure**                                                                              **Notes**

     0000           Plain Value          No (est.)                    Setup byte (opt.) + Value block at declared tier                                                         Most common Wave category

     0001         Simple Message         No (est.)                             1-byte length prefix + content                                                                Length-prefixed text or data

     0010          Status / Log          No (est.)                           Status code or length + log content                                                              Status update or log entry

     0011        Command / Request       No (est.)                     Task short form (1 byte) + optional extensions                                                          Single command or request

     0100          Basic Record             YES                          Layer 1 + opt. Layer 2 + value + opt. time                                                             Structured value record

     0101      Transaction + Message        YES                          Layer 1 + Layer 2 + BL ctrl + value + note                                                              Value with narrative

     0110         Rich Log Entry            YES                                 Layer 1 + all four components                                                                   All components present

     0111         Priority Alert            YES                          Layer 1 + value + task. Priority override.                                                            Elevated priority record

     1000           Text Stream           Session                            Stream-length prefix + UTF-8 bytes                                                                 Continuous text channel

     1001     Flag / Archetype Stream     Session                         Stream-Open ctrl + length + packed flags                                                            BitLedger archetype stream

     1010      Variable Field Stream      Session                           Stream-Open + length-prefixed fields                                                                Structured field stream

     1011           Binary Blob           Session                                Length prefix + raw binary                                                                    Unstructured binary data

     1100       **Compact Command**      No (est.)            *Command byte sequence. See Enhancement Sub-Protocol Section 11.*             NEW v2.0: Discrete command queue. Upper 3 bits=class, lower 5=code. Enhancement grammar active.

     1101     **Context Declaration**        No        *Context Declaration Block 1-4 bytes. See Enhancement Sub-Protocol Section 12.*            NEW v2.0: Dynamic context management. Standalone Wave or in-band stream mechanism.

     1110     **Telegraph Emulation**     Session             *C0 enhancement stream. See Enhancement Sub-Protocol Section 13.*          NEW v2.0: Full C0 Enhancement Grammar. Every byte: upper 3=flags, lower 5=C0 code. Legacy compatible.

     1111        Extended Category        Depends                         Next byte = 8-bit extended category code                                                             256 additional categories
  ---------- ------------------------- -------------- --------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------

> *v2.0: Categories 1100, 1101, and 1110 are now formally assigned. They replace the placeholder Mission Specific A/B/C entries. Full specifications are in the BitPads Enhancement Sub-Protocol v2.0.*

**2.4 Bits 5-8 Role C --- Record Mode Component Expect Flags (bit1=1)**

  ----------- ---------------- ------------ ----------------------------------------------------------------------------------------------------------------------------------------------------
   **Bits**      **Field**      **Values**                                                                    **Description**

   **Bit 5**   Value Present       0/1       1=Value block follows. Triggers: BitLedger Context ctrl (when BL active), Setup byte check (Meta byte 2 bit 7), then value block at declared tier.

   **Bit 6**    Time Present       0/1                                     1=Time field follows Value block. Tier and reference declared in Meta byte 2 bits 5-6.

   **Bit 7**    Task Present       0/1                                       1=Task short form follows Time. May include extension bytes for target and timing.

   **Bit 8**    Note Present       0/1                                        1=Note block follows Task. Note header declares encoding, language, and length.
  ----------- ---------------- ------------ ----------------------------------------------------------------------------------------------------------------------------------------------------

**2.5 The Pure Signal --- Single Byte Transmission**

When Meta byte 1 is transmitted alone the transmission closes immediately. The entire message is in 8 bits.

0 1 0 0 0 0 0 0 = 0x40 = Wave, ACK request, complete, basic, no flags

Meaning: I am here. Acknowledge me.

Response: ACK control record 0x31. Two bytes for verified handshake.

0 0 0 1 0111 = Wave, no ACK, complete, category, Priority Alert

Meaning: Priority alert incoming. Receiver enters elevated mode.

**3. META BYTE 2 --- EXTENDED RECORD CONTEXT**

Meta byte 2 is present in every Record mode transmission immediately after Meta byte 1. Together the two Meta bytes form 16 bits that fully declare the record structure.

**3.1 Complete Bit Layout**

  -------------- ---------------------------- ------------ ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
     **Bits**             **Field**            **Values**                                                                                                   **Description**

   **Bits 1-4**   Archetype / Extended Flags   0000-1111    PRIMARY: When category is 1001 (Archetype Stream), bits 1-4 carry the active BitLedger relationship archetype (0000-1111). SECONDARY: For other Record categories, carries sub-type or sub-category declaration.

   **Bits 5-6**    Time Reference Selector       00-11                       00=No timestamp. 01=Tier 1, session offset (8-bit follows). 10=Tier 1, external reference (8-bit follows). 11=Tier 2 Time Block (variable, header + ref byte + value fields).

    **Bit 7**         Setup Byte Present          0/1                                   0=Value uses session/Layer 2 defaults (Tier 3, SF x1, D=2, session type). 1=Setup byte follows before Value block, overriding defaults for this record.

    **Bit 8**      **Signal Slot Presence**       0/1         UPDATED v2.0: Reassigned from Reserved=1. 0=No signal slots in this record (default). 1=Signal Slot Presence byte follows Meta byte 2, before Layer 1, declaring which of P4-P8 are active. See Section 3.3.
  -------------- ---------------------------- ------------ ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

> *v2.0: Bit 8 was previously Reserved (always transmit 1). It is now the Signal Slot Presence flag. When 0 (the common case) behaviour is identical to v1. When 1, a Signal Slot Presence byte follows Meta byte 2. All existing decoders that assumed bit 8=1 must be updated to check this bit before assuming legacy behaviour.*

**3.2 Bits 1-4 Secondary Role by Record Category**

  ---------------------------- --------------------------------------------------------------------------------------------------------------
          **Category**                                                 **Bits 1-4 Secondary Meaning**

       0100 Basic Record                 Bits 1-2: sub-type (00=measurement, 01=observation, 10=state, 11=event). Bits 3-4: spare.

   0101 Transaction + Message   Bits 1-4: abbreviated BitLedger account pair (4-bit from Protocol v3.0 table). Pre-loads accounting context.

      0110 Rich Log Entry                     Bits 1-2: log level (00=debug, 01=info, 10=warn, 11=critical). Bits 3-4: domain.

      0111 Priority Alert          Bits 1-2: alert type (00=threshold, 01=fault, 10=command, 11=emergency). Bits 3-4: escalation target.

        1000 Text Stream                Bits 1-2: encoding (00=UTF-8, 01=ASCII-7, 10=packed-6-bit, 11=declared). Bits 3-4: language.

   1010 Variable Field Stream                         Bits 1-4: field schema index referencing a pre-declared schema.
  ---------------------------- --------------------------------------------------------------------------------------------------------------

**3.3 Signal Slot Presence Byte**

Present when Meta byte 2 bit 8 = 1. Immediately follows Meta byte 2, before Layer 1. Declares which of the five record-layer signal slots (P4-P8) are active in this record.

  -------------- ---------------- ------------ -----------------------------------------------------------------------------------------------------------------------
     **Bits**       **Field**      **Values**                                                      **Description**

    **Bit 1**      P4 Pre-Value       0/1       1=Signal slot active before Value block. Decoder reads enhanced C0 byte(s) at this position before reading the value.

    **Bit 2**     P5 Post-Value       0/1                                    1=Signal slot active after Value block, before Time field.

    **Bit 3**      P6 Post-Time       0/1                                     1=Signal slot active after Time field, before Task block.

    **Bit 4**      P7 Post-Task       0/1                                     1=Signal slot active after Task block, before Note block.

    **Bit 5**     P8 Post-Record      0/1                           1=Signal slot active after final component. The record close signal position.

   **Bits 6-8**      Reserved         111                                    Transmit as 1. Reserved for future slot positions P14-P16.
  -------------- ---------------- ------------ -----------------------------------------------------------------------------------------------------------------------

> *When Meta byte 2 bit 8 = 0, this byte is absent. The record sequence proceeds directly from Meta byte 2 to Layer 1. This is the common case --- no overhead for transmissions that do not use signal slots.*

**4. LAYER 1 --- REVISED UNIVERSAL SESSION HEADER (64 bits)**

Layer 1 is the 64-bit session initialisation block. Bit 12 has been reassigned in v2.0. The Opposing Convention function has moved to a session extension byte, freeing bit 12 as the Session Enhancement Flag.

**4.1 Complete Bit Layout**

  ---------------- ------------------------------ ------------ --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
      **Bits**               **Field**             **Values**                                                                                                                                     **Description**

     **Bit 1**               SOH Marker                1                                                                         Always 1. Self-framing bootstrap anchor. In IDLE state byte 0x01 unconditionally opens Layer 1 read. The sole context-free signal in the protocol.

     **Bit 2**          Wire Format Version           0/1                                                                                     0=Wire format version 1 (current). 1=Non-standard. Version declaration control byte follows Layer 1 before any content.

    **Bits 3-4**               Domain                00-11                                                                                            00=Financial (default). 01=Engineering. 10=Hybrid. 11=Custom (domain extension follows at session open).

    **Bits 5-8**            Permissions             4 flags                                                                                                 Bit 5: Read/Observe. Bit 6: Write/Actuate. Bit 7: Correct/Override. Bit 8: Represent/Proxy.

     **Bit 9**          Split Order Default           0/1                                                                                                    0=Multiplicand first. 1=Multiplier first. Session default for value encoding split order.

   **Bits 10-11**       Sender ID Split Mode         00-11                                                                           00=Flat 32-bit Node ID. 01=16/16 (System+Node). 10=8/8/16 (Network+System+Node). 11=Custom, System Context Extension declares boundaries.

     **Bit 12**     **Session Enhancement Flag**      0/1       UPDATED v2.0: Reassigned from Opposing Convention. 0=No C0 Enhancement Grammar for this session (default). 1=C0 Enhancement Grammar active session-wide. All 13 signal slot positions P1-P13 available. See Enhancement Sub-Protocol. When 1, a Nesting Declaration follows Layer 1.

   **Bits 13-44**            Sender ID               32-bit                                                                              Interpreted per bits 10-11 split mode. Flat: 4.29 billion nodes. 16/16: 65,535 systems x 65,535 nodes. 8/8/16: 255 x 255 x 65,535.

   **Bits 45-49**          Sub-Entity ID             5-bit                                                                                                              31 sub-divisions within sender. Department, sub-system, or sub-node.

   **Bits 50-64**         CRC-15 Checksum            15-bit                                                                                         CRC-15 over bits 1-49, polynomial x\^15+x+1. Zero remainder = valid. Non-zero = NACK and session rejection.
  ---------------- ------------------------------ ------------ --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

> *v2.0: Bit 12 is now the Session Enhancement Flag. Opposing Convention has moved to the Session Configuration Extension byte (see Section 4.3). This frees bit 12 to carry the session-wide enhancement flag at zero additional overhead --- it was already part of Layer 1 which is only transmitted once per session.*

**4.2 Layer 1 Requirement Matrix**

  ------------------------------------------------ ----------------------- ------------------------------------------------------------
                    **Scenario**                    **Layer 1 Required?**                           **Reason**

       First transmission of any new session                 YES                No context exists. Layer 1 bootstraps everything.

       Wave 0000-0003 in established session                 NO                         Identity known from prior Layer 1.

        Wave 0000-0003 with no prior session                 YES                             No identity established.

         Wave 0100-0111 (Record categories)                  YES                Record categories always require formal identity.

      Stream 1000-1011 in established session                NO                         Session context carries identity.

       Stream 1000-1011 with no prior session                YES                  Without identity, stream cannot be attributed.

     Category 1100 Compact Command, established              NO                      Commands interpreted in session context.

         Category 1101 Context Declaration                   NO             Context declarations are structural, not identity-bearing.

   Category 1110 Telegraph Emulation, established            NO                       Enhancement grammar scoped to stream.

   Category 1110 Telegraph Emulation, no session             YES                    First transmission requires session open.

            Record mode (bit1=1) always                      YES                      Record mode is unconditionally formal.

       Session reset or reconnect after drop                 YES                           Prior context may be stale.
  ------------------------------------------------ ----------------------- ------------------------------------------------------------

**4.3 Session Configuration Extension Byte**

When the session requires explicit opposing convention declaration or nesting configuration, a Session Configuration Extension byte follows Layer 1. This byte is present when bit 12 = 1 (Session Enhancement active) OR when the implementation needs to declare non-default opposing convention. The receiver checks for it before reading the first batch header.

  -------------- -------------------------- ------------ ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
     **Bits**            **Field**           **Values**                                                                                   **Description**

   **Bits 1-2**      Nesting Level Code        00-11                 00=Flat only (no nesting). 01=Depth 2. 10=Depth 4. 11=Extended --- Nesting Declaration Extension byte follows (see Enhancement Sub-Protocol Section 8.5).

    **Bit 3**       Opposing Convention         0/1       MOVED from Layer 1 bit 12. 0=Opposing account or node inferred from relationship pair and direction. 1=Opposing always transmitted explicitly in extension byte on every record.

    **Bit 4**       Compound Mode Active        0/1                                           MOVED from Layer 1 session defaults. 0=Off. 1=1111 compound continuation markers valid in this session.

    **Bit 5**     BitLedger Block Optional      0/1                                 MOVED from Layer 1 session defaults. 0=BitLedger accounting block always present in records. 1=Optional --- record may omit.

   **Bits 6-8**           Reserved              111                                                                                        Transmit as 1.
  -------------- -------------------------- ------------ ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

> *The Session Configuration Extension byte consolidates the two displaced session defaults (Compound Mode, BL Block Optional) together with the moved Opposing Convention and the new Nesting Level Code. When bit 12=0 and no explicit opposing convention is needed, this byte is absent --- the common case costs nothing.*

**4.4 Displaced BitLedger Context Control Byte**

The BitLedger Context Control byte (type 110 control record) is now REMOVED --- its content (Compound Mode and BitLedger Block Optional) has moved to the Session Configuration Extension byte. The BitLedger Context ctrl byte previously described in v1 Section 4.2 is superseded.

> *v2.0: The BitLedger Context Control byte is replaced by the Session Configuration Extension byte which carries the same information (compound mode, BL optional) alongside the new nesting level code and the displaced opposing convention field. Implementations using the v1 BitLedger Context ctrl byte must update to read the Session Configuration Extension byte instead.*

**5. IDENTITY SYSTEM --- TRIANGULATING WHO**

A sender ID number without a namespace is a coordinate without a map. BitPads resolves identity at three levels using the Sender ID split mode in Layer 1 bits 10-11, optionally extended by a System Context Extension block.

**5.1 Identity as a Coordinate**

THREE LEVELS:

Level 1: Network ID --- which network or organisation

Level 2: System ID --- which system within the network

Level 3: Node ID --- which device within the system

SPLIT MODE 01 (16/16):

Upper 16 = System ID = 0-65,535 systems

Lower 16 = Node ID = 0-65,535 nodes per system

SPLIT MODE 10 (8/8/16):

Bits 13-20 = Network = 0-255 networks

Bits 21-28 = System = 0-255 systems

Bits 29-44 = Node = 0-65,535 nodes

**5.2 System Context Extension Block**

When Meta byte 1 bit 2 = 1 in Record mode, a System Context Extension block follows Layer 1 (and the Session Config Extension if present). Provides human-resolvable namespace context for the numeric Sender ID.

  -------------------------------- ---------------------------------------- ----------- ------------------------------
              **Case**                          **Structure**                **Bytes**           **Example**

       System ID only (8-bit)        Struct byte: 00 00 1111 + 1 ID byte         2          System 7 = Artemis IV

   Network + System (16-bit each)   Struct byte: 01 01 1111 + 2+2 ID bytes       5           Network 4 / System 7

     Three levels (8-bit each)       Struct byte: 10 00 1111 + 3 ID bytes        4       Network 4 / System 7 / Sub 3
  -------------------------------- ---------------------------------------- ----------- ------------------------------

**6. VALUE BLOCK --- FOUR TIERS AND SETUP BYTE**

The Value block encodes any conserved scalar quantity as a whole integer. Default is Tier 3 (24 bits). Tiers 1 and 2 are transmission optimisations. Tier 4 extends to full 32-bit range.

**6.1 Value Tiers**

  -------------- ---------- ----------------- ---------------------- ------------------------------------------------------------
     **Tier**     **Bits**   **Max Integer**   **Max at SF x1 D=2**                        **When to Use**

   1 (explicit)      8             255                \$2.55          Status codes, counts, deep space IoT --- every byte counts

   2 (explicit)      16          65,535              \$655.35                  Small measurements, local sensor values

   3 (DEFAULT)       24        16,777,215          \$167,772.15              General purpose. Assumed when no Setup byte.

   4 (explicit)      32       4,294,967,295      \$42,949,672.95          Extended range, large assets, high-volume physical
  -------------- ---------- ----------------- ---------------------- ------------------------------------------------------------

**6.2 The Setup Byte**

Present when Meta byte 2 bit 7 = 1. Follows before the Value block. Overrides session defaults for this record\'s value encoding.

  ---------- ------------------ ------------- -----------------------------------------------------------------------
   **Bits**      **Field**       **Values**                                 **Meaning**

     1-2         Value Tier         00-11               00=Tier 1 01=Tier 2 10=Tier 3 (explicit) 11=Tier 4

     3-4       Scaling Factor       00-11                 00=x1 01=x1,000 10=x1,000,000 11=x1,000,000,000

     5-6      Decimal Position      00-11         00=0 places 01=2 places (standard) 10=4 places 11=in extension

      7        Context Source        0/1       0=Override Layer 2 for this record. 1=Standalone (no Layer 2 active).

      8        Rounding Conv.        0/1        0=Account-type rounding. 1=Round to nearest (physical quantities).
  ---------- ------------------ ------------- -----------------------------------------------------------------------

**6.3 Value Encoding Formula**

N = A x (2\^S) + r

Real Value = (N x Scaling Factor) / 10\^DecimalPosition

Default Tier 3: N max = 16,777,215.

At SF x1B, D=2: max = \$167 trillion in a single 3-byte block.

**7. TIME SYSTEM --- TWO-TIER ARCHITECTURE**

Tier 1 handles the common case in one byte. Tier 2 handles complex temporal requirements including task execution timing, duration windows, and validity/expiry deadlines.

**7.1 Tier Selection --- Meta Byte 2 Bits 5-6**

  -------------- ---------------------------- ---------- -------------------------------------------------
   **Bits 5-6**            **Tier**            **Cost**                       **Use**

        00                   None              0 bytes              No timestamp in this record

        01          Tier 1, session offset      1 byte     8-bit offset from session open. Most common.

        10        Tier 1, external reference    1 byte    8-bit offset from mission epoch or system time.

        11            Tier 2 Time Block        Variable   Full temporal specification. Multiple purposes.
  -------------- ---------------------------- ---------- -------------------------------------------------

**7.2 Tier 1 --- 8-Bit Integer**

A pure 8-bit integer. Reference from Meta byte 2 bits 5-6. Unit from session profile (seconds, minutes, hours, 10ms ticks). Range 0-255 units.

**7.3 Tier 2 Time Block Header**

  --------- ------------------- -----------------------------------------------------------------
   **Bit**       **Field**                                 **Meaning**

      1      Record timestamp               1=timestamp for when this record occurred

      2       Task exec time                1=when declared Task should be performed

      3        Task duration                      1=task window end or duration

      4      Validity / expiry   1=after this time, discard as stale --- critical for deep space

      5           Quality                         0=estimated 1=verified/synced

     6-7        Shared unit           00=milliseconds 01=seconds 10=minutes 11=in next byte

      8      Mixed references      0=all fields same reference 1=per-field reference selector
  --------- ------------------- -----------------------------------------------------------------

**8. TASK AND NOTE COMPONENTS**

**8.1 Task Short Form (8 bits)**

  ---------- ------------------ ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   **Bits**      **Field**                                                                                                                     **Values**

     1-4       Task Category     0000=Execute. 0001=Acknowledge. 0010=Request. 0011=Cancel/Abort. 0100=Schedule. 0101=Delegate. 0110=Monitor. 0111=Alert. 1000=Approve. 1001=Reject. 1010=Transfer. 1011=Hold. 1100=Resume. 1101=Close. 1110=Correction. 1111=Extended.

     5-6          Priority                                                                                                    00=Routine 01=Elevated 10=Urgent 11=Critical

      7       Target Specified                                                                                             0=Default node 1=Target node ID in extension byte

      8       Timing Specified                                                                                         0=Immediate. 1=TIME component carries task execution time.
  ---------- ------------------ ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**8.2 Note Component**

Note Header (8 bits): encoding type (bits 1-2), language (bits 3-4), length (bits 5-8, escape 1111 for next-byte length up to 255).

**8.2.1 Binary Pictography**

When Note encoding type = 10 (Stream category reference), note content is a nibble stream decoded through the active codebook. 4 bits per symbol. 16-entry codebook maps to full semantic concepts declared at session open.

Codebook 0001 (example):

0000=Nominal 0001=Warning 0010=Critical 0011=Burn complete

0100=Fuel low 0101=Power nominal \...

Note content 2 bytes: 0011 0101 0110 0000

= Burn complete / Power nominal / Comms nominal / Nominal

4 status reports in 2 bytes.

> *v2.0: Mid-Note codebook shifts use SO/SI enhanced C0 signals in the P7 (Post-Task/Pre-Note) signal slot when the Session Enhancement Flag is active. The SO signal shifts to an alternate codebook for the note content. SI restores primary codebook after the note. See Enhancement Sub-Protocol Section 7.6.*

**9. STREAM ARCHITECTURE AND BINARY PICTOGRAPHY**

Stream categories (1000-1011, 1100, 1110) open a continuous channel typed by its category code and, for flag streams, by the active relationship archetype and codebook.

**9.1 Stream Open Sequence**

1\. Meta byte 1 declares stream category

2\. If Record mode: Meta byte 2 bits 1-4 carry archetype

3\. Stream-Open Control byte (for category 1001, 1100, 1110)

4\. Length prefix or terminator

5\. Stream content

6\. Category update control bytes may shift codebook mid-stream

7\. Stream closes at length or new Meta byte

**9.2 Stream-Open Control Byte --- Category 1001 and 1110**

  ---------- ------------------ -----------------------------------------------------------------------
   **Bits**      **Field**                                    **Values**

     1-4      Active Archetype           0000-1111, BitLedger Universal Domain archetype codes

     5-6          Codebook       00=Universal 01=Session-declared 10=Shift offset (cipher) 11=Extended

      7         Cipher Shift              0=Literal archetype 1=Offset from session baseline

      8         Update Flag                0=Fixed for stream 1=Mid-stream updates permitted
  ---------- ------------------ -----------------------------------------------------------------------

**9.3 Rolling Codebook and Semantic Obscuration**

Enhancement field 110 bytes within an active enhancement stream update the active codebook. Lower 5 bits carry the new codebook index. Both sender and receiver derive the shift sequence from the session key. An interceptor without session context cannot determine which codebook is active at any point.

> *This is semantic obscuration, not cryptographic security. It must not be relied upon as the sole protection mechanism. It provides meaningful resistance to casual interception on low-threat channels.*

**10. COMPONENT ORDER AND DECODER RULES**

All components appear in fixed sequence. Position plus expect flags fully determine what each byte means without field-type identifiers.

**10.1 Fixed Component Sequence --- Updated v2.0**

  -------------- ------------------------------- ------------- ------------------------------------------ --------------------------------------
   **Position**           **Component**            **Size**                 **Present When**                          **v2 Change?**

        1                  Meta byte 1              1 byte                       Always                                    ---

        2                  Meta byte 2              1 byte               Bit 1=1 (Record mode)                             ---

      **3**       **Signal Slot Presence byte**     1 byte                  **Meta2 bit8=1**                           **NEW v2.0**

        4                    Layer 1                8 bytes                Record mode always                              ---

      **5**       **Session Config Extension**     1-5 bytes    **When bit12=1 OR opposing non-default**   **NEW v2.0 (replaces BL ctrl byte)**

        6           System Context Extension      2-17 bytes             Meta1 bit2=1 in Record                            ---

        7             Layer 2 Set B Header          6 bytes            When batch context needed                           ---

        8                  Setup byte               1 byte                    Meta2 bit7=1                                 ---

        9                  VALUE block             1-4 bytes                  Meta1 bit5=1                                 ---

        10                 TIME field             1-10 bytes              Meta2 bits5-6 != 00                              ---

        11                 TASK block              1+ bytes                   Meta1 bit7=1                                 ---

        12                 NOTE block              1+ bytes                   Meta1 bit8=1                                 ---

        13               Extension bytes            1 each                Per component flags                              ---
  -------------- ------------------------------- ------------- ------------------------------------------ --------------------------------------

> *v2.0: Position 3 is the new Signal Slot Presence byte (conditional on Meta byte 2 bit 8=1). Position 5 is the Session Configuration Extension byte (replaces the BitLedger Context Control byte from v1). All other positions shift accordingly when these new conditional bytes are present.*

**10.2 Decoder Decision Tree**

READ Meta byte 1

IF bit 1 = 1 (Record mode):

READ Meta byte 2

IF Meta2 bit8=1: READ Signal Slot Presence byte (NEW v2.0)

EXPECT Layer 1 (read 64 bits, CRC-15)

IF Layer1 bit12=1 OR opposing non-default:

READ Session Config Extension byte(s) (NEW v2.0)

IF nesting code=11: READ Nesting Declaration Extension

IF Meta1 bit2=1: READ System Context Extension

IF Layer 2 needed: READ Layer 2 Set B (48 bits)

IF Meta2 bit7=1: READ Setup byte

IF Meta1 bit5=1: READ Value block at declared tier

IF Layer1 bit12=1 AND slot P4 active: READ P4 signal(s)

IF Meta2 bits5-6 != 00: READ Time field

IF Layer1 bit12=1 AND slot P5 active: READ P5 signal(s)

IF Meta1 bit7=1: READ Task block

IF Layer1 bit12=1 AND slot P6 active: READ P6 signal(s)

IF Meta1 bit8=1: READ Note block

IF Layer1 bit12=1 AND slot P7 active: READ P7 signal(s)

IF Layer1 bit12=1 AND slot P8 active: READ P8 signal(s)

ELSE (Wave mode):

IF bit4=0: process Role A descriptors

IF bit4=1: read category, process per category rules

For categories 1100/1101/1110: see Enhancement Sub-Protocol

**11. TRANSMISSION FOOTPRINTS**

**11.1 Baseline Footprints (No Enhancement)**

  ------------------------------- ---------- ----------- ------------------------------------------------------------
         **Transmission**          **Bits**   **Bytes**                          **Contents**

            Pure signal               8           1                            Meta byte 1 only

     Anonymous value (Tier 3)         32          4                          Meta + 24-bit value

      Anonymous value + setup         40          5                          Meta + Setup + value

          Wave with time              48          6                       Meta + 8-bit time + value

   Simple message (est. session)     24+         3+                        Meta + length + content

        Minimal full record          104         13                       Meta x2 + Layer 1 + Tier 3

         Record with time            120         15                      Meta x2 + L1 + time + value

      Record with time + task        128         16                   Meta x2 + L1 + time + value + task

    Full record all components       232         29       Meta x2 + L1 + SysCtx + Setup + Value + Time + Task + Note

     Full BitLedger in BitPads       224         28                Meta x2 + L1 + L2 + SessCfg + L3 record
  ------------------------------- ---------- ----------- ------------------------------------------------------------

**11.2 Enhancement Overhead --- Additive Costs**

> *v2.0: The following overhead applies when the C0 Enhancement Module is active. All footprints above are baseline costs. Enhancement overhead is strictly additive and only incurred when specific enhancement features are used.*

  --------------------------------------------- --------------------- ---------------------- ---------------------------------------------------------
             **Enhancement Element**             **Additional Bits**   **Additional Bytes**                        **Frequency**

   Session Enhancement Flag (Layer 1 bit 12=1)            1                    \<1                               Once per session

          Session Config Extension byte                   8                     1             Once per session (when bit12=1 or opposing non-default)

       Nesting Declaration Extension byte                 8                     1                Once per session (when nesting depth \> 4 needed)

    Signal Slot Presence byte (Meta2 bit8=1)              8                     1                      Once per record with any slot active

        Individual signal slot (plain C0)                 8                     1                            Per declared active slot

      Individual signal slot (enhanced C0)                8                     1                            Per declared active slot

      Signal sequence continuation (C flag)               8                     1                     Per additional signal in a C=1 sequence

            Stream-Open Control byte                      8                     1                       Once per stream (1001, 1100, 1110)
  --------------------------------------------- --------------------- ---------------------- ---------------------------------------------------------

> *For full overhead analysis at each of the 6 industrial strength levels (0-5) see Enhancement Sub-Protocol Section 15. Break-even analysis (session vs batch vs record activation scope) is also in Section 15.3.*

**12. v2.0 CHANGE SUMMARY**

This section consolidates all changes between BitPads Protocol v1.0 and v2.0. Each change is cross-referenced to its new location and to the Enhancement Sub-Protocol section that motivated it.

  ------------------------------------- --------------------- ------------------------------------------------------ ----------------------------------------------------------------------------------------------------------- ---------------------------------------
               **Change**                **Field / Section**                      **v1.0 State**                                                                   **v2.0 State**                                                           **Motivated By**

      Meta byte 2 bit 8 reassigned           Section 3.1                       Reserved = always 1                                         Signal Slot Presence flag. 0=no slots. 1=Presence byte follows.                        Enhancement Sub-Protocol Section 6.6

     Signal Slot Presence byte added      Section 3.3 (NEW)                        Not present                                   Conditional byte at position 3 in component sequence. Declares P4-P8 slot presence.              Enhancement Sub-Protocol Section 6.6

        Layer 1 bit 12 reassigned            Section 4.1                     Opposing Convention flag                               Session Enhancement Flag. 0=no enhancement. 1=C0 grammar active session-wide.                 Enhancement Sub-Protocol Section 10.2

      Opposing Convention displaced       Section 4.3 (NEW)                       Layer 1 bit 12                                      Session Config Extension byte bit 3. Present when bit12=1 or non-default.                         Architecture consistency

         Compound Mode displaced          Section 4.3 (NEW)                  Layer 1 session defaults                                                   Session Config Extension byte bit 4.                                            Architecture consistency

       BL Block Optional displaced        Section 4.3 (NEW)                  Layer 1 session defaults                                                   Session Config Extension byte bit 5.                                            Architecture consistency

   BitLedger Context ctrl byte removed       Section 4.4       Type 110 control record with compound+optional flags                                 Superseded by Session Config Extension byte.                                       Architecture simplification

   Session Config Extension byte added    Section 4.3 (NEW)                        Not present                                      New conditional byte following Layer 1 when bit12=1 or opposing non-default.                  Enhancement Sub-Protocol Section 8.5

         Role A bit 6 corrected              Section 2.2                     ACK Request (incorrect)                                            Cipher Active --- rolling codebook mechanism active.                              Enhancement Sub-Protocol Section 2.2

         Category 1100 assigned              Section 2.3                 Mission Specific A (placeholder)                                         Compact Command Mode --- discrete command queue.                                 Enhancement Sub-Protocol Section 11

         Category 1101 assigned              Section 2.3                 Mission Specific B (placeholder)                                        Context Declaration --- dynamic context management.                               Enhancement Sub-Protocol Section 12

         Category 1110 assigned              Section 2.3                 Mission Specific C (placeholder)                                         Telegraph Emulation Mode --- full C0 enhancement.                                Enhancement Sub-Protocol Section 13

       Component ordering updated           Section 10.1                           12 positions                       13 positions. Position 3=Signal Slot Presence (conditional). Position 5=Session Config Ext (conditional).       New bytes from above changes

      Decoder decision tree updated         Section 10.2                       No enhancement path                                  Enhancement signal slot reads added at each component boundary when bit12=1.                  Enhancement Sub-Protocol architecture

           Footprints updated                Section 11                        Baseline costs only                                                  Baseline costs + Enhancement overhead table.                                   Enhancement Sub-Protocol Section 15

      Binary pictography note added         Section 8.2.1                     No codebook shift info                                       Note on SO/SI signals in P7 slot for mid-Note codebook shifts.                         Enhancement Sub-Protocol Section 7.6
  ------------------------------------- --------------------- ------------------------------------------------------ ----------------------------------------------------------------------------------------------------------- ---------------------------------------

**13. GLOSSARY**

  --------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
              **Term**                                                                                                              **Definition**

         Binary Pictography                        Encoding of rich semantic content in compact nibble streams decoded through a shared codebook. Note encoding type 10. The Sumerian principle applied to binary data transmission.

       C0 Enhancement Grammar                   The mechanism by which C0 controls carry 3-bit flag matrices (Priority, ACK Request, Continuation) at declared signal slot positions. Specified fully in Enhancement Sub-Protocol v2.0.

        C0 Enhancement Module                       Optional microservice module providing industrial-strength signalling. Activatable at session, batch, category, record, or inline scope. Specified in Enhancement Sub-Protocol.

        Component Escalation                                        Enhancement field 101 in a stream signal slot. Triggers delivery of a full BitPads Record within the active stream. Requires parser stack push.

          Continuation Flag                               Flag C (bit 3) of enhanced C0 bytes. When set, more signals follow at the same slot position. Creates variable-length signal sequences without structural nesting.

              Meta Byte                                             The first byte of every BitPads transmission. Declares mode, continuation, treatment, and content field role. The universal table-of-contents.

       Microservices Principle                          System bytes carry only invariant logic. Everything else is a module --- attached on demand, costing zero when absent, costing exactly its declared size when present.

            Parser Stack             Fixed-size LIFO structure of ParserStateFrame objects required for nested sequence handling. Maximum depth is min(hardware_max, policy_max, negotiated_max). Specified in Enhancement Sub-Protocol Section 8.

             Pure Signal                                                          A transmission consisting of Meta byte 1 alone. 8 bits. The universal heartbeat, pulse request, and status beacon.

             Record Mode                                    Meta byte 1 bit 1=1. Full BitPad. Meta byte 2, Layer 1, Signal Slot Presence byte (conditional), Session Config Extension (conditional), and components follow.

          Rolling Codebook                                        Mid-stream codebook update via enhancement field 110. Creates semantic obscuration. Session-derived shift sequence. Not a cryptographic guarantee.

   Session Configuration Extension                  New in v2.0. Follows Layer 1 when bit 12=1 or opposing convention is non-default. Carries Nesting Level Code, Opposing Convention, Compound Mode Active, and BL Block Optional.

      Session Enhancement Flag                      Layer 1 bit 12 in v2.0. When set, C0 Enhancement Grammar is active session-wide. All 13 signal slot positions P1-P13 available. Triggers Session Configuration Extension byte.

             Signal Slot                                     Declared position in the BitPads transmission structure where enhanced C0 bytes appear. 13 positions P1-P13. Specified in Enhancement Sub-Protocol Section 6.

      Signal Slot Presence Byte                                          Conditional byte at position 3 in Record mode sequence. Present when Meta byte 2 bit 8=1. Bits 1-5 declare which of P4-P8 are active.

             Setup Byte                                         8-bit configuration byte preceding Value block when Meta byte 2 bit 7=1. Declares Tier, SF, Decimal Position, context source, and rounding convention.

      Telegraph Emulation Mode                                 Category 1110. Full C0 Enhancement Grammar active for stream duration. Legacy receivers see standard C0 controls. BitPads receivers decode flag matrices.

              Wave Mode                                               Meta byte 1 bit 1=0. Lightweight. No Layer 1 required in established session. Suitable for values, status, commands, messages, and streams.
  --------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
