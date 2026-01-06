import Foundation

/// Pool of conversational passages for benchmark testing
struct Passages {
    /// All available passages (~100-120 words each, ~35-45 seconds when read naturally)
    static let all: [String] = [
        """
        I was walking to the coffee shop this morning when I ran into an old friend \
        from college. We hadn't seen each other in years, so we decided to catch up \
        over breakfast at that little diner on Main Street. She told me about her new \
        job at a tech startup and how much she loves working from home now. The \
        flexibility has really changed her life for the better. She can pick up her \
        kids from school, work on her own schedule, and still get everything done. \
        It made me think about my own work situation and whether I should look for \
        something more flexible. We exchanged numbers and promised to get coffee again \
        soon. It's funny how random encounters can make you reconsider things.
        """,

        """
        Last weekend I finally cleaned out my garage after putting it off for months. \
        It took the whole day, but I found so many things I forgot I had. Old photos \
        from family vacations, my first guitar that I learned to play in high school, \
        and even some letters from college that my grandmother had written me. It's \
        funny how objects can bring back so many memories. I ended up spending more \
        time reminiscing than actually organizing. My wife came out around dinner time \
        wondering what was taking so long, and she found me sitting on the floor \
        looking through a box of old yearbooks. We ordered pizza and looked through \
        everything together. Sometimes the best weekends are the unplanned ones.
        """,

        """
        My neighbor has the most beautiful garden I've ever seen. Every spring she \
        plants tomatoes, peppers, zucchini, and all kinds of herbs. She starts the \
        seedlings indoors in February and transplants them once the frost passes. She \
        always shares her harvest with everyone on the street, which is incredibly \
        generous. Last summer she gave me so many zucchinis I didn't know what to do \
        with them all. I must have made a dozen loaves of zucchini bread and gave most \
        of them away to friends and coworkers. This year she's teaching me how to grow \
        my own tomatoes. We set up a small raised bed in my backyard and she helped me \
        pick out the best varieties for our climate. I'm hopeful for a good harvest.
        """,

        """
        I've been trying to learn how to cook more elaborate meals lately. I started \
        with simple things like pasta with homemade sauce and scrambled eggs with \
        vegetables. Now I'm getting into soups, stir fries, and even some baking. The \
        key is not being afraid to make mistakes. Some of my best dishes came from \
        happy accidents in the kitchen, like the time I accidentally added too much \
        garlic and it turned out amazing. My family has been supportive, even when \
        things don't turn out perfectly. Last week I tried making bread from scratch \
        for the first time. It took three attempts to get it right, but there's nothing \
        quite like fresh homemade bread. I'm thinking about trying croissants next, \
        though that might be too ambitious. We'll see how it goes.
        """,

        """
        We took a road trip to the coast last month for our anniversary. The drive was \
        about four hours, but we stopped at this amazing little diner halfway there \
        that we found on a food blog. Best pancakes I've ever had, and they make their \
        own maple syrup. The beach was perfect when we arrived, not too crowded since \
        it was a weekday. We stayed until sunset watching the waves roll in and the \
        sky turn orange and pink. The next day we explored the tide pools and found \
        all kinds of sea creatures. Starfish, hermit crabs, even a small octopus. We \
        took hundreds of photos and I've already started putting together an album. \
        It was one of those trips where everything just worked out perfectly.
        """,

        """
        My kids have been asking for a dog for years, and we finally adopted one from \
        the local shelter last week. She's a mix of labrador and something else, very \
        sweet and gentle. The shelter said she's about two years old and was found as \
        a stray. The house has been chaos ever since, but the good kind of chaos. \
        Everyone fights over who gets to take her for walks and who gets to sit next \
        to her on the couch. She's already learned where the treat jar is and sits by \
        it hopefully every time someone walks into the kitchen. We named her Luna \
        because she has a white patch on her chest that looks like a crescent moon. \
        The kids are taking turns with training responsibilities and it's teaching \
        them a lot about commitment.
        """,

        """
        I started running a few months ago after my doctor suggested I get more \
        exercise. Just around the block at first, barely able to finish without \
        stopping. Then longer routes through the park as I built up endurance. Now \
        it's become my favorite part of the morning. The quiet streets before everyone \
        wakes up, watching the sunrise paint the sky, just me and my thoughts. I never \
        thought I'd be a morning person, but here we are. Last weekend I ran my first \
        five kilometer race. I didn't set any records, but I finished, and that felt \
        like a huge accomplishment. Some of my coworkers have started joining me on \
        weekend runs. We're thinking about training for a half marathon together next \
        spring. It's amazing how one small change can transform your whole routine.
        """,

        """
        There's this little independent bookstore downtown that I absolutely love. \
        It's been there for decades, run by the same family for three generations now. \
        They have a orange cat named Marmalade that sleeps in the front window and \
        greets customers when he's in the mood. The shelves are packed floor to \
        ceiling with books, organized in a way that only the owners fully understand. \
        I always find something unexpected there, books I never would have picked up \
        if I was just browsing online. Last visit I discovered this amazing mystery \
        series set in 1920s Chicago. I've already read four of them and ordered the \
        rest. The owner recommended them after I mentioned I liked historical fiction. \
        That personal touch is something you just can't get from algorithms.
        """,

        """
        We're planning a family reunion for next summer at a cabin by the lake. It's \
        been five years since we all got together, and I've really missed everyone. \
        My cousins are flying in from all over the country. Sarah from Seattle, Mike \
        from Miami, and the twins from Texas. We rented a big cabin with enough room \
        for all twenty of us, right on the waterfront. There's going to be so much \
        food. Aunt Maria is bringing her famous lasagna, and Uncle Joe promised to \
        grill burgers and hot dogs. We're planning a bonfire the first night, and \
        someone suggested we do a talent show like we used to when we were kids. I've \
        already started practicing my terrible guitar playing. I can't wait to see \
        everyone and catch up on the last five years of our lives.
        """,

        """
        I've been watching a lot of documentaries about space exploration lately. \
        It's incredible how much we've learned about the universe in just the last \
        few years. The images from those new space telescopes are absolutely stunning. \
        Galaxies billions of light years away, nebulae where new stars are being born, \
        planets orbiting distant suns. It makes you feel small but also connected to \
        something much bigger than yourself. We're all made of star stuff, as they \
        say. My daughter has gotten interested too, and we've started watching them \
        together after dinner. She's asking questions I can't always answer, which \
        has led us down some fascinating rabbit holes of research. Last week we built \
        a model of the solar system for her science class. It was a great bonding \
        experience and reminded me why I loved science as a kid.
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
