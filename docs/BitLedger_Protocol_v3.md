**BITLEDGER**

**BINARY FINANCIAL TRANSMISSION PROTOCOL**

*Specification v3.0 --- Full Revised Edition*

A complete double-entry accounting record and transmission standard

engineered for minimum bit footprint on low-power hardware.

*A full double-entry transaction --- both sides, full accounting classification,*

*direction, status, value, rounding metadata, and currency --- in 40 bits.*

**1. PROTOCOL OVERVIEW**

BitLedger is a binary-native financial record and transmission protocol. Its purpose is to carry complete double-entry accounting transactions in the smallest possible binary footprint while maintaining full accounting integrity, auditability, and extensibility. The protocol was designed from first principles beginning at the binary representation of accounting states and building upward, not by compressing an existing format. Every bit position carries defined meaning. No layer ends with unused zero-padded bits. The accounting rules of double-entry are enforced at the encoding level.

  ----------- ------------------------ ----------------- ---------------------- -----------------------------------------------------------------
   **Layer**          **Name**             **Size**          **Frequency**                                 **Purpose**

       1       Session Initialisation   64 bits 8 bytes     Once per session        Identity, permissions, session defaults, CRC-15 checksum

       2         Set B Batch Header     48 bits 6 bytes      Once per batch      Denomination, precision, currency, separators, rounding balance

       3         Set A + BitLedger      40 bits 5 bytes   Once per transaction               Value, flags, accounting classification

       C           Control Record        8 bits 1 byte         On demand                 Band change, ACK, batch close, parameter update
  ----------- ------------------------ ----------------- ---------------------- -----------------------------------------------------------------

> *Transmission cost for 100 transactions: 64 + 48 + (100 x 40) = 4,112 bits --- 514 bytes. A comparable JSON representation typically requires 50,000 to 200,000 bytes. The reduction is structural, not compressive. No decompression is required at the receiver.*

**1.1 Design Principles**

  ---------------------------------- -----------------------------------------------------------------------------------------------------------------------------------------------------
            **Principle**                                                                             **Implementation**

      Every bit carries meaning                   No field in any layer is zero-padded or structurally unused. Reserved bits transmit as 1 to prevent zeroed trailing bytes.

   Accounting integrity at encoding           Double-entry rules enforced by cross-layer flag redundancy. Mismatches are protocol errors detectable without a separate checksum.

        Defaults cost nothing                      The most common transaction --- single unit, exact value, standard account pair --- uses 40 bits with no extension bytes.

     Complexity scales with need                            Extension bytes, control records, and compound markers appear only when the transaction requires them.

        8-bit block discipline                                         All layers are exact multiples of 8 bits. No layer ends with trailing zero bits.

      Self-framing session open                                            SOH leading 1-bit triggers protocol without a preamble or sync sequence.

       Error detection layered        CRC-15 at Layer 1 protects session identity. Cross-layer flag validation protects every record. Invalid bit states provide a third detection layer.
  ---------------------------------- -----------------------------------------------------------------------------------------------------------------------------------------------------

**2. LAYER 1 --- SESSION INITIALISATION (64 bits / 8 bytes)**

Transmitted once at the opening of a session. Establishes sender identity, permissions, session-level defaults, protocol version, and integrity checksum. All subsequent transmissions in the session inherit this context.

**2.1 Bit Layout**

  ---------------- ---------------------- ------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
      **Bits**           **Field**         **Values**                                                                                                                **Description**

     **Bit 1**         **SOH Marker**           1                                         Always high. Self-framing --- the leading 1 triggers protocol state in the receiver. Bit-filling rules inferred deterministically. No preamble or sync byte required.

    **Bits 2-4**    **Protocol Version**     000-111                                                    8 protocol versions. Receivers reject sessions with unsupported version codes. Allows future revision without breaking existing decoders.

    **Bits 5-8**    **Core Permissions**     4 flags                                                Bit 5: Read. Bit 6: Write. Bit 7: Correct or Amend. Bit 8: Represent third party. All four must be set appropriately before records are accepted.

   **Bits 9-12**    **Session Defaults**     4 flags             Bit 9: Split order default (0=Multiplicand first, 1=Multiplier first). Bit 10: Opposing account convention (0=inferred, 1=always explicit). Bit 11: Compound mode active for session. Bit 12: BitLedger block optional.

   **Bits 13-44**      **Sender ID**       32-bit int                                  Unique sender identifier. Supports 4,294,967,295 distinct senders. On closed networks reducible to 16 bits --- freed bits reserved-transmit-1 to maintain 64-bit block size.

   **Bits 45-49**    **Sub-Entity ID**     00000-11111        31 sub-divisions per sender. Mirrors the Entity ID field in Layer 2 for standard transmissions. In represented entity mode, Layer 2 Entity ID identifies the represented party and will intentionally differ from this field.

   **Bits 50-64**   **CRC-15 Checksum**      15-bit      CRC-15 computed over bits 1-49 using generator polynomial x\^15 + x + 1 (0x8001). Receiver runs same CRC over all 64 bits --- zero remainder confirms integrity. Any non-zero result causes session rejection and NACK. See Section 2.3.
  ---------------- ---------------------- ------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**2.2 Session Default Bits 9-12**

These four bits resolve session-level conventions that would otherwise require per-record overhead or floating references. Each declares a default that Layer 3 records follow or deviate from with a single bit.

  --------- ------------------ ------------------------------------------- ------------------------------------------------- -------------------------------------------------------------
   **Bit**    **Convention**                   **Value 0**                                    **Value 1**                                         **Layer 3 Effect**

      9        Split order      Multiplicand first (value then quantity)        Multiplier first (quantity then value)                  Bit 28 confirms or reverses per record

     10      Opposing account   Inferred from account pair and direction    Always transmitted explicitly in extension byte               Governs extension byte requirement

     11       Compound mode     Records are independent, 1111 never valid          1111 continuation markers active                     Interpreter enters compound-aware mode

     12      BitLedger block         Always present in every record                Optional --- flagged when absent           Allows pure value records without accounting classification
  --------- ------------------ ------------------------------------------- ------------------------------------------------- -------------------------------------------------------------

**2.3 CRC-15 Checksum --- Full Specification**

The checksum validates the 49-bit session payload (bits 1-49) before any records are processed. A corrupt session header would cause every subsequent record to be decoded against wrong identity, permissions, or defaults. The CRC catches this at session open.

Generator polynomial: G = x\^15 + x + 1 = 1000000000000011 (binary)

= 0x8003 (hex)

ENCODER --- computing the checksum:

INPUT: P = bits 1-49 (49-bit session payload)

STEP 1: Append 15 zero bits: W = P\[1..49\] + 000000000000000

W is now 64 bits

STEP 2: For each bit position i from 1 to 49:

if leading bit of W == 1:

W = W XOR (G shifted left to align with W)

shift W left by 1

STEP 3: Remainder R = final 15 bits of W

STEP 4: Transmit bits 1-49 followed by R

Total = 64 bits

DECODER --- verifying the checksum:

INPUT: All 64 received bits

STEP 1: Run CRC-15 over all 64 bits using same polynomial

STEP 2: if result == 0x0000: no error, session accepted

if result != 0x0000: error detected

send NACK control byte

reject session

request retransmission

Error detection capability of CRC-15 over a 49-bit payload:

  ---------------------------------- -------------------- ---------------------------------------------------
            **Error Type**            **Detection Rate**                       **Notes**

          Single-bit errors                  100%           All single-bit flips detected without exception

          Double-bit errors                  100%               All two-bit error combinations detected

       Odd number of bit errors              100%               Any odd count of flipped bits detected

      Burst errors up to 15 bits             100%          Any contiguous error sequence of 15 bits or fewer

   Burst errors longer than 15 bits        99.997%             Probability of undetected error is 2\^-15
  ---------------------------------- -------------------- ---------------------------------------------------

Implementation cost on low-power hardware: the XOR shift loop runs in approximately 150-200 clock cycles for a 49-bit payload. At 1 MHz this is 0.2 milliseconds. At 8 MHz it is 0.025 milliseconds. For devices with hardware CRC acceleration the operation completes in a single instruction cycle.

**2.4 Closed Network Reduction**

  ------------- ------------------ -------------------- ------------ -----------------------
    **Field**    **Full Network**   **Closed Network**   **Saving**      **Freed Bits**

    Sender ID        32 bits             16 bits          16 bits      Reserved transmit-1

    Checksum         15 bits              8 bits           7 bits      Reserved transmit-1

   Total block       64 bits             64 bits           0 bits     Block size unchanged
  ------------- ------------------ -------------------- ------------ -----------------------

**3. LAYER 2 --- SET B BATCH HEADER (48 bits / 6 bytes)**

Transmitted once before each batch of transaction records. Establishes the decoding context that every record in the batch inherits. No record repeats Layer 2 information. When all values match session defaults, a single control byte replaces the entire 48-bit header.

**3.1 Bit Layout**

  ---------------- ----------------------- --------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
      **Bits**            **Field**          **Values**                                                                                                                                                         **Description**

    **Bits 1-2**    **Transmission Type**       01-11                                                                    01=Pre-converted. 10=Copy from sender. 11=For represented entity. Code 00 is invalid and reserved as a protocol error signal --- guarantees no valid Layer 2 begins with all-zero first byte.

    **Bits 3-9**     **Scaling Factor**         0-127                                                      Denomination multiplier applied to all decoded values in this batch. Always multiplies upward --- never used for sub-unit precision (that is Decimal Position). Indexed as powers of 10 for standard use. See Section 3.2.

   **Bits 10-13**     **Optimal Split**         0-15                                                Number of bits allocated to the Multiplier (quantity) in Layer 3 value block when bit 32 of a record is 1. Remainder allocated to Multiplicand (value). Default=8 giving 17-bit value field (max 131,071) and 8-bit quantity (max 255).

   **Bits 14-16**   **Decimal Position**       000-111                     Number of decimal places applied to decoded values. 000=integer, 001=1 place, 010=2 places (standard banking and retail), 011=3 places, 100=4 places (forex pip), 101=5 places (institutional forex), 110=6 places (crypto). 111=declared in extension byte. Applied after Scaling Factor.

     **Bit 17**       **Enquiry Bell**          0 / 1                                                                                         1=Sender requests acknowledgement of this batch before transmitting the next. Receiver must respond with ACK control record before sender proceeds.

     **Bit 18**     **Acknowledge Bell**        0 / 1                                                                                                            1=Receiver confirms successful receipt and validation of the previous batch. Clears any pending Enquiry state.

   **Bits 19-22**    **Group Separator**       4 bits                                                                                Identifies the group within which this batch falls. 4 bits = 15 group identifiers. Typically corresponds to accounting periods, quarters, or organisational divisions.

   **Bits 23-27**   **Record Separator**       5 bits                                             Identifies the record group within this batch. 5 bits = 31 identifiers. In compound transaction mode, the current Record Separator value is the implicit identity of the compound group. All linked records in a compound share this value.

   **Bits 28-30**    **File Separator**        3 bits                                                                                                 Identifies the file context. 3 bits = 7 file identifiers. Associates batches with logical file structures without external metadata.

   **Bits 31-35**       **Entity ID**        00000-11111    Identifies the sub-entity to which this batch is attributed. In standard transmissions matches Layer 1 Sub-Entity ID. In represented entity mode (Transmission Type 11) identifies the represented party and will intentionally differ from Layer 1. Used for routing and ledger attribution, not as a validation check.

   **Bits 36-41**     **Currency Code**     000000-111111                                               6-bit currency index. 64 codes. 000000=session default. 000001-011111=31 standard world currencies (seeded at setup). 100000-111110=user-defined or regional. 111111=multi-currency batch, per-record currency via control byte.

   **Bits 42-45**   **Rounding Balance**    4-bit signed                         Net rounding adjustment for the batch. Sign-magnitude encoding. 0000=exactly balanced. High bit=sign (0=net rounded up, 1=net rounded down). Lower 3 bits=magnitude in minimum precision units 1-7. 1000=escape, magnitude exceeds 7, see batch-close control record payload.

   **Bits 46-47**    **Compound Prefix**        00-11                                     00=No compound records in batch, 1111 markers are protocol errors if encountered. 01=Up to 3 compound groups. 10=Up to 7 compound groups. 11=Unlimited compound groups, interpreter uses 1111 markers throughout. Prepares interpreter before first record.

     **Bit 48**         **Reserved**              1                                                                                                                 Transmit as 1. Ensures final byte of Layer 2 is never all zeros. Reserved for future protocol versions.
  ---------------- ----------------------- --------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**3.2 Scaling Factor**

The Scaling Factor controls the magnitude of all values in the batch. It always multiplies the decoded integer upward. The full decode formula combining Scaling Factor and Decimal Position:

Real Value = (Stored Integer x Scaling Factor) / 10\^DecimalPosition

  ---------------------- -------------------- ----------------- -------------------------- ---------------------------------
   **Index (bits 3-9)**   **Scaling Factor**   **Step at D=2**     **Max Value at D=2**             **Typical Use**

         0000000                 x 1               \$0.01              \$335,544.31         Retail, payroll, small business

         0000001                 x 10              \$0.10             \$3,355,443.10             Mid-market invoicing

         0000010                x 100              \$1.00            \$33,554,431.00                Large corporate

         0000011               x 1,000             \$10.00           \$335,544,310.00       Real estate, capital equipment

         0000100               x 10,000           \$100.00          \$3,355,443,100.00        Institutional transactions

         0000101              x 100,000          \$1,000.00        \$33,554,431,000.00          Large asset portfolios

         0000110             x 1,000,000         \$10,000.00       \$335,544,310,000.00           Major institutional

         0000111             x 10,000,000       \$100,000.00      \$3,355,443,100,000.00      National scale transactions

         0001000            x 100,000,000      \$1,000,000.00    \$33,554,431,000,000.00        Sovereign, large state

         0001001           x 1,000,000,000      \$10,000,000     \$335,544,310,000,000.00    Reserve banking, central bank
  ---------------------- -------------------- ----------------- -------------------------- ---------------------------------

**3.3 Decimal Position**

  ---------- -------------- -------------- ------------------ --------------------------------------
   **Code**   **Decimals**   **Min Step**   **Max at SF x1**         **Standard Application**

     000           0             \$1          \$33,554,431        Whole units, inventory counts

     001           1            \$0.10       \$3,355,443.1         Fuel, some commodity pricing

     010           2            \$0.01        \$335,544.31     Standard retail, banking, GAAP, IFRS

     011           3           \$0.001        \$33,554.431     Fuel per litre, precision commodity

     100           4           \$0.0001       \$3,355.4431             Forex pip precision

     101           5          \$0.00001       \$335.54431        Institutional forex, bond yields

     110           6          \$0.000001      \$33.554431         Cryptocurrency, micropayments

     111        see ext        variable         variable        Exotic precision in extension byte
  ---------- -------------- -------------- ------------------ --------------------------------------

**3.4 Rounding Balance --- Sign-Magnitude Encoding**

Bits 42-45 of Layer 2:

0000 = Batch exactly balanced. No net rounding.

0001 = Net +1 precision unit rounded up

0010 = Net +2 precision units rounded up

0011 = Net +3 precision units rounded up

0100 = Net +4 precision units rounded up

0101 = Net +5 precision units rounded up

0110 = Net +6 precision units rounded up

0111 = Net +7 precision units rounded up

1000 = ESCAPE --- net rounding exceeds 7 units

see batch-close control record for full value

1001 = Net -1 precision unit rounded down

1010 = Net -2 precision units rounded down

1011 = Net -3 precision units rounded down

1100 = Net -4 precision units rounded down

1101 = Net -5 precision units rounded down

1110 = Net -6 precision units rounded down

1111 = Net -7 precision units rounded down

The precision unit is always the minimum step for the batch: Scaling Factor divided by 10\^DecimalPosition. At SF x1, D=2 the precision unit is \$0.01. At SF x1,000, D=2 it is \$10.00.

**3.5 Compound Prefix --- Bits 46-47**

These bits prepare the receiver before the first record arrives. Without them the receiver would encounter compound transactions mid-stream and have to switch modes unexpectedly. The prefix is a batch-level declaration of intent.

  ---------- --------------------------- ------------------------------------------------------------------------- --------------------------------------------------------------------
   **Code**          **Meaning**                                 **Interpreter Behaviour**                                                **Error on Violation**

      00         No compound records      Operates in simple mode. 1111 pair is a protocol error if encountered.            Any 1111 marker triggers NACK and batch rejection.

      01       Up to 3 compound groups    Compound-watch active. After 3 groups close, deactivates for remainder.   4th compound group triggers NACK, group skipped, violation logged.

      10       Up to 7 compound groups                         Same as 01 with ceiling of 7.                                        8th compound group triggers NACK.

      11      Unlimited compound groups           Full compound-aware mode for entire batch. No ceiling.                    No ceiling violation possible. 1111 always valid.
  ---------- --------------------------- ------------------------------------------------------------------------- --------------------------------------------------------------------

> *Layer 1 bit 11 must be 1 for compound mode to be active in a session. Even when Layer 1 permits compounds, a batch can declare 00 to suppress compound processing for that batch. Both must be active for 1111 markers to be valid in a given batch.*

**4. LAYER 3 --- SET A VALUE BLOCK (bits 1-32)**

The first 32 bits of every transaction record. Carries the monetary value and seven flag bits. The value is always a whole integer. Layer 2 context resolves its denomination, precision, and scale.

**4.1 Value Fields --- Bits 1-25**

  ---------------- ------------------ ------------ ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
      **Bits**         **Field**       **Values**                                                                                                                                          **Description**

   **Bits 1-17**    **Multiplicand**   0-131,071    Upper portion of value block. At default Optimal Split of 8 this field is 17 bits. When bit 32=1 (Quantity Present) this field holds price per unit. When bit 32=0 (flat value) this field is the upper part of a 25-bit flat integer --- use the full encoding formula, not this field alone.

   **Bits 18-25**    **Multiplier**      0-255                 Lower portion of value block. At default Optimal Split of 8 this field is 8 bits. When bit 32=1 this field holds the unit quantity. When bit 32=0 this field is the lower portion of the flat 25-bit integer carrying the remainder r from the formula N = A x 2\^S + r.
  ---------------- ------------------ ------------ ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**4.2 The Value Encoding Formula**

The 25-bit value block encodes any integer from 0 to 33,554,431 without gaps. The Optimal Split value S from Layer 2 governs the formula. At the default S=8:

FORMULA: N = A x (2\^S) + r

Where:

S = Optimal Split value from Layer 2 (default 8)

A = upper (25-S) bits = floor(N / 2\^S)

r = lower S bits = N mod 2\^S

N = the stored integer (0 to 33,554,431)

At default S=8:

N = A x 256 + r

A = floor(N / 256)

r = N mod 256

Max N = 131,071 x 256 + 255 = 33,554,431

COVERAGE PROOF --- no gaps:

For any target V where 0 \<= V \<= 33,554,431:

A = floor(V / 256) \-- always a whole integer

r = V mod 256 \-- always in range 0-255

N = A x 256 + r = V \-- reconstructs exactly

Therefore every integer in range is reachable.

**4.3 Full Decode Formula**

When bit 32 = 0 (flat total value):

N = A x (2\^S) + r

Real Value = (N x Scaling Factor) / (10 \^ Decimal Position)

When bit 32 = 1 (quantity split active):

Price = A field value (Multiplicand)

Quantity = r field value (Multiplier)

N = Price x Quantity

Real Value = (N x Scaling Factor) / (10 \^ Decimal Position)

Note: When bit 32 = 1, Optimal Split is ALWAYS taken from

Layer 2 regardless of bit 27. This resolves the potential

conflict between bits 27 and 32. See Section 5.

**4.4 Decode Examples**

**Example 1 --- \$4.53 exact, flat value**

Layer 2: SF=x1, D=2 (step \$0.01, max \$335,544.31)

Target: \$4.53

Encoder:

V = 4.53 x 100 / 1 = 453

A = floor(453/256) = 1

r = 453 mod 256 = 197

Store A=1 in bits 1-17, r=197 in bits 18-25

bit 26=0 (exact), bit 32=0 (flat)

Decoder:

N = 1 x 256 + 197 = 453

Real Value = (453 x 1) / 100 = \$4.53 exact

**Example 2 --- \$98,765.43, large value**

Layer 2: SF=x1, D=2

Target: \$98,765.43

Encoder:

V = 98,765.43 x 100 / 1 = 9,876,543

Check: 9,876,543 \<= 33,554,431 fits

A = floor(9,876,543/256) = 38,580

r = 9,876,543 mod 256 = 63

Decoder:

N = 38,580 x 256 + 63 = 9,876,543

Real Value = (9,876,543 x 1) / 100 = \$98,765.43 exact

**Example 3 --- 24 units at \$2.49 each, quantity split**

Layer 2: SF=x1, D=2, Optimal Split=8

Target: 24 units at \$2.49 = \$59.76

Encoder:

bit 32=1 (Quantity Present)

Price in cents: 249 =\> A = 249

Quantity: 24 =\> r = 24

Decoder:

N = 249 x 24 = 5,976

Real Value = (5,976 x 1) / 100 = \$59.76 exact

**Example 4 --- \$2,450,000.00 large corporate transfer**

Layer 2: SF=x100, D=2 (step \$1.00, max \$33,554,431)

Target: \$2,450,000.00

Encoder:

V = 2,450,000.00 x 100 / 100 = 2,450,000 / 100 = 24,500

Actually: N = V / SF \* 10\^D = 2,450,000 / 100 = 24,500

A = floor(24,500/256) = 95

r = 24,500 mod 256 = 180

Decoder:

N = 95 x 256 + 180 = 24,500

Real Value = (24,500 x 100) / 100 = \$2,450,000.00 exact

**Example 5 --- \$1,847,293,651.37 arbitrary billion-scale, exact via compound**

Strategy: split across two records using compound continuation

Record 1 --- Billions component:

Layer 2: SF=x100,000, D=2 (step \$1,000, max \$33,554,431,000)

Encode: \$1,847,293,000.00

N = 1,847,293,000 / 1,000 = 1,847,293

Check: 1,847,293 \<= 33,554,431 fits

bit 26=0 (exact at this scale), bit 39=1 (partial, continuation follows)

Record 2 --- Sub-thousand component (1111 continuation):

SF=x1, D=2 (via control byte band change)

Encode: \$651.37

N = 65,137

bit 26=0 (exact), bit 39=0 (full, compound closed)

Decoder sum: \$1,847,293,000.00 + \$651.37 = \$1,847,293,651.37 exact

**5. LAYER 3 --- SET A FLAGS (bits 26-32)**

Seven flag bits qualify the value block. Bits 29-30 are mirrored in BitLedger bits 37-38 to provide cross-layer error detection. Bits 26-27 form a two-bit rounding signal with one permanently invalid state.

  ------------ ------------------------------ ------------ -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    **Bits**             **Field**             **Values**                                                                                                                                                         **Description**

   **Bit 26**        **Rounding Flag**           0 / 1                                            0=Value is exact. No precision loss occurred. Bit 27 is always 0 when bit 26 is 0. 1=Value is rounded. The stored integer approximates the true value. Bit 27 carries rounding direction. Encoder must set this flag whenever rounding occurs.

   **Bit 27**      **Rounding Direction**        0 / 1      Meaningful only when bit 26=1. 0=Rounded down (floor). True value is greater than or equal to decoded value. 1=Rounded up (ceiling). True value is less than or equal to decoded value. When bit 26=0, bit 27 MUST be 0. State 01 (bit26=0, bit27=1) is invalid --- any record in this state is malformed. See Section 5.1.

   **Bit 28**         **Split Order**            0 / 1                                                       0=This record follows the session default split order declared in Layer 1 bit 9. 1=This record reverses the session default for this record only. No separate Setup Signal required --- fully resolved by Layer 1 bit 9.

   **Bit 29**   **Direction --- Plus/Minus**     0 / 1                                                              0=Plus, In --- value is being received. 1=Minus, Out --- value is being disbursed. MUST equal BitLedger bit 37. A mismatch is a protocol error indicating a corrupt record. Cross-layer validation rule 1.

   **Bit 30**    **Status --- Past/Future**      0 / 1                                                                              0=Past, Paid --- transaction is settled. Cash basis. 1=Future, Debt --- accrued or anticipated. Accrual basis. MUST equal BitLedger bit 38. Cross-layer validation rule 2.

   **Bit 31**        **Debit / Credit**          0 / 1                                                                                                  0=Credit side. 1=Debit side. Used with BitLedger account pair to resolve which account takes the debit and which takes the credit.

   **Bit 32**       **Quantity Present**         0 / 1       0=All 25 bits are a flat total value. Quantity is implicitly 1. Use for single-unit transactions. 1=Optimal Split is active. Upper bits=price per unit, lower bits=quantity. When bit 32=1, Optimal Split is ALWAYS taken from Layer 2 regardless of bit 27. This resolves the potential conflict between these two bits.
  ------------ ------------------------------ ------------ -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**5.1 Bits 26-27 Two-Bit Rounding Signal**

Bits 26 and 27 form a clean two-bit signal. Reading them as a pair eliminates conditional logic in the decoder:

BITS 26-27 DECODING TABLE:

00 =\> Exact value. Proceed to decode normally.

10 =\> Rounded down. True value \>= decoded value.

Record rounding direction in audit log.

11 =\> Rounded up. True value \<= decoded value.

Record rounding direction in audit log.

01 =\> PROTOCOL ERROR. Malformed record.

bit 26=0 means exact, therefore bit 27 must be 0.

Flag and reject. Do not post to ledger.

DECODER PSEUDOCODE:

if record\[26\]==0 and record\[27\]==1:

raise ProtocolError(\'malformed record: invalid rounding state\')

rounding_occurred = record\[26\]

rounded_up_if_true = record\[27\] \# only valid when record\[26\]==1

> *The invalid state 01 provides a third error detection layer alongside the two cross-layer validation rules. A single-bit error corrupting bit 26 from 1 to 0 while bit 27 remains 1 is immediately detectable without checking any other field.*

**5.2 Bits 27 and 32 --- Conflict Resolution**

Bit 27 previously had a dual role as both Optimal Split confirmation and Rounding Direction. Bit 32 being active (Quantity Present) required knowing the Optimal Split, creating a conflict when rounding also occurred. Resolution:

RULE: When bit 32 = 1 (Quantity Present active),

Optimal Split is ALWAYS taken from Layer 2.

Bit 27 is permanently Rounding Direction only.

No split confirmation is needed in any record.

For mixed split geometries within a batch:

Primary: Set Optimal Split in Layer 2 to the widest

geometry needed. Narrower records accept small

precision reduction, flagged by bit 26 if needed.

Fallback: Control record type 101 updates Optimal Split

for a record group and reverts at batch close.

**5.3 Cross-Layer Validation Rules**

RULE 1: record\[29\] == record\[37\] (Direction must match)

RULE 2: record\[30\] == record\[38\] (Status must match)

RULE 3: record\[26\]==0 =\> record\[27\]==0 (Rounding state valid)

Any violation =\> PROTOCOL ERROR, record rejected, NACK sent

**5.4 Encoder Decision Algorithm**

INPUT: V = true value (decimal)

D = Decimal Position from Layer 2

SF = Scaling Factor from Layer 2

STEP 1: Compute raw stored integer

R = V x 10\^D / SF

STEP 2: Check if exact

if R == floor(R):

store R, set bit 26=0, bit 27=0

DONE

STEP 3: Rounding required

Determine direction by accounting context:

Liability =\> round UP (never understate debt)

Asset =\> round DOWN (never overstate ownership)

Tax =\> round UP (conservative compliance)

Income =\> round DOWN (conservative recognition)

General =\> round to nearest

STEP 4: Apply and store

R_stored = floor(R) or ceil(R) per Step 3

set bit 26=1 (rounded)

set bit 27=0 if floor, 1 if ceiling

STEP 5: Check range

if R_stored \> 33,554,431:

SF = next power of 10

return to STEP 1

else: DONE

**6. LAYER 3 --- BITLEDGER ACCOUNTING BLOCK (bits 33-40)**

The final 8 bits of every transaction record. Carries the complete double-entry accounting classification. Combined with Set A flags 29-31 a full accounting entry is encoded in 8 bits.

  ---------------- -------------------- ------------ -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
      **Bits**          **Field**        **Values**                                                                                                       **Description**

   **Bits 33-36**    **Account Pair**    0000-1111    4-bit code identifying both account categories. 14 valid pairs. 1110=correction or netting, inference suspended. 1111=compound continuation marker --- this record continues a preceding compound group. See Section 7.

     **Bit 37**       **Direction**        0 / 1               0=In, receiving side is primary. 1=Out, disbursing side is primary. Identifies which account in the pair is the primary side of this entry. MUST match Set A bit 29 (Cross-layer validation rule 1).

     **Bit 38**         **Status**         0 / 1                         0=Paid, settled, cash basis. 1=Debt, accrued, not yet settled. Applies to both sides of the double entry simultaneously. MUST match Set A bit 30 (Cross-layer validation rule 2).

     **Bit 39**      **Completeness**      0 / 1                          0=Full settlement, transaction complete. 1=Partial, more follows. In a 1111 continuation record: 1=more continuations follow, 0=this is the final record in the compound group.

     **Bit 40**     **Extension Flag**     0 / 1       0=Record complete. 1=Extension byte follows. Used for quantity, subcategory, currency override, timestamp, opposing account, or precision anchor. Extension bytes are chainable --- bit 8 of each triggers the next.
  ---------------- -------------------- ------------ -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**6.1 Account Pair Table**

  ---------- ---------------------------- -------------------------------------- ---------------------------------------
   **Code**        **Account Pair**              **Direction In Primary**               **Direction Out Primary**

     0000         Op Expense / Asset        Expense receives goods or service     Expense reversal, return to supplier

     0001       Op Expense / Liability          Expense incurred on credit         Liability reduces, expense reversed

     0010       Non-Op Expense / Asset         Non-core expense from asset              Non-core expense reversal

     0011     Non-Op Expense / Liability        Non-core expense on credit             Non-core liability reduces

     0100         Op Income / Asset             Revenue received as asset           Revenue reversed, asset returned

     0101       Op Income / Liability        Revenue earned, not yet received            Earned revenue reversed

     0110       Non-Op Income / Asset            One-time income received               One-time income reversed

     0111     Non-Op Income / Liability      One-time income earned on credit            Credit income reversed

     1000         Asset / Liability              Asset acquired on credit              Liability repaid from asset

     1001           Asset / Equity               Owner contributes asset               Asset distributed to owner

     1010         Liability / Equity           Equity converts to liability           Liability converts to equity

     1011           Asset / Asset          Asset received --- internal transfer   Asset disbursed --- internal transfer

     1100       Liability / Liability       Liability assumed from third party    Liability transferred to third party

     1101          Equity / Equity                Equity reallocated in                  Equity reallocated out

     1110        Correction / Netting       Correction --- inference suspended       Netting --- inference suspended

     1111       Compound Continuation                 See Section 7                           See Section 7
  ---------- ---------------------------- -------------------------------------- ---------------------------------------

**7. COMPOUND TRANSACTIONS --- THE 1111 CONTINUATION MARKER**

Some accounting events require more than one record. A sale with simultaneous inventory reduction involves an income entry and a COGS entry. The compound mechanism links multiple records into one logical event. The first record is always complete and self-sufficient. Subsequent records declare their linkage by setting their account pair to 1111.

**7.1 Model B --- Continuation Signal**

The first record in a compound group is a standard 40-bit record with a valid account pair. Its Completeness bit (39) is set to 1 (Partial) to signal that a continuation follows. The next record sets its BitLedger pair to 1111, declaring linkage to the immediately preceding record. The current Record Separator value in Layer 2 is the implicit identity of the compound group.

**7.2 Continuation Record Bits 33-40**

  ---------------- -------------------- ------------ ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
      **Bits**          **Field**        **Values**                                                                                                         **Description**

   **Bits 33-36**    **Pair = 1111**        1111      Compound continuation signal. All other bits in the record function normally --- the 1111 pair is the only special marker. Direction, status, debit/credit, and value are all valid and fully decoded for this linked entry.

   **Bits 37-38**      **Sub-type**        00-11               00=Standard linked entry (COGS, contra, paired leg). 01=Correcting entry for the preceding record. 10=Reversal of the preceding record. 11=Cross-batch continuation, compound group spans into next batch.

     **Bit 39**      **Completeness**      0 / 1                                     1=More continuation records follow after this one. 0=This is the final record in the compound group. The transition from 1 to 0 is the compound close signal.

     **Bit 40**     **Extension Flag**     0 / 1                                                                                Standard role. 1 if an extension byte follows this continuation record.
  ---------------- -------------------- ------------ ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**7.3 Worked Example --- Sale with COGS Recognition**

Scenario: Sale of 10 units at \$49.99. Revenue \$499.90.

COGS for those units \$180.00.

Layer 2: SF=x1, D=2, Compound Prefix=01

Layer 1: Bit 11=1 (compound mode active)

RECORD 1 --- Income entry (standard 40-bit record)

Bits 1-17 : A=19 (4999/256=19.527, floor=19)

Bits 18-25 : r=10 (quantity=10)

Bit 26 : 0 (exact at unit level)

Bit 27 : 0 (must be 0 when bit 26=0)

Bit 28 : 0 (follow session split order)

Bit 29 : 0 (In --- revenue received)

Bit 30 : 0 (Paid --- settled)

Bit 31 : 0 (Credit)

Bit 32 : 1 (Quantity Present)

Bits 33-36 : 0100 (Op Income / Asset)

Bit 37 : 0 (In --- matches bit 29 VALID)

Bit 38 : 0 (Paid --- matches bit 30 VALID)

Bit 39 : 1 (Partial --- continuation follows)

Bit 40 : 0 (no extension)

Decode: (4999 x 10 x 1) / 100 = \$499.90 exact

RECORD 2 --- COGS entry (1111 continuation)

N=18000: A=floor(18000/256)=70, r=18000 mod 256=80

Bit 26 : 0 (exact)

Bit 27 : 0 (must be 0)

Bit 29 : 1 (Out --- cost leaves inventory)

Bit 30 : 0 (Paid)

Bit 31 : 1 (Debit)

Bit 32 : 0 (flat value)

Bits 33-36 : 1111 (compound continuation)

Bits 37-38 : 00 (standard linked entry)

Bit 37 : 1 (Out --- matches bit 29 VALID)

Bit 39 : 0 (Full --- compound closed)

Decode: (70x256+80) / 100 = 18000/100 = \$180.00 exact

INTERPRETER:

Record 1: Completeness=1, enter compound watch

Record 2: pair=1111, link to Record 1

Completeness=0, compound closed

Post both entries as one logical event

**8. CONTROL RECORDS (8 bits / 1 byte)**

Control records are distinguished by their leading 0 bit. All transaction records begin within a session framing that starts with 1. A leading 0 identifies an 8-bit control byte. The 3-bit type field determines the meaning of the 4-bit payload.

Structure: 0 \[ TTT \] \[ PPPP \]

\| \| \|

\| type payload (4 bits)

leading 0 = control record

Example --- band change to SF x1,000:

0 000 0011

Type 000 = Scaling Factor change

Payload 0011 = index 3 = x1,000

  ---------- ----------------------- ------------------------------------------------------------------------------------------------------------------------------------------ ------------------------------------------------------
   **Type**       **Function**                                                                      **Payload**                                                                                    **Escape 1111**

     000      Scaling Factor change                        0000-1001: powers of 10 (x1 to x1,000,000,000). 1010-1110: user-defined factors from Layer 1.                           Next byte carries full 7-bit arbitrary SF value.

     001         Currency change                                                       0000-1110: 15 standard currency codes.                                                     Next byte carries full 6-bit code (64 currencies).

     010           Batch close                                                      0000-1110: record count confirmation (0-14).                                                   Next byte carries full count for larger batches.

     011           ACK / NACK                                               Bit 5=0 ACK, 1 NACK. Bits 6-8: batch sequence reference 0-7.                                                                 N/A

     100       Compound group open                   0001-1110: record count for next compound group (1-14). Lightweight alternative to 1111 BitLedger marker.                   Use 1111 BitLedger marker for groups larger than 14.

     101      Optimal Split update    0000-1111: new Optimal Split value (0-15). Applies to subsequent records in current batch only. Reverts to Layer 2 value at batch close.                           N/A

     110       Layer 2 short-form                                     1111=all Layer 2 values equal session defaults, skip full 48-bit header.                                                           N/A

     111            Reserved                                                                     Transmit as 1111.                                                                                       N/A
  ---------- ----------------------- ------------------------------------------------------------------------------------------------------------------------------------------ ------------------------------------------------------

**9. EXTENSION BYTES**

When BitLedger bit 40 is 1, an extension byte follows the 40-bit record. Extension bytes are optional and chainable --- bit 8 of each triggers the next. They carry supplementary detail that does not belong in the fixed record structure.

  ------------------- ---------- ----------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------
        **Use**        **Bits**      **Range**                                                                              **Description**

       Quantity         8 of 8      0-255 units                            Unit count when bit 32=0 and quantity is needed separately. Frees the full 25-bit value block for a precise total.

      Subcategory       3 of 8     0-7 sub-types                            8 sub-classifications per account pair. Rent, salaries, utilities under Op Expense. Remaining 5 bits available.

   Opposing Account     4 of 8      0-15 codes                                          When Layer 1 bit 10=1, explicit opposing account pair code. Remaining 4 bits available.

   Currency Override    6 of 8    0-63 currencies                                              Overrides batch currency for this record. 2 bits for chain flag and spare.

   Timestamp Offset     8 of 8      0-255 units                                     Relative offset from session epoch. Unit declared in Layer 1. For devices without a live clock.

   Precision Anchor     8 of 8    0-255 sub-units   Sub-SF-unit remainder. Decoder: (N x SF + extension) / 10\^D. Restores full precision on high-denomination records where the SF step would otherwise cause loss.

      Party Type        2 of 8          0-3                                                  00=Internal. 01=Customer. 10=Vendor. 11=Other. Identifies counterparty nature.
  ------------------- ---------- ----------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------

**10. VALUE RANGE AND PRECISION ANALYSIS**

This section confirms the complete range of expressible values at every Scaling Factor and Decimal Position combination. It identifies where exact representation is available, where precision steps occur, and how the compound continuation mechanism recovers full precision when a single record reaches its step limit.

**10.1 The Master Formula**

Max Real Value = 33,554,431 x SF / 10\^D

Precision Step = 1 x SF / 10\^D = SF / 10\^D

Min Non-Zero = Precision Step (same as step)

Every integer multiple of Precision Step from zero

to Max Real Value is exactly reachable. No gaps within a band.

**10.2 Complete Maximum Value Grid**

All values in dollars. Read as: the largest value expressible as an exact integer multiple of the precision step at each SF/D combination.

  ---------------- ----------------- ----------------- ----------------- ----------------- ----------------- ----------------- ----------------
       **SF**           **D=0**           **D=1**           **D=2**           **D=3**           **D=4**           **D=5**          **D=6**

         x1           33,554,431        3,355,443.1       335,544.31        33,554.431        3,355.4431         335.54431        33.554431

        x10           335,544,310       33,554,431       3,355,443.10       335,544.310       33,554.431        3,355.4431        335.54431

        x100         3,355,443,100      335,544,310       33,554,431        3,355,443.1       335,544.31        33,554.431        3,355.4431

       x1,000       33,554,431,000     3,355,443,100      335,544,310       33,554,431        3,355,443.1       335,544.31        33,554.431

      x10,000       335,544,310,000   33,554,431,000     3,355,443,100      335,544,310       33,554,431        3,355,443.1       335,544.31

      x100,000      3.355 trillion    335,544,310,000   33,554,431,000     3,355,443,100      335,544,310       33,554,431       3,355,443.1

     x1,000,000     33.554 trillion   3.355 trillion    335,544,310,000   33,554,431,000     3,355,443,100      335,544,310       33,554,431

    x10,000,000     335.5 trillion    33.554 trillion   3.355 trillion    335,544,310,000   33,554,431,000     3,355,443,100     335,544,310

    x100,000,000    3,355 trillion    335.5 trillion    33.554 trillion   3.355 trillion    335,544,310,000   33,554,431,000    3,355,443,100

   x1,000,000,000   33,554 trillion   3,355 trillion    335.5 trillion    33.554 trillion   3.355 trillion    335,544,310,000   33,554,431,000
  ---------------- ----------------- ----------------- ----------------- ----------------- ----------------- ----------------- ----------------

**10.3 Complete Precision Step Grid**

The precision step is the smallest non-zero value expressible and the gap between any two consecutive expressible values at each combination.

  ---------------- ----------- ----------- ----------- ----------- ----------- ----------- ------------
       **SF**        **D=0**     **D=1**     **D=2**     **D=3**     **D=4**     **D=5**     **D=6**

         x1            \$1       \$0.10      \$0.01      \$0.001    \$0.0001    \$0.00001   \$0.000001

        x10           \$10         \$1       \$0.10      \$0.010     \$0.001    \$0.0001    \$0.00001

        x100          \$100       \$10         \$1       \$0.10      \$0.01      \$0.001     \$0.0001

       x1,000        \$1,000      \$100       \$10         \$1       \$0.10      \$0.01      \$0.001

      x10,000       \$10,000     \$1,000      \$100       \$10         \$1       \$0.10       \$0.01

      x100,000      \$100,000   \$10,000     \$1,000      \$100       \$10         \$1        \$0.10

     x1,000,000       \$1M      \$100,000   \$10,000     \$1,000      \$100       \$10         \$1

    x10,000,000       \$10M       \$1M      \$100,000   \$10,000     \$1,000      \$100        \$10

    x100,000,000     \$100M       \$10M       \$1M      \$100,000   \$10,000     \$1,000      \$100

   x1,000,000,000     \$1B       \$100M       \$10M       \$1M      \$100,000   \$10,000     \$1,000
  ---------------- ----------- ----------- ----------- ----------- ----------- ----------- ------------

**10.4 Diagonal Symmetry --- The Design Invariant**

Every diagonal running top-left to bottom-right in both grids holds the same value. Increasing SF by one power of 10 while simultaneously increasing D by 1 produces identical maximum value and precision step. The encoder has flexibility in selecting SF and D combinations.

CANONICAL ENCODER SELECTION RULE:

1\. Choose the lowest SF that keeps stored integer

within 33,554,431

2\. Set D to match required precision of input value

3\. If multiple combinations produce identical results,

use the one with lowest SF index

EQUIVALENT COMBINATIONS (same effective range and precision):

SF=x1, D=2 =\> max \$335,544.31, step \$0.01

SF=x10, D=3 =\> max \$335,544.310, step \$0.010

SF=x100, D=4 =\> max \$335,544.31, step \$0.01

These are mathematically identical. Use SF=x1, D=2.

**10.5 Verification --- Arbitrary Numbers at Each Scale**

The following tests confirm that specific irregular, non-round values are reachable at appropriate scale configurations. Each test shows the stored integer, the decode, and whether the result is exact or requires rounding.

**Retail Scale --- SF x1, D=2, step \$0.01**

  ------------------ --------------- --------- -------- ------------------- --------------------------------
   **Target Value**   **Encoded N**    **A**    **r**    **Decoded Value**             **Exact?**

        \$4.53             453           1       197          \$4.53                      Yes

       \$47.99            4,799         18       191          \$47.99                     Yes

       \$183.07          18,307         71       131         \$183.07                     Yes

      \$2,847.53         284,753       1,112      81        \$2,847.53                    Yes

     \$98,765.43        9,876,543     38,580      63        \$98,765.43                   Yes

     \$335,544.31      33,554,431     131,071    255       \$335,544.31             Yes --- maximum

     \$335,544.32       OVERFLOW        \--      \--            N/A          No --- exceeds max, use SF x10
  ------------------ --------------- --------- -------- ------------------- --------------------------------

**Corporate Scale --- SF x100, D=2, step \$1.00**

  ------------------ --------------- ------------------- ------------ -------------------------------------------------------
   **Target Value**   **Encoded N**   **Decoded Value**   **Exact?**                         **Notes**

      \$1,247.00         12,470          \$1,247.00          Yes                      N = value / step = 1247

     \$847,293.00       8,472,930       \$847,293.00         Yes                         Fits comfortably

    \$5,000,000.00     50,000,000            \--              No            50,000,000 \> 33,554,431 --- use SF x1,000

   \$24,750,000.00       247,500       \$24,750,000.00       Yes                     SF x1,000, D=2, step \$10

   \$33,554,431.00       335,544       \$33,554,440.00        No       Nearest \$10 step, rounding \$9 --- set bit 26=1,27=0
  ------------------ --------------- ------------------- ------------ -------------------------------------------------------

**Billion Scale --- SF x100,000, D=2, step \$1,000**

Testing arbitrary irregular numbers in the billions confirms continuous coverage at the declared precision step:

  -------------------- ------------------ ------------------------- ------------------------------------- ---------------------- -----------------------------------------------------------------
    **Target Value**    **N = V / 1000**        **Stored N**                     **Decoded**                     **Loss**                                **Recoverable?**

   \$1,847,293,651.37    1,847,293.651     1,847,293 or 1,847,294    \$1,847,293,000 or \$1,847,294,000    \$651.37 or \$348.63   Yes --- compound continuation at SF x1 carries \$651.37 exactly

   \$4,003,847,291.09    4,003,847.291            4,003,847                    \$4,003,847,000                   \$291.09                          Yes --- compound continuation

   \$7,392,001,847.53    7,392,001.847            7,392,001                    \$7,392,001,000                   \$847.53                          Yes --- compound continuation

   \$9,999,999,999.99    9,999,999.999     9,999,999 or 10,000,000   \$9,999,999,000 or \$10,000,000,000    \$999.99 or \$0.01                     Yes --- compound continuation

   \$2,718,281,828.46    2,718,281.828            2,718,281                    \$2,718,281,000                   \$828.46                          Yes --- compound continuation

   \$3,141,592,653.59    3,141,592.653            3,141,592                    \$3,141,592,000                   \$653.59                          Yes --- compound continuation
  -------------------- ------------------ ------------------------- ------------------------------------- ---------------------- -----------------------------------------------------------------

> *All six test values --- including deliberately irregular numbers approximating mathematical constants e and pi at billion scale --- are reachable within the declared precision band. Sub-step precision is recovered in every case via a single 40-bit compound continuation record. Total cost for full precision at billion scale: 80 bits (two records).*

**Trillion Scale --- SF x1,000,000,000, D=2, step \$10,000,000**

  ----------------------- ----------------- -------------- ------------ -----------------------------------------
     **Target Value**      **N = V / 10M**   **Stored N**    **Max**                    **Fits?**

   \$50,000,000,000,000       5,000,000       5,000,000     33,554,431                     Yes

   \$335,544,310,000,000     33,554,431       33,554,431    33,554,431         Yes --- exactly at maximum

   \$999,999,999,999,999     99,999,999          \--        33,554,431   No --- use compound two-record approach
  ----------------------- ----------------- -------------- ------------ -----------------------------------------

**10.6 Absolute Ceiling**

Maximum expressible single-record value:

SF = x1,000,000,000

D = 0 (integer steps)

N = 33,554,431

Max = 33,554,431 x 1,000,000,000 = \$33,554,431,000,000,000

= approximately \$33.5 quadrillion

Global GDP (2024 estimate): approximately \$110 trillion

Protocol ceiling is approximately 305x global GDP.

At D=2 and SF x1,000,000,000 (standard banking precision):

Max = \$335,544,310,000,000 = approximately \$335 trillion

Step = \$10,000,000 per integer unit

**11. STANDARD TRANSACTION ENCODING REFERENCE**

All examples assume Layer 2 defaults: SF x1, D=2, Optimal Split 8 unless stated.

  --------------------- ---------- --------- ------------ -------------- --------- --------- ---------------------------------------------------------------
     **Transaction**     **Pair**   **Dir**   **Status**   **Complete**   **D/C**   **Qty**                             **Notes**

        Cash sale          0100       In         Paid          Full         Cr         0      Income/Asset. Asset increases, income recognised immediately.

       Credit sale         0101       In         Debt        Partial        Cr         0      Revenue earned not yet received. Liability tracks receivable.

      Cash purchase        0000       In         Paid          Full         Dr         1               Op Expense/Asset. Goods received and paid.

   Purchase on account     0001       In         Debt          Full         Dr         1         Op Expense/Liability. Goods received, payable created.

   Account settlement      0001       Out        Paid          Full         Dr         0                      Liability cleared from asset.

    Asset acquisition      1000       In         Debt          Full         Dr         0            Asset/Liability. Financed purchase, loan created.

     Loan repayment        1000       Out        Paid          Full         Dr         0                         Cash reduces liability.

   Owner contribution      1001       In         Paid          Full         Cr         0               Asset/Equity. Owner funds enter the entity.

   Owner distribution      1001       Out        Paid          Full         Dr         0                    Equity/Asset. Cash paid to owner.

      Debt transfer        1100       Out        Debt          Full         Dr         0                Liability/Liability. Creditor reassigned.

    Revenue reversal       0100       Out        Paid          Full         Dr         0                    Income reversed. Asset returned.

    COGS recognition       0000       Out        Paid          Full         Dr         0           Second record in compound. Links to sale via 1111.

     Asset transfer        1011       In         Paid          Full         Dr         0                     Asset/Asset. Internal movement.

       Correction          1110       \--        \--           \--          \--        0        Inference suspended. Use for void or correction entries.
  --------------------- ---------- --------- ------------ -------------- --------- --------- ---------------------------------------------------------------

**12. TRANSMISSION EFFICIENCY ANALYSIS**

**12.1 Per-Layer Bit Accounting**

  ---------------------- ---------- ----------- -------------------- -----------------------------
       **Element**        **Bits**   **Bytes**     **Frequency**      **Amortised / 100 records**

   Layer 1 Session Init      64          8        Once per session             0.64 bits

   Layer 2 Full Header       48          6         Once per batch              0.48 bits

    Layer 2 Short-form       8           1       When all defaults             0.08 bits

   Layer 3 Transaction       40          5           Per record                 40 bits

      Extension Byte         8           1          When needed               0 if unused

    1111 Continuation        40          5       Per compound entry           0 if unused

      Control Record         8           1           On demand                0 if unused
  ---------------------- ---------- ----------- -------------------- -----------------------------

**12.2 Scenarios**

SCENARIO A --- 100 independent records, all defaults:

Layer 1: 64 bits

Layer 2 (short): 8 bits

100 x Layer 3: 4,000 bits

Total: 4,072 bits = 509 bytes

SCENARIO B --- 100 records, full Layer 2, 30% with extension byte:

Layer 1: 64 bits

Layer 2 (full): 48 bits

100 x Layer 3: 4,000 bits

30 x extension: 240 bits

Total: 4,352 bits = 544 bytes

SCENARIO C --- 50 standard + 10 compound pairs (primary+continuation):

Layer 1: 64 bits

Layer 2 (full): 48 bits

60 x Layer 3: 2,400 bits

10 x 1111 cont: 400 bits

Total: 2,912 bits = 364 bytes

Accounting entries posted: 70

SCENARIO D --- 1,000 records across 10 batches:

Layer 1: 64 bits (once)

10 x Layer 2: 480 bits

1,000 x Layer 3: 40,000 bits

Total: 40,544 bits = 5,068 bytes = 4.95 KB

**12.3 Format Comparison --- 100 Transactions**

  --------------------- ---------------------- ---------------------------- -------------------------------
       **Format**        **Size (100 txns)**       **Parsing Required**      **Accounting Logic Embedded**

   BitLedger Protocol       509-544 bytes       No --- fixed bit positions     Yes --- at encoding level

   Fixed binary struct    2,000-5,000 bytes        No --- schema needed                   No

       MessagePack        3,000-8,000 bytes                Yes                            No

           CSV           10,000-20,000 bytes               Yes                            No

          JSON           50,000-200,000 bytes              Yes                            No

       XML / SOAP           200,000+ bytes                 Yes                            No
  --------------------- ---------------------- ---------------------------- -------------------------------

**13. HUMAN-READABLE JOURNAL ENTRY FORMAT**

Every encoded BitLedger record can be rendered as a human-readable journal entry. This format is the canonical output for display, audit, and verification. It presents the same data as the binary record in a form that a trained accountant can read without reference to the protocol specification.

**13.1 Proposed Format**

───────────────────────────────────────────────────────────────

BITLEDGER JOURNAL ENTRY

Session : Sender 00291847 / East Division (sub-entity 04)

Batch : Group 01 / Record 04 / Currency: USD

───────────────────────────────────────────────────────────────

DEBIT Operational Expense \$ 1,247.50

CREDIT Accounts Payable \$ 1,247.50

───────────────────────────────────────────────────────────────

Description : Goods received on account.

5 units at \$249.50 each.

Payment pending.

Status : Accrued --- not yet settled

Precision : Exact

───────────────────────────────────────────────────────────────

Bits : 00000000010011010 00000101 0011010 0001 0 1 1 0

Hex : 04 D0 05 1A 16

Decimal : \[17-bit A=9\] \[8-bit r=5\] \[flags=0x1A\] \[BL=0x16\]

───────────────────────────────────────────────────────────────

**13.2 Rounded Value Example**

───────────────────────────────────────────────────────────────

BITLEDGER JOURNAL ENTRY

Session : Sender 00291847 / Head Office (sub-entity 01)

Batch : Group 02 / Record 11 / Currency: USD

───────────────────────────────────────────────────────────────

DEBIT Operational Expense \$ 847,293,000.00

CREDIT Accounts Payable \$ 847,293,000.00

───────────────────────────────────────────────────────────────

Description : Bulk materials received on account.

Invoice total \$847,293,291.47.

Rounded down to nearest \$1,000 step.

Sub-step remainder \$291.47 pending in

linked continuation record.

Status : Accrued --- not yet settled

Precision : Rounded DOWN (true value \>= displayed value)

Rounding : -\$291.47 (see continuation record 12)

───────────────────────────────────────────────────────────────

Bits : \[value block\] \[flags: bit26=1 bit27=0\] \[BL block\]

Hex : \[as encoded\]

───────────────────────────────────────────────────────────────

**13.3 Compound Pair Example**

───────────────────────────────────────────────────────────────

BITLEDGER COMPOUND ENTRY \[1 of 2\]

Session : Sender 00291847 / Sales Division (sub-entity 07)

Batch : Group 01 / Record 07 / Currency: USD

───────────────────────────────────────────────────────────────

DEBIT Accounts Receivable \$ 499.90

CREDIT Operational Income \$ 499.90

───────────────────────────────────────────────────────────────

Description : Sale of 10 units at \$49.99 each.

Revenue recognised. Payment pending.

Status : Accrued --- awaiting receipt

Precision : Exact

Continuation: Record 08 follows (COGS recognition)

───────────────────────────────────────────────────────────────

───────────────────────────────────────────────────────────────

BITLEDGER COMPOUND ENTRY \[2 of 2\] --- CONTINUATION

Linked to Record 07 / Sub-type: Standard

───────────────────────────────────────────────────────────────

DEBIT Cost of Goods Sold \$ 180.00

CREDIT Inventory \$ 180.00

───────────────────────────────────────────────────────────────

Description : Inventory reduction for 10 units sold.

COGS recognised simultaneously with sale.

Status : Settled

Precision : Exact

Group Close : Compound entry complete.

───────────────────────────────────────────────────────────────

**14. GLOSSARY**

  ------------------------ --------------------------------------------------------------------------------------------------------------------------------------------------------------------
          **Term**                                                                                    **Definition**

        Account Pair         4-bit code in BitLedger bits 33-36 encoding both account categories in a double-entry transaction. 14 valid pairs, 1110 correction, 1111 compound continuation.

           Batch                                                 Group of Layer 3 records prefixed by a Layer 2 Set B Header or short-form control byte.

      BitLedger Block                                              Bits 33-40 of every Layer 3 record. Complete double-entry accounting classification.

    Canonical Selection                   Encoder rule: choose the lowest Scaling Factor that keeps N within 33,554,431, then set Decimal Position to match required precision.

   Compound Continuation               A Layer 3 record with account pair 1111. Declares linkage to the immediately preceding record. All bits other than 33-38 function normally.

       Control Record                        8-bit record beginning with leading 0. Carries session management signals --- band changes, ACK, batch close, parameter updates.

           CRC-15                      Cyclic Redundancy Check using 15-bit generator polynomial x\^15 + x + 1. Applied over Layer 1 bits 1-49. Zero remainder confirms integrity.

   Cross-layer Validation   Set A bit 29 must equal BitLedger bit 37. Set A bit 30 must equal BitLedger bit 38. State 01 in bits 26-27 is invalid. Three independent error signals per record.

      Decimal Position                                 3-bit Layer 2 field declaring decimal places applied after Scaling Factor. 000=integer through 110=6 places.

       Extension Byte                                       Optional 8-bit block after a Layer 3 record when bit 40=1. Chainable via bit 8 of each extension.

          Layer 1                                 64-bit session initialisation. SOH, version, permissions, session defaults, sender ID, sub-entity ID, CRC-15 checksum.

      Layer 2 / Set B                 48-bit batch header. SF, Optimal Split, Decimal Position, bells, separators, entity ID, currency, rounding balance, compound prefix, reserved.

      Layer 3 / Set A                                            40-bit transaction record. Value block bits 1-32, BitLedger accounting block bits 33-40.

        Multiplicand                                 Upper bits of Layer 3 value block. Price per unit when bit 32=1. Upper component of flat integer when bit 32=0.

         Multiplier                                            Lower bits of Layer 3 value block. Quantity when bit 32=1. Lower remainder r when bit 32=0.

       Optimal Split                          4-bit Layer 2 field. Number of bits for Multiplier. Default 8. When bit 32=1, always taken from Layer 2 regardless of bit 27.

      Precision Anchor                                        Extension byte carrying sub-SF-unit remainder for full precision on high-denomination records.

       Precision Step                                         Smallest non-zero expressible value at a given SF/D combination. Equal to SF divided by 10\^D.

      Quantity Present                     Bit 32 of Layer 3. 0=flat total value, quantity implicitly 1. 1=Optimal Split active, upper bits are price, lower bits are quantity.

      Rounding Balance                                   4-bit sign-magnitude field at Layer 2 bits 42-45. Net rounding for the batch. 0000=exact. High bit=sign.

     Rounding Direction                    Bit 27 of Layer 3. Meaningful only when bit 26=1. 0=rounded down (floor). 1=rounded up (ceiling). Permanently assigned to this role.

       Rounding Flag                                         Bit 26 of Layer 3. 0=exact. 1=rounded. State 01 with bit 27=1 and bit 26=0 is a protocol error.

       Scaling Factor                          7-bit Layer 2 field. Magnitude multiplier for all batch values. Always multiplies upward. Never used for decimal precision.

            SOH                                                     Start of Header. Bit 1 of Layer 1, always 1. Self-framing --- no preamble needed.

        Split Order                                   Declared in Layer 1 bit 9. Whether Multiplicand or Multiplier transmits first. Resolved per record by bit 28.

           Status                                             Paid (0)=settled cash basis. Debt (1)=accrued. Both sides of the entry share the same status.

        1111 Marker           Account pair code signalling compound continuation. Preceding record must have Completeness=1. Current Record Separator value is the compound group identity.
  ------------------------ --------------------------------------------------------------------------------------------------------------------------------------------------------------------
