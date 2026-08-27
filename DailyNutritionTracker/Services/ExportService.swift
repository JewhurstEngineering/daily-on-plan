import Foundation
import UIKit
import OnPlanCore

enum ExportService {
    static func csv(
        logs: [DailyLog],
        weights: [WeightEntry],
        bodyComps: [BodyCompositionReading] = [],
        settings: AppSettings
    ) -> String {
        var lines: [String] = [
            "type,date,time,name,value,extra"
        ]

        for log in logs {
            let day = log.date.formatted(.iso8601.year().month().day())
            lines.append(csvRow(["day", day, "", "proteinGoal", "\(log.proteinGoal)", ""]))
            lines.append(csvRow(["day", day, "", "proteinCalories", "\(log.totalProteinCalories)", ""]))
            if let dayMacros = log.dayMacros {
                lines.append(csvRow([
                    "day",
                    day,
                    "",
                    "macros",
                    Macros.gramsText(dayMacros.protein) ?? "",
                    dayMacros.fullSummary
                ]))
            }
            lines.append(csvRow(["day", day, "", "ketosis", "\(log.ketosis)", ""]))
            if let ketone = log.ketoneMmol {
                lines.append(csvRow(["day", day, "", "ketoneMmol", String(format: "%.1f", ketone), ""]))
            }
            if let start = log.eatingWindowStart {
                lines.append(csvRow(["day", day, "", "eatingWindowStart", DateHelpers.formattedTime(start), ""]))
            }
            if let end = log.eatingWindowEnd {
                lines.append(csvRow(["day", day, "", "eatingWindowEnd", DateHelpers.formattedTime(end), ""]))
            }
            if log.offPlanExtraKcal > 0 || log.offPlanExtraCarbGrams > 0 || log.offPlanExtraFatGrams > 0 {
                lines.append(csvRow([
                    "day",
                    day,
                    "",
                    "offPlanExtras",
                    "\(log.offPlanExtraKcal)",
                    "carb \(log.offPlanExtraCarbGrams)g fat \(log.offPlanExtraFatGrams)g"
                ]))
            }
            lines.append(csvRow(["day", day, "", "followedPlan", "\(log.followedPlan)", ""]))
            if !log.offPlanReasons.isEmpty {
                lines.append(csvRow(["day", day, "", "offPlanReasons", log.offPlanReasons.joined(separator: "; "), ""]))
            }
            lines.append(csvRow(["day", day, "", "waterOz", "\(log.totalHydrationOz(settings: settings))", ""]))
            lines.append(csvRow(["day", day, "", "waterSlotsOz", "\(log.slotWaterOz)", ""]))
            lines.append(csvRow(["day", day, "", "proteinHydrationOz", "\(log.proteinHydrationOz(settings: settings))", ""]))
            lines.append(csvRow(["day", day, "", "electrolyteDrinks", "\(log.electrolyteDrinkCount)", ""]))
            for (index, slot) in log.waterSlots.enumerated() {
                guard let slot else { continue }
                lines.append(csvRow([
                    "water",
                    day,
                    "",
                    slot.displayLabel.lowercased(),
                    String(format: "%.1f", slot.oz),
                    "slot \(index + 1)"
                ]))
            }
            lines.append(csvRow(["day", day, "", "notes", log.notes, ""]))
            lines.append(csvRow(["day", day, "", "cigarettes", "\(log.cigarettesSmoked)", ""]))
            for event in log.cigaretteEvents {
                lines.append(csvRow([
                    "cigarette",
                    day,
                    DateHelpers.formattedTime(event.timeLogged),
                    event.label,
                    "\(event.count)",
                    ""
                ]))
            }
            for urge in log.cigaretteUrges {
                lines.append(csvRow([
                    "urge",
                    day,
                    DateHelpers.formattedTime(urge.timeLogged),
                    "cigarette",
                    "",
                    urge.note
                ]))
            }

            lines.append(csvRow(["day", day, "", "drinks", "\(log.drinksLogged)", ""]))
            for event in log.drinkEvents {
                lines.append(csvRow([
                    "drink",
                    day,
                    DateHelpers.formattedTime(event.timeLogged),
                    event.label,
                    "\(event.count)",
                    ""
                ]))
            }
            for urge in log.drinkUrges {
                lines.append(csvRow([
                    "urge",
                    day,
                    DateHelpers.formattedTime(urge.timeLogged),
                    "drink",
                    "",
                    urge.note
                ]))
            }

            lines.append(csvRow(["day", day, "", "urineCount", "\(log.urineCount)", ""]))
            lines.append(csvRow(["day", day, "", "stoolCount", "\(log.stoolCount)", ""]))
            for event in log.bathroomEvents {
                lines.append(csvRow([
                    "bathroom",
                    day,
                    DateHelpers.formattedTime(event.timeLogged),
                    event.kind.rawValue,
                    "",
                    event.note
                ]))
            }

            for feeling in log.sortedFeelings {
                lines.append(csvRow([
                    "feeling",
                    day,
                    DateHelpers.formattedTime(feeling.timeLogged),
                    feeling.type,
                    "",
                    feeling.note
                ]))
            }
            for protein in log.sortedProteins {
                lines.append(csvRow([
                    "protein",
                    day,
                    DateHelpers.formattedTime(protein.time),
                    protein.name,
                    "\(protein.calories)",
                    "\(protein.servingSize);hunger \(protein.hungerBefore)->\(protein.hungerAfter)"
                ]))
                if let macros = protein.macros {
                    lines.append(csvRow([
                        "proteinMacros",
                        day,
                        DateHelpers.formattedTime(protein.time),
                        protein.name,
                        Macros.gramsText(macros.protein) ?? "",
                        macros.fullSummary
                    ]))
                }
                if protein.hydrationOz > 0 {
                    lines.append(csvRow([
                        "proteinHydration",
                        day,
                        DateHelpers.formattedTime(protein.time),
                        protein.name,
                        String(format: "%.1f", protein.hydrationOz),
                        "oz"
                    ]))
                }
            }
            for workout in log.sortedWorkouts {
                lines.append(csvRow([
                    "workout",
                    day,
                    DateHelpers.formattedTime(workout.timeLogged),
                    workout.activityName,
                    "\(workout.durationMinutes)",
                    ""
                ]))
            }
            for item in ChecklistStorage.vegetables(in: log) {
                let parsed = ChecklistStorage.parse(item)
                lines.append(csvRow(["checklist", day, "", "vegetable", parsed.name, parsed.amount]))
            }
            for item in ChecklistStorage.fats(in: log) {
                let parsed = ChecklistStorage.parse(item)
                lines.append(csvRow(["checklist", day, "", "fat", parsed.name, parsed.amount]))
            }
            for item in log.checkedFruits {
                let parsed = ChecklistStorage.parse(item)
                lines.append(csvRow(["checklist", day, "", "fruit", parsed.name, parsed.amount]))
            }
            for item in log.checkedMiscItems {
                let parsed = ChecklistStorage.parse(item)
                lines.append(csvRow(["checklist", day, "", "misc", parsed.name, parsed.amount]))
            }
            for item in log.completedSupplements {
                lines.append(csvRow(["supplement", day, "", item, "", ""]))
            }
        }

        for weight in weights {
            let day = weight.date.formatted(.iso8601.year().month().day())
            var bmiText = ""
            if let bmi = BMICalculator.bmi(weightLbs: weight.weightLbs, heightInches: settings.heightInches) {
                bmiText = String(format: "%.1f", bmi)
            }
            lines.append(csvRow([
                "weight",
                day,
                DateHelpers.formattedTime(weight.timeLogged),
                "bodyWeight",
                String(format: "%.1f", weight.weightLbs),
                "bmi=\(bmiText)"
            ]))
        }

        for reading in bodyComps {
            let day = reading.date.formatted(.iso8601.year().month().day())
            lines.append(csvRow([
                "bodyComp",
                day,
                "",
                "summary",
                reading.summaryLine,
                reading.notes
            ]))
            lines.append(csvRow(["bodyComp", day, "", "proteinGoal", reading.proteinGoalText, ""]))
            lines.append(csvRow(["bodyComp", day, "", "waterTarget", reading.waterTargetText, ""]))
            lines.append(csvRow(["bodyComp", day, "", "bodyType", reading.bodyType.rawValue, ""]))
            lines.append(csvRow(["bodyComp", day, "", "gender", reading.gender.rawValue, ""]))
            lines.append(csvRow(["bodyComp", day, "", "age", "\(reading.age)", ""]))
            lines.append(csvRow(["bodyComp", day, "", "heightInches", String(format: "%.1f", reading.heightInches), ""]))
            lines.append(csvRow(["bodyComp", day, "", "weightLbs", String(format: "%.1f", reading.weightLbs), ""]))
            lines.append(csvRow(["bodyComp", day, "", "bmi", String(format: "%.1f", reading.bmi), ""]))
            lines.append(csvRow(["bodyComp", day, "", "bmrKcal", "\(reading.bmrKcal)", ""]))
            lines.append(csvRow(["bodyComp", day, "", "impedance", String(format: "%.1f", reading.impedance), ""]))
            lines.append(csvRow(["bodyComp", day, "", "fatPercent", String(format: "%.1f", reading.fatPercent), ""]))
            lines.append(csvRow(["bodyComp", day, "", "fatMassLbs", String(format: "%.1f", reading.fatMassLbs), ""]))
            lines.append(csvRow(["bodyComp", day, "", "ffmLbs", String(format: "%.1f", reading.ffmLbs), ""]))
            lines.append(csvRow(["bodyComp", day, "", "tbwLbs", String(format: "%.1f", reading.tbwLbs), ""]))
            lines.append(csvRow([
                "bodyComp",
                day,
                "",
                "desirableFatPercent",
                String(format: "%.1f-%.1f", reading.desirableFatPercentLow, reading.desirableFatPercentHigh),
                ""
            ]))
            lines.append(csvRow([
                "bodyComp",
                day,
                "",
                "desirableFatMassLbs",
                String(format: "%.1f-%.1f", reading.desirableFatMassLow, reading.desirableFatMassHigh),
                ""
            ]))
        }

        return lines.joined(separator: "\n") + "\n"
    }

    static func writeCSVFile(
        logs: [DailyLog],
        weights: [WeightEntry],
        bodyComps: [BodyCompositionReading] = [],
        settings: AppSettings,
        filenameStem: String
    ) throws -> URL {
        let csv = csv(logs: logs, weights: weights, bodyComps: bodyComps, settings: settings)
        let url = try ExportFileStore.uniqueURL(stem: filenameStem, ext: "csv")
        try Data(csv.utf8).write(to: url, options: .atomic)
        return url
    }

    static func writePDFFile(
        logs: [DailyLog],
        weights: [WeightEntry],
        bodyComps: [BodyCompositionReading] = [],
        settings: AppSettings,
        title: String,
        filenameStem: String
    ) throws -> URL {
        let data = pdfData(logs: logs, weights: weights, bodyComps: bodyComps, settings: settings, title: title)
        let url = try ExportFileStore.uniqueURL(stem: filenameStem, ext: "pdf")
        try data.write(to: url, options: .atomic)
        return url
    }

    static func pdfData(
        logs: [DailyLog],
        weights: [WeightEntry],
        bodyComps: [BodyCompositionReading] = [],
        settings: AppSettings,
        title: String
    ) -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 36
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        return renderer.pdfData { context in
            var y: CGFloat = 0

            func newPage() {
                context.beginPage()
                y = margin
                let header = title as NSString
                header.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 18)
                ])
                y += 28
            }

            func ensureSpace(_ needed: CGFloat) {
                if y + needed > pageHeight - margin {
                    newPage()
                }
            }

            func drawLine(_ text: String, font: UIFont = .systemFont(ofSize: 11), indent: CGFloat = 0) {
                ensureSpace(16)
                (text as NSString).draw(
                    at: CGPoint(x: margin + indent, y: y),
                    withAttributes: [.font: font]
                )
                y += 15
            }

            newPage()
            drawLine("Generated \(Date().formatted(date: .abbreviated, time: .shortened))", font: .systemFont(ofSize: 10))
            if logs.isEmpty {
                drawLine("No daily logs in this range.")
            }
            y += 8

            for log in logs {
                ensureSpace(80)
                drawLine(DateHelpers.formattedDay(log.date), font: .boldSystemFont(ofSize: 14))
                drawLine("Protein \(log.totalProteinCalories)/\(log.proteinGoal) kcal  |  Ketosis: \(log.ketosis ? "Y" : "N")\(log.ketoneMmol.map { String(format: " (%.1f mmol/L)", $0) } ?? "")  |  Plan: \(log.followedPlan ? "Y" : "N")")
                drawLine("Water: \(log.totalHydrationOz(settings: settings)) / \(settings.hydrationTargetOz) oz")
                if log.proteinHydrationOz(settings: settings) > 0 {
                    drawLine("Incl. protein drinks: \(log.proteinHydrationOz(settings: settings)) oz", indent: 12)
                }
                if log.hasElectrolyteDrink {
                    drawLine("Electrolyte drinks: \(log.electrolyteDrinkCount)", indent: 12)
                }
                if settings.smokingMode.showsSection || log.cigarettesSmoked > 0 || !log.cigaretteUrges.isEmpty {
                    drawLine("Cigarettes: \(log.cigarettesSmoked) (\(CigarettePackMath.packsLabel(cigarettes: log.cigarettesSmoked)))\(settings.effectiveDailyCigaretteLimit.map { " / max \($0)" } ?? "")")
                    for event in log.cigaretteEvents {
                        drawLine("\(DateHelpers.formattedTime(event.timeLogged)) — \(event.label)", indent: 12)
                    }
                    if !log.cigaretteUrges.isEmpty {
                        drawLine("Urges: \(log.cigaretteUrges.count)", indent: 12)
                    }
                }
                if settings.drinkingMode.showsSection || log.drinksLogged > 0 || !log.drinkUrges.isEmpty {
                    drawLine("Drinks: \(log.drinksLogged)\(settings.effectiveDailyDrinkLimit.map { " / max \($0)" } ?? "")")
                    for event in log.drinkEvents {
                        drawLine("\(DateHelpers.formattedTime(event.timeLogged)) — \(event.label)", indent: 12)
                    }
                    if !log.drinkUrges.isEmpty {
                        drawLine("Urges: \(log.drinkUrges.count)", indent: 12)
                    }
                }
                if settings.showBathroomSection || !log.bathroomEvents.isEmpty {
                    drawLine("Bathroom: urination \(log.urineCount) · bowel \(log.stoolCount)")
                    for event in log.bathroomEvents {
                        var line = "\(DateHelpers.formattedTime(event.timeLogged)) — \(event.kind.title)"
                        if !event.note.isEmpty { line += " (\(event.note))" }
                        drawLine(line, indent: 12)
                    }
                }
                if !log.offPlanReasons.isEmpty {
                    drawLine("Off-plan: \(log.offPlanReasons.joined(separator: ", "))")
                }
                if !log.notes.isEmpty {
                    drawLine("Notes: \(log.notes)")
                }

                if let weight = weights.first(where: { DateHelpers.isSameDay($0.date, log.date) }) {
                    var line = String(format: "Weight: %.1f lb", weight.weightLbs)
                    if let bmi = BMICalculator.bmi(weightLbs: weight.weightLbs, heightInches: settings.heightInches) {
                        line += String(format: "  |  BMI: %.1f (%@)", bmi, BMICalculator.category(for: bmi))
                    }
                    drawLine(line)
                }

                if !log.sortedFeelings.isEmpty {
                    drawLine("Feelings & Cravings", font: .boldSystemFont(ofSize: 12))
                    for feeling in log.sortedFeelings {
                        var text = "\(DateHelpers.formattedTime(feeling.timeLogged)) — \(feeling.type)"
                        if !feeling.note.isEmpty { text += " (\(feeling.note))" }
                        drawLine(text, indent: 12)
                    }
                }

                if !log.sortedProteins.isEmpty {
                    drawLine("Protein Log", font: .boldSystemFont(ofSize: 12))
                    for protein in log.sortedProteins {
                        var line = "\(DateHelpers.formattedTime(protein.time)) — \(protein.name) \(protein.servingSize) · \(protein.calories) kcal · hunger \(protein.hungerBefore)→\(protein.hungerAfter)"
                        if let macros = protein.macros, !macros.compactSummary.isEmpty {
                            line += " · \(macros.compactSummary)"
                        }
                        if protein.hydrationOz > 0 {
                            line += String(format: " · +%.0f oz hydration", protein.hydrationOz)
                        }
                        drawLine(line, indent: 12)
                    }
                }

                let veg = ChecklistStorage.vegetables(in: log)
                let fats = ChecklistStorage.fats(in: log)
                if !veg.isEmpty || !fats.isEmpty || !log.checkedFruits.isEmpty {
                    drawLine("Fats, Fruits & Vegetables", font: .boldSystemFont(ofSize: 12))
                    for raw in veg {
                        let parsed = ChecklistStorage.parse(raw)
                        drawLine("Veg — \(parsed.name)\(parsed.amount.isEmpty ? "" : " (\(parsed.amount))")", indent: 12)
                    }
                    for raw in fats {
                        let parsed = ChecklistStorage.parse(raw)
                        drawLine("Fat — \(parsed.name)\(parsed.amount.isEmpty ? "" : " (\(parsed.amount))")", indent: 12)
                    }
                    for raw in log.checkedFruits {
                        let parsed = ChecklistStorage.parse(raw)
                        drawLine("Fruit — \(parsed.name)\(parsed.amount.isEmpty ? "" : " (\(parsed.amount))")", indent: 12)
                    }
                }

                if !log.checkedMiscItems.isEmpty {
                    drawLine("Miscellaneous", font: .boldSystemFont(ofSize: 12))
                    for raw in log.checkedMiscItems {
                        let parsed = ChecklistStorage.parse(raw)
                        drawLine("\(parsed.name)\(parsed.amount.isEmpty ? "" : " (\(parsed.amount))")", indent: 12)
                    }
                }

                if !log.sortedWorkouts.isEmpty {
                    drawLine("Workouts", font: .boldSystemFont(ofSize: 12))
                    for workout in log.sortedWorkouts {
                        drawLine("\(workout.activityName) — \(workout.durationMinutes) min", indent: 12)
                    }
                }

                let defs = settings.supplements.filter(\.isEnabled)
                if !defs.isEmpty {
                    drawLine("Supplements", font: .boldSystemFont(ofSize: 12))
                    for def in defs {
                        let done = (0..<def.dosesPerDay).filter { log.completedSupplements.contains(def.doseKey($0)) }.count
                        drawLine("\(def.name): \(done)/\(def.dosesPerDay)", indent: 12)
                    }
                }

                y += 10
            }

            if !bodyComps.isEmpty {
                drawLine("Body composition", font: .boldSystemFont(ofSize: 14))
                for reading in bodyComps.sorted(by: { $0.date < $1.date }) {
                    drawLine(DateHelpers.formattedDay(reading.date), font: .boldSystemFont(ofSize: 12))
                    drawLine(reading.summaryLine, indent: 12)
                    if !reading.proteinGoalText.isEmpty {
                        drawLine("Protein goal: \(reading.proteinGoalText)", indent: 12)
                    }
                    if !reading.waterTargetText.isEmpty {
                        drawLine("Water target: \(reading.waterTargetText)", indent: 12)
                    }
                    drawLine("Body type: \(reading.bodyType.rawValue) · \(reading.gender.rawValue) · age \(reading.age)", indent: 12)
                    drawLine(String(format: "Impedance %.1f · Fat %.1f%% · FFM %.1f lb · TBW %.1f lb",
                                    reading.impedance, reading.fatPercent, reading.ffmLbs, reading.tbwLbs), indent: 12)
                    if !reading.notes.isEmpty {
                        drawLine("Notes: \(reading.notes)", indent: 12)
                    }
                }
            }
        }
    }

    private static func csvRow(_ fields: [String]) -> String {
        fields.map(escapeCSV).joined(separator: ",")
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
