import Foundation

/// Single source for the user-facing app name.
/// Change `PRODUCT_DISPLAY_NAME` in Info.plist / Xcode build settings — Swift reads it from the bundle.
enum AppIdentity {
    static var displayName: String {
        if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !name.isEmpty {
            return name
        }
        if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !name.isEmpty {
            return name
        }
        return "Daily On Plan"
    }

    static let tagline = "Stay on plan. One day at a time."
}

enum MotivationQuoteStore {
    private static let lastQuoteKey = "motivation.lastQuoteText"

    /// Built-in one-day-at-a-time quotes (no clinic branding).
    static let builtIn: [String] = [
        "Stay on plan. One day at a time.",
        "You don’t have to be perfect — just consistent.",
        "Small choices stack into big results.",
        "Today’s sheet is enough. Fill it honestly.",
        "Progress isn’t linear. Showing up is.",
        "Drink the water. Log the protein. Keep going.",
        "A slip isn’t a restart — it’s data.",
        "Hungry feelings pass. Your goals don’t have to.",
        "Ketosis starts with today’s decisions.",
        "You’re building a habit, not chasing a mood.",
        "The plan works when you work the plan.",
        "One honest weigh-in beats a week of guessing.",
        "Cravings are temporary. Quitting on yourself isn’t required.",
        "Log it, don’t judge it.",
        "You already survived hard days. This is another one.",
        "Protein first. Then the rest gets easier.",
        "Hydration is free willpower.",
        "Followed plan today? That’s a win — full stop.",
        "Off-plan days teach. On-plan days compound.",
        "Your future self is watching this choice.",
        "Don’t negotiate with the old habit after 8pm.",
        "Ash less. Pour less. Breathe more.",
        "Urge surfing: ride it for ten minutes.",
        "You can want it and still not take it.",
        "Identity shift: “I’m someone who sticks to the plan.”",
        "Missed a meal log? Catch up without drama.",
        "The scale measures weight, not worth.",
        "BMI is a number. Your effort is the story.",
        "Sleep, water, protein — boring and powerful.",
        "If it’s on the sheet, it’s manageable.",
        "Tomorrow’s easier when tonight’s honest.",
        "You don’t need motivation. You need the next tap.",
        "Feelings are allowed. Cheating the log isn’t helpful.",
        "Half a pack less is still less.",
        "One fewer drink still counts.",
        "Streaks start over every morning — that’s a gift.",
        "Be the kind of stubborn that protects your goals.",
        "Discipline is self-respect in action.",
        "You’re allowed to restart mid-day.",
        "Silence the “all or nothing” voice.",
        "The plan isn’t punishment. It’s structure.",
        "Check hunger before and after — learn your patterns.",
        "Saved meals remove decision fatigue.",
        "Suggest is a nudge, not a verdict. You choose.",
        "Privacy collapse exists so you can still show up.",
        "Export the week. Celebrate the receipts.",
        "Ketosis isn’t magic. It’s consistency plus patience.",
        "Vegetables fill the plate and the gap.",
        "Walk it off. Log the workout. Move on.",
        "Supplements don’t replace the plan — they support it.",
        "Your height is set. Your habits aren’t.",
        "Goal weight is a direction, not a day.",
        "To-go pounds shrink with to-go choices.",
        "Don’t outrun a bad day with a worse night.",
        "Open the app. Close the fridge. Same courage.",
        "You’re not behind — you’re here.",
        "The hard part is starting. You’ve already started.",
        "Name the craving. Then name the goal louder.",
        "Friends can wait. Your health can’t forever.",
        "Boredom isn’t an emergency snack.",
        "Salt, water, protein — then reassess.",
        "If it’s not on the plan, it needs a reason.",
        "Off-plan tags make patterns visible. Use them.",
        "Notes are for you, not for shame.",
        "A quiet day on plan is still a victory lap.",
        "You can be tired and still follow through.",
        "Momentum loves boring repetition.",
        "The next best choice is always available.",
        "Don’t finish the pack to “get rid of it.”",
        "Don’t finish the bottle to “not waste it.”",
        "Waste the temptation. Keep the streak.",
        "Your lungs and liver prefer today’s restraint.",
        "Money saved is proof you’re changing.",
        "Urge logged beats urge obeyed.",
        "Tap ash only when it’s real — honesty first.",
        "Pour to add is optional. So is stopping.",
        "Reduce mode means progress, not failure.",
        "Quit mode means target zero — protect it.",
        "Count mode means awareness. Awareness is power.",
        "Heatmaps don’t lie. Neither should the log.",
        "Share a card when you’re proud — or when you’re trying.",
        "This app is your sheet, not a courtroom.",
        "Stay curious about what works for you.",
        "If today was messy, make tonight clean.",
        "You only need to win the next hour.",
        "The plan is simple on purpose.",
        "Complexity is where excuses hide.",
        "Eat what you planned. Drink what you planned.",
        "Smoke less than yesterday if you can.",
        "Drink less than yesterday if you can.",
        "Or the same — and call that stability.",
        "Stability is underrated progress.",
        "You’re allowed to want dessert and choose protein.",
        "You’re allowed to want a cig and choose air.",
        "You’re allowed to want a drink and choose water.",
        "Freedom is choosing again after the urge.",
        "Keep the streak of honesty even when the plan slips.",
        "The sheet remembers so you don’t have to spiral.",
        "One day at a time isn’t a slogan — it’s the strategy.",
        "You’ve got this hour. Then the next."
    ]

    static func allQuotes(custom: [String]) -> [String] {
        let trimmedCustom = custom
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return builtIn + trimmedCustom
    }

    static func nextQuote(custom: [String]) -> String {
        let pool = allQuotes(custom: custom)
        guard !pool.isEmpty else { return "Stay on plan. One day at a time." }
        let last = UserDefaults.standard.string(forKey: lastQuoteKey)
        var candidates = pool
        if let last, candidates.count > 1 {
            candidates.removeAll { $0 == last }
        }
        let pick = candidates.randomElement() ?? pool[0]
        UserDefaults.standard.set(pick, forKey: lastQuoteKey)
        return pick
    }

    static func smokingBodies() -> [String] {
        [
            "Log today’s smokes when you have a sec.",
            "Still under your max? Check the Smoking section.",
            "Urge check — open Smoking if you need to log.",
            "A quick ash log keeps the day honest."
        ]
    }

    static func drinkingBodies() -> [String] {
        [
            "Log today’s drinks when you can.",
            "Still under your drink max? Check Drinking.",
            "Urge check — open Drinking if you need to log.",
            "A quick pour log keeps the day clear."
        ]
    }
}
