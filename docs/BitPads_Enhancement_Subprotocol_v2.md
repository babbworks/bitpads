**BITPADS**

**ENHANCEMENT SUB-PROTOCOL**

*Specification v2.0*

*C0 Enhancement Grammar • Signal Slot Architecture • Nested Sequences*

*Telegraph Emulation • Compact Commands • Dynamic Context*

Companion to BitPads Protocol v1.0 \| BitLedger Protocol v3.0 \| Universal Domain v1.0

**1. INTRODUCTION AND PURPOSE**

This document specifies the BitPads Enhancement Sub-Protocol --- an optional module that attaches to any BitPads transmission to provide industrial-strength signalling, dynamic context management, legacy-compatible telegraph emulation, compact command sequencing, and nested transmission structures. It is a companion to BitPads Protocol Specification v1.0, BitLedger Protocol Specification v3.0, and the BitLedger Universal Domain Specification v1.0.

The sub-protocol introduces three new BitPads categories (1100, 1101, 1110), the C0 Enhancement Grammar with its signal slot architecture, and a complete nesting framework with a formally specified parser stack. None of these additions are required for standard BitPads transmissions. Each attaches as a microservice --- present only when needed, costing nothing when absent.

> *The governing principle throughout this document is the same microservices principle established in the main BitPads specification: system bytes carry invariant load-bearing logic; everything else is a module. The C0 Enhancement Module is a service loaded on demand, at exactly the scope level required, at exactly the cost of what it provides.*

  ------------------------- --------------------------------------------------------------------------------------------------- ------------------------------------------------------
        **Document**                                                     **Role**                                                                 **Assumed Known?**

    BitPads Protocol v1.0    Defines Meta bytes, Layer 1, Layer 2, all original 13 categories, Value/Time/Task/Note components       YES --- this document assumes full knowledge

   BitLedger Protocol v3.0           Defines Layer 3 financial records, CRC-15, compound continuation, control records           YES --- referenced for value encoding and accounting

    Universal Domain v1.0                   Defines engineering domain, 16 flow archetypes, Quantity Type codes                  YES --- archetype codes used in stream declarations

        This document                    C0 Enhancement Grammar, Signal Slots, Nesting, Categories 1100/1101/1110                                  Current document
  ------------------------- --------------------------------------------------------------------------------------------------- ------------------------------------------------------

**2. PREAMBLE --- BITPADS ARCHITECTURE REFERENCE**

This section is a complete self-contained reference for BitPads transmission architecture. A reader who understands this section has all the structural context needed to follow the sub-protocol. For full derivation and rationale see BitPads Protocol v1.0.

**2.1 The Transmission Spectrum**

  ------------- ---------------- -------------------------------------------- -------------------------------
    **Size**        **Type**                    **Structure**                      **Layer 1 Required?**

     1 byte       Pure Signal     Meta byte 1 only. The byte IS the message.                No

    2-6 bytes         Wave           Meta byte 1 + content per category.       Only for categories 0100-0111

   12-21 bytes       Record         Meta bytes 1+2 + Layer 1 + components.                Always

    28+ bytes    Full BitLedger     Record + Layer 2 + BitLedger Layer 3.                 Always
  ------------- ---------------- -------------------------------------------- -------------------------------

**2.2 Meta Byte 1 --- Complete Specification**

Present at the start of every BitPads transmission without exception. Bits 5-8 have three roles depending on bits 1 and 4.

  -------------- ---------------------- ------------ -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
     **Bits**          **Field**         **Values**                                                                                       **Description**

    **Bit 1**       **BitPad Mode**         0/1       0=Wave mode. Lightweight. Layer 1 not required unless category demands it. Bits 5-8 role set by bit 4. 1=Record mode. Full BitPad. Meta byte 2 always follows. Layer 1 always expected.

    **Bit 2**     **ACK Req / SysCtx**      0/1                        DUAL. Wave (bit1=0): 1=ACK request. Single byte with only bit2=1 is the universal pulse. Record (bit1=1): 1=System Context Extension follows Layer 1.

    **Bit 3**       **Continuation**        0/1                                      0=Complete, self-contained. 1=Fragment. More BitPads follow for the same logical unit. Universal across Wave and Record.

    **Bit 4**     **Treatment Switch**      0/1                             Wave only. 0=Basic treatment, bits 5-8 are Role A descriptors. 1=Category mode, bits 5-8 are Role B category code. Ignored in Record mode.

   **Bits 5-8**    **Content Field**       varies         Role A (bit1=0, bit4=0): Priority / Cipher / ExtFlags / Profile flags. Role B (bit1=0, bit4=1): 4-bit category code. Role C (bit1=1): Value / Time / Task / Note expect flags.
  -------------- ---------------------- ------------ -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**Role B --- Category Codes (bit1=0, bit4=1)**

  ---------- ------------------------- -------------- ------------------------------------------
   **Code**        **Category**         **Layer 1?**                 **Content**

     0000           Plain Value              No                  Setup + Value block

     0001         Simple Message             No                Length prefix + content

     0010          Status / Log              No                   Status code or log

     0011        Command / Request           No                    Task short form

     0100          Basic Record             YES                 Value + optional time

     0101      Transaction + Message        YES                      Value + note

     0110         Rich Log Entry            YES                  All four components

     0111         Priority Alert            YES                      Value + task

     1000           Text Stream           Session                    UTF-8 stream

     1001     Flag / Archetype Stream     Session              Packed archetype stream

     1010      Variable Field Stream      Session               Length-prefixed fields

     1011           Binary Blob           Session                     Raw binary

     1100         Compact Command            No          Command byte sequence --- Section 11

     1101       Context Declaration          No        Context Declaration Block --- Section 12

     1110       Telegraph Emulation       Session        C0 enhancement stream --- Section 13

     1111        Extended Category        Depends          Next byte = 8-bit extended code
  ---------- ------------------------- -------------- ------------------------------------------

**2.3 Meta Byte 2 --- Complete Specification**

Present in every Record mode transmission immediately after Meta byte 1.

  -------------- ----------------------------- ------------ --------------------------------------------------------------------------------------------------------------------------------------------------
     **Bits**              **Field**            **Values**                                                                   **Description**

   **Bits 1-4**    **Archetype / Sub-type**     0000-1111            When category 1001: active BitLedger flow archetype (0000-1111). Other Record categories: sub-type or sub-category declaration.

   **Bits 5-6**   **Time Reference Selector**     00-11      00=No timestamp. 01=Tier 1 session offset (8-bit follows). 10=Tier 1 external reference (8-bit follows). 11=Tier 2 Time Block (variable length).

    **Bit 7**       **Setup Byte Present**         0/1                                0=Use session/Layer 2 defaults (Tier 3, SF x1, D=2). 1=Setup byte follows before Value block.

    **Bit 8**      **Signal Slot Presence**        0/1                  REVISED from Reserved. 0=No signal slots in this record. 1=Signal Slot Presence byte follows Meta byte 2, before Layer 1.
  -------------- ----------------------------- ------------ --------------------------------------------------------------------------------------------------------------------------------------------------

**2.4 Layer 1 --- Session Header (64 bits)**

  ---------------- -------------------------- ------------ ------------------------------------------------------------------------------------------------------------------------------------------
      **Bits**             **Field**           **Values**                                                               **Description**

     **Bit 1**           **SOH Marker**            1        Always 1. The sole context-free bootstrap anchor. In IDLE state byte 0x01 unconditionally opens Layer 1 read. Every session begins here.

     **Bit 2**      **Wire Format Version**       0/1                     0=Version 1, current. 1=Non-standard. A version declaration control byte follows Layer 1 before any content.

    **Bits 3-4**           **Domain**            00-11                      00=Financial. 01=Engineering. 10=Hybrid. 11=Custom (domain declared in extension block at session open).

    **Bits 5-8**        **Permissions**         4 flags                           Bit 5: Read/Observe. Bit 6: Write/Actuate. Bit 7: Correct/Override. Bit 8: Represent/Proxy.

     **Bit 9**      **Split Order Default**       0/1                                                      0=Multiplicand first. 1=Multiplier first.

   **Bits 10-11**   **Sender ID Split Mode**     00-11             00=Flat 32-bit Node ID. 01=16/16 (System+Node). 10=8/8/16 (Network+System+Node). 11=Custom, extension declares boundaries.

     **Bit 12**     **Opposing Convention**       0/1                                              0=Opposing inferred. 1=Always explicit in extension byte.

   **Bits 13-44**        **Sender ID**           32-bit                                                      Interpreted per bits 10-11 split mode.

   **Bits 45-49**      **Sub-Entity ID**         5-bit                                                          31 sub-divisions within sender.

   **Bits 50-64**          **CRC-15**            15-bit                                      Over bits 1-49, polynomial x\^15+x+1. Zero remainder = valid session.
  ---------------- -------------------------- ------------ ------------------------------------------------------------------------------------------------------------------------------------------

**2.5 Layer 2 --- Set B Batch Header (48 bits)**

Transmitted once per batch. Inherited by all records in the batch. Carries denomination, precision, separator counters, entity identity, and currency/quantity type.

  ---------------- ------------------------- ------------- -----------------------------------------------------------------
      **Bits**             **Field**          **Values**                            **Description**

    **Bits 1-2**     **Transmission Type**       01-11          01=Pre-converted. 10=Copy. 11=Represented. 00=INVALID.

    **Bits 3-9**      **Scaling Factor**      7-bit index             x1 through x1,000,000,000 in powers of 10.

   **Bits 10-13**      **Optimal Split**         4-bit                  Default 8. Value block split parameter.

   **Bits 14-16**    **Decimal Position**        3-bit          000=integer, 010=2 places, 100=4 places, 110=6 places.

   **Bits 17-18**          **Bells**            2 flags              Bit 17=Enquiry Bell. Bit 18=Acknowledge Bell.

   **Bits 19-30**       **Separators**          12 bits           Group(4) + Record(5) + File(3) separator counters.

   **Bits 31-35**        **Entity ID**           5-bit                             31 sub-entities.

   **Bits 36-41**   **Currency/QType Code**      6-bit      Financial: currency index. Engineering: physical quantity type.

   **Bits 42-45**    **Rounding Balance**        4-bit                  Sign-magnitude net rounding for batch.

   **Bits 46-47**     **Compound Prefix**        2-bit              00=none, 01=up to 3, 10=up to 7, 11=unlimited.

     **Bit 48**          **Reserved**              1                                   Always 1.
  ---------------- ------------------------- ------------- -----------------------------------------------------------------

**2.6 Component Ordering in Record Mode**

Fixed sequence. Decoder never needs field-type identifiers --- position plus expect flags determine every byte\'s meaning.

  -------------- --------------------------- --------------------------- --------------------
   **Position**         **Component**             **Present When**             **Size**

        1                Meta byte 1                   Always                   1 byte

        2                Meta byte 2                   Bit 1=1                  1 byte

        3         Signal Slot Presence byte         Meta2 bit8=1                1 byte

        4                  Layer 1               Record mode always            8 bytes

        5          BitLedger Context ctrl     Value present + BL active         1 byte

        6         System Context Extension     Meta1 bit2=1 in Record         2-17 bytes

        7               Layer 2 Set B           Batch context needed           6 bytes

        8                Setup byte                 Meta2 bit7=1                1 byte

        9                Value block                   Bit 5=1                1-4 bytes

        10               Time field              Meta2 bits5-6 != 00          1-10 bytes

        11               Task block                    Bit 7=1                 1+ bytes

        12               Note block                    Bit 8=1                 1+ bytes

        13             Extension bytes           Per component flags         1 byte each
  -------------- --------------------------- --------------------------- --------------------

**2.7 Parser State Machine**

The receiver is always in exactly one named state. State transitions are deterministic. Stack operations (push/pop) occur at nesting boundaries --- see Section 8 for full stack specification.

STATE 0 --- IDLE

No session. Waiting.

Byte 0x01 (SOH) =\> STATE 1 (Layer 1 Read)

All other bytes =\> discard

STATE 1 --- LAYER 1 READ

Raw 64-bit read. No interpretation. No enhancement.

CRC-15 pass =\> load session flags, STATE 2

CRC-15 fail =\> NACK, STATE 0

STATE 2 --- SESSION ACTIVE

Bit 1=0 =\> read as Meta byte 1, STATE 3 (Wave)

Bit 1=1 =\> read as Meta byte 1, STATE 4 (Record)

0x01 =\> session reset, STATE 1

STATE 3 --- WAVE MODE sub-states:

3A: categories 0000-0011 (Wave content, no L1 needed)

3B: categories 0100-0111 (Wave-declared Record, L1 expected)

3C: categories 1000-1011 (Stream open sequence)

3D: category 1100 (Compact Command) \[enhancement active\]

3E: category 1101 (Context Declaration)

3F: category 1110 (Telegraph Emulation) \[enhancement active\]

3G: category 1111 (Extended --- read next byte)

STATE 4 --- RECORD MODE

Read Meta byte 2.

If Meta2 bit8=1: read Signal Slot Presence byte.

Read Layer 1 (STATE 1 sub-context).

Read components in order per expect flags.

At each declared signal slot position: read enhanced C0 byte(s).

PUSH stack at component escalation or sub-session open.

POP stack when nested structure closes.

STATE 3F --- TELEGRAPH EMULATION

Enhancement grammar fully active.

Every byte: bits 1-3=flags, bits 4-8=C0 code.

On enhancement field 101: PUSH, open inner Record.

Stream close: length exhausted OR new Meta byte OR EOT.

STATE 3D --- COMPACT COMMAND

Enhancement grammar active.

Command bytes: bits 1-3=class, bits 4-8=code.

Parameter bytes follow when class requires.

Close: length exhausted OR EOT byte OR new Meta byte.

**3. THE MURRAY-BAUDOT-ASCII-BITPADS LINEAGE**

The 3-bit flag matrix in the C0 Enhancement Grammar is not an invention. It is an inheritance --- the claiming of bits that 155 years of binary communication protocol development left structurally available without ever using them.

**3.1 The Five-Bit Atom**

  ---------- ------------------ ---------- --------------------------------------------------------------------------------------- -----------------------------------------------------------------------
   **Year**     **Standard**     **Bits**                                     **Five-Bit Role**                                                                **Upper Bits**

     1870     Baudot telegraph      5                  32 signals. The complete alphabet of mechanical communication.                                        N/A --- 5-bit only

     1899       Murray code         5                    Standardised. 32 controls. Shift states for extended sets.                                          N/A --- 5-bit only

     1963          ASCII            7       C0 controls in positions 0-31. Murray 5-bit space is the lower 5 bits of 7-bit ASCII.         Bits 6-7: group identifiers (00-11 for four groups of 32)

     1986      ISO 6429 / C1        8                            C0 preserved. C1 controls added at 128-159.                                       Bit 8: extended to Latin-1 and C1 space

     1991     Unicode / UTF-8       8+                     C0 at U+0000-U+001F and C1 at U+0080-U+009F preserved.                                      Multi-byte sequences above 127

     2025         BitPads           8                        C0 code identity in lower 5 bits of enhanced byte.                     Upper 3 bits RECLAIMED as flag matrix. 8 states. 3 independent flags.
  ---------- ------------------ ---------- --------------------------------------------------------------------------------------- -----------------------------------------------------------------------

> *The 3 bits reclaimed by BitPads are precisely the bits that every prior generation either did not have (5-bit era) or used only for group identification (ASCII era) or left partially unused (8-bit era). BitPads does not invent new bit positions. It claims the inheritance that 155 years of protocol evolution left structurally available.*

**3.2 The Sumerian Principle**

Sumerian scribes used minimal clay marks whose meaning expanded through shared context --- the mark was compact, the codebook was in the reader\'s knowledge. Baudot\'s 5-bit codes used shift states as a codebook. ASCII used the high group bits as a codebook. BitPads uses the parser state and the signal slot architecture as its codebook. The principle is identical across 5,000 years: minimal transmission, rich shared interpretation.

The signal slot architecture is the modern equivalent of the tablet type in Sumerian accounting. The tablet type told the reader whether they were reading a grain receipt, a debt record, or a temple inventory --- before they read the first symbol. The signal slot position tells the decoder whether it is reading a control signal or content before it reads the first bit.

**4. THE C0 BLOCK --- FULL ANALYSIS**

All 32 Unicode C0 controls (U+0000 to U+001F) are examined for their transmission and sequencing role in BitPads. Three criteria determine inclusion: does the control have a natural transmission role independent of text formatting; can it carry meaningful flag combinations; is its use safe on declared enhancement channels?

**4.1 Analysis Methodology**

Three outcome tiers are defined. Unconditional: the control has a clear transmission role and is safe in any declared enhancement channel. Conditional: useful but requires non-text channel typing because of deep embedding in text handling systems. Excluded: the control serves only text formatting with no useful transmission or sequencing role.

**4.2 Full 32-Code Assessment**

  ---------- ----------- ---------- ---------------------- ------------------------------------------------------------------- -------------
   **Code**   **Value**   **Name**   **Original Purpose**                           **BitPads Role**                            **Verdict**

    00000         0         NUL          Null, filler       Typed padding / null keep-alive. Enhanced: priority pad, ACK pad.     INCLUDE

    00001         1         SOH        Start of Header      Session open bootstrap anchor. In signal slot: sub-session open.       CORE

    00010         2         STX         Start of Text             Content / stream open. Pre-announces payload arrival.            CORE

    00011         3         ETX          End of Text                     Content / stream close. Pairs with STX.                   CORE

    00100         4         EOT      End of Transmission               Transmission end, batch close, session end.                 CORE

    00101         5         ENQ            Enquiry                    ACK request, status query, session handshake.                CORE

    00110         6         ACK          Acknowledge                   Confirmation signal, receipt confirmation.                  CORE

    00111         7         BEL          Bell / Alert                   Alert, attention, priority notification.                   CORE

    01000         8          BS           Backspace                     Compact retransmit request for last unit.                 INCLUDE

    01001         9          HT         Horizontal Tab                  Field advance in schema-declared streams.               CONDITIONAL

    01010        10          LF           Line Feed                        Record advance in non-text streams.                  CONDITIONAL

    01011        11          VT          Vertical Tab                      Group advance in non-text streams.                   CONDITIONAL

    01100        12          FF           Form Feed                   Phase or section advance in non-text streams.             CONDITIONAL

    01101        13          CR        Carriage Return          Restart current partial record assembly. Discard partial.         INCLUDE

    01110        14          SO           Shift Out              Shift to secondary codebook (lightweight SO/SI toggle).          INCLUDE

    01111        15          SI            Shift In                    Restore primary codebook. Companion to SO.                 INCLUDE

    10000        16         DLE        Data Link Escape                 Protocol mode shift, context transition.                   CORE

    10001        17         DC1        Device Control 1               Resume / XON / flow resume / session resume.                 CORE

    10010        18         DC2        Device Control 2                   Parameter update, mode configuration.                    CORE

    10011        19         DC3        Device Control 3                     Pause / XOFF / flow pause / hold.                      CORE

    10100        20         DC4        Device Control 4                Controlled shutdown, graceful termination.                  CORE

    10101        21         NAK      Negative Acknowledge                    NACK, rejection, error signal.                        CORE

    10110        22         SYN        Synchronous Idle                   Heartbeat, keep-alive, pre-announce.                     CORE

    10111        23         ETB       End of Trans Block              Block boundary, intermediate batch separator.                CORE

    11000        24         CAN             Cancel                           Cancel last unit, void record.                        CORE

    11001        25          EM         End of Medium                     Capacity signal, buffer full warning.                    CORE

    11010        26         SUB           Substitute                Data substitution placeholder, correction marker.              CORE

    11011        27         ESC             Escape                    Escape to extended code, protocol transition.                CORE

    11100        28          FS         File Separator                 File boundary, major collection separator.                  CORE

    11101        29          GS        Group Separator                         Group boundary within file.                         CORE

    11110        30          RS        Record Separator                       Record boundary within group.                        CORE

    11111        31          US         Unit Separator                        Sub-record / field boundary.                         CORE
  ---------- ----------- ---------- ---------------------- ------------------------------------------------------------------- -------------

**4.3 The Conditional Controls --- Non-Text Channel Requirement**

LF, VT, FF, and HT are excluded from use on any channel that may carry text content. Their byte values appear frequently in UTF-8 text streams and their use as enhanced control signals on text channels would generate phantom protocol events from ambient content. Non-text channel declaration (via Category 1101 Context Declaration with encoding type set to binary) is required before these controls are active.

**4.4 Final Agreed Set**

The final set contains 29 unconditional controls (10 Core + 6 Include + 13 Strong Candidates) and 4 conditional controls. All 32 C0 codes are usable given correct channel typing. Hardware implementations must support all 29 unconditional controls. Conditional controls are optional and require non-text channel declaration.

**5. THE ENHANCEMENT GRAMMAR**

The Enhancement Grammar is the mechanism by which C0 controls carry 3-bit flag matrices. It is a property of declared signal slot positions --- the hardware knows which byte positions are signal slots and applies the five-plus-three split at those positions unconditionally.

**5.1 Byte Structure --- The Five-Plus-Three Split**

ENHANCED C0 BYTE STRUCTURE (8 bits):

Bit 1 Flag A --- Priority

Bit 2 Flag B --- Acknowledge Request

Bit 3 Flag C --- Continuation

Bits 4-8 C0 Code Identity (5 bits, values 0-31)

THE HARDWARE KNOWS:

At a signal slot position, bits 4-8 identify the C0 code.

This knowledge is hardcoded. No runtime declaration needed.

The agreed set of 29-32 C0 codes is firmware-resident.

PLAIN FORM (flags 000):

When bits 1-3 = 000, the byte value is 0-31.

This is the plain C0 byte --- no flags, legacy compatible.

Plain BEL = 000 00111 = 0x07 = decimal 7

Plain EOT = 000 00100 = 0x04 = decimal 4

Plain ACK = 000 00110 = 0x06 = decimal 6

ENHANCED FORMS (flags 001-111):

Byte value is necessarily above 31.

Priority BEL = 100 00111 = 0x87 = decimal 135

ACK-req BEL = 010 00111 = 0x47 = decimal 71

Continuation BEL= 001 00111 = 0x27 = decimal 39

All-flags BEL = 111 00111 = 0xE7 = decimal 231

**5.2 The Three Flags --- Definitions**

  ----------- ---------------------------------- ------------ --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   **Bits**               **Field**               **Values**                                                                                                                                     **Description**

   **Bit 1**        **Priority (Flag A)**            0/1             0=Normal priority. Receiver processes in queue order. 1=Elevated priority. Receiver processes before lower-priority pending items. Applies to the specific signal in which it appears --- does not change overall session priority unless session-wide flag is also set.

   **Bit 2**   **Acknowledge Request (Flag B)**      0/1       0=No confirmation needed. Sender does not wait. 1=Receiver must confirm receipt and action. Sender buffers until ACK received. The mechanism that makes fire-and-forget into reliable delivery. Receiver responds with ACK enhanced C0 byte in the corresponding return signal slot.

   **Bit 3**      **Continuation (Flag C)**          0/1                   0=Standalone, complete signal. Receiver processes and moves to next slot. 1=Sequence open. More enhanced C0 bytes follow at the same slot position. Receiver reads until C=0. Creates variable-length signal sequences without opening a new nesting level.
  ----------- ---------------------------------- ------------ --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**5.3 The Eight Flag Combinations**

  -------------- ------------------------- ---------------------------------------------------------- ------------------------------------------------------------
   **Bits 1-3**          **Name**                                 **Meaning**                                               **Typical Use**

       000                 Plain            No flags active. Legacy compatible. Standard C0 control.    Backward compatible signalling, simple boundary markers

       001           Continuation only      Sequence open. More signals follow. No urgency, no ACK.    Opening a parameter sequence or multi-signal announcement

       010               ACK only               Confirm receipt. Not urgent. Standalone signal.          Reliable delivery on unreliable links without urgency

       011          ACK + Continuation         Sequence open. Confirm when complete. Not urgent.       Fragmented reliable delivery --- confirm on final fragment

       100             Priority only                  Urgent. No confirmation. Standalone.               Fire-and-forget urgent signal where loss is acceptable

       101        Priority + Continuation            Urgent sequence open. No confirmation.              Priority parameter sequence or alert detail following

       110            Priority + ACK                  Urgent. Confirm receipt. Standalone.             Standard form for important alerts requiring confirmation

       111               All flags                      Urgent. Confirm. Sequence open.                 Maximum weight signal. Emergency with detail following.
  -------------- ------------------------- ---------------------------------------------------------- ------------------------------------------------------------

**5.4 The Byte Value Table --- All Enhanced Forms**

For every C0 code in the unconditional set, the eight byte values produced by each flag combination. ASCII/Latin-1 meaning of enhanced byte values noted for collision awareness on shared channels.

  ------------- ----------- ----------------- --------------- --------------- ---------------- --------------- --------------- --------------- ---------------
   **C0 Code**   **Value**   **Plain (000)**   **Pri (100)**   **ACK (010)**   **Cont (001)**   **P+A (110)**   **P+C (101)**   **A+C (011)**   **All (111)**

       SOH           1            0x01             0x81            0x41             0x21            0xC1            0xA1            0x61            0xE1

       STX           2            0x02             0x82            0x42             0x22            0xC2            0xA2            0x62            0xE2

       ETX           3            0x03             0x83            0x43             0x23            0xC3            0xA3            0x63            0xE3

       EOT           4            0x04             0x84            0x44             0x24            0xC4            0xA4            0x64            0xE4

       ENQ           5            0x05             0x85            0x45             0x25            0xC5            0xA5            0x65            0xE5

       ACK           6            0x06             0x86            0x46             0x26            0xC6            0xA6            0x66            0xE6

       BEL           7            0x07             0x87            0x47             0x27            0xC7            0xA7            0x67            0xE7

       BS            8            0x08             0x88            0x48             0x28            0xC8            0xA8            0x68            0xE8

       CR           13            0x0D             0x8D            0x4D             0x2D            0xCD            0xAD            0x6D            0xED

       SO           14            0x0E             0x8E            0x4E             0x2E            0xCE            0xAE            0x6E            0xEE

       SI           15            0x0F             0x8F            0x4F             0x2F            0xCF            0xAF            0x6F            0xEF

       DLE          16            0x10             0x90            0x50             0x30            0xD0            0xB0            0x70            0xF0

       DC1          17            0x11             0x91            0x51             0x31            0xD1            0xB1            0x71            0xF1

       DC2          18            0x12             0x92            0x52             0x32            0xD2            0xB2            0x72            0xF2

       DC3          19            0x13             0x93            0x53             0x33            0xD3            0xB3            0x73            0xF3

       DC4          20            0x14             0x94            0x54             0x34            0xD4            0xB4            0x74            0xF4

       NAK          21            0x15             0x95            0x55             0x35            0xD5            0xB5            0x75            0xF5

       SYN          22            0x16             0x96            0x56             0x36            0xD6            0xB6            0x76            0xF6

       ETB          23            0x17             0x97            0x57             0x37            0xD7            0xB7            0x77            0xF7

       CAN          24            0x18             0x98            0x58             0x38            0xD8            0xB8            0x78            0xF8

       EM           25            0x19             0x99            0x59             0x39            0xD9            0xB9            0x79            0xF9

       SUB          26            0x1A             0x9A            0x5A             0x3A            0xDA            0xBA            0x7A            0xFA

       ESC          27            0x1B             0x9B            0x5B             0x3B            0xDB            0xBB            0x7B            0xFB

       FS           28            0x1C             0x9C            0x5C             0x3C            0xDC            0xBC            0x7C            0xFC

       GS           29            0x1D             0x9D            0x5D             0x3D            0xDD            0xBD            0x7D            0xFD

       RS           30            0x1E             0x9E            0x5E             0x3E            0xDE            0xBE            0x7E            0xFE

       US           31            0x1F             0x9F            0x5F             0x3F            0xDF            0xBF            0x7F            0xFF

       NUL           0            0x00             0x80            0x40             0x20            0xC0            0xA0            0x60            0xE0
  ------------- ----------- ----------------- --------------- --------------- ---------------- --------------- --------------- --------------- ---------------

**5.5 Channel Safety and Slot Positioning**

Enhanced C0 bytes (values 32-255 with matching lower-5-bit C0 codes) coincide with ASCII printable characters, Latin-1 characters, and UTF-8 byte sequences. On a channel carrying text content, these bytes would be misread as content rather than signals. The signal slot architecture eliminates this concern entirely.

> *A signal slot position is a declared position in the transmission sequence where the decoder expects an enhanced C0 byte and nothing else. Text content never arrives at a signal slot position. Value bytes never arrive at a signal slot position. The slot position IS the declaration. The decoder applies the five-plus-three split at slot positions unconditionally and never applies it at content positions.*

**6. SIGNAL SLOTS --- THE POSITIONAL ARCHITECTURE**

Signal slots are declared positions within the BitPads transmission structure where enhanced C0 bytes appear. The decoder knows slot positions in advance from the Signal Slot Presence byte and from the active category. The slot position itself is the declaration --- no byte-level type field is needed.

**6.1 Slot Type Taxonomy**

  ---------- --------------- ----------------------------------------------------------------------------------------------------------------- --------------------------------------------
   **Type**     **Name**                                                      **Description**                                                                  **Examples**

      A       System Slots                        Fixed-structure bytes defined by the protocol. Never enhanced C0 bytes.                       Meta byte 1, Meta byte 2, Layer 1, Layer 2

      B       Signal Slots    Declared positions expecting enhanced C0 bytes. The decoder applies five-plus-three split here unconditionally.                P1-P13 positions

      C       Content Slots       Value blocks, Note content, message bodies, stream data. Enhanced C0 interpretation NEVER applied here.       Value block bytes, UTF-8 text, binary data

      D       Control Slots                     Control records, extension bytes. Own defined structures. Not signal slots.                      Control record type 0-7, extension bytes
  ---------- --------------- ----------------------------------------------------------------------------------------------------------------- --------------------------------------------

**6.2 Session Layer Signal Slots --- P1, P2, P3**

  ---------- ----------------------------------------- ------------------------------------------------------ --------------------------------------------------------------------------------------------------------- ----------------------------------------------------
   **Slot**                **Position**                                   **Declared By**                                                             **Appropriate C0 Codes**                                                               **Notes**

      P1      After SOH bit, before Layer 1 remainder   Session enhancement flag in Layer 1 session defaults      ENQ (session handshake), SYN (routine open), BEL (emergency open), SOH+Continuation (sub-session)      Presence declared by session flag. Not per-record.

      P2      After Layer 1 complete, before Layer 2                  Session enhancement flag                 ETB (batch boundary), STX+Priority (priority batch), DC2+Continuation (parameter update precedes batch)          The pre-batch character declaration.

      P3      After last record, before session close                 Session enhancement flag                     EOT (session end), EOT+ACK (confirmed close), EOT+Continuation (session suspends, will resume)                 The clean session close signal.
  ---------- ----------------------------------------- ------------------------------------------------------ --------------------------------------------------------------------------------------------------------- ----------------------------------------------------

**6.3 Record Layer Signal Slots --- P4 through P8**

  ---------- ------------------------------------- ---------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------
   **Slot**              **Position**                                                    **Appropriate C0 Codes**                                                                                             **Key Flag Combinations**

      P4              Before Value block             STX (content begins), BEL (alert --- value is significant), DC2+Continuation (parameters follow)                         STX+Priority: priority value. BEL+ACK: alert requiring confirmation before value is read.

      P5           After Value, before Time               US (unit separator), RS (record boundary between value and time), ACK (value received)                       US+ACK: confirm value received before reading time. RS+Continuation: more value-related signals follow.

      P6            After Time, before Task                           RS (boundary), DC1 (resume --- timing noted), SYN (sync point)                                              RS+ACK: time noted, confirm before task. SYN: sync point between time and action.

      P7            After Task, before Note                           STX (note content begins), DLE (mode shift for note encoding)                                                STX+Priority: important note follows. DLE+ACK: mode shift confirmed before note.

      P8      After final component (Post-Record)   ETX (record complete), EOT (session end after record), ETB+Continuation (block ends, more records)   ETX+ACK: most important form --- record complete, confirm receipt. ETX+Priority+ACK: urgent record requiring immediate confirmation.
  ---------- ------------------------------------- ---------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------

**6.4 Stream Layer Signal Slots --- P9, P10, P11**

  ---------- ------------------------------------------ ------------------------------------------------------------------------------------------------------------------------------------------------ -------------------------------------------------------------------------------------------------------------
   **Slot**                 **Position**                                                                            **Appropriate C0 Codes**                                                                                                               **Notes**

      P9      After Meta byte 1, before stream content                            STX (stream open), SOH+Continuation (sub-stream within stream), BEL+Priority (urgent stream)                                          Declared by stream category itself. Always present for category 1110 and 1100.

     P10      Before each stream unit (when declared)    SYN (per-unit heartbeat), RS (record boundary between units), CAN (cancel previous unit, this replaces it), BEL+Priority (urgent unit follows)                     Declared by bit in Stream-Open Control byte. One signal slot per unit.

     P11               After last stream byte                     ETX+ACK (stream complete, confirm), EOT (transmission ends after stream), ETB+Continuation (block ends, more blocks follow)             Length-based close: slot is at the position after the Nth byte. Terminator close: EOT byte at any position.
  ---------- ------------------------------------------ ------------------------------------------------------------------------------------------------------------------------------------------------ -------------------------------------------------------------------------------------------------------------

**6.5 Wave Layer Signal Slots --- P12, P13**

  ---------- ---------------------------------------- ----------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------
   **Slot**                **Position**                                               **Appropriate C0 Codes**                                                                                       **Notes**

     P12      After Meta byte 1, before Wave content           STX (content begins), BEL+Priority (urgent content), SYN (pre-announce)           Declared by Meta byte 1 bit 7=1 (Extended Flags active) with a descriptor extension byte indicating slot presence.

     P13                After Wave content             ETX (content complete), ETX+ACK (confirm receipt), EOT+Continuation (more Waves follow)                   Lightweight post-content signal. Minimum overhead form of confirmed Wave delivery.
  ---------- ---------------------------------------- ----------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------

**6.6 Signal Slot Presence Declaration**

The Signal Slot Presence byte appears when Meta byte 2 bit 8 = 1. It declares which of the five record-layer slots (P4-P8) are active in this record. Session-layer slots (P1-P3) are declared by the session enhancement flag in Layer 1. Stream-layer slots are declared by the stream type and Stream-Open Control byte.

  -------------- -------------------- ------------ ---------------------------------------------------------------------------------------------------------
     **Bits**         **Field**        **Values**                                               **Description**

    **Bit 1**      **P4 Pre-Value**       0/1       1=Signal slot present before value block. Decoder reads enhanced C0 byte(s) before reading Value block.

    **Bit 2**     **P5 Post-Value**       0/1                             1=Signal slot present after value block, before time field.

    **Bit 3**      **P6 Post-Time**       0/1                             1=Signal slot present after time field, before task block.

    **Bit 4**      **P7 Post-Task**       0/1                             1=Signal slot present after task block, before note block.

    **Bit 5**     **P8 Post-Record**      0/1                                    1=Signal slot present after final component.

   **Bits 6-8**      **Reserved**         111                                 Transmit as 1. Reserved for future slot positions.
  -------------- -------------------- ------------ ---------------------------------------------------------------------------------------------------------

**6.7 Signal Slot Sequences and Continuation Chaining**

The Continuation flag (C, bit 3) turns any signal slot into a variable-length sequence. The decoder reads enhanced C0 bytes at the same slot position until it reads a byte with C=0. The sequence does not push the parser stack --- it is a repetition at one position, not a structural nesting.

CONTINUATION SEQUENCE EXAMPLE at P4 (Pre-Value):

BYTE 1: DC2 + ACK + Continuation (011 10010)

= Parameter update, ACK needed, more follows

BYTE 2: DC2 + ACK + Continuation (011 10010)

= Second parameter, ACK needed, more follows

BYTE 3: DC2 + ACK + no Continuation (010 10010)

= Final parameter, ACK needed, sequence complete

SEQUENCE RULES:

1\. All bytes in a sequence must share the same C0 code identity

UNLESS the code is ESC (27) which may introduce a new code.

2\. Maximum sequence length per slot: policy-configured (default 8).

3\. If maximum exceeded: receiver sends NAK+Priority, sender must close

the sequence with C=0 immediately.

4\. Timeout: if C=1 and next byte does not arrive within the

session timeout period, receiver sends NAK and resets the slot.

5\. ACK responses: if any byte in a sequence has B=1, the receiver

sends ACK after each such byte before reading the next.

**7. ALL C0 CONTROLS --- COMPLETE ROLE AND FLAG TABLES**

Every control in the agreed set receives a full specification. For each: BitPads role, compatible slot positions, and all eight flag combinations with precise meaning.

> *TABLE FORMAT: Code \| BitPads Role \| Slots \| Flag Combinations. Slot codes: S=Session(P1-P3), R=Record(P4-P8), T=Stream(P9-P11), W=Wave(P12-P13). Flag notation: \-\--=000 plain, P\--=100 priority, -A-=010 ACK, \--C=001 continuation, PA-=110, P-C=101, -AC=011, PAC=111.*

**7.2 Core Transmission Controls**

**SOH --- Start of Header (code 1)**

Bootstrap anchor and session open signal. In P1 slot: declares session character before Layer 1. Sub-session open when combined with Continuation.

  --------------------- ---------- ---------------------------------------------------------------------------------
        **Flags**        **Byte**                                     **Meaning**

      \-\-- (plain)        0x01                       Standard session open. No special handling.

     P\-- (priority)       0x81            Emergency session open. Receiver elevates above queued sessions.

        -A- (ACK)          0x41     Session open with confirmation request. Receiver must ACK before records begin.

   \--C (continuation)     0x21              Sub-session open. Nested session begins. Parser PUSHES stack.

       PA- (P+ACK)         0xC1                    Emergency open requiring immediate confirmation.

      P-C (P+cont)         0xA1                               Emergency sub-session open.

     -AC (ACK+cont)        0x61                   Sub-session open with ACK on session establishment.

        PAC (all)          0xE1              Emergency confirmed sub-session. Maximum weight session open.
  --------------------- ---------- ---------------------------------------------------------------------------------

**EOT --- End of Transmission (code 4)**

Transmission end signal. Batch close, session end, or transmission suspend. Compatible with all slot positions as a closing signal.

  --------------------- ---------- ------------------------------------------------------------------------------
        **Flags**        **Byte**                                   **Meaning**

      \-\-- (plain)        0x04            Transmission complete. No confirmation. Sender clears buffer.

     P\-- (priority)       0x84              Priority close. Process immediately before pending queue.

        -A- (ACK)          0x44        Confirmed close. Sender waits for ACK before clearing. Critical form.

   \--C (continuation)     0x24         Suspend, not terminate. Session resumes later. Do not close context.

           PA-             0xC4               Priority confirmed close. Urgent bilateral termination.

           P-C             0xA4               Priority suspend. Session paused urgently, will resume.

           -AC             0x64     Suspension with ACK. Receiver confirms it has buffered state for resumption.

           PAC             0xE4           Priority suspension with confirmation. Emergency graceful pause.
  --------------------- ---------- ------------------------------------------------------------------------------

**ENQ --- Enquiry (code 5)**

Question signal. Are you there? Did you receive? What is your status? The universal request for response.

  --------------- ---------- ---------------------------------------------------------------------------
     **Flags**     **Byte**                                  **Meaning**

   \-\-- (plain)     0x05               Are you alive? Expect any response. Universal pulse.

       P\--          0x85                Urgent status check. Respond before other traffic.

        -A-          0x45                  Enquiry requesting ACK of last specific record.

       \--C          0x25               Query sequence opening. Multi-part response expected.

        PA-          0xC5                       Priority ACK request for last record.

        P-C          0xA5                         Priority query sequence opening.

        -AC          0x65          Query with meta-ACK. Receiver confirms it understood the query.

        PAC          0xE5     Priority query with full confirmation and multi-part response commitment.
  --------------- ---------- ---------------------------------------------------------------------------

**ACK --- Acknowledge (code 6)**

Confirmation signal. I received, validated, and am ready for more. Response to ENQ and to any signal with B=1.

  --------------- ---------- ---------------------------------------------------------------------
     **Flags**     **Byte**                               **Meaning**

   \-\-- (plain)     0x06                   Received and validated. Ready for more.

       P\--          0x86     Priority ACK. I know you are waiting urgently. Proceed immediately.

        -A-          0x46              ACK requesting counter-ACK. Symmetric validation.

       \--C          0x26     Partial ACK. Fragment received. More expected. Do not clear buffer.

        PA-          0xC6                   Priority ACK with counter-ACK request.

        P-C          0xA6                            Priority partial ACK.

        -AC          0x66              Partial ACK with completion confirmation request.

        PAC          0xE6             Priority partial ACK with completion confirmation.
  --------------- ---------- ---------------------------------------------------------------------

**NAK --- Negative Acknowledge (code 21)**

Failure signal. Something was wrong --- corrupted, incomplete, or rejected. Distinct from CAN: NAK asks for retransmission. CAN discards without replacement.

  --------------- ---------- --------------------------------------------------------------------------------
     **Flags**     **Byte**                                    **Meaning**

   \-\-- (plain)     0x15                             Failed. Retransmit last unit.

       P\--          0x95          Critical failure. Retransmit immediately. System integrity at risk.

        -A-          0x55     NACK requesting error report ACK. Confirm NACK received before retransmitting.

       \--C          0x35               Partial failure. Detail follows. Some records were valid.

        PA-          0xD5                     Priority NACK with error confirmation request.

        P-C          0xB5                        Priority partial NACK. Detail incoming.

        -AC          0x75                Partial NACK with structured detail sequence following.

        PAC          0xF5       Priority partial NACK with structured error report. Emergency diagnostics.
  --------------- ---------- --------------------------------------------------------------------------------

**ESC --- Escape (code 27)**

Meta-signal. What follows uses a different coding context. The signal about signals.

  --------------- ---------- -----------------------------------------------------------------------------
     **Flags**     **Byte**                                   **Meaning**

   \-\-- (plain)     0x1B                    Next byte is extended code. Standard escape.

       P\--          0x9B        Priority escape. Apply new context immediately before buffered bytes.

        -A-          0x5B           Escape with confirmation. Receiver confirms new context loaded.

       \--C          0x3B             Multi-byte context declaration. More context bytes follow.

        PA-          0xDB             Priority escape with confirmation. Critical context change.

        P-C          0xBB                      Priority multi-byte context declaration.

        -AC          0x7B                     Multi-byte context with ACK on completion.

        PAC          0xFB     Priority multi-byte context with confirmation. Maximum protocol transition.
  --------------- ---------- -----------------------------------------------------------------------------

**FS, GS, RS, US --- Separator Group (codes 28-31)**

Structural boundary markers. FS=File, GS=Group, RS=Record, US=Unit. Form the 4-level hierarchy already present in Layer 2 separator fields. In signal slots these serve as lightweight separator advances --- one byte instead of Layer 2 retransmission.

  ------------- ----------- -------------- --------- ------------------ ----------- ------------ -------------- ---------
   **Control**   **Plain**   **Priority**   **ACK**   **Continuation**   **P+ACK**   **P+Cont**   **ACK+Cont**   **All**

     FS (28)       0x1C          0x9C        0x5C           0x3C           0xDC         0xBC          0x7C        0xFC

     GS (29)       0x1D          0x9D        0x5D           0x3D           0xDD         0xBD          0x7D        0xFD

     RS (30)       0x1E          0x9E        0x5E           0x3E           0xDE         0xBE          0x7E        0xFE

     US (31)       0x1F          0x9F        0x5F           0x3F           0xDF         0xBF          0x7F        0xFF
  ------------- ----------- -------------- --------- ------------------ ----------- ------------ -------------- ---------

Flag meaning for all four: plain=boundary advance, Priority=significant phase transition, ACK=synchronised boundary (receiver confirms prior unit complete), Continuation=nested boundary structure follows.

**7.3 Content Boundary Controls**

**STX (2), ETX (3), BEL (7), DLE (16)**

  ------------- ----------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   **Control**                     **Role**                                                                                             **Key Flag Combinations**

     STX (2)     Content/stream begins. Pre-announces payload.                             Plain=standard open. +Priority=urgent content. +ACK=confirm ready before sending. +Continuation=fragmented content.

     ETX (3)       Content/stream complete. Pairs with STX.                 Plain=complete. +ACK=most important form --- confirmed delivery. +Priority+ACK=urgent confirmed close. +Continuation=partial close, more follows.

     BEL (7)               Alert / attention signal.                  Plain=informational. +ACK=standard alert (confirm you heard). +Priority+ACK=standard alert form. +Priority+ACK+Continuation=emergency with detail following.

    DLE (16)       Protocol/mode shift. Context transition.      Plain=next byte uses different code. +ACK=safe transition (verify before using). +Continuation=multi-byte mode declaration. +Priority+ACK=urgent confirmed mode change.
  ------------- ----------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**7.4 Flow Control Group**

**DC1 (17), DC2 (18), DC3 (19), DC4 (20), SYN (22)**

  ------------- --------------------------------------------- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   **Control**                    **Role**                                                                                                 **Key Flag Combinations**

    DC1 (17)             Resume / XON / flow resume.                      Plain=resume. +ACK=safe resume handshake. +Continuation=resume with status report following. +Priority=expedite, process queued items at elevated priority.

    DC2 (18)       Parameter update / mode configuration.                           Plain=parameter follows. +ACK=confirmed config change. +Continuation=parameter sequence. +Priority=urgent parameter, apply immediately.

    DC3 (19)             Pause / XOFF / flow pause.                      Plain=pause, await DC1. +ACK=sender confirms halt. +Priority=emergency stop, halt immediately. +Priority+ACK+Continuation=emergency pause with reason report.

    DC4 (20)     Controlled shutdown / graceful termination.                            Plain=shutdown. +ACK=bilateral shutdown. +Continuation=shutdown with handover to successor context. +Priority=urgent shutdown.

    SYN (22)        Heartbeat / synchronise / keep-alive.      Plain=I am alive. +ACK=bidirectional check, confirm you are alive. +Continuation=data incoming shortly, pre-warm receiver. +Priority+Continuation=urgent data imminent, stand by.
  ------------- --------------------------------------------- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**7.5 Block and Session Management**

**ETB (23), CAN (24), EM (25), SUB (26)**

  ------------- ---------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   **Control**                        **Role**                                                                                                               **Key Flag Combinations**

    ETB (23)       Block boundary / intermediate batch separator.                      Plain=block complete, more follow. +ACK=validation gate (receiver confirms block before next). +Continuation=continuous block stream. +Priority=priority block close.

    CAN (24)              Cancel last unit / void record.                              Plain=discard, no replacement. +ACK=confirm cancellation applied. +Continuation=cancel with replacement following. +Priority=discard immediately, no queue processing.

     EM (25)           Capacity signal / buffer full warning.                         Plain=capacity reached, pause. +ACK=receiver acknowledges constraint. +Continuation=capacity report follows. +Priority+ACK=capacity crisis requiring immediate response.

    SUB (26)     Data substitution placeholder / correction marker.   Plain=data missing, placeholder follows. +ACK=confirm placeholder registered, not processed as real. +Continuation=real data incoming, hold placeholder. +Priority+Continuation=urgent correction chain.
  ------------- ---------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**7.6 Codebook and Mode Controls**

**SO (14), SI (15)**

Lightweight codebook toggle. SO shifts to secondary codebook declared at session open. SI restores the primary. Together they provide a 1-byte codebook toggle distinct from the full DLE mode transition, useful for brief alternate-interpretation windows within a stream.

  ------------- ------------------------------ ------------------------------------------------------------------------------------------------------------------------------------------------------------
   **Control**             **Role**                                                                             **Key Flag Combinations**

     SO (14)     Shift to secondary codebook.              Plain=shift. +ACK=confirm secondary codebook loaded. +Continuation=multi-codebook shift sequence. +Priority=urgent codebook change.

     SI (15)      Restore primary codebook.     Plain=restore. +ACK=confirm primary restored. +Continuation=partial restore (intermediate codebook active before final restore). +Priority=urgent restore.
  ------------- ------------------------------ ------------------------------------------------------------------------------------------------------------------------------------------------------------

**7.7 Auxiliary Controls**

**NUL (0), BS (8), CR (13)**

  ------------- ------------------------------------------ ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   **Control**                   **Role**                                                                                                    **Key Flag Combinations**

     NUL (0)         Typed padding / null keep-alive.                Plain=no-op filler. +ACK=null ACK --- alive confirmation with no content. +Continuation=padding continues, more follows. +Priority=alignment padding in priority stream.

     BS (8)            Compact retransmit request.          Plain=retransmit last byte or unit. +Priority=urgent retransmit, last unit was critical. +ACK=retransmit and confirm when received. +Continuation=retransmit multiple units, count follows.

     CR (13)     Restart current partial record assembly.      Plain=discard partial record, start fresh. +ACK=confirm partial was discarded. +Priority=urgent restart, current partial is corrupt. +Continuation=restart and stream reset follows.
  ------------- ------------------------------------------ ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**7.8 Conditional Controls**

**HT (9), LF (10), VT (11), FF (12)**

> *These controls require explicit non-text channel declaration before use. On any channel that may carry UTF-8, ASCII, or Latin-1 text their byte values appear as content and will be misread as protocol signals. Non-text declaration: Category 1101 Context Declaration with encoding type binary, OR session-level binary mode flag.*

  ------------- ------------------------------------------------------------------------------ ---------------------------------------------------------------------------------------------------------------------------------------
   **Control**                           **Role (non-text channels)**                                                                                 **Key Flag Combinations**

     HT (9)                       Field advance in schema-declared streams.                     Plain=advance to next field. +Priority=skip to priority field. +ACK=confirm current field received. +Continuation=multiple advances.

     LF (10)                    Record advance in structured non-text streams.                  Plain=next record. +ACK=confirm previous record before advancing. +Priority=priority record follows. +Continuation=multiple advances.

     VT (11)                    Group advance in structured non-text streams.                                         Plain=next group. +ACK=confirm previous group complete. +Priority=priority group follows.

     FF (12)     Phase or section advance. Distinct from FS (marker) --- FF commands advance.         Plain=next phase. +ACK=confirm section complete. +Priority=urgent phase transition. +Continuation=multi-step transition.
  ------------- ------------------------------------------------------------------------------ ---------------------------------------------------------------------------------------------------------------------------------------

**8. NESTED SEQUENCES**

A nested sequence occurs when a transmission structure contains another transmission structure within it. The outer structure is active and the inner structure opens, completes, and closes before the outer structure resumes. BitPads supports six nesting scenarios, each with defined stack behaviour and context rules.

**8.1 The Six Nesting Scenarios**

  ------------------------------ -------------------------------------------------------------------------------------------- ---------------------- -------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
           **Scenario**                                                  **Trigger**                                             **Stack Push?**      **Outer Pauses?**                                                                                           **Description**

       1\. Record in Stream                 Enhancement field 101 (component escalation) in any stream signal slot                     YES                   YES                      A full BitPads Record delivered within an active stream. Stream counter pauses. Inner Record reads Meta bytes, Layer 1, and components. Stack restores stream on close.

    2\. Sub-session in Session                           SOH + Continuation (\--C) in P1 signal slot                                   YES                   YES           A nested session with its own Layer 1 opens within the current session. Outer session suspended. Inner session has independent identity, domain, and permissions. Stack restores outer on EOT.

      3\. Compound in Stream      1111 continuation marker in a BitLedger record that was delivered via component escalation     YES (already in)          Partial            A compound record pair (primary + 1111 continuation) within an escalated record within a stream. The compound close (bit 39=0) closes the inner compound before the inner record closes.

       4\. Signal Sequence                                Continuation flag (C=1) in any signal slot                                    NO            No (same position)                       Multiple enhanced C0 bytes at the same slot position. Not structural nesting --- repetition at one position. No stack push. Receiver reads until C=0.

     5\. Fragmented + Signal               Meta bit 3=1 (BitPad fragment) simultaneously with C=1 in a signal slot             Partial (bit 3 only)           No                   Outer BitPad fragment sequence open AND inner signal sequence open simultaneously. Both close independently. Meta bit 3=0 closes BitPad fragment. C=0 closes signal sequence.

   6\. Context Update in Stream                    Enhancement field 111 + opcode byte in any active stream                             NO                  Brief                              In-stream context operation via DLE + opcode. Stream pauses for 2 bytes. No stack push --- context updates in place. Stream resumes under new context.
  ------------------------------ -------------------------------------------------------------------------------------------- ---------------------- -------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**8.2 The Parser Stack**

Scenarios 1 and 2 require a parser stack --- a last-in-first-out structure of saved parser state frames. Each frame is a complete snapshot of the parser context at the moment nesting was entered. When the nested structure closes, the frame is popped and the outer context is restored exactly.

**ParserStateFrame --- Data Structure**

\@dataclass

class ParserStateFrame:

\# Where outer structure was interrupted

outer_mode: int \# WAVE/RECORD/STREAM/COMMAND/CONTEXT

outer_category: int \# category code 0-15

outer_slot_position: int \# slot P1-P13 at time of interrupt

outer_component_flags: int \# which components remain unread

\# Signal sequence state at interruption

signal_sequence_open: bool \# was a C=1 sequence in progress?

signal_c0_code: int \# which C0 code was sequencing

signal_count: int \# how many signals received so far

\# Stream state (if outer was a stream)

stream_bytes_remaining: int \# length countdown, 0 if not stream

stream_codebook: int \# active codebook index

stream_archetype: int \# active archetype code

stream_cipher_active: bool \# cipher shift flag

\# Session/batch context

scaling_factor_index: int \# current SF

decimal_position: int \# current D

optimal_split: int \# current S

currency_code: int \# current currency/qty type

\# Enhancement and continuation state

enhancement_active: bool \# was grammar active?

meta_continuation: bool \# was Meta byte bit 3=1?

\# Resume position

resume_byte_offset: int \# stream position to resume from

\# Frame size: approximately 20 bytes on 32-bit embedded device

\# Stack memory formula:

\# hardware_max = floor(available_stack_bytes / 20)

\# Examples:

\# 64 bytes available =\> hardware_max = 3

\# 256 bytes available =\> hardware_max = 12

\# 1 KB available =\> hardware_max = 51

**ParserStack --- Class and Operations**

class ParserStack:

def \_\_init\_\_(self, hardware_max: int, policy: NestingPolicy):

self.max_depth = min(hardware_max, policy.max_depth)

self.policy = policy

self.\_stack: list\[ParserStateFrame\] = \[\]

\@property

def depth(self) -\> int:

return len(self.\_stack)

\@property

def at_limit(self) -\> bool:

return self.depth \>= self.max_depth

def push(self, frame: ParserStateFrame) -\> bool:

\# Returns False if at limit --- caller handles overflow policy

if self.at_limit:

return False

self.\_stack.append(frame)

\# Warn at threshold

if self.depth \>= self.policy.warn_at_depth:

emit_enhanced_c0(C0Code.EM,

priority=(self.depth \>= self.max_depth - 1))

return True

def pop(self) -\> ParserStateFrame:

if not self.\_stack:

raise ProtocolError(\'Stack underflow\')

return self.\_stack.pop()

def peek(self) -\> ParserStateFrame \| None:

return self.\_stack\[-1\] if self.\_stack else None

**8.3 Stack Operations at Each Nesting Boundary**

**Component Escalation (Record in Stream)**

def handle_component_escalation(byte: int,

session: SessionState,

stack: ParserStack) -\> None:

\'\'\'

Called when: enhancement field 101 in a stream signal slot.

Effect: pause stream, begin reading inner BitPads Record.

\'\'\'

frame = ParserStateFrame(

outer_mode = session.current_mode,

outer_category = session.current_category,

outer_slot_position = session.current_slot,

outer_component_flags = session.remaining_components,

signal_sequence_open = session.signal_sequence_open,

signal_c0_code = session.signal_c0_code,

signal_count = session.signal_count,

stream_bytes_remaining= session.stream_counter,

stream_codebook = session.active_codebook,

stream_archetype = session.active_archetype,

stream_cipher_active = session.cipher_active,

scaling_factor_index = session.sf_index,

decimal_position = session.decimal_pos,

optimal_split = session.split,

currency_code = session.currency,

enhancement_active = session.enhancement_active,

meta_continuation = session.meta_continuation,

resume_byte_offset = session.stream_position

)

if not stack.push(frame):

if session.policy.nesting.overflow_policy == \'reject\':

raise ProtocolError(\'Nesting limit exceeded\')

elif session.policy.nesting.overflow_policy == \'flatten\':

emit_enhanced_c0(C0Code.NAK,

flags=ParserFlags(continuation=True))

return \# treat as same level

\# Transition to inner Record

session.current_mode = ParserMode.RECORD

session.inner_record_active = True

**Inner Record Close --- Pop and Resume**

def handle_inner_record_close(session: SessionState,

stack: ParserStack) -\> None:

\'\'\'

Called when inner Record completes (ETX/EOT in P8 slot,

or final component read with Continuation=0).

Effect: pop stack, restore outer stream context.

\'\'\'

outer = stack.pop() \# raises ProtocolError if empty

session.current_mode = outer.outer_mode

session.current_category = outer.outer_category

session.current_slot = outer.outer_slot_position

session.remaining_components = outer.outer_component_flags

session.signal_sequence_open = outer.signal_sequence_open

session.signal_c0_code = outer.signal_c0_code

session.signal_count = outer.signal_count

session.stream_counter = outer.stream_bytes_remaining

session.active_codebook = outer.stream_codebook

session.active_archetype = outer.stream_archetype

session.cipher_active = outer.stream_cipher_active

session.sf_index = outer.scaling_factor_index

session.decimal_pos = outer.decimal_position

session.split = outer.optimal_split

session.currency = outer.currency_code

session.enhancement_active = outer.enhancement_active

session.meta_continuation = outer.meta_continuation

session.stream_position = outer.resume_byte_offset

session.inner_record_active = False

**Sub-Session Open and Close**

def handle_sub_session_open(session, stack):

\'\'\'SOH + Continuation in P1 slot.\'\'\'

frame = build_full_session_frame(session)

if not stack.push(frame):

handle_overflow(session, stack)

return

\# Reset session --- sub-session reads own Layer 1

session.current_mode = ParserMode.IDLE

session.sub_session_depth += 1

def handle_sub_session_close(session, stack):

\'\'\'EOT in sub-session.\'\'\'

outer = stack.pop()

restore_session_from_frame(session, outer)

session.sub_session_depth -= 1

def read_signal_slot(position: int,

session: SessionState) -\> list\[C0Signal\]:

\'\'\'

Read one signal slot. Handles C=1 Continuation chaining.

No stack push --- sequence is repetition at one position.

\'\'\'

signals = \[\]

count = 0

max_seq = session.policy.nesting.max_signal_sequence_len

while True:

byte = read_next_byte()

priority = bool(byte & 0b10000000)

ack_request = bool(byte & 0b01000000)

continuation = bool(byte & 0b00100000)

c0_code = byte & 0b00011111

if c0_code not in AGREED_C0_SET:

raise ProtocolError(f\'Unknown C0 {c0_code} at slot {position}\')

signals.append(C0Signal(c0_code, priority,

ack_request, continuation, position))

count += 1

if count \> max_seq:

raise ProtocolError(\'Signal sequence exceeded max length\')

if ack_request:

emit_enhanced_c0(C0Code.ACK,

ParserFlags(priority=priority, continuation=continuation))

if c0_code == 0b00111 and enhancement_field(byte) == 0b101:

\# Component escalation --- push stack, begin inner Record

handle_component_escalation(byte, session, stack)

if not continuation:

break

return signals

**8.4 Nesting Rules and Depth Limits**

  ------------------------------------------- ------------------------------ -------------------------------------------- ------------------ -------------------
               **Nesting Type**                       **Stack Push**                         **Context**                   **Default Max**    **Configurable**

    Record in Stream (component escalation)                YES                Partial --- stream resets, session carries     2 per stream       Profile JSON

   Sub-session in Session (SOH+Continuation)               YES                           Full restore on pop                 1 (usually)      Layer 1 + Profile

         Compound in Escalated Record          Already in (from escalation)                    Partial                     4 compound chain     Profile JSON

           Signal Sequence (C flag)                         NO                                No change                       8 per slot        Profile JSON

      Fragmented + Signal simultaneously           Partial (bit 3 only)                   Meta bit 3 tracked               System dependent     Profile JSON

    Context Update in Stream (DLE + opcode)                 NO                             Updates in place                   30 opcodes           Session
  ------------------------------------------- ------------------------------ -------------------------------------------- ------------------ -------------------

OPERATIVE NESTING LIMIT:

effective_depth = min(hardware_max, policy_max, negotiated_max)

hardware_max = floor(stack_memory_bytes / frame_size_bytes)

policy_max = declared in NestingPolicy dataclass

negotiated_max= min(sender_declared, receiver_declared)

negotiated via DC2 parameter in P1 slot

**8.5 Hardware Configuration**

The device declares its nesting capability in Layer 1. Two bits in Layer 1 session defaults carry a nesting level code. When extended declaration is needed (depth beyond 4), a Nesting Declaration Extension byte follows Layer 1.

LAYER 1 BITS 9 AND 12 --- NESTING CODE (2-bit):

00 = depth 1 (flat only, no nesting permitted)

01 = depth 2 (one level of nesting)

10 = depth 4 (up to 4 levels)

11 = extended --- Nesting Declaration Extension byte follows Layer 1

NESTING DECLARATION EXTENSION BYTE (when code = 11):

Bits 1-4: Maximum nesting depth (0-15 levels)

Bit 5: Stack overflow policy 0=reject 1=flatten

Bit 6: Timeout active 0=no 1=yes

Bits 7-8: Timeout scale 00=none 01=seconds 10=units 11=control bytes

**8.6 Operator Configuration**

\@dataclass

class NestingPolicy:

max_depth: int = 3

overflow_policy: str = \'reject\' \# \'reject\'\|\'flatten\'\|\'error\'

timeout_enabled: bool = False

timeout_units: int = 30

\# Per-type limits

max_record_in_stream: int = 2

max_session_in_session: int = 1

max_signal_sequence_len: int = 8

max_compound_depth: int = 4

\# Warning threshold --- emits EM signal at this depth

warn_at_depth: int = 2

\# Profile JSON representation:

NESTING_JSON = {

\'nesting\': {

\'max_depth\': 3,

\'overflow_policy\': \'reject\',

\'per_type\': {

\'record_in_stream\': 2,

\'session_in_session\': 1,

\'signal_sequence\': 8,

\'compound_depth\': 4

},

\'warn_at_depth\': 2

}

}

**8.7 Depth Negotiation at Session Open**

When sender and receiver have different nesting limits they negotiate at session open using the P1 signal slot. The agreed depth is the minimum of both declared values.

NEGOTIATION SEQUENCE at P1 (Pre-Session Signal Slot):

1\. Sender transmits Layer 1 with nesting code in bits 9+12.

2\. Receiver reads Layer 1, extracts sender_max.

3\. Receiver transmits DC2 + ACK in P1 slot:

parameter byte = receiver_max

4\. Both sides compute:

agreed_depth = min(sender_max, receiver_max)

5\. If agreed_depth == 0:

Receiver emits EM + Priority:

\'Nesting not permitted. Flat sessions only.\'

session.nesting_permitted = False

def negotiate_nesting(sender_max, receiver_max) -\> int:

agreed = min(sender_max, receiver_max)

emit_enhanced_c0(C0Code.DC2,

ParserFlags(ack_request=True), parameter=agreed)

return agreed

**8.8 Context Preservation Rules**

When pushing the parser stack, the following rules determine what each context field does in the inner structure:

  ---------------------- -------------------------- ----------------------------- ----------------------------------------------------------
        **Field**         **On Push (inner gets)**   **On Pop (outer restored)**                          **Notes**

        sender_id               Carries over             Restored from frame                Fundamental identity always preserved

          domain                Carries over                  Restored             Inner operates in same domain unless Layer 1 re-declares

       permissions              Carries over                  Restored                      Inner cannot exceed outer permissions

   session_enhancement          Carries over                  Restored                       Enhancement grammar state preserved

      scaling_factor            Carries over             Restored from frame             Inner may re-declare; outer restored on pop

     decimal_position           Carries over             Restored from frame                              Same as SF

      currency_code             Carries over             Restored from frame                              Same as SF

      optimal_split             Carries over             Restored from frame                              Same as SF

      stream_counter            RESETS to 0              Restored from frame                   Inner has its own length context

     active_codebook            RESETS to 0              Restored from frame                  Inner starts with primary codebook

     active_archetype           RESETS to 0              Restored from frame                 Inner starts with default archetype

      cipher_active           RESETS to false            Restored from frame                 Cipher must be re-declared in inner

      compound_open           RESETS to false            Restored from frame                   Inner compounds are independent

     records_received           RESETS to 0           Not restored (outer kept)               Inner record count is independent

   signal_sequence_open        Saved in frame            Restored from frame              Outer sequence resumes after inner closes
  ---------------------- -------------------------- ----------------------------- ----------------------------------------------------------

**9. CONFLICT RESOLUTION**

Every potential conflict between enhanced C0 signals and existing BitPads mechanisms is addressed here. In most cases the signal slot architecture resolves conflicts structurally --- they occupy different declared positions and cannot collide.

**9.1 Enhanced C0 vs Control Records**

BitPads control records begin with a leading 0 bit (type field bits 2-4, payload bits 5-8). An enhanced C0 byte in a signal slot may also have specific upper bit patterns. The structural separation is absolute: control records are Wave-layer constructs read at the session level between transmission units. Signal slots are sub-components within records and streams, read at declared positions inside those structures. The parser is never simultaneously expecting a control record and a signal slot at the same position.

**9.2 Enhanced C0 vs Extension Bytes**

Extension bytes are triggered by bit 40 of the BitLedger Layer 3 block (the extension flag). They follow the BitLedger record and carry sub-category, party type, timestamp, and other per-record details. Signal slots are declared by the Signal Slot Presence byte (Meta byte 2 bit 8 = 1) and occupy positions between components. The two mechanisms have completely separate declaration paths and never share a position. An extension byte triggered by bit 40 arrives after the full 40-bit Layer 3 record. A Post-Record signal slot (P8) arrives after the final component of the BitPads record. Both can be present and both are read --- in order.

**9.3 ESC in Signal Slot vs Extended Category in Meta**

ESC (C0 code 27) in a signal slot triggers a protocol context transition --- an in-stream or in-session escape into extended operation. The extended category flag in Meta byte 1 (bits 5-8 = 1111) triggers an extended category code for the transmission unit. These are different mechanisms at different structural levels. Meta byte 1 is a System Slot (Type A) --- the extended category flag there operates on the category system for the whole transmission. An ESC byte in a Signal Slot (Type B) operates on the stream or record context at that position. The parser reads Meta byte 1 in System Slot mode; it reads signal slot positions in Signal Slot mode. The two modes are mutually exclusive at any given position.

**9.4 SOH as Bootstrap vs SOH as Signal Code**

SOH (code 1, byte 0x01) is the Layer 1 bootstrap anchor --- the single context-free signal that transitions the parser from IDLE to Layer 1 Read. It is also C0 code 1 in the agreed set and can appear in signal slots (particularly P1) with flag modifications. The rule is absolute and simple: in IDLE state, byte 0x01 always means session open. In a signal slot position (P1-P13), a byte with lower 5 bits = 00001 means SOH with flags in the upper 3 bits. These two interpretations are separated by parser state. The IDLE state is the only state where the bootstrap rule applies. The parser is never simultaneously in IDLE state and reading a signal slot.

**9.5 The Plain Form Rule**

The 000-flag form of every C0 code is its plain byte value (0-31). A plain BEL is byte 0x07. A plain EOT is byte 0x04. No escape sequence is needed to transmit a plain C0 signal in a signal slot --- the 000-flag combination is naturally the byte value itself, which is naturally the plain C0 control. This means backward compatibility for legacy receivers that do not know about enhancement is automatic: they read bytes 0-31 as standard C0 controls, which is exactly what the 000-flag form produces.

**10. THE C0 ENHANCEMENT MICROSERVICE**

The C0 Enhancement Module satisfies all three microservice properties: independent (attaches without affecting uninvolved transmissions), bounded (clean four-operation interface), and proportional (cost exactly matches use).

**10.1 The Microservice Principle Applied**

> *If the C0 Enhancement Module is not activated, a transmission is byte-for-byte identical to a standard BitPads transmission. The module adds no overhead to transmissions that do not use it. Every byte of overhead it adds is directly earning its cost by providing a signal, a confirmation, or a nesting boundary that the transmission explicitly needs.*

**10.2 The Five Attachment Points**

  ------------- ---------------------------- --------------------------------------------------------- -------------------------------------- ---------------------------------------------------------------------------
    **Level**       **Attachment Point**                     **Activation Mechanism**                      **Per-Transmission Overhead**                                     **Use Cases**

     Session        Layer 1 session flag                 1 bit in Layer 1 session defaults                    Zero after session open              Deep space, safety-critical, high-BER links, maximum reliability

      Batch             Layer 2 flag                      1 bit in Layer 2 reserved space                     Zero per record in batch         Mixed sessions, engineering telemetry batches alongside financial records

    Category        Implicit in category         Categories 1100/1101/1110 activate automatically       Zero beyond the category declaration          Telegraph emulation, command sequences, context management

     Record      Signal Slot Presence byte    Meta byte 2 bit 8 = 1, then 1-byte presence declaration       1 byte when any slot active               Occasional high-reliability records within routine batches

   Inline Wave   Meta byte + enhanced bytes          Category 1110 Wave with enhanced C0 bytes              1 Meta byte + N signal bytes          Heartbeat, alert, flow control, codebook shifts --- pure signalling
  ------------- ---------------------------- --------------------------------------------------------- -------------------------------------- ---------------------------------------------------------------------------

**10.3 The Industrial Strength Spectrum --- Levels 0 through 5**

  ----------- -------------------------- ------------------------------------------- -------------------------------- -------------------------------------------------------------------------
   **Level**           **Name**                        **Activation**                            **Cost**                                    **Reliability Layer Added**

       0            No Enhancement              Standard BitPads. No module.                       Zero                                   Standard protocol validation only

       1            Inline Signals          Category 1110 Wave for pure control.         1 Meta + N signal bytes                    Priority, ACK, and Continuation on C0 signals

       2            Record Signals        Signal Slot Presence byte in Record mode.      1 byte when slots active           Component boundary signalling, confirmed delivery per record

       3          Batch Enhancement                  Layer 2 batch flag.                          1 bit                    All records in batch can use signals. Zero per-record overhead.

       4         Session Enhancement                Layer 1 session flag.                         1 bit                   All control positions in session can use signals. Zero per-batch.

       5       Full Telegraph Emulation         Category 1110 + session flag.         Session flag + stream overhead   Complete Murray-Baudot lineage. All 32 codes active. Legacy compatible.
  ----------- -------------------------- ------------------------------------------- -------------------------------- -------------------------------------------------------------------------

**10.4 The Microservice Interface**

INTERFACE --- four operations:

activate(scope: Scope) -\> EnhancementContext

scope: SESSION \| BATCH \| STREAM \| RECORD \| INLINE

Returns: context handle for subsequent operations

Raises: NestingLimitError if scope cannot be activated

signal(c0_code: int, flags: ParserFlags,

parameter: int = 0) -\> bytes

c0_code: 0-31, must be in AGREED_C0_SET

flags: ParserFlags(priority, ack_request, continuation)

parameter: optional following byte (for DC2 updates, etc.)

Returns: 1-2 byte sequence ready for transmission

Raises: InvalidC0Code, FlagCombinationError

decode(byte: int, context: EnhancementContext) -\> C0Signal \| None

byte: received byte at current signal slot position

Returns: C0Signal(code, priority, ack_request, continuation)

None if byte is not a valid enhanced C0 signal

Raises: InvalidC0Code if lower 5 bits not in agreed set

deactivate(context: EnhancementContext) -\> None

Closes the enhancement context at the declared scope.

For SESSION scope: removes session flag from state.

For STREAM scope: marks stream as closing.

For RECORD scope: resets Signal Slot Presence byte.

**10.5 Integration Examples at Each Level**

LEVEL 1 --- Inline: 2-byte priority alert with ACK:

BYTE 1: Meta byte 1 = 0 0 0 1 1110 (category 1110)

BYTE 2: BEL + Priority + ACK = 110 00111 = 0xC7

Total: 2 bytes. Receiver rings alert, sends ACK.

LEVEL 2 --- Record: P4 and P8 slots active:

Signal Slot Presence: 1000 0100 (P4 and P8 active)

P4: STX + Priority (100 00010 = 0x82)

\[Value block - 3 bytes\]

P8: ETX + ACK (010 00011 = 0x43)

Extra cost: 1 (presence byte) + 2 (signals) = 3 bytes

LEVEL 4 --- Session: all slots available at zero per-record cost:

Layer 1 session flag set. Every record can use P1-P13.

No presence byte needed per record.

Signal slots are always open at declared positions.

Per-record overhead: 0 bytes (flag paid once at session open).

**11. CATEGORY 1100 --- COMPACT COMMAND MODE**

Compact Command Mode fills the gap between a single Wave command (one Task short form, Category 0011) and a full Record (which requires Layer 1 and all component overhead). It handles discrete sequences of compact typed commands --- a command queue --- where each command is 1-3 bytes.

**11.1 Activation and Stream Structure**

META BYTE 1: 0 x x 1 1100

\|\|\|\|

Category 1100

SEQUENCE:

\[Meta byte 1\]

\[Stream-Open signal slot P9 --- optional enhanced C0\]

\[1-byte length prefix --- number of commands, optional\]

\[Command bytes --- 1-3 bytes each\]

\[Stream-Close signal slot P11\]

COMMAND BYTE STRUCTURE:

Bits 1-3: Command class (8 classes)

Bits 4-8: Command code (32 per class)

STREAM CLOSE TRIGGERS:

Length prefix exhausted

EOT plain byte (0x04) at any position

New Meta byte detected

**11.2 Standard Command Code Tables**

  ---------------------- ---------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   **Class (bits 1-3)**      **Name**                                                                                                                             **Key Codes (bits 4-8)**

           000            System Control                                                 00001=NOP/Ping. 00010=Reset. 00011=Sync. 00100=Checkpoint save. 00101=Checkpoint restore. 00110=Mode shift. 00111=Status request. 11100=FS. 11101=GS. 11110=RS. 11111=US.

           001               Execute                                   00001=Start. 00010=Stop. 00011=Pause. 00100=Resume. 00101=Abort. 00110=Complete. 00111=Retry. 01000=Fire/Actuate. 01001=Release. 01010=Lock. 01011=Unlock. 01100=Open. 01101=Close. 01110=Toggle. 01111=Cycle.

           010                Query                       00001=Status. 00010=Health. 00011=Position. 00100=Velocity. 00101=Temperature. 00110=Pressure. 00111=Power. 01000=Fuel. 01001=Battery. 01010=Signal. 01011=Error count. 01100=Queue depth. 01101=Uptime. 01110=Version. 01111=Identity.

           011              Configure      00001=Set value. 00010=Set threshold. 00011=Set mode. 00100=Set rate. 00101=Set address. 00110=Set codebook. 00111=Set archetype. 01000=Enable. 01001=Disable. 01010=Set SF. 01011=Set D. 01100=Set timeout. 01101=Set priority. 01110=Set encoding. 01111=Set domain.

           100               Schedule                      00001=At time (time byte follows). 00010=After duration. 00011=At interval. 00100=On trigger. 00101=On threshold. 00110=On sequence complete. 00111=On error. 01000=Cancel schedule. 01001=Defer. 01010=Expedite. 01011=Set deadline.

           101               Delegate                                                                  00001=To node (node ID byte follows). 00010=Broadcast. 00011=Multicast. 00100=Return to originator. 00101=Proxy. 00110=Relay. 00111=Escalate.

           110             Conditional                                                   00001=If value GT. 00010=If value LT. 00011=If value EQ. 00100=If state equals. 00101=If error present. 00110=If connected. 00111=If timeout. 01000=If sequence complete.

           111               Extended                                                                                                   Next byte = 8-bit command code. 256 additional commands per domain profile.
  ---------------------- ---------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**11.3 Signal Slots in Compact Command Mode**

P9 (Stream-Open) declared by category. P10 (Inline, before each command) declared by a flag in the Stream-Open Control byte. P11 (Stream-Close) always present as the final signal. BEL+Priority in P9 pre-announces urgent sequence. CAN in P10 before a command voids the previous command. ETB+Continuation in P11 announces more command batches follow.

**12. CATEGORY 1101 --- CONTEXT DECLARATION**

Category 1101 provides dynamic context management --- the ability to declare, update, or switch interpretation context before a stream opens, mid-stream while active, or at session level for all subsequent transmissions.

**12.1 Standalone Wave Usage**

META BYTE 1: 0 x 0 1 1101 (Wave, category 1101)

FOLLOWED BY: Context Declaration Block (1-4 bytes)

THEN: The stream or transmission to which context applies

CONTEXT DECLARATION BLOCK --- BYTE 1:

Bits 1-4: Context type

0001 = Activate enhancement grammar

0010 = Deactivate enhancement grammar

0011 = Declare codebook index (index byte follows)

0100 = Declare archetype assignment

0101 = Declare encoding type for following stream

0110 = Declare binary mode window

0111 = Update session parameter

1000 = Declare compound event context

1001 = Pre-declare stream structure

1010 = Suspend error checking for N bytes

1011 = Resume error checking

1100-1110 = Profile defined

1111 = Extended (next byte = 8-bit code)

Bits 5-8: Context scope

0001 = Next byte only

0010 = Next N bytes (N in following byte)

0011 = Next stream unit

0100 = Until next context declaration

0101 = Until stream close

0110 = Until session close

0111 = Until explicitly deactivated

1000-1110 = N stream units

1111 = Session level (requires Layer 1 ACK)

**12.2 In-Stream Context Opcodes**

Within an active enhancement stream, enhancement field 111 (Extended opcode) + an opcode byte performs a context operation in-stream. Stream pauses for 2 bytes, context updates, stream resumes.

  ------------------- ----------------------------------- ---------------------------- --------------------------------------------
      **Opcode**                 **Operation**                   **Parameters**                         **Effect**

       00000001         Activate C0 enhancement grammar               None              Enhancement grammar active from next byte.

       00000010        Deactivate C0 enhancement grammar              None                       Return to content mode.

       00000011              Switch to binary mode                    None                    Subsequent bytes are raw data.

       00000100             Return from binary mode                   None                  Resume prior interpretation mode.

       00000101           Temporary UTF-8 window open      1 byte: N bytes in window        Next N bytes interpreted as UTF-8.

       00000110          Temporary UTF-8 window close                 None                Window closed, return to stream mode.

       00000111              Codebook index update          1 byte: new index 0-255              Active codebook shifts.

       00001000                Archetype update            1 byte: new archetype 0-15            Active archetype shifts.

       00001001             Decimal position update           1 byte: new D value        Precision changes for subsequent values.

       00001010              Scaling factor update            1 byte: new SF index       Magnitude changes for subsequent values.

       00001011        Suspend stream integrity checking              None                     Entering known noisy window.

       00001100        Resume stream integrity checking               None                         Noisy window ended.

       00001101             Insert annotation block         1 byte: N, then N bytes          N bytes of annotation inserted.

       00001110          Mark compound event boundary                 None               Links this position to next stream unit.

       00001111                    Reserved                           ---                              Do not use.

   00010000-11101110      Profile-defined (15 slots)           Profile-dependent             Deployment-specific operations.

       11101111         Session-level parameter update        Requires Layer 1 ACK             Full session context change.
  ------------------- ----------------------------------- ---------------------------- --------------------------------------------

**12.3 Context Scope Reference**

Scope nibble (bits 5-8 of Context Declaration byte 1) controls how long the declared context applies. Single-byte scope is the minimum. Session-level scope is the maximum and requires Layer 1 re-confirmation via ACK before the new context applies globally.

**13. CATEGORY 1110 --- TELEGRAPH EMULATION MODE**

Telegraph Emulation Mode is the full expression of the C0 Enhancement Grammar. Every byte in the stream carries legacy C0 semantics in its lower 5 bits for legacy receivers and BitPads flag semantics in its upper 3 bits for modern receivers.

**13.1 Activation and Stream Structure**

META BYTE 1: 0 x x 1 1110 (Wave, category 1110)

STREAM OPEN CONTROL BYTE:

Bits 1-4: Active archetype (0000-1111, Universal Domain table)

Bits 5-6: Codebook declaration

00 = Universal archetype codebook

01 = Session-declared codebook

10 = Shift offset from session baseline (cipher)

11 = Extended codebook in next byte

Bit 7: Cipher shift active

0 = Archetype code is literal

1 = Archetype code is offset from session baseline

Bit 8: Archetype update permitted

0 = Persists for entire stream

1 = May update mid-stream via field 110 bytes

SEQUENCE: \[Meta1\] \[Stream-Open ctrl\] \[optional length\] \[stream bytes\]

EXIT: length exhausted OR EOT byte (0x04) OR new Meta byte

**13.2 C0 Separator Mapping**

In Telegraph Emulation mode the C0 structural separator and boundary controls map to BitPads Layer 2 separator equivalents. A single byte replaces a Layer 2 retransmission for separator advances on extremely low-bandwidth links.

  ------------- ---------- ------------------------------------ ----------------------------------------------
   **C0 Code**   **Byte**         **BitPads Equivalent**                  **Enhanced Form Example**

     FS (28)       0x1C      Layer 2 File Separator increment    0xDC = FS + Priority = urgent file boundary

     GS (29)       0x1D     Layer 2 Group Separator increment     0x5D = GS + ACK = confirmed group boundary

     RS (30)       0x1E     Layer 2 Record Separator increment   0xDE = RS + Priority = priority record group

     US (31)       0x1F         Sub-record field boundary          0xDF = US + Priority = priority sub-unit

     EOT (4)       0x04          Stream close / batch end             0x44 = EOT + ACK = confirmed close

     ENQ (5)       0x05                ACK request               0xC5 = ENQ + Priority = urgent status check

     ACK (6)       0x06              Acknowledgement                    0x06 = plain ACK always valid

     SOH (1)       0x01       Sub-stream or sub-session open     0x21 = SOH + Continuation = sub-session open
  ------------- ---------- ------------------------------------ ----------------------------------------------

**13.3 The Rolling Codebook Mechanism**

Enhancement field 110 in a stream byte (upper 3 bits = 110) updates the active codebook. The lower 5 bits carry the new codebook index. Both sender and receiver compute the same shift sequence from a session key established at Layer 1. An interceptor who does not have the session key sees a byte stream that appears to change interpretation unpredictably.

> *This is semantic obscuration --- a natural emergent property of the flexible codebook system. It is not a cryptographic guarantee and must not be relied upon as the sole security mechanism for sensitive data. It provides meaningful resistance to casual interception in low-threat environments.*

**13.4 Legacy Compatibility**

A legacy teleprinter or terminal receiving a Telegraph Emulation stream sees: bytes 0-31 as standard C0 controls (the plain 000-flag forms). Bytes 32-255 as ASCII printable characters, Latin-1 characters, or undefined characters. The C0 structural signals (FS, GS, RS, US, EOT, ENQ, ACK, BEL) are transmitted as their plain byte values (28, 29, 30, 31, 4, 5, 6, 7) whenever the sender wants to produce correct legacy behaviour. Enhanced forms (values 32-255) produce neutral or innocuous legacy output --- a printable character, a Latin-1 glyph, or a C1 control --- that does not crash the legacy receiver.

**14. WORKED EXAMPLES --- COMPLETE STEP-BY-STEP SEQUENCES**

Five detailed examples. Every byte is annotated. Parser state transitions are shown. Signal slots are identified at each position.

**14.1 Example 1 --- Two-Byte Priority Alert with ACK**

The minimum enhanced exchange. Meta byte opens Telegraph Emulation, second byte carries the alert with Priority and ACK flags. Three total bytes including the ACK response.

═══════════════════════════════════════════════════════

SENDER --- 2 bytes transmitted:

═══════════════════════════════════════════════════════

STEP 1: Choose transmission type: priority alert, confirm receipt.

STEP 2: Meta byte 1 = 0 0 0 1 1110

Bit1=0: Wave. Bit4=1: Category. Bits5-8=1110: Telegraph.

BYTE 1: 0x1E = 30 = plain RS (legacy: record separator)

STEP 3: Build alert signal:

BEL code = 00111 (lower 5 bits)

Priority=1 (bit1), ACK=1 (bit2), Continuation=0 (bit3)

Byte = 110 00111 = 0xC7 = 199

BYTE 2: 0xC7

═══════════════════════════════════════════════════════

RECEIVER --- step-by-step decode:

═══════════════════════════════════════════════════════

STEP 1: Receive 0x1E. Parser STATE 2 (session active).

STEP 2: Bit1=0 =\> Wave. Bit4=1 =\> Category mode.

Bits5-8=1110 =\> Category 1110 Telegraph Emulation.

Transition STATE 3F. Enhancement grammar ACTIVATES.

P9 (Stream-Open slot) expected next.

STEP 3: Receive 0xC7. In STATE 3F --- apply five-plus-three split:

Bits 1-3 = 110 =\> Priority=1, ACK=1, Continuation=0

Bits 4-8 = 00111 =\> C0 code 7 = BEL

Result: Priority BEL with ACK request.

ACTION: Raise priority alert. Register alert in log.

ACK required (bit2=1). No continuation (bit3=0).

STEP 4: Stream has no length prefix. EOT or new Meta byte closes.

No more bytes arrive =\> stream closes on idle.

STEP 5: Send ACK: 0 011 0001 = control type ACK, seq ref 1.

BYTE 3: 0x31

TOTAL: 2 bytes sent + 1 byte ACK = 3 bytes. Confirmed priority alert.

**14.2 Example 2 --- Session Open with P1 and P2 Signal Slots**

A formal session open using signal slots P1 and P2 to declare session character and batch priority.

SENDER:

STEP 1: Layer 1 with session enhancement flag set.

Bits2-4=001 (v1, financial). Session flag activates P1-P3.

BYTES 1-8: \[Layer 1 block, 64 bits, CRC-15 included\]

STEP 2: P1 Signal Slot (Pre-Session, enabled by session flag):

Want: safe session open with ACK confirmation.

ENQ + ACK = 010 00101 = 0x45

BYTE 9: 0x45

STEP 3: Receiver reads P1. Decodes ENQ + ACK.

Sends ACK response: 0x46 (ACK plain) or 0xC6 (ACK+Priority)

Session confirmed. Sender proceeds.

STEP 4: P2 Signal Slot (Pre-Batch, enabled by session flag):

Want: declare this batch is priority.

STX + Priority = 100 00010 = 0x82

BYTE 10: 0x82

STEP 5: Layer 2 Set B Header (48 bits).

BYTES 11-16: \[Layer 2 block\]

STEP 6: Records follow. Receiver treats all records in this

batch as priority due to STX+Priority in P2.

TOTAL OVERHEAD: 2 signal bytes (P1 + P2) across full session setup.

**14.3 Example 3 --- Record with Component Boundary Signals**

A full Record with signal slots P4, P5, and P8 active. Shows how boundary signals wrap the value component and close the record with confirmed delivery.

SENDER:

STEP 1: Meta byte 1: 1 0 0 x 1 0 0 0

Bit1=1: Record. Bit5=1: Value present.

BYTE 1: 0x88

STEP 2: Meta byte 2: 0000 00 0 1

Bits5-6=00: No time. Bit7=0: No setup byte.

Bit8=1: Signal Slot Presence byte follows.

BYTE 2: 0x01

STEP 3: Signal Slot Presence byte:

Bit1=1 (P4 active), Bit2=1 (P5 active),

Bit5=1 (P8 active), Bits3,4,6-8=0.

BYTE: 1100 0100 = 0xC4\... recalculate:

Bit1=P4, Bit2=P5, Bit3=P6, Bit4=P7, Bit5=P8, Bits6-8=111

P4+P5+P8 active: 1 1 0 0 1 1 1 1 = 0xCF

BYTE 3: 0xCF

STEP 4: Layer 1 (8 bytes). BYTES 4-11.

STEP 5: P4 Signal Slot (Pre-Value):

STX + Priority = 100 00010 = 0x82

BYTE 12: 0x82 \'Priority value incoming\'

STEP 6: Value block --- Tier 3 default (24 bits, 3 bytes).

Value = \$1,247.50 =\> N=124,750

BYTES 13-15: \[24-bit N encoding\]

STEP 7: P5 Signal Slot (Post-Value):

US + ACK = 010 11111 = 0x5F

BYTE 16: 0x5F \'Value boundary, confirm receipt\'

STEP 8: No Time, no Task, no Note. Skip to P8.

STEP 9: P8 Signal Slot (Post-Record):

ETX + Priority + ACK = 110 00011 = 0xC3

BYTE 17: 0xC3 \'Record complete, urgent confirmation\'

RECEIVER DECODES:

STEP 1: Reads Meta1 (0x88): Record mode, Value expected.

STEP 2: Reads Meta2 (0x01): No time/task/note. Slots present.

STEP 3: Reads Presence (0xCF): P4, P5, P8 active.

STEP 4: Reads Layer 1 (8 bytes): session loaded.

STEP 5: Reads P4 slot (0x82): Priority STX noted, elevated mode.

STEP 6: Reads 3-byte Value block: \$1,247.50 decoded.

STEP 7: Reads P5 slot (0x5F): US+ACK. Sends ACK for value.

STEP 8: Reads P8 slot (0xC3): ETX+Priority+ACK.

Record complete. Urgently send final ACK.

TOTAL SIGNAL OVERHEAD: 3 bytes (P4+P5+P8) + 1 (presence) = 4 bytes

**14.4 Example 4 --- Telegraph Emulation with Rolling Codebook**

Spacecraft transmits mission status stream. Mid-stream codebook shift. Legacy terminal alongside BitPads receiver.

PRECONDITIONS:

Session open. Engineering domain.

Codebook 0: mission status (BEL=nominal, LF=burn_complete, etc.)

Codebook 1: fault codes (DC3=fault_class_3, etc.)

BYTES TRANSMITTED:

B1: 0x1E = Meta byte 1, category 1110 (RS to legacy)

B2: 0x03 = Stream-Open ctrl: archetype=0000, codebook=00,

cipher=1, updates=1 (ETX to legacy)

B3: 0x06 = Length prefix: 6 stream bytes (ACK to legacy)

B4: 0x07 = BEL plain (000 00111) --- nominal status

B5: 0x2A = BEL+Continuation (001 00111) \'\*\' to legacy

= burn complete, more status follows

B6: 0xC1 = field 110, code 00001 = codebook shift to index 1

(UTF-8 leader to legacy --- renders artefact)

B7: 0x33 = Priority, code DC3 (100 10011)

\'3\' to legacy

= PRIORITY fault class 3 (codebook 1)

B8: 0x85 = Task trigger, code ENQ (100 00101)

C1 NEL to legacy

= Task trigger: abort command follows

B9: 0x38 = Task short form: Cancel/Abort, Urgent

\'8\' to legacy

B10: 0x04 = EOT plain: stream close

LEGACY TERMINAL SEES:

RS ACK ETX BEL \* \<artefact\> 3 \<NEL\> 8 EOT

Reasonable telemetry-style output. No crash.

BITPADS RECEIVER DECODES:

B4: Nominal status (BEL, codebook 0)

B5: Burn complete + sequence open (BEL+Continuation, codebook 0)

B6: Codebook shifts to 1 (fault codes). Cipher active.

B7: PRIORITY fault class 3 (DC3, codebook 1)

B8: Task trigger --- read next byte as Task

B9: URGENT ABORT command (Cancel/Abort + Priority)

B10: Stream close.

**14.5 Example 5 --- Nested Sequence: Record Within Stream**

A BitPads Record is delivered inside a Telegraph Emulation stream via component escalation. Parser stack push and pop shown explicitly. Both outer stream and inner record use signal slots and Continuation flags simultaneously.

PRECONDITIONS:

Established session. Stack max_depth=3. Depth currently 0.

═══════════════════════════════════════════════════════

SENDER ENCODES:

═══════════════════════════════════════════════════════

PHASE 1: Open Telegraph Emulation Stream

B1: 0x1E Meta byte 1, category 1110

B2: 0x03 Stream-Open ctrl: archetype=Source-Sink,

codebook=00, cipher=1, updates=1

B3: 0x08 Length prefix: 8 stream bytes

PHASE 2: Stream bytes begin

B4: 0x16 SYN plain (000 10110) --- heartbeat

B5: 0x07 BEL plain (000 00111) --- nominal status

PHASE 3: Component escalation from P10 inline slot

B6: 0xA7 BEL + Priority + Continuation (101 00111)

Enhancement field 101 = COMPONENT ESCALATION

Code = BEL = alert pre-context for inner record

\*\*\* PARSER PUSHES STACK HERE \*\*\*

Stream counter saved: 5 bytes remaining

Stream position saved: offset 6

Stack depth: 0 -\> 1

PHASE 4: Inner BitPads Record

B7: 0x9F Meta byte 1: 1 0 0 1 1 1 1 1

Record mode. Value+Time+Task+Note expected.

B8: 0x55 Meta byte 2: 0101 01 0 1

Archetype=0101. Time=Tier1 session. Bit8=1: slots.

B9: 0x30 Signal Slot Presence: 0011 0000

P6(Post-Time) and P7(Post-Task) active. Wait---

Bits: P4=0,P5=0,P6=1,P7=1,P8=0,res=111

0x37 = 0011 0111

B10-B17: Layer 1 (8 bytes, inner session same as outer)

B18: 0x82 P4 not active. No slot. \[skipped\]

Wait --- P4=0 so no Pre-Value slot.

B18-B20: Value block Tier 3 (3 bytes) --- propellant: 450 kg

B21: 0x17 Time field Tier 1: 23 seconds

B22: 0xDE P6 Post-Time slot: RS + Priority + Cont (110 11110)

Record separator between time and task, priority, more

B23: 0x5E P6 continuation: RS + ACK (010 11110)

Continuation=0 closes P6 sequence

B24: 0x38 Task short form: Cancel/Abort, Urgent

B25: 0x43 P7 Post-Task: ETX + ACK (010 00011)

Task noted, confirm before note

B26: 0xC3 P8 Post-Record: ETX + Priority + ACK (110 00011)

\*\*\* INNER RECORD COMPLETE \*\*\*

\*\*\* PARSER POPS STACK HERE \*\*\*

Stack depth: 1 -\> 0

Stream counter restored: 5 remaining

Stream position restored: offset 6

PHASE 5: Outer stream resumes

B27: 0x16 SYN plain --- stream continues

B28: 0x16 SYN plain

B29: 0x16 SYN plain

B30: 0x16 SYN plain

B31: 0x04 EOT plain --- stream close (5 bytes used = correct)

═══════════════════════════════════════════════════════

RECEIVER DECODES --- KEY TRANSITIONS:

═══════════════════════════════════════════════════════

B1-B3: Stream open. STATE 3F. Enhancement active.

Stream counter = 8.

B4-B5: Decode SYN (heartbeat) and BEL (nominal).

Counter: 8-\>6.

B6: 0xA7 in enhancement state.

Bits1-3=101: COMPONENT ESCALATION.

Bits4-8=00111: BEL --- alert pre-context.

\*\*\* PUSH STACK. \*\*\*

Frame saved: mode=STREAM, counter=5, codebook=0,

archetype=0000, cipher=1, offset=6.

Stack depth 0-\>1. Transition STATE 4 (Record).

EM warning threshold not reached (depth 1 \< warn_at 2).

B7-B8: Read inner Meta bytes. Record structure loaded.

B9: Read Signal Slot Presence. P6 and P7 active.

B10-B17: Read inner Layer 1. Inner session context loaded.

B18-B20: Read Value block. 450 kg propellant decoded.

B21: Read Time. T+23 seconds.

B22: P6 slot. 0xDE = RS+Priority+Continuation.

Signal sequence open at P6.

B23: P6 continuation. 0x5E = RS+ACK. Continuation=0.

P6 sequence complete. Send ACK.

B24: Task block. Urgent abort.

B25: P7 slot. ETX+ACK. Send ACK. Task confirmed.

B26: P8 slot. ETX+Priority+ACK.

Inner Record complete. Send urgent ACK.

\*\*\* POP STACK. \*\*\*

Restored: mode=STREAM, counter=5, codebook=0,

archetype=0000, cipher=1, offset=6.

Stack depth 1-\>0. Return STATE 3F.

B27-B30: Four SYN heartbeats. Counter: 5-\>4-\>3-\>2-\>1.

B31: EOT plain. Stream close. Counter=0. Confirmed.

TOTAL BYTES: 31

NESTING ACHIEVED: 1 level (Record within Stream)

SIGNAL SLOTS USED: P6 (sequence), P7, P8, P10 (escalation)

STACK OPS: 1 push, 1 pop. Clean resolution.

**15. TRANSMISSION FOOTPRINTS --- ENHANCEMENT OVERHEAD REFERENCE**

**15.1 Per-Element Costs**

  ---------------------------------------------------- ---------- ----------- -------------------------------------------
                      **Element**                       **Bits**   **Bytes**                 **Frequency**

           Session enhancement flag (Layer 1)              1          \<1                  Once per session

           Nesting Declaration Extension byte              8           1       Once per session (when depth\>4 declared)

        Signal Slot Presence byte (Meta2 bit8=1)           8           1         Once per record with any slot active

     Individual signal slot --- plain C0 (000 flag)        8           1               Per slot declared present

   Individual signal slot --- enhanced (001-111 flag)      8           1               Per slot declared present

           Signal sequence continuation byte               8           1        Per additional signal in a C=1 sequence

    Stream-Open Control byte (categories 1001/1110)        8           1                    Once per stream

               Context Declaration Block                  8-32        1-4                 Per context change

     In-stream context opcode (field 111 + opcode)         16          2            Per in-stream context operation
  ---------------------------------------------------- ---------- ----------- -------------------------------------------

**15.2 Overhead at Each Microservice Level**

  ---------------------- ----------------------- --------------- ------------------- -------------------
        **Level**            **Per Session**      **Per Batch**    **Per Record**      **Per Signal**

        0 --- None                  0                   0                 0                  N/A

       1 --- Inline            1 Meta byte              0                 0                1 byte

       2 --- Record                 0                   0         1 byte (presence)    1 byte per slot

       3 --- Batch           1 bit (Layer 2)            0                 0            1 byte per slot

      4 --- Session          1 bit (Layer 1)            0                 0            1 byte per slot

   5 --- Full Emulation   1 bit + 1 stream ctrl         0                 0           1 byte per signal
  ---------------------- ----------------------- --------------- ------------------- -------------------

**15.3 Break-Even Analysis**

Session-level activation (Level 4, 1 bit) versus Record-level (Level 2, 1 byte per record) breaks even at 8 records --- after 8 records the session flag is cheaper. Batch-level (Level 3, 1 bit per batch) versus Record-level breaks even at 8 records per batch. For any session with more than 8 records, session-level activation is the optimal choice. For mixed sessions where only occasional records need enhancement, record-level keeps overhead proportional to actual use.

**16. COMPLETE CATEGORY TABLE --- FINAL STATE**

  ---------- ------------------------- ------------- ------------- --------------------------- ---------------------------------
   **Code**        **Category**          **Mode**     **Layer 1**        **Enhancement**                **Description**

     0000           Plain Value            Wave        No (est.)               No                      Value block only

     0001         Simple Message           Wave        No (est.)               No                   Length-prefixed content

     0010          Status / Log            Wave        No (est.)               No                  Status code or log entry

     0011             Command              Wave        No (est.)               No                       Task short form

     0100          Basic Record           Record          YES            Optional slots              Value + optional time

     0101         Transaction+Msg         Record          YES            Optional slots                  Value + note

     0110            Rich Log             Record          YES            Optional slots               All four components

     0111         Priority Alert          Record          YES            Optional slots            Elevated priority record

     1000           Text Stream           Stream        Session                No                        UTF-8 stream

     1001        Archetype Stream         Stream        Session           Nibble-level              Packed archetype flags

     1010         Variable Field          Stream        Session                No                   Length-prefixed fields

     1011           Binary Blob           Stream        Session          Non-UTF-8 only                 Raw binary data

     1100       **Compact Command**        Wave        No (est.)    **YES --- command bytes**       Discrete command queue

     1101     **Context Declaration**      Wave           No            **Context gate**          Dynamic context management

     1110     **Telegraph Emulation**   Wave/Stream     Session       **YES --- all bytes**       Full C0 enhancement grammar

     1111        Extended Category          Any         Depends              Depends            Next byte = 8-bit extended code
  ---------- ------------------------- ------------- ------------- --------------------------- ---------------------------------

**17. GLOSSARY**

  ------------------------------ -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
             **Term**                                                                                                                                   **Definition**

          Agreed C0 Set                                                        The final set of C0 controls confirmed for use in BitPads enhancement. 29 unconditional plus 4 conditional. Hardware implementations carry this set in firmware.

         Bootstrap Anchor                                     Byte 0x01 (SOH) received in IDLE parser state. The sole context-free signal in the protocol. Unconditionally opens Layer 1 read. The only byte whose meaning does not depend on prior parser state.

      C0 Enhancement Grammar                          The mechanism by which C0 controls carry 3-bit flag matrices. Active only in declared signal slot positions or enhancement states. The five-plus-three split: bits 4-8 = C0 code identity, bits 1-3 = flag matrix.

   C0 Enhancement Microservice                                                   The optional module implementing the C0 Enhancement Grammar. Attachable at session, batch, category, record, or inline Wave scope. Costs nothing when absent.

       Component Escalation                                Enhancement field 101 (bits 1-3 = 101) in a stream signal slot. Triggers delivery of a full BitPads Record within the active stream. Pushes parser stack. Outer stream resumes when inner record closes.

           Context Slot                                                                                     See Signal Slot. Positional declaration of where enhanced C0 bytes appear in a transmission structure.

        Continuation Flag                     Flag C, bit 3 of the enhancement byte. When set (C=1), more enhanced C0 bytes follow at the same slot position. Receiver reads until C=0. Does not push parser stack --- creates sequence at one position, not structural nesting.

        Enhancement State         A named parser state in which every byte at a signal slot position is interpreted using the five-plus-three split. Entered via session flag, category declaration, or in-stream activation. Exited via stream close, new Meta byte, or deactivation opcode.

      Five-Plus-Three Split                                                      The byte decomposition rule active at signal slot positions: bits 1-3 = flag matrix (A Priority, B ACK, C Continuation), bits 4-8 = C0 code identity (0-31).

   Industrial Strength Spectrum                                         Levels 0-5 defining progressive activation scopes for the C0 Enhancement Module. Level 0 = no enhancement. Level 5 = full Telegraph Emulation, session-wide, legacy compatible.

      Murray-Baudot Lineage                                         The 155-year heritage from Baudot (1870) through Murray, ASCII, ISO 6429, Unicode to BitPads. The 5-bit payload is preserved across all generations. BitPads reclaims the 3 upper bits.

          NestingPolicy                                                             Operator-configured dataclass declaring maximum nesting depth, overflow policy, per-type limits, and warning threshold. Stored in session profile JSON.

           ParserStack                                  Fixed-size last-in-first-out structure of ParserStateFrame objects. Required for scenarios 1 and 2 (record-in-stream, sub-session-in-session). Maximum depth is min(hardware_max, policy_max, negotiated_max).

         ParserStateFrame                                Complete snapshot of parser context at moment of nesting entry. Approximately 20 bytes. Contains outer mode, category, slot position, component flags, stream state, session context, and enhancement state.

         Plain Form Rule                                                   The 000-flag combination of any C0 code produces the plain byte value (0-31). Plain BEL = 0x07. No escape mechanism needed. Backward compatible with all legacy systems.

         Rolling Codebook                                           Stream shift mechanism via enhancement field 110 bytes. Lower 5 bits carry new codebook index. Active codebook shifts mid-stream. Creates semantic obscuration for enhancement streams.

           Signal Slot               A declared position in the BitPads transmission structure where the decoder expects enhanced C0 bytes. 13 positions P1-P13 across session, record, stream, and Wave layers. The slot position is the declaration --- no byte-level type field needed.

    Signal Slot Presence Byte                                             8-bit byte present when Meta byte 2 bit 8 = 1. Declares which of the five record-layer slots (P4-P8) are active. Bits 1-5 = P4-P8 presence flags. Bits 6-8 = reserved = 1.

           Sub-Session                                         A nested session opened by SOH + Continuation in the P1 signal slot. Has its own Layer 1, identity, and records. Outer session suspended until sub-session closes with EOT. Pushes parser stack.

        Sumerian Principle                                       The foundational design philosophy: minimal mark plus shared context equals rich communication. The signal slot architecture is the codebook. The enhancement grammar is the notation system.

     Telegraph Emulation Mode                  Category 1110. Full C0 Enhancement Grammar active for stream duration. Legacy receivers see standard C0 controls and printable ASCII. BitPads receivers decode flag matrices and rich semantic events from the same byte stream.
  ------------------------------ -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**APPENDIX A --- BYTE VALUE QUICK REFERENCE**

For every C0 code in the agreed unconditional set: plain byte value plus all eight enhanced byte values. ASCII/Latin-1 meaning of enhanced values noted. Use for hardware implementation and collision awareness.

  ---------- ---------- ----------- ------- ------- ------- -------- -------- -------- --------- --------------------------------------------------------------------------------------
   **Code**   **Name**   **Plain**   **P**   **A**   **C**   **PA**   **PC**   **AC**   **PAC**                           **ASCII/Latin-1 of Enhanced Bytes**

      0         NUL        0x00      0x80    0x40    0x20     0xC0     0xA0     0x60     0xE0       0x80=C1PAD, 0x40=\'@\', 0x20=SP, 0xC0=\'À\', 0xA0=NBSP, 0x60=\'\`\', 0xE0=\'à\'

      1         SOH        0x01      0x81    0x41    0x21     0xC1     0xA1     0x61     0xE1      0x81=C1HOP, 0x41=\'A\', 0x21=\'!\', 0xC1=\'Á\', 0xA1=\'¡\', 0x61=\'a\', 0xE1=\'á\'

      2         STX        0x02      0x82    0x42    0x22     0xC2     0xA2     0x62     0xE2     0x82=C1BPH, 0x42=\'B\', 0x22=\'\"\', 0xC2=\'Â\', 0xA2=\'¢\', 0x62=\'b\', 0xE2=\'â\'

      3         ETX        0x03      0x83    0x43    0x23     0xC3     0xA3     0x63     0xE3      0x83=C1NBH, 0x43=\'C\', 0x23=\'#\', 0xC3=\'Ã\', 0xA3=\'£\', 0x63=\'c\', 0xE3=\'ã\'

      4         EOT        0x04      0x84    0x44    0x24     0xC4     0xA4     0x64     0xE4     0x84=C1IND, 0x44=\'D\', 0x24=\'\$\', 0xC4=\'Ä\', 0xA4=\'¤\', 0x64=\'d\', 0xE4=\'ä\'

      5         ENQ        0x05      0x85    0x45    0x25     0xC5     0xA5     0x65     0xE5      0x85=C1NEL, 0x45=\'E\', 0x25=\'%\', 0xC5=\'Å\', 0xA5=\'¥\', 0x65=\'e\', 0xE5=\'å\'

      6         ACK        0x06      0x86    0x46    0x26     0xC6     0xA6     0x66     0xE6      0x86=C1SSA, 0x46=\'F\', 0x26=\'&\', 0xC6=\'Æ\', 0xA6=\'¦\', 0x66=\'f\', 0xE6=\'æ\'

      7         BEL        0x07      0x87    0x47    0x27     0xC7     0xA7     0x67     0xE7       0x87=C1ESA, 0x47=\'G\', 0x27=\', 0xC7=\'Ç\', 0xA7=\'§\', 0x67=\'g\', 0xE7=\'ç\'

      8          BS        0x08      0x88    0x48    0x28     0xC8     0xA8     0x68     0xE8      0x88=C1HTS, 0x48=\'H\', 0x28=\'(\', 0xC8=\'È\', 0xA8=\'¨\', 0x68=\'h\', 0xE8=\'è\'

      13         CR        0x0D      0x8D    0x4D    0x2D     0xCD     0xAD     0x6D     0xED     0x8D=C1RI, 0x4D=\'M\', 0x2D=\'-\', 0xCD=\'Í\', 0xAD=\'SHY\', 0x6D=\'m\', 0xED=\'í\'

      14         SO        0x0E      0x8E    0x4E    0x2E     0xCE     0xAE     0x6E     0xEE      0x8E=C1SS2, 0x4E=\'N\', 0x2E=\'.\', 0xCE=\'Î\', 0xAE=\'®\', 0x6E=\'n\', 0xEE=\'î\'

      15         SI        0x0F      0x8F    0x4F    0x2F     0xCF     0xAF     0x6F     0xEF      0x8F=C1SS3, 0x4F=\'O\', 0x2F=\'/\', 0xCF=\'Ï\', 0xAF=\'¯\', 0x6F=\'o\', 0xEF=\'ï\'

      16        DLE        0x10      0x90    0x50    0x30     0xD0     0xB0     0x70     0xF0      0x90=C1DCS, 0x50=\'P\', 0x30=\'0\', 0xD0=\'Ð\', 0xB0=\'°\', 0x70=\'p\', 0xF0=\'ð\'

      17        DC1        0x11      0x91    0x51    0x31     0xD1     0xB1     0x71     0xF1      0x91=undef, 0x51=\'Q\', 0x31=\'1\', 0xD1=\'Ñ\', 0xB1=\'±\', 0x71=\'q\', 0xF1=\'ñ\'

      18        DC2        0x12      0x92    0x52    0x32     0xD2     0xB2     0x72     0xF2      0x92=undef, 0x52=\'R\', 0x32=\'2\', 0xD2=\'Ò\', 0xB2=\'²\', 0x72=\'r\', 0xF2=\'ò\'

      19        DC3        0x13      0x93    0x53    0x33     0xD3     0xB3     0x73     0xF3      0x93=undef, 0x53=\'S\', 0x33=\'3\', 0xD3=\'Ó\', 0xB3=\'³\', 0x73=\'s\', 0xF3=\'ó\'

      20        DC4        0x14      0x94    0x54    0x34     0xD4     0xB4     0x74     0xF4      0x94=undef, 0x54=\'T\', 0x34=\'4\', 0xD4=\'Ô\', 0xB4=\'´\', 0x74=\'t\', 0xF4=\'ô\'

      21        NAK        0x15      0x95    0x55    0x35     0xD5     0xB5     0x75     0xF5      0x95=undef, 0x55=\'U\', 0x35=\'5\', 0xD5=\'Õ\', 0xB5=\'µ\', 0x75=\'u\', 0xF5=\'õ\'

      22        SYN        0x16      0x96    0x56    0x36     0xD6     0xB6     0x76     0xF6      0x96=undef, 0x56=\'V\', 0x36=\'6\', 0xD6=\'Ö\', 0xB6=\'¶\', 0x76=\'v\', 0xF6=\'ö\'

      23        ETB        0x17      0x97    0x57    0x37     0xD7     0xB7     0x77     0xF7      0x97=undef, 0x57=\'W\', 0x37=\'7\', 0xD7=\'×\', 0xB7=\'·\', 0x77=\'w\', 0xF7=\'÷\'

      24        CAN        0x18      0x98    0x58    0x38     0xD8     0xB8     0x78     0xF8      0x98=C1MW, 0x58=\'X\', 0x38=\'8\', 0xD8=\'Ø\', 0xB8=\'¸\', 0x78=\'x\', 0xF8=\'ø\'

      25         EM        0x19      0x99    0x59    0x39     0xD9     0xB9     0x79     0xF9      0x99=undef, 0x59=\'Y\', 0x39=\'9\', 0xD9=\'Ù\', 0xB9=\'¹\', 0x79=\'y\', 0xF9=\'ù\'

      26        SUB        0x1A      0x9A    0x5A    0x3A     0xDA     0xBA     0x7A     0xFA      0x9A=undef, 0x5A=\'Z\', 0x3A=\':\', 0xDA=\'Ú\', 0xBA=\'º\', 0x7A=\'z\', 0xFA=\'ú\'

      27        ESC        0x1B      0x9B    0x5B    0x3B     0xDB     0xBB     0x7B     0xFB     0x9B=C1CSI, 0x5B=\'\[\', 0x3B=\';\', 0xDB=\'Û\', 0xBB=\'»\', 0x7B=\'{\', 0xFB=\'û\'

      28         FS        0x1C      0x9C    0x5C    0x3C     0xDC     0xBC     0x7C     0xFC     0x9C=C1ST, 0x5C=\'\\\', 0x3C=\'\<\', 0xDC=\'Ü\', 0xBC=\'¼\', 0x7C=\'\|\', 0xFC=\'ü\'

      29         GS        0x1D      0x9D    0x5D    0x3D     0xDD     0xBD     0x7D     0xFD     0x9D=C1OSC, 0x5D=\'\]\', 0x3D=\'=\', 0xDD=\'Ý\', 0xBD=\'½\', 0x7D=\'}\', 0xFD=\'ý\'

      30         RS        0x1E      0x9E    0x5E    0x3E     0xDE     0xBE     0x7E     0xFE     0x9E=C1PM, 0x5E=\'\^\', 0x3E=\'\>\', 0xDE=\'Þ\', 0xBE=\'¾\', 0x7E=\'\~\', 0xFE=\'þ\'

      31         US        0x1F      0x9F    0x5F    0x3F     0xDF     0xBF     0x7F     0xFF      0x9F=C1APC, 0x5F=\'\_\', 0x3F=\'?\', 0xDF=\'ß\', 0xBF=\'¿\', 0x7F=DEL, 0xFF=\'ÿ\'
  ---------- ---------- ----------- ------- ------- ------- -------- -------- -------- --------- --------------------------------------------------------------------------------------

**APPENDIX B --- SIGNAL SLOT QUICK REFERENCE**

Implementation guide format. All 13 positions, presence declaration, and most common C0 codes per position.

  ---------- ----------------------------------------- ------------------------------------------ ---------------------------------------------------------------------- ------------------------------------
   **Slot**                **Position**                             **Declared By**                                       **Most Common Codes**                                       **Notes**

      P1        After SOH, before Layer 1 remainder       Session enhancement flag in Layer 1      ENQ (handshake), SYN (routine), BEL (emergency), SOH+C (sub-session)     Session-level. Not per-record.

      P2           After Layer 1, before Layer 2                Session enhancement flag             ETB (batch boundary), STX+P (priority batch), DC2+C (parameters)      Pre-batch character declaration.

      P3      After last record, before session close           Session enhancement flag                   EOT (end), EOT+A (confirmed close), EOT+C (suspend)                   Clean session close.

      P4                Before Value block                     Signal Slot Presence bit 1                  STX (content begins), BEL+A (alert), DC2+C (params)                 Pre-value announcement.

      P5             After Value, before Time                  Signal Slot Presence bit 2                  US (boundary), US+A (confirm value), RS (separator)                   Value/time boundary.

      P6              After Time, before Task                  Signal Slot Presence bit 3                        RS (boundary), DC1 (resume), SYN (sync)                         Time/task boundary.

      P7              After Task, before Note                  Signal Slot Presence bit 4                          STX (note begins), DLE (mode shift)                           Task/note boundary.

      P8               After final component                   Signal Slot Presence bit 5                   ETX+A (confirmed close), ETX+PA (urgent confirmed)            Record close. Most important slot.

      P9         After Meta byte 1, before content           Implied by category 1100/1110                    STX (open), BEL+P (urgent), SOH+C (sub-stream)                Always present for 1100/1110.

     P10              Before each stream unit                  Stream-Open Control bit 8                     SYN (heartbeat), RS (boundary), CAN (void prev)                   Per-unit when declared.

     P11              After last stream byte                    Length exhaustion or EOT                    ETX+A (confirmed), EOT (end), ETB+C (more blocks)                       Stream close.

     P12      After Meta byte 1, before Wave content    Meta byte 1 bit 7 + descriptor extension                   STX (content begins), BEL+P (urgent)                      Lightweight Wave pre-signal.

     P13                After Wave content              Meta byte 1 bit 7 + descriptor extension              ETX+A (confirmed delivery), EOT+C (more Waves)                      Wave post-signal.
  ---------- ----------------------------------------- ------------------------------------------ ---------------------------------------------------------------------- ------------------------------------

**APPENDIX C --- PARSER STACK QUICK REFERENCE**

Compact implementation checklist for embedded device developers.

**Stack Frame Fields (20 bytes on 32-bit device)**

  ------------------------ ----------------- ----------- ------------------------------------
         **Field**             **Type**       **Bytes**              **Purpose**

         outer_mode              uint8            1       WAVE/RECORD/STREAM/COMMAND/CONTEXT

       outer_category            uint8            1               Category code 0-15

    outer_slot_position          uint8            1            Slot P1-P13 at interrupt

   outer_component_flags         uint8            1        Remaining component expect flags

    signal_sequence_open    bool+code+count       2        C=1 sequence state at interrupt

   stream_bytes_remaining       uint16            2                Length countdown

      stream_codebook            uint8            1             Active codebook index

      stream_archetype           uint8            1             Active archetype code

    stream_cipher_active         bool             1               Cipher shift state

    sf+d+split+currency        uint8 x4           4             Session value context

     enhancement_active          bool             1                 Grammar state

     meta_continuation           bool             1             Meta byte bit 3 state

     resume_byte_offset         uint32            4             Stream resume position
  ------------------------ ----------------- ----------- ------------------------------------

**Push/Pop Decision Tree**

ON ENCOUNTERING NESTING TRIGGER:

1\. Check stack.at_limit

YES and policy=\'reject\' =\> ProtocolError

YES and policy=\'flatten\' =\> emit NAK+Continuation, return

NO =\> proceed to step 2

2\. Build ParserStateFrame from current session state

3\. stack.push(frame)

4\. Check depth \>= warn_at_depth

YES =\> emit EM signal (Priority if depth \>= max-1)

5\. Reset inner context (stream_counter=0, codebook=0, etc.)

6\. Transition to inner structure parser mode

ON INNER STRUCTURE CLOSE:

1\. Check stack.depth \> 0

NO =\> ProtocolError(\'Stack underflow\')

YES =\> proceed

2\. outer = stack.pop()

3\. Restore all fields from outer frame

4\. Return to outer parser mode

**Nesting Type Compatibility Matrix**

  -------------------- ------------------- ---------------------- -------------------- ------------------
   **Inner \\ Outer**      **Stream**           **Session**            **Record**         **Command**

         Record         YES (escalation)    YES (Layer 1 record)   NO (compound only)   YES (escalation)

      Sub-session       YES (SOH+C in P9)    YES (SOH+C in P1)             NO                  NO

    Signal sequence       YES (C flag)          YES (C flag)          YES (C flag)        YES (C flag)

     Context update       YES (opcode)        YES (1101 Wave)      NO (use 1101 Wave)     YES (opcode)
  -------------------- ------------------- ---------------------- -------------------- ------------------

**APPENDIX D --- PROTOCOL CHANGE LOG**

All confirmed protocol changes across all specifications. Items 1-30 from BitLedger Protocol v3.0. Items 31-36 from Universal Domain v1.0. Items 37 onwards from this sub-protocol.

  ---------- ------------------- --------------------------------------------------------------------------------- ------------
   **Item**   **Specification**                                     **Change**                                      **Status**

     1-30      BitLedger v3.0                          See BitLedger Protocol v3.0 Appendix                         Confirmed

      31      Universal Domain               Bits 2-4 reinterpreted: bit2=wire version, bits3-4=domain              Confirmed

      32      Universal Domain            Layer 2 Currency Code = Quantity Type Code in engineering mode            Confirmed

      33      Universal Domain                  Universal flow archetype table --- 16 codes defined                 Confirmed

      34      Universal Domain                   Physical quantity type table --- 64 codes seeded                   Confirmed

      35      Universal Domain                Journal formatter extended with domain-aware vocabulary               Confirmed

      36      Universal Domain                 Conservation tolerance formalised in Rounding Balance                Confirmed

      37       Enhancement v2        Meta byte 2 bit 8 repurposed from Reserved=1 to Signal Slot Presence flag      Confirmed

      38       Enhancement v2     Signal Slot Presence byte added to Record mode component sequence (position 3)    Confirmed

      39       Enhancement v2                    13 signal slot positions P1-P13 formally defined                   Confirmed

      40       Enhancement v2           C0 Enhancement Grammar formally specified as five-plus-three split          Confirmed

      41       Enhancement v2     Three flags confirmed: Priority (bit1), ACK Request (bit2), Continuation (bit3)   Confirmed

      42       Enhancement v2         Agreed C0 set confirmed: 29 unconditional, 4 conditional, all 32 viable       Confirmed

      43       Enhancement v2                      Category 1100 assigned: Compact Command Mode                     Confirmed

      44       Enhancement v2                       Category 1101 assigned: Context Declaration                     Confirmed

      45       Enhancement v2                    Category 1110 assigned: Telegraph Emulation Mode                   Confirmed

      46       Enhancement v2                ParserStateFrame dataclass defined (\~20 bytes per frame)              Confirmed

      47       Enhancement v2            ParserStack class defined with push/pop/peek and overflow policy           Confirmed

      48       Enhancement v2                  Six nesting scenarios formally defined and specified                 Confirmed

      49       Enhancement v2            NestingPolicy dataclass defined with profile JSON representation           Confirmed

      50       Enhancement v2                  Depth negotiation via DC2 parameter in P1 signal slot                Confirmed

      51       Enhancement v2             CONTEXT_CARRY_RULES table --- full/partial/reset classification           Confirmed

      52       Enhancement v2                    Layer 1 bits 9+12 carry 2-bit nesting level code                   Confirmed

      53       Enhancement v2                Nesting Declaration Extension byte defined (when code=11)              Confirmed

      54       Enhancement v2                    SO/SI assigned: lightweight codebook toggle pair                   Confirmed

      55       Enhancement v2             NUL, BS, CR added to agreed C0 set with specific BitPads roles            Confirmed

      56       Enhancement v2                  In-stream context opcode table defined: 30 operations                Confirmed

      57       Enhancement v2                    Industrial Strength Spectrum defined: Levels 0-5                   Confirmed

      58       Enhancement v2             Five Attachment Points defined for C0 Enhancement Microservice            Confirmed
  ---------- ------------------- --------------------------------------------------------------------------------- ------------
