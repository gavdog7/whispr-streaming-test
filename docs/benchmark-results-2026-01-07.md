# Whisper Streaming Benchmark - Full Test Results

**Date:** 2026-01-07 10:25:00
**Machine:** MacBookPro18,2 (64GB RAM), macOS 26.1.0
**Test Duration:** ~35 seconds per model

---

## Test Environment

- **Hardware:** MacBook Pro M1 Max (MacBookPro18,2)
- **RAM:** 64GB
- **OS:** macOS 26.1.0
- **Build:** Release configuration (`swift build -c release`)

---

## Model 1: openai_whisper-tiny (39 MB)

### Metrics
| Metric | Value |
|--------|-------|
| Processing Ratio | 0.28x realtime |
| First-Word Latency | 4.4 seconds |
| Backpressure Events | 0 |
| Compute Unit | ANE |
| User Quality Rating | 2/5 (Poor) |
| **Status** | **MARGINAL** |

### Reference Passage
```
We took a road trip to the coast last month for our anniversary. The drive was
about four hours, but we stopped at this amazing little diner halfway there that
we found on a food blog. Best pancakes I've ever had, and they make their own
maple syrup. The beach was perfect when we arrived, not too crowded since it was
a weekday. We stayed until sunset watching the waves roll in and the sky turn
orange and pink. The next day we explored the tide pools and found all kinds of
sea creatures. Starfish, hermit crabs, even a small octopus. We took hundreds of
photos and I've already started putting together an album. It was one of those
trips where everything just worked out perfectly.
```

### Transcription Output
```
We took a road trip because last month for anniversary, we drive about four hours
but we stopped at this at this amazing little diner halfway for where we found on
a food blog. Best pancakes ever ever had had and they make their own make-all
syrup. The beach was perfect when we arrived, not too crowded since it was a week
We stayed until sunset watching the waves roll in and the sky turned of photos
and have already started putting together together in an album.
```

### Observations
- Word duplications: "at this at this", "ever ever had had", "together together"
- Word substitutions: "because" for "to the coast", "make-all" for "maple"
- Missing content: "orange and pink", "tide pools", "sea creatures", "Starfish, hermit crabs, even a small octopus"
- Sentence fragments and broken structure

---

## Model 2: openai_whisper-base (74 MB)

### Metrics
| Metric | Value |
|--------|-------|
| Processing Ratio | 0.34x realtime |
| First-Word Latency | 4.4 seconds |
| Backpressure Events | 0 |
| Compute Unit | ANE |
| User Quality Rating | 2/5 (Poor) |
| **Status** | **MARGINAL** |

### Reference Passage
```
I've been trying to learn how to cook more elaborate meals lately. I started with
simple things like pasta with homemade sauce and scrambled eggs with vegetables.
Now I'm getting into soups, stir fries, and even some baking. The key is not being
afraid to make mistakes. Some of my best dishes came from happy accidents in the
kitchen, like the time I accidentally added too much garlic and it turned out
amazing. My family has been supportive, even when things don't turn out perfectly.
Last week I tried making bread from scratch for the first time. It took three
attempts to get it right, but there's nothing quite like fresh homemade bread. I'm
thinking about trying croissants next, though that might be too ambitious. We'll
see how it goes.
```

### Transcription Output
```
I've been starting to, I've been trying to learn how to cook I started with simple
things like pasta with homemade sauce and scrambled eggs with vegetables. Now I'm
getting the soup, soup, stir fries and even some baking. The key is not being
afraid to make mistake mistakes. Some of my best dishes came from happy accident
in the well. Last week I tried making bread from scratch for the first time. It
took three attempt stamps to get it right. And there's nothing quite like fresh
homemade bread. I'm thinking about trying gruesome stuff.
```

### Observations
- False starts: "I've been starting to, I've been trying"
- Word duplications: "soup, soup", "mistake mistakes"
- Hallucinations: "gruesome stuff" instead of "croissants next, though that might be too ambitious"
- Missing middle section about kitchen accidents and family support
- Word errors: "attempt stamps" for "attempts", "well" for "kitchen"

---

## Model 3: openai_whisper-small (244 MB)

### Metrics
| Metric | Value |
|--------|-------|
| Processing Ratio | 1.76x realtime |
| First-Word Latency | 4.7 seconds |
| Backpressure Events | 8 |
| Compute Unit | ANE |
| User Quality Rating | 3/5 (Fair) |
| **Status** | **NOT VIABLE** |

### Reference Passage
```
I started running a few months ago after my doctor suggested I get more exercise.
Just around the block at first, barely able to finish without stopping. Then
longer routes through the park as I built up endurance. Now it's become my favorite
part of the morning. The quiet streets before everyone wakes up, watching the
sunrise paint the sky, just me and my thoughts. I never thought I'd be a morning
person, but here we are. Last weekend I ran my first five kilometer race. I didn't
set any records, but I finished, and that felt like a huge accomplishment. Some of
my coworkers have started joining me on weekend runs. We're thinking about training
for a half marathon together next spring. It's amazing how one small change can
transform your whole routine.
```

### Transcription Output
```
I started running a few months ago after my doctor suggested I get more exercise.
Just around the block of the first, barely able to finish without stopping. Then
longer became through the park as I built built up into the endurance. Now it's
become my favourite part of the morning. The The quiet, quiet streets before
everyone wakes up watching the sunrise paint the sky. Just me and my thoughts. I
never thought I'd be a morning person but joining me on weekend runs.
```

### Observations
- Word duplications: "built built", "The The quiet, quiet"
- Missing large section: everything from "here we are" through "coworkers have started"
- Abrupt ending mid-thought
- Slightly better accuracy on captured portions vs tiny/base
- Processing ratio exceeded 1.0x (1.76x) - cannot keep up with realtime

---

## Model 4: openai_whisper-medium (769 MB)

### Metrics
| Metric | Value |
|--------|-------|
| Processing Ratio | 15.91x realtime |
| First-Word Latency | 8.7 seconds |
| Backpressure Events | 20 |
| Compute Unit | GPU |
| User Quality Rating | 4/5 (Good) |
| **Status** | **NOT VIABLE** |

### Reference Passage
```
There's this little independent bookstore downtown that I absolutely love. It's
been there for decades, run by the same family for three generations now. They
have a orange cat named Marmalade that sleeps in the front window and greets
customers when he's in the mood. The shelves are packed floor to ceiling with
books, organized in a way that only the owners fully understand. I always find
something unexpected there, books I never would have picked up if I was just
browsing online. Last visit I discovered this amazing mystery series set in 1920s
Chicago. I've already read four of them and ordered the rest. The owner recommended
them after I mentioned I liked historical fiction. That personal touch is something
you just can't get from algorithms.
```

### Transcription Output
```
There's this little independent bookstore downtown that I absolutely love. It's
been there for decades, run by the same family for three generations now. They
have an orange cat named Marmalade that sleeps in the front window and greets
customers when he's in the mood. The shelves are packed floor to ceiling with
books, organized in a way that only the owners fully understand. I always find
series set in the 1920s.
```

### Observations
- **Highest accuracy** of captured content - nearly word-perfect
- Corrected grammar: "an orange cat" (reference had "a orange cat")
- But severely truncated - missing ~40% of passage
- Missing: "something unexpected there, books I never would have picked up if I was just browsing online. Last visit I discovered this amazing mystery"
- Missing entire ending about owner recommendation and algorithms
- 15.91x realtime ratio means it processes 1 second of audio in ~16 seconds
- Switched to GPU (ANE couldn't handle model size efficiently)

---

## Model 5: openai_whisper-large-v3 (1.5 GB)

### Metrics
| Metric | Value |
|--------|-------|
| Processing Ratio | 55.61x realtime |
| First-Word Latency | 38.3 seconds |
| Backpressure Events | 25 |
| Compute Unit | GPU |
| User Quality Rating | 1/5 (Unusable) |
| **Status** | **NOT VIABLE** |

### Reference Passage
```
Last weekend I finally cleaned out my garage after putting it off for months. It
took the whole day, but I found so many things I forgot I had. Old photos from
family vacations, my first guitar that I learned to play in high school, and even
some letters from college that my grandmother had written me. It's funny how
objects can bring back so many memories. I ended up spending more time reminiscing
than actually organizing. My wife came out around dinner time wondering what was
taking so long, and she found me sitting on the floor looking through a box of old
yearbooks. We ordered pizza and looked through everything together. Sometimes the
best weekends are the unplanned ones.
```

### Transcription Output (During Recording)
```
Last weekend I finally cleaned out my garage after putting it off for months. It
took the whole day. But I found so many things I forgot I had. photos from family
vacations, my first guitar.
```

### Post-Recording Output (Continued Processing)
```
It took the whole day, but I found so many things I forgot I had. Old photos from
family vacations, my first guitar that I learned to play in high school, and even
some letters from college that my grandmother had written me. It's funny how
objects can bring back so many memories. I ended up spending more time reminiscing
than actually organising. My wife came out around dinner time, wondering what was
taking so long, and she found me sitting on the floor, looking through a box of
old yearbooks.
```

### Observations
- **Most accurate transcription** when allowed to complete
- Spelled "organising" with British spelling (model behavior)
- Added appropriate punctuation and commas
- **BUT: Completely unusable for streaming**
  - 38.3 second latency to first word (longer than the entire recording)
  - 55.61x realtime means 1 second of audio takes ~56 seconds to process
  - Recording finished before first transcription appeared
  - Errors during processing: "Unable to compute the asynchronous prediction using ML Program"
  - Transcription continued running after benchmark ended

---

## Summary Table

| Model | Size | Ratio | Latency | Backpressure | Compute | Quality | Status |
|-------|------|-------|---------|--------------|---------|---------|--------|
| tiny | 39 MB | 0.28x | 4.4s | 0 | ANE | 2/5 | Marginal |
| base | 74 MB | 0.34x | 4.4s | 0 | ANE | 2/5 | Marginal |
| small | 244 MB | 1.76x | 4.7s | 8 | ANE | 3/5 | Not Viable |
| medium | 769 MB | 15.91x | 8.7s | 20 | GPU | 4/5 | Not Viable |
| large-v3 | 1.5 GB | 55.61x | 38.3s | 25 | GPU | 1/5 | Not Viable |

---

## Errors Encountered

### large-v3 ML Program Errors
```
Warning: Chunk 9 failed: Unable to compute the asynchronous prediction using ML
Program. It can be an invalid input data or broken/unsupported model.
```
This error repeated multiple times during and after the large-v3 test, indicating the model struggled with the cumulative buffer approach on this hardware.

---

## Raw JSON Results
Results saved to: `/Users/gavin/Documents/whisper-streaming-benchmark-2026-01-07.json`
