# UX Feedback: Streaming Benchmark Flow

**Date:** 2026-01-06
**Status:** Pending implementation

---

## Summary

The current benchmark UX creates cognitive overload - users cannot simultaneously read the reference passage, speak it aloud, AND monitor the streaming transcript. The flow needs restructuring for usability.

---

## Issues Identified

### 1. Model Downloads Interrupt Flow
**Problem:** Models download mid-benchmark, breaking user focus.
**Solution:** Download ALL models upfront before benchmark begins, with progress indicator (e.g., "Downloading model 2/5: base...").

### 2. Cannot Read Reference While Monitoring Transcript
**Problem:** Reference text appears at top, transcript streams below. User must read text to speak it, but can't watch transcript while reading.
**Solution:** Side-by-side layout with reference passage on left, accumulated transcript on right. Conservative words-per-line for easy visual comparison.

### 3. Transcript Not Persistent
**Problem:** Streamed text is not accumulated into a reviewable block.
**Solution:** Build up confirmed transcript throughout the test. At end of each model test, user can scroll/review the full transcript vs reference.

### 4. Reference Passage Too Difficult
**Problem:** Current passage requires concentration to read, making it hard to speak naturally.
**Solution:** Use conversational, natural speech patterns. Shorter sentences. Content that flows without requiring careful pronunciation.

### 5. Same Passage Every Time
**Problem:** User gets bored reading the same text repeatedly across 5 models.
**Solution:** Pool of 10-20 varied passages, randomly selected for each model test.

### 6. No Review Period Before Rating
**Problem:** User is asked to rate quality while still processing the test.
**Solution:** After each model test, pause for review. Display side-by-side comparison (reference vs transcript), THEN prompt for quality rating.

---

## Proposed Flow

```
1. STARTUP
   - Display welcome message
   - Download all 5 models with progress indicator
   - "Ready to begin benchmark"

2. FOR EACH MODEL:
   a. Display model name and "Press Enter to start"
   b. Show side-by-side layout:
      ┌─────────────────────┬─────────────────────┐
      │   REFERENCE TEXT    │    YOUR TRANSCRIPT  │
      │                     │                     │
      │ "The quick brown    │ "The quick brown    │
      │ fox jumped over     │ fox jumped over     │
      │ the lazy dog..."    │ the lazy dock..."   │
      │                     │                     │
      └─────────────────────┴─────────────────────┘
   c. User reads passage aloud
   d. Transcript accumulates in real-time on right side
   e. Test completes
   f. REVIEW PHASE: User compares columns
   g. Prompt: "Rate transcription quality (1-5)"
   h. Record rating, proceed to next model

3. FINAL REPORT
   - Summary table with metrics + user ratings
   - Recommendation for streaming viability
```

---

## Passage Requirements

- Conversational tone (like telling a story to a friend)
- Natural speech patterns
- No technical jargon or tongue-twisters
- ~30-60 seconds when read at normal pace
- 10-20 different passages in rotation

### Example Passage Style

**Before (too formal):**
> "The implementation of distributed systems requires careful consideration of network latency, fault tolerance mechanisms, and consensus protocols."

**After (conversational):**
> "I was walking to the coffee shop this morning when I ran into an old friend. We hadn't seen each other in years, so we decided to catch up over breakfast. She told me about her new job and how much she loves working from home."

---

## Implementation Checklist

- [ ] Add model pre-download phase with progress UI
- [ ] Create pool of 10-20 conversational passages
- [ ] Implement side-by-side terminal layout
- [ ] Accumulate transcript text persistently
- [ ] Add review phase after each model test
- [ ] Update quality rating prompt timing
