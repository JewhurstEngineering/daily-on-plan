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
            lines.append("day,\(day),,proteinGoal,\(log.proteinGoal),")
            lines.append("day,\(day),,proteinCalories,\(log.totalProteinCalories),")
            lines.append("day,\(day),,ketosis,\(log.ketosis),")
            lines.append("day,\(day),,followedPlan,\(log.followedPlan),")
            lines.append("day,\(day),,waterOz,\(log.waterOz),")
            lines.append("day,\(day),,notes,\"\(log.notes.replacingOccurrences(of: "\"", with: "\"\""))\",")

            for feeling in log.sortedFeelings {
                lines.append(
                    "feeling,\(day),\(DateHelpers.formattedTime(feeling.timeLogged)),\(feeling.type),,\"\(feeling.note.replacingOccurrences(of: "\"", with: "\"\""))\""
                )
            }
            for protein in log.sortedProteins {
                lines.append(
                    "protein,\(day),\(DateHelpers.formattedTime(protein.time)),\(protein.name),\(protein.calories),\(protein.servingSize);hunger \(protein.hungerBefore)->\(protein.hungerAfter)"
                )
            }
            for workout in log.sortedWorkouts {
                lines.append(
                    "workout,\(day),\(DateHelpers.formattedTime(workout.timeLogged)),\(workout.activityName),\(workout.durationMinutes),"
                )
            }
            for item in log.checkedFatsAndVeggies {
                lines.append("checklist,\(day),,fatOrVeg,\(item),")
            }
            for item in log.checkedFruits {
                lines.append("checklist,\(day),,fruit,\(item),")
            }
            for item in log.checkedMiscItems {
                lines.append("checklist,\(day),,misc,\(item),")
            }
            for item in log.completedSupplements {
                lines.append("supplement,\(day),,,\(item),")
            }
        }

        for weight in weights {
            let day = weight.date.formatted(.iso8601.year().month().day())
            var bmiText = ""
            if let bmi = BMICalculator.bmi(weightLbs: weight.weightLbs, heightInches: settings.heightInches) {
                bmiText = String(format: "%.1f", bmi)
            }
            lines.append("weight,\(day),\(DateHelpers.formattedTime(weight.timeLogged)),bodyWeight,\(weight.weightLbs),bmi=\(bmiText)")
        }

        return lines.joined(separator: "\n")
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
            y += 8

            for log in logs {
                ensureSpace(80)
                drawLine(DateHelpers.formattedDay(log.date), font: .boldSystemFont(ofSize: 14))
                drawLine("Protein \(log.totalProteinCalories)/\(log.proteinGoal) kcal  |  Ketosis: \(log.ketosis ? "Y" : "N")  |  Plan: \(log.followedPlan ? "Y" : "N")")
                drawLine("Water: \(log.waterOz) oz")
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

                if !log.sortedWorkouts.isEmpty {
                    drawLine("Workouts", font: .boldSystemFont(ofSize: 12))
                    for workout in log.sortedWorkouts {
                        drawLine("\(workout.activityName) — \(workout.durationMinutes) min", indent: 12)
                    }
                }

                y += 10
            }
        }
    }
}
