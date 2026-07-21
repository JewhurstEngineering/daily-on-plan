import Foundation
import UIKit

enum ExportService {
    static func csv(
        logs: [DailyLog],
        weights: [WeightEntry],
        settings: AppSettings
    ) -> String {
        var lines: [String] = [
            "type,date,time,name,value,extra"
        ]

        for log in logs {
            let day = log.date.formatted(.iso8601.year().month().day())
            lines.append(csvRow(["day", day, "", "proteinGoal", "\(log.proteinGoal)", ""]))
            lines.append(csvRow(["day", day, "", "proteinCalories", "\(log.totalProteinCalories)", ""]))
            lines.append(csvRow(["day", day, "", "ketosis", "\(log.ketosis)", ""]))
            lines.append(csvRow(["day", day, "", "followedPlan", "\(log.followedPlan)", ""]))
            if !log.offPlanReasons.isEmpty {
                lines.append(csvRow(["day", day, "", "offPlanReasons", log.offPlanReasons.joined(separator: "; "), ""]))
            }
            lines.append(csvRow(["day", day, "", "waterOz", "\(log.waterOz)", ""]))
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
            for item in log.checkedFatsAndVeggies {
                let parsed = ChecklistStorage.parse(item)
                lines.append(csvRow(["checklist", day, "", "fatOrVeg", parsed.name, parsed.amount]))
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

        return lines.joined(separator: "\n") + "\n"
    }

    static func writeCSVFile(
        logs: [DailyLog],
        weights: [WeightEntry],
        settings: AppSettings,
        filenameStem: String
    ) throws -> URL {
        let csv = csv(logs: logs, weights: weights, settings: settings)
        let url = try ExportFileStore.uniqueURL(stem: filenameStem, ext: "csv")
        try Data(csv.utf8).write(to: url, options: .atomic)
        return url
    }

    static func writePDFFile(
        logs: [DailyLog],
        weights: [WeightEntry],
        settings: AppSettings,
        title: String,
        filenameStem: String
    ) throws -> URL {
        let data = pdfData(logs: logs, weights: weights, settings: settings, title: title)
        let url = try ExportFileStore.uniqueURL(stem: filenameStem, ext: "pdf")
        try data.write(to: url, options: .atomic)
        return url
    }

    static func pdfData(
        logs: [DailyLog],
        weights: [WeightEntry],
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
                drawLine("Protein \(log.totalProteinCalories)/\(log.proteinGoal) kcal  |  Ketosis: \(log.ketosis ? "Y" : "N")  |  Plan: \(log.followedPlan ? "Y" : "N")")
                drawLine("Water: \(log.waterOz) / \(settings.hydrationTargetOz) oz")
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
                        drawLine(
                            "\(DateHelpers.formattedTime(protein.time)) — \(protein.name) \(protein.servingSize) · \(protein.calories) kcal · hunger \(protein.hungerBefore)→\(protein.hungerAfter)",
                            indent: 12
                        )
                    }
                }

                let veg = log.checkedFatsAndVeggies.filter { raw in
                    let name = ChecklistStorage.name(of: raw)
                    return FoodCatalog.vegetables.contains(where: { $0.name == name })
                }
                let fats = log.checkedFatsAndVeggies.filter { raw in
                    let name = ChecklistStorage.name(of: raw)
                    return FoodCatalog.fats.contains(where: { $0.name == name })
                }
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
