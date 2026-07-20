import Foundation

enum FoodCatalog {
    static let all: [CatalogFood] = proteins + vegetables + misc + fats + fruits

    static func foods(
        category: FoodCategory? = nil,
        phase: ProgramPhase,
        search: String = ""
    ) -> [CatalogFood] {
        all.filter { item in
            if let category, item.category != category { return false }
            if item.phase == .week2Plus && phase == .week1 { return false }
            if !search.isEmpty {
                return item.name.localizedCaseInsensitiveContains(search)
            }
            return true
        }
    }

    static func calories(for item: CatalogFood, servings: Double) -> Int {
        if let per = item.proteinCategory?.caloriesPerServing {
            return Int((Double(per) * servings).rounded())
        }
        return Int((Double(item.calories) * servings / max(item.servingsPerUnit, 0.01)).rounded())
    }

    // MARK: - Proteins

    static let proteins: [CatalogFood] = veryLean + lean + mediumFat + shakes + snacks + substitutions

    static let veryLean: [CatalogFood] = [
        .init(name: "Canadian bacon", category: .protein, servingLabel: "1 oz", calories: 35, proteinCategory: .veryLean),
        .init(name: "Chicken (white meat, no skin)", category: .protein, servingLabel: "1 oz", calories: 35, proteinCategory: .veryLean),
        .init(name: "Cornish hen (no skin)", category: .protein, servingLabel: "1 oz", calories: 35, proteinCategory: .veryLean),
        .init(name: "Deli meat (≤1g fat/oz)", category: .protein, servingLabel: "1 oz", calories: 35, proteinCategory: .veryLean),
        .init(name: "Egg Beaters", category: .protein, servingLabel: "1/4 cup", calories: 35, proteinCategory: .veryLean),
        .init(name: "Egg whites", category: .protein, servingLabel: "2", calories: 35, proteinCategory: .veryLean),
        .init(name: "Fish (cod, flounder, grouper, haddock, halibut, mahi-mahi, orange roughy, tilapia, trout, tuna in water)", category: .protein, servingLabel: "1 oz", calories: 35, proteinCategory: .veryLean),
        .init(name: "Ground beef (96% lean)", category: .protein, servingLabel: "1 oz", calories: 35, proteinCategory: .veryLean),
        .init(name: "Ground turkey breast (98% lean)", category: .protein, servingLabel: "1 oz", calories: 35, proteinCategory: .veryLean),
        .init(name: "Pork (lean chop, tenderloin)", category: .protein, servingLabel: "1 oz", calories: 35, proteinCategory: .veryLean),
        .init(name: "Shellfish (clams, crab, lobster, scallops, shrimp)", category: .protein, servingLabel: "1 oz", calories: 35, proteinCategory: .veryLean),
        .init(name: "Smoked salmon (lox)", category: .protein, servingLabel: "1 oz", calories: 35, proteinCategory: .veryLean),
        .init(name: "Tuna (light, pouch or canned in water)", category: .protein, servingLabel: "1 1/2 oz", calories: 35, proteinCategory: .veryLean),
        .init(name: "Turkey (white meat, no skin)", category: .protein, servingLabel: "1 oz", calories: 35, proteinCategory: .veryLean),
        .init(name: "Turkey bacon (uncured)", category: .protein, servingLabel: "1 oz strip", calories: 35, proteinCategory: .veryLean),
        .init(name: "Turkey pepperoni", category: .protein, servingLabel: "8 slices", calories: 35, proteinCategory: .veryLean),
        .init(name: "Very lean turkey burger", category: .protein, servingLabel: "1 oz", calories: 35, proteinCategory: .veryLean)
    ]

    static let lean: [CatalogFood] = [
        .init(name: "Beef (USDA Choice or Select)", category: .protein, servingLabel: "1 oz", calories: 55, proteinCategory: .lean),
        .init(name: "Chicken (dark meat, no skin)", category: .protein, servingLabel: "1 oz", calories: 55, proteinCategory: .lean),
        .init(name: "Chilean sea bass", category: .protein, servingLabel: "1 oz", calories: 55, proteinCategory: .lean),
        .init(name: "Deli meat (1–3g fat/oz)", category: .protein, servingLabel: "1 oz", calories: 55, proteinCategory: .lean),
        .init(name: "Ground beef (93% lean)", category: .protein, servingLabel: "1 oz", calories: 55, proteinCategory: .lean),
        .init(name: "Herring (not creamed/smoked)", category: .protein, servingLabel: "1 oz", calories: 55, proteinCategory: .lean),
        .init(name: "Lamb (roast, chop, leg)", category: .protein, servingLabel: "1 oz", calories: 55, proteinCategory: .lean),
        .init(name: "Salmon", category: .protein, servingLabel: "1 oz", calories: 55, proteinCategory: .lean),
        .init(name: "Broiled salmon", category: .protein, servingLabel: "1 oz", calories: 55, proteinCategory: .lean),
        .init(name: "Sardines", category: .protein, servingLabel: "1 oz", calories: 55, proteinCategory: .lean),
        .init(name: "Turkey (dark meat, no skin)", category: .protein, servingLabel: "1 oz", calories: 55, proteinCategory: .lean),
        .init(name: "Turkey sausage (patty)", category: .protein, servingLabel: "1 patty", calories: 55, proteinCategory: .lean),
        .init(name: "Veal (cutlet, loin chop, roast)", category: .protein, servingLabel: "1 oz", calories: 55, proteinCategory: .lean)
    ]

    static let mediumFat: [CatalogFood] = [
        .init(name: "Corned beef", category: .protein, servingLabel: "1 oz", calories: 75, proteinCategory: .mediumFat),
        .init(name: "Egg (cooked or raw)", category: .protein, servingLabel: "1", calories: 75, proteinCategory: .mediumFat),
        .init(name: "Ground beef (80% lean)", category: .protein, servingLabel: "1 oz", calories: 75, proteinCategory: .mediumFat),
        .init(name: "Ground turkey (85% lean)", category: .protein, servingLabel: "1 oz", calories: 75, proteinCategory: .mediumFat),
        .init(name: "Prime rib", category: .protein, servingLabel: "1 oz", calories: 75, proteinCategory: .mediumFat),
        .init(name: "Short ribs", category: .protein, servingLabel: "1 oz", calories: 75, proteinCategory: .mediumFat)
    ]

    static let shakes: [CatalogFood] = [
        .init(name: "Premium Protein Shake", category: .protein, servingLabel: "1 scoop", calories: 110, proteinCategory: .shake),
        .init(name: "Chocolate Premium Protein", category: .protein, servingLabel: "1 scoop", calories: 110, proteinCategory: .shake),
        .init(name: "Ready to Drink Shake", category: .protein, servingLabel: "1", calories: 120, proteinCategory: .shake),
        .init(name: "Shake to Go", category: .protein, servingLabel: "1", calories: 120, proteinCategory: .shake)
    ]

    static let snacks: [CatalogFood] = [
        .init(name: "Protein Bar", category: .protein, servingLabel: "1 bar", calories: 120, proteinCategory: .snack),
        .init(name: "Protein Snack", category: .protein, servingLabel: "1 snack", calories: 120, proteinCategory: .snack),
        .init(name: "Prepared Meal", category: .protein, servingLabel: "1 meal", calories: 140, proteinCategory: .snack)
    ]

    static let substitutions: [CatalogFood] = [
        .init(name: "Cheddar (fat-free, shredded)", category: .protein, servingLabel: "1/4 cup", calories: 45, proteinCategory: .substitution),
        .init(name: "Cottage cheese (1%)", category: .protein, servingLabel: "1/4 cup", calories: 45, proteinCategory: .substitution),
        .init(name: "Feta (fat free)", category: .protein, servingLabel: "2 Tbsp (1 oz)", calories: 35, proteinCategory: .substitution),
        .init(name: "Greek yogurt (plain, nonfat)", category: .protein, servingLabel: "2 oz", calories: 35, proteinCategory: .substitution),
        .init(name: "Mozzarella (fat-free, shredded)", category: .protein, servingLabel: "1/4 cup", calories: 45, proteinCategory: .substitution),
        .init(name: "String cheese (light)", category: .protein, servingLabel: "1 stick", calories: 50, proteinCategory: .substitution)
    ]

    // MARK: - Vegetables (25 cal / serving)

    static let vegetables: [CatalogFood] = [
        "Artichoke/artichoke hearts (no oil)", "Asparagus (8 medium spears)", "Bagged greens (kale, mustard, spinach, spring mix)",
        "Bamboo shoots", "Bean sprouts", "Beans (green, Italian, wax)", "Beets", "Broccoli", "Brussels sprouts",
        "Cabbage", "Carrots", "Cauliflower", "Celery", "Cucumber", "Eggplant", "Green onions/scallions",
        "Greens (collard, kale, mustard, turnip)", "Jicama", "Leeks", "Mixed vegetables (no starchy)",
        "Mushrooms", "Okra", "Onions", "Peppers (all varieties)", "Radishes", "Rutabaga", "Sauerkraut",
        "Snap peas", "Snow pea pods", "Spinach", "Summer squash", "Swiss chard", "Tomato", "Turnips",
        "Water chestnuts", "Watercress", "Zucchini", "Salad greens", "Steamed broccoli"
    ].map {
        CatalogFood(
            name: $0,
            category: .vegetable,
            servingLabel: "1 cup raw or 1/2 cup cooked",
            calories: 25
        )
    }

    // MARK: - Misc (limit 4/day)

    static let misc: [CatalogFood] = [
        .init(name: "Almond milk (unsweetened)", category: .misc, servingLabel: "1/2 cup", calories: 15),
        .init(name: "Balsamic vinegar", category: .misc, servingLabel: "1 Tbsp", calories: 10),
        .init(name: "Barbecue sauce (low sugar)", category: .misc, servingLabel: "1 Tbsp", calories: 15),
        .init(name: "Broth/stock", category: .misc, servingLabel: "1 cup", calories: 10),
        .init(name: "Chocolate Sensations (any flavor)", category: .misc, servingLabel: "1/2 piece", calories: 20),
        .init(name: "Coffee creamer (sugar free)", category: .misc, servingLabel: "1 Tbsp", calories: 10),
        .init(name: "Cooking spray", category: .misc, servingLabel: "as needed", calories: 0),
        .init(name: "Cream cheese (fat free)", category: .misc, servingLabel: "1 Tbsp", calories: 15),
        .init(name: "Flavoring extracts", category: .misc, servingLabel: "1 Tbsp", calories: 5),
        .init(name: "Gelatin (sugar-free, powder)", category: .misc, servingLabel: "1/4 package", calories: 10),
        .init(name: "Gelatin (sugar-free, ready to eat)", category: .misc, servingLabel: "1 container", calories: 10),
        .init(name: "Hot sauce (no sugar added)", category: .misc, servingLabel: "2 Tbsp", calories: 5),
        .init(name: "Italian salad dressing (fat free)", category: .misc, servingLabel: "2 Tbsp", calories: 15),
        .init(name: "Ketchup (reduced sugar)", category: .misc, servingLabel: "1 Tbsp", calories: 10),
        .init(name: "Lemon/lime (juiced, wedges)", category: .misc, servingLabel: "1 medium", calories: 10),
        .init(name: "Mustard (brown, Dijon, yellow)", category: .misc, servingLabel: "2 Tbsp", calories: 10),
        .init(name: "Parmesan (grated)", category: .misc, servingLabel: "1 Tbsp", calories: 20),
        .init(name: "Pickles (dill)", category: .misc, servingLabel: "3 slices / 1 medium", calories: 5),
        .init(name: "Salsa", category: .misc, servingLabel: "2 Tbsp", calories: 10),
        .init(name: "Shirataki noodles", category: .misc, servingLabel: "1/2 cup", calories: 10),
        .init(name: "Signature PB", category: .misc, servingLabel: "2 tsp", calories: 20),
        .init(name: "Sour cream (light)", category: .misc, servingLabel: "1 Tbsp", calories: 20),
        .init(name: "Soy sauce", category: .misc, servingLabel: "2 Tbsp", calories: 10),
        .init(name: "Syrup (sugar free)", category: .misc, servingLabel: "2 Tbsp", calories: 10),
        .init(name: "Whipped topping (sugar free)", category: .misc, servingLabel: "2 Tbsp", calories: 15),
        .init(name: "Lemon juice & slices", category: .misc, servingLabel: "as needed", calories: 5)
    ]

    // MARK: - Fats (Week 2+, ~45 cal)

    static let fats: [CatalogFood] = [
        .init(name: "Almonds", category: .fat, servingLabel: "6", calories: 45, phase: .week2Plus, isHealthier: true),
        .init(name: "Almond meal/flour", category: .fat, servingLabel: "1 Tbsp", calories: 45, phase: .week2Plus),
        .init(name: "Avocado", category: .fat, servingLabel: "2 Tbsp (1 oz)", calories: 45, phase: .week2Plus, isHealthier: true),
        .init(name: "Black olives", category: .fat, servingLabel: "8", calories: 45, phase: .week2Plus),
        .init(name: "Brazil nuts", category: .fat, servingLabel: "2", calories: 45, phase: .week2Plus, isHealthier: true),
        .init(name: "Butter (stick)", category: .fat, servingLabel: "1 tsp", calories: 45, phase: .week2Plus),
        .init(name: "Cashews", category: .fat, servingLabel: "6", calories: 45, phase: .week2Plus),
        .init(name: "Chia seeds", category: .fat, servingLabel: "2 tsp", calories: 45, phase: .week2Plus, isHealthier: true),
        .init(name: "Coconut milk (light)", category: .fat, servingLabel: "1/3 cup", calories: 45, phase: .week2Plus),
        .init(name: "Coconut milk (unsweetened)", category: .fat, servingLabel: "1 cup", calories: 45, phase: .week2Plus),
        .init(name: "Cream cheese (regular)", category: .fat, servingLabel: "1 Tbsp", calories: 45, phase: .week2Plus),
        .init(name: "Cream cheese (light)", category: .fat, servingLabel: "1 1/2 Tbsp", calories: 45, phase: .week2Plus),
        .init(name: "Flaxseed (ground)", category: .fat, servingLabel: "1 1/2 Tbsp", calories: 45, phase: .week2Plus, isHealthier: true),
        .init(name: "Green olives (stuffed)", category: .fat, servingLabel: "10", calories: 45, phase: .week2Plus),
        .init(name: "Hemp seeds", category: .fat, servingLabel: "2 tsp", calories: 45, phase: .week2Plus, isHealthier: true),
        .init(name: "Macadamia nuts", category: .fat, servingLabel: "3", calories: 45, phase: .week2Plus),
        .init(name: "Margarine (light, 0g trans fat)", category: .fat, servingLabel: "1 Tbsp", calories: 45, phase: .week2Plus),
        .init(name: "Mayonnaise (reduced-fat, olive oil)", category: .fat, servingLabel: "1 Tbsp", calories: 45, phase: .week2Plus),
        .init(name: "Nut butters", category: .fat, servingLabel: "1 1/2 tsp", calories: 45, phase: .week2Plus),
        .init(name: "Oil (avocado, canola, coconut, corn, olive, safflower, vegetable)", category: .fat, servingLabel: "1 tsp", calories: 45, phase: .week2Plus, isHealthier: true),
        .init(name: "Olive oil", category: .fat, servingLabel: "1 tsp", calories: 45, phase: .week2Plus, isHealthier: true),
        .init(name: "Peanuts", category: .fat, servingLabel: "10", calories: 45, phase: .week2Plus),
        .init(name: "Pecans", category: .fat, servingLabel: "4 halves", calories: 45, phase: .week2Plus, isHealthier: true),
        .init(name: "Pistachios", category: .fat, servingLabel: "16", calories: 45, phase: .week2Plus, isHealthier: true),
        .init(name: "Salad dressing (reduced fat)", category: .fat, servingLabel: "2 Tbsp", calories: 45, phase: .week2Plus),
        .init(name: "Salad dressing (regular)", category: .fat, servingLabel: "1 Tbsp", calories: 45, phase: .week2Plus),
        .init(name: "Seeds (pumpkin, sunflower, sesame)", category: .fat, servingLabel: "1 Tbsp", calories: 45, phase: .week2Plus, isHealthier: true),
        .init(name: "Tahini", category: .fat, servingLabel: "2 tsp", calories: 45, phase: .week2Plus),
        .init(name: "Walnuts", category: .fat, servingLabel: "4 halves", calories: 45, phase: .week2Plus, isHealthier: true)
    ]

    // MARK: - Fruits (Week 2+, ~60 cal)

    static let fruits: [CatalogFood] = [
        .init(name: "Apple (unpeeled)", category: .fruit, servingLabel: "1 small (4 oz)", calories: 60, phase: .week2Plus),
        .init(name: "Applesauce (unsweetened)", category: .fruit, servingLabel: "1/2 cup", calories: 60, phase: .week2Plus),
        .init(name: "Apricot", category: .fruit, servingLabel: "4 whole", calories: 60, phase: .week2Plus),
        .init(name: "Banana", category: .fruit, servingLabel: "1 extra small (4 oz)", calories: 60, phase: .week2Plus),
        .init(name: "Blackberries", category: .fruit, servingLabel: "1 cup", calories: 60, phase: .week2Plus, isHighFiber: true),
        .init(name: "Blueberries", category: .fruit, servingLabel: "3/4 cup", calories: 60, phase: .week2Plus),
        .init(name: "Cantaloupe", category: .fruit, servingLabel: "1 cup diced", calories: 60, phase: .week2Plus),
        .init(name: "Cherries (bing)", category: .fruit, servingLabel: "12", calories: 60, phase: .week2Plus),
        .init(name: "Dates (deglet noor)", category: .fruit, servingLabel: "3 small", calories: 60, phase: .week2Plus),
        .init(name: "Dates (medjool)", category: .fruit, servingLabel: "1 large", calories: 60, phase: .week2Plus),
        .init(name: "Figs (fresh)", category: .fruit, servingLabel: "2 medium", calories: 60, phase: .week2Plus, isHighFiber: true),
        .init(name: "Grapefruit (fresh)", category: .fruit, servingLabel: "1/2 large", calories: 60, phase: .week2Plus),
        .init(name: "Grapes (any variety)", category: .fruit, servingLabel: "17 small", calories: 60, phase: .week2Plus),
        .init(name: "Honeydew melon", category: .fruit, servingLabel: "1 cup cubed", calories: 60, phase: .week2Plus),
        .init(name: "Kiwi", category: .fruit, servingLabel: "1", calories: 60, phase: .week2Plus),
        .init(name: "Mandarin", category: .fruit, servingLabel: "1", calories: 60, phase: .week2Plus),
        .init(name: "Mango", category: .fruit, servingLabel: "1/2 small or 1/2 cup", calories: 60, phase: .week2Plus),
        .init(name: "Nectarine", category: .fruit, servingLabel: "1 medium", calories: 60, phase: .week2Plus),
        .init(name: "Orange", category: .fruit, servingLabel: "1 medium", calories: 60, phase: .week2Plus, isHighFiber: true),
        .init(name: "Papaya", category: .fruit, servingLabel: "1 cup cubed", calories: 60, phase: .week2Plus),
        .init(name: "Peach", category: .fruit, servingLabel: "1 medium", calories: 60, phase: .week2Plus),
        .init(name: "Pear (fresh)", category: .fruit, servingLabel: "1/2 large", calories: 60, phase: .week2Plus, isHighFiber: true),
        .init(name: "Pineapple", category: .fruit, servingLabel: "1/2 cup canned or 3/4 cup fresh", calories: 60, phase: .week2Plus),
        .init(name: "Plums", category: .fruit, servingLabel: "2 small", calories: 60, phase: .week2Plus),
        .init(name: "Raspberries", category: .fruit, servingLabel: "1 cup", calories: 60, phase: .week2Plus, isHighFiber: true),
        .init(name: "Strawberries", category: .fruit, servingLabel: "1 1/4 cup whole", calories: 60, phase: .week2Plus, isHighFiber: true),
        .init(name: "Tangerine", category: .fruit, servingLabel: "1 large", calories: 60, phase: .week2Plus),
        .init(name: "Watermelon", category: .fruit, servingLabel: "1 1/4 cup diced", calories: 60, phase: .week2Plus)
    ]

    static let quickProteinPresets: [CatalogFood] = [
        .init(name: "Canadian bacon", category: .protein, servingLabel: "1 oz", calories: 35, proteinCategory: .veryLean),
        .init(name: "Egg whites", category: .protein, servingLabel: "2", calories: 35, proteinCategory: .veryLean),
        .init(name: "Very lean turkey burger", category: .protein, servingLabel: "4 oz", calories: 140, proteinCategory: .veryLean, servingsPerUnit: 4),
        .init(name: "Turkey bacon (uncured)", category: .protein, servingLabel: "1 oz strip", calories: 35, proteinCategory: .veryLean),
        .init(name: "Chocolate Premium Protein", category: .protein, servingLabel: "1 scoop", calories: 110, proteinCategory: .shake),
        .init(name: "Broiled salmon", category: .protein, servingLabel: "3 oz", calories: 165, proteinCategory: .lean, servingsPerUnit: 3)
    ]
}
