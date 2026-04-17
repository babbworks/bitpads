**BITLEDGER / BITPADS**

**COMPOUND MODE --- DESIGN NOTE**

*What Compound Mode Is, Why It Matters, and the v2 Tradeoff*

Companion to BitPads Protocol v2.0 \| BitLedger Protocol v3.0

**1. WHAT COMPOUND MODE IS**

Compound mode is a session-level permission flag that allows the 1111 account pair code to appear in BitLedger Layer 3 records. When compound mode is off, 1111 is a protocol error. When compound mode is on, 1111 is a valid continuation marker linking the current record to its predecessor as part of one logical event.

> *The 1111 marker is not a separate mechanism --- it is one of the 16 account pair codes. Its entire meaning is: this record does not stand alone. Link it to the record that preceded it. Together they describe one transaction.*

**1.1 The 1111 Continuation Marker**

BITLEDGER LAYER 3 --- ACCOUNT PAIR FIELD (bits 33-36):

0000-1101 Standard account pairs (14 defined pairs)

1110 Correction / Void

1111 Compound Continuation \<\-- requires compound mode ON

When compound mode = OFF:

Receiving 1111 in bits 33-36 = protocol error. Reject.

Free error detection --- this bit pattern should never appear.

When compound mode = ON:

Receiving 1111 = link this record to the preceding record.

Bits 37-38 carry sub-type (not direction/status mirrors).

Bit 39 = Completeness. 0=compound group closed. 1=more follows.

**1.2 Sub-Types of the 1111 Continuation**

  ---------------- -------------- ----------------------------------------------------------------
   **Bits 37-38**   **Sub-type**                            **Meaning**

         00           Standard     Normal linked entry --- COGS, contra, paired leg of same event

         01          Correcting    This record corrects a specific error in the preceding record

         10           Reversal            This record fully reverses the preceding record

         11         Cross-batch     Continuation spans a batch boundary --- links to prior batch
  ---------------- -------------- ----------------------------------------------------------------

**2. WHAT COMPOUND MODE ENABLES**

A compound event is a real-world transaction that requires more than one accounting entry to describe completely. Without compound mode, each record must stand alone --- which forces the application layer to link related entries, introducing the risk of partial posting and broken audit trails. With compound mode, the wire protocol enforces the link. Either both records arrive and post together, or neither does.

**2.1 Financial Domain Example --- Sale with COGS**

A retail sale simultaneously generates two accounting entries: revenue recognised, and cost of goods removed from inventory. These are one economic event expressed as two ledger movements.

WITHOUT COMPOUND MODE:

Record A: Op Income / Asset (revenue)

Record B: Op Expense / Asset (COGS)

These are two independent records. The protocol does not

know they are related. If Record B is lost in transmission,

revenue posts but inventory does not reduce. Broken ledger.

WITH COMPOUND MODE:

Record A: account pair=0100 (Op Income/Asset)

Completeness bit=1 (Partial --- continuation follows)

value = sale price \$499.90

Record B: account pair=1111 (Compound Continuation)

Sub-type bits 37-38=00 (Standard linked entry)

Completeness bit=0 (Full --- compound group closed)

value = COGS \$180.00

The 1111 marker in Record B tells the decoder:

Do not post this record independently.

Link it to Record A.

Post both together or neither.

Group identity = Record Separator value at time of group open.

**2.2 Engineering Domain Example --- Engine Firing**

In the Universal Domain a compound event links physical flow records. An engine firing simultaneously consumes propellant (Source to Sink) and creates a thermal load obligation (Debtor to Creditor). These are one physical event expressed as two conservation entries.

Record A: archetype=0000 (Source to Sink)

Quantity Type=mass, 180 kg propellant

Completeness=1 (Partial)

\[Control byte: switch Quantity Type to energy\]

Record B: account pair=1111 (Compound Continuation)

Sub-type=00 (Standard)

Completeness=0 (Full --- closed)

Quantity Type=energy, 847.50 Wh thermal load

Same 1111 marker. Same compound mode permission.

Same wire format. Engineering semantics not financial.

**2.3 Why the Completeness Bit Matters**

The Completeness bit (Layer 3 bit 39) works in conjunction with the 1111 marker to create unambiguous group boundaries. When a record has Completeness=1 (Partial) the decoder enters compound watch --- it holds that record pending and waits for a 1111 continuation. When a 1111 record has Completeness=0 (Full) the group closes and all held records post together.

  --------------------------- ------------------- -------------------------------------------------------------
   **Completeness (bit 39)**   **Account Pair**                        **Decoder Action**

           0 (Full)            Any standard pair              Standalone record. Post immediately.

          1 (Partial)          Any standard pair    Enter compound watch. Hold this record. Expect 1111 next.

           0 (Full)                  1111            Compound group closed. Post all held records together.

          1 (Partial)                1111          Compound continues. More 1111 records follow. Keep holding.
  --------------------------- ------------------- -------------------------------------------------------------

**3. WHY COMPOUND MODE NEEDS A PERMISSION FLAG**

The 1111 code could simply be defined as always valid. The decision to gate it behind a permission flag was deliberate and provides a concrete reliability benefit.

**3.1 The Error Detection Benefit**

The account pair field (bits 33-36) is 4 bits. A random transmission error could flip any combination of those bits. The value 1111 is one of 16 possible states. For a session that never uses compound records, 1111 should be unreachable by any valid transmission. If it appears, it is noise.

Session with compound mode = OFF:

Valid account pairs: 0000 through 1110 (15 values)

Invalid / detectable: 1111

Any record with bits 33-36 = 1111 is unambiguously corrupt.

Reject without further analysis.

Free error detection --- zero transmission overhead.

Session with compound mode = ON:

Valid account pairs: 0000 through 1111 (all 16 values)

1111 is valid --- the decoder must process it as a continuation.

A corrupted record whose pair bits happened to land on 1111

will be processed as a compound continuation.

The cross-layer validation (bits 29=37, 30=38) may still catch

the corruption, but 1111 records have different validation rules

(bits 37-38 carry sub-type not direction/status mirrors).

The detection layer is weaker.

> *This is the third layer of error detection in the BitLedger protocol. CRC-15 protects the session header. Cross-layer flag validation protects each record. Compound mode off makes 1111 a detectable sentinel --- a pattern that should never appear, and whose appearance signals corruption.*

**3.2 The Compound Prefix in Layer 2**

Layer 2 carries a related but separate mechanism --- the Compound Prefix (bits 46-47) which limits how many compound groups are permitted within a batch. This is a capacity control, not an error detection mechanism. Compound mode in Layer 1 (or the Session Config Extension in v2) is the fundamental permission. Compound Prefix is the per-batch ceiling.

  ------------------------ ---------------------------------- -----------------------------------------------------------------------
   **Layer 2 bits 46-47**             **Meaning**                                           **Effect**

             00             No compound groups in this batch   1111 is a protocol error even if compound mode is ON at session level

             01                 Up to 3 compound groups                             NACK after 3rd group closes

             10                 Up to 7 compound groups                             NACK after 7th group closes

             11                Unlimited compound groups                           No ceiling within this batch
  ------------------------ ---------------------------------- -----------------------------------------------------------------------

**4. THE V1 TO V2 TRADEOFF**

In BitPads Protocol v1.0, compound mode was declared in the BitLedger Context Control byte --- a per-transmission control record triggered by the Value expect flag. In BitPads Protocol v2.0 this byte was removed and compound mode moved to the Session Configuration Extension byte --- a session-open declaration. This consolidation introduced a specific tradeoff.

**4.1 How it Worked in v1**

BITLEDGER CONTEXT CONTROL BYTE (v1, now removed):

0 110 C B R R

\| \| \| \| \|

\| \| \| Reserved = 1

\| \| BitLedger block optional

\| Compound mode active

Type 110 = BitLedger context declaration

Leading 0 = control record

TRIGGER: Present when Meta byte 1 bit 5=1 (Value expect flag set)

AND BitLedger accounting active.

Transmitted once per batch that contains Value records.

This meant compound mode could be:

OFF for batch 1 =\> 1111 is detectable error in batch 1

ON for batch 2 =\> 1111 is valid compound continuation

OFF for batch 3 =\> 1111 is detectable error again

**4.2 How it Works in v2**

SESSION CONFIGURATION EXTENSION BYTE (v2):

Bits 1-2: Nesting Level Code

Bit 3: Opposing Convention

Bit 4: Compound Mode Active \<\-- was in BL ctrl byte

Bit 5: BitLedger Block Optional \<\-- was in BL ctrl byte

Bits 6-8: Reserved = 1

TRIGGER: Present when Layer 1 bit 12=1 (Session Enhancement Flag)

OR when opposing convention is non-default.

Transmitted ONCE at session open.

This means compound mode is now:

Set at session open. Fixed for the entire session.

Cannot be toggled per-batch without opening a new session.

**4.3 The Four Tradeoffs**

  ------------------------ ------------------------------------------------------------- ------------------------------------------------------------------------------ -------------------------------------------------------------------------------------------------------
        **Tradeoff**                             **v1 Behaviour**                                                       **v2 Behaviour**                                                                              **Impact**

     Trigger condition                  Per-batch, triggered by Value flag                                             Session-open, once                                Minor improvement: 1 byte at session open vs potential 1 byte per batch. Net saving in most sessions.

   Compound mode toggling          Could be ON for some batches, OFF for others                               Session-level only. All-or-nothing.                                   Real constraint for mixed sessions. Loss of per-batch error detection benefit.

   Error detection scope      1111 detectable as error in batches where compound=OFF      1111 always valid if session compound=ON, even in batches that don\'t use it                          Minor degradation for mixed sessions on noisy channels.

   Consolidation benefit    BL context spread across Layer 1 and per-batch control byte                   All session config in one declared position                            Architecture improvement. Cleaner decoder. Single read for complete session picture.
  ------------------------ ------------------------------------------------------------- ------------------------------------------------------------------------------ -------------------------------------------------------------------------------------------------------

**4.4 The Genuine Problem Case**

The most significant practical consequence is for a high-reliability financial or engineering system that processes mixed batch types within one session --- some batches containing compound events (e.g. sale+COGS pairs) and others containing only simple single-entry records.

MIXED SESSION SCENARIO:

Batch 1: Routine single-entry sales records

No compound events.

Ideal: compound mode OFF. 1111=error detection.

Batch 2: End-of-day close with sale+COGS pairs

Requires compound events.

Requires: compound mode ON. 1111=valid continuation.

Batch 3: Routine records again.

Ideal: compound mode OFF again.

Under v1: compound mode toggled per batch via BL ctrl byte.

Batches 1 and 3 have full 1111 error detection.

Under v2: compound mode set at session open.

If ON: batches 1 and 3 lose 1111 error detection.

If OFF: batch 2 cannot use compound records at all.

No middle ground within one session.

> *For sessions that are uniformly compound-capable or uniformly not --- which is the large majority of real deployments --- the v2 behaviour is identical to v1 in effect. The tradeoff only matters for sessions explicitly designed to mix compound and non-compound batches with per-batch error detection as a requirement.*

**5. MITIGATION --- RESTORING PER-BATCH COMPOUND CONTROL**

The per-batch compound mode toggling capability lost in v2 can be restored using the Category 1101 Context Declaration mechanism from the Enhancement Sub-Protocol. This is not as compact as the original one-byte control record but provides equivalent functionality within the v2 architecture.

**5.1 The Workaround**

RESTORE COMPOUND MODE PER-BATCH USING CATEGORY 1101:

At session open: compound mode = OFF in Session Config Extension.

Before a batch requiring compound records:

Meta byte 1: 0 0 0 1 1101 (Wave, category 1101)

Context Declaration Block:

Type = 0111 (Update session parameter)

Scope = 0011 (Next stream unit = next batch)

Parameter byte = compound mode ON

Cost: 3 bytes (Meta + 2 declaration bytes)

After that batch closes:

Scope expires automatically (was \'next stream unit\').

Compound mode returns to session default = OFF.

1111 is again a detectable error in subsequent batches.

VERSUS v1 APPROACH:

One BL ctrl byte (1 byte) toggled compound mode per batch.

v2 workaround costs 3 bytes for the same effect.

Overhead: 2 extra bytes per batch requiring compound toggle.

**5.2 Recommendation**

For the large majority of deployments compound mode is a session-level concern and the v2 behaviour is correct and simpler. Declare compound mode at session open. Leave it fixed. The Layer 2 Compound Prefix already provides per-batch ceiling control.

For deployments that specifically need per-batch compound toggling with maximum error detection on non-compound batches --- typically high-reliability financial systems on challenged channels --- use the Category 1101 workaround described above. Document it as a standard pattern in the deployment profile.

A future protocol revision could restore the one-byte compound toggle as a named control record type, giving the compactness of v1 within the v2 architecture. This would cost one of the reserved type slots in the control record type field and is worth considering if the pattern proves common in deployed systems.

**5.3 The Layer 2 Compound Prefix as a Partial Substitute**

The Layer 2 Compound Prefix (bits 46-47) already provides per-batch compound control in one sense: setting it to 00 in a batch header forbids compound groups in that specific batch even if session compound mode is ON. This does not restore the error detection benefit (the decoder still treats 1111 as potentially valid because session mode is ON) but it does prevent accidental compound groups from posting in batches that should not contain them.

  ------------------------------------- ----------------------------- --------------------------- ------------------------------------------------ ------------------------------
              **Scenario**                **Session Compound Mode**    **Batch Compound Prefix**                 **1111 Detection**                 **Compound Records Allowed**

      v2 standard compound session                   ON                     11 (unlimited)                      Weak --- 1111 valid                             YES

   v2 with prefix 00 on simple batches               ON                           00               Medium --- decoder rejects 1111 at batch level        NO for this batch

           v2 full off session                       OFF                          Any                       Strong --- 1111 always error               NO for entire session

         v2 with 1101 workaround         OFF at session, ON via 1101    11 for compound batches     Strong on simple batches, normal on compound     Per-batch control restored
  ------------------------------------- ----------------------------- --------------------------- ------------------------------------------------ ------------------------------

**6. SUMMARY**

  ------------------------------ ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
           **Question**                                                                                                                           **Answer**

      What is compound mode?                                             The session-level permission flag that makes the 1111 account pair code valid in BitLedger Layer 3 records. Without it, 1111 is a detectable protocol error.

       What does it enable?             Multi-entry events where more than one accounting or flow record is required to describe one logical transaction. Sale+COGS pairs, engine firing with thermal obligation, any event with simultaneous bilateral ledger impact.

   Why is it a permission flag?                           Because 1111 appearing in a session that should never produce it is a detectable corruption signal. The flag turns 1111 from a valid code into an error sentinel for non-compound sessions.

       What changed in v2?                                         Compound mode moved from a per-batch BitLedger Context Control byte (now removed) to the session-open Session Configuration Extension byte. It is now session-level only.

      What is the tradeoff?       Mixed sessions that need compound mode ON for some batches and OFF (with error detection) for others cannot do this natively in v2. They must use a Category 1101 Context Declaration workaround at 3 bytes per toggle versus 1 byte in v1.

         Who is affected?                                       Only deployments that explicitly design for mixed compound and non-compound batches within one session with maximum per-batch error detection. Uniform sessions are unaffected.

     What is the mitigation?                           Category 1101 Context Declaration with scope \'next stream unit\' and parameter \'compound mode ON\'. 3 bytes. Automatic expiry after the batch. Documents as a named deployment profile pattern.
  ------------------------------ ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
