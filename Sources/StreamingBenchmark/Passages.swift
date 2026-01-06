import Foundation

/// Pool of conversational passages for benchmark testing
struct Passages {
    /// All available passages (~30-45 seconds each when read naturally)
    static let all: [String] = [
        """
        I was walking to the coffee shop this morning when I ran into an old friend. \
        We hadn't seen each other in years, so we decided to catch up over breakfast. \
        She told me about her new job and how much she loves working from home. \
        The flexibility has really changed her life for the better.
        """,

        """
        Last weekend I finally cleaned out my garage. It took the whole day, but I found \
        so many things I forgot I had. Old photos, my first guitar, even some letters \
        from college. It's funny how objects can bring back so many memories. \
        I ended up spending more time reminiscing than actually organizing.
        """,

        """
        My neighbor has the most beautiful garden. Every spring she plants tomatoes, \
        peppers, and herbs. She always shares her harvest with everyone on the street. \
        Last summer she gave me so many zucchinis I didn't know what to do with them. \
        I must have made a dozen loaves of zucchini bread.
        """,

        """
        I've been trying to learn how to cook more lately. Started with simple things \
        like pasta and scrambled eggs. Now I'm getting into soups and stir fries. \
        The key is not being afraid to make mistakes. Some of my best dishes came \
        from happy accidents in the kitchen.
        """,

        """
        We took a road trip to the coast last month. The drive was about four hours, \
        but we stopped at this little diner halfway there. Best pancakes I've ever had. \
        The beach was perfect, not too crowded. We stayed until sunset watching the \
        waves roll in.
        """,

        """
        My kids have been asking for a dog for years. We finally adopted one from the \
        shelter last week. She's a mix of something and something else, very sweet. \
        The house has been chaos ever since, but the good kind. Everyone fights over \
        who gets to take her for walks.
        """,

        """
        I started running a few months ago. Just around the block at first, then longer \
        routes through the park. It's become my favorite part of the morning. The quiet \
        streets, the sunrise, just me and my thoughts. I never thought I'd be a morning \
        person, but here we are.
        """,

        """
        There's this little bookstore downtown that I love. It's been there for decades, \
        run by the same family. They have a cat that sleeps in the window. I always \
        find something unexpected there, books I never would have picked up otherwise. \
        Last visit I discovered this amazing mystery series.
        """,

        """
        We're planning a family reunion for next summer. It's been five years since we \
        all got together. My cousins are flying in from across the country. We rented \
        a big cabin by the lake. There's going to be so much food and catching up. \
        I can't wait to see everyone.
        """,

        """
        I've been watching a lot of documentaries about space lately. It's incredible \
        how much we've learned in just the last few years. The images from those new \
        telescopes are amazing. Makes you feel small but also connected to something \
        much bigger. We're all made of star stuff, as they say.
        """
    ]

    /// Get a random passage, excluding recently used indices
    /// - Parameter excluding: Set of passage indices to exclude from selection
    /// - Returns: Tuple of (index, passage text)
    static func random(excluding: Set<Int> = []) -> (index: Int, text: String) {
        var available = Array(all.indices).filter { !excluding.contains($0) }

        // Reset if we've used all passages
        if available.isEmpty {
            available = Array(all.indices)
        }

        // Safe random selection (guard against empty array, though shouldn't happen)
        guard let index = available.randomElement() else {
            return (0, all[0])
        }

        return (index, all[index])
    }
}
