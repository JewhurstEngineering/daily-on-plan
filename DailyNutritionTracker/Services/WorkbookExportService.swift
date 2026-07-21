import Foundation

/// Builds Excel-compatible SpreadsheetML workbooks (one worksheet per day).
enum WorkbookExportService {
    static func spreadsheetML(
        logs: [DailyLog],
        weights: [WeightEntry],
        settings: AppSettings
    ) -> String {
        var body = """
        <?xml version="1.0" encoding="UTF-8"?>
        <?mso-application progid="Excel.Sheet"?>
        <Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
         xmlns:o="urn:schemas-microsoft-com:office:office"
         xmlns:x="urn:schemas-microsoft-com:office:excel"
         xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"
         xmlns:html="http://www.w3.org/TR/REC-html40">
        <Styles>
          <Style ss:ID="Default" ss:Name="Normal"><Font ss:FontName="Calibri" ss:Size="11"/></Style>
          <Style ss:ID="Header"><Font ss:FontName="Calibri" ss:Size="14" ss:Bold="1"/></Style>
          <Style ss:ID="Section"><Font ss:FontName="Calibri" ss:Size="12" ss:Bold="1"/></Style>
          <Style ss:ID="ColHeader"><Font ss:Bold="1"/><Interior ss:Color="#D9EAD3" ss:Pattern="Solid"/></Style>
        </Styles>
        """

        if logs.isEmpty {
            body += worksheet(name: "Empty", content: row(["No daily logs in this range"]))
        } else {
            for log in logs {
                let weight = weights.first(where: { DateHelpers.isSameDay($0.date, log.date) })
                let sheetName = sheetTitle(for: log.date)
                body += worksheet(name: sheetName, content: daySheet(log: log, weight: weight, settings: settings))
            }
        }

        body += "</Workbook>"
        return body
    }

    static func writeTemporaryFile(
        logs: [DailyLog],
        weights: [WeightEntry],
        settings: AppSettings,
        filenameStem: String
    ) throws -> URL {
        let xml = spreadsheetML(logs: logs, weights: weights, settings: settings)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(filenameStem).xls")
        guard let data = xml.data(using: .utf8) else {
            throw NSError(domain: "WorkbookExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode workbook"])
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Day layout

    private static func daySheet(log: DailyLog, weight: WeightEntry?, settings: AppSettings) -> String {
        var xml = ""
        xml += row(["\(AppIdentity.displayName) Log"], style: "Header")
        xml += row([])
        xml += row(["Date", DateHelpers.formattedDay(log.date)])
        xml += row(["Protein Goal (kcal)", "\(log.proteinGoal)"])
        xml += row(["Total Protein Calories", "\(log.totalProteinCalories)"])
        xml += row(["Ketosis", log.ketosis ? "Y" : "N"])
        xml += row(["Followed Plan", log.followedPlan ? "Y" : "N"])
        xml += row(["Notes", log.notes])
        xml += row([])

        if let weight {
            var bmi = ""
            if let value = BMICalculator.bmi(weightLbs: weight.weightLbs, heightInches: settings.heightInches) {
                bmi = String(format: "%.1f (%@)", value, BMICalculator.category(for: value))
            }
            xml += row(["Weight & BMI"], style: "Section")
            xml += row(["Weight (lb)", String(format: "%.1f", weight.weightLbs)])
            xml += row(["BMI", bmi])
            xml += row([])
        }

        xml += row(["Feelings & Cravings"], style: "Section")
        xml += row(["Type", "Time", "Note"], style: "ColHeader")
        if log.sortedFeelings.isEmpty {
            xml += row(["—", "", ""])
        } else {
            for feeling in log.sortedFeelings {
                xml += row([
                    feeling.type,
                    DateHelpers.formattedTime(feeling.timeLogged),
                    feeling.note
                ])
            }
        }
        xml += row([])

        xml += row(["Protein Source"], style: "Section")
        xml += row(
            ["Protein Source", "Time", "Serving Size", "Protein Calories", "Hunger Before", "Hunger After"],
            style: "ColHeader"
        )
        if log.sortedProteins.isEmpty {
            xml += row(["—", "", "", "", "", ""])
        } else {
            for protein in log.sortedProteins {
                xml += row([
                    protein.name,
                    DateHelpers.formattedTime(protein.time),
                    protein.servingSize,
                    "\(protein.calories)",
                    "\(protein.hungerBefore)",
                    "\(protein.hungerAfter)"
                ])
            }
        }
        xml += row([])

        xml += row(["Fats, Fruits & Vegetables"], style: "Section")
        xml += row(["Category", "Item", "Amount"], style: "ColHeader")
        let veg = log.checkedFatsAndVeggies.filter { raw in
            let name = ChecklistStorage.name(of: raw)
            return FoodCatalog.vegetables.contains(where: { $0.name == name })
        }
        let fats = log.checkedFatsAndVeggies.filter { raw in
            let name = ChecklistStorage.name(of: raw)
            return FoodCatalog.fats.contains(where: { $0.name == name })
        }
        if veg.isEmpty && fats.isEmpty && log.checkedFruits.isEmpty {
            xml += row(["—", "", ""])
        } else {
            for raw in veg {
                let parsed = ChecklistStorage.parse(raw)
                xml += row(["Vegetable", parsed.name, parsed.amount])
            }
            for raw in fats {
                let parsed = ChecklistStorage.parse(raw)
                xml += row(["Fat", parsed.name, parsed.amount])
            }
            for raw in log.checkedFruits {
                let parsed = ChecklistStorage.parse(raw)
                xml += row(["Fruit", parsed.name, parsed.amount])
            }
        }
        xml += row([])

        xml += row(["Miscellaneous Items"], style: "Section")
        xml += row(["Item", "Amount"], style: "ColHeader")
        if log.checkedMiscItems.isEmpty {
            xml += row(["—", ""])
        } else {
            for raw in log.checkedMiscItems {
                let parsed = ChecklistStorage.parse(raw)
                xml += row([parsed.name, parsed.amount])
            }
        }
        xml += row([])

        xml += row(["Activity / Workout"], style: "Section")
        xml += row(["Activity", "Duration (minutes)", "Time"], style: "ColHeader")
        if log.sortedWorkouts.isEmpty {
            xml += row(["—", "", ""])
        } else {
            for workout in log.sortedWorkouts {
                xml += row([
                    workout.activityName,
                    "\(workout.durationMinutes)",
                    DateHelpers.formattedTime(workout.timeLogged)
                ])
            }
        }
        xml += row([])

        xml += row(["Supplements"], style: "Section")
        xml += row(["Supplement", "Completed", "Planned"], style: "ColHeader")
        let defs = settings.supplements.filter(\.isEnabled)
        if defs.isEmpty {
            xml += row(["—", "", ""])
        } else {
            for def in defs {
                let done = (0..<def.dosesPerDay).filter { log.completedSupplements.contains(def.doseKey($0)) }.count
                xml += row([def.name, "\(done)", "\(def.dosesPerDay)"])
            }
        }
        xml += row([])

        xml += row(["Hydration"], style: "Section")
        xml += row(["Total oz", "\(log.waterOz)"])
        xml += row(["Target oz", "\(settings.hydrationTargetOz)"])
        let drinks = log.waterDrinks.map { formatOz($0) }.joined(separator: ", ")
        xml += row(["Drinks", drinks.isEmpty ? "—" : drinks])

        return xml
    }

    // MARK: - XML helpers

    private static func worksheet(name: String, content: String) -> String {
        """
        <Worksheet ss:Name="\(escapeAttr(sanitizeSheetName(name)))">
        <Table>
        \(content)
        </Table>
        </Worksheet>
        """
    }

    private static func row(_ values: [String], style: String? = nil) -> String {
        let cells = values.map { value -> String in
            let styleAttr = style.map { " ss:StyleID=\"\($0)\"" } ?? ""
            return "<Cell\(styleAttr)><Data ss:Type=\"String\">\(escapeXML(value))</Data></Cell>"
        }.joined()
        return "<Row>\(cells)</Row>\n"
    }

    private static func sheetTitle(for date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    private static func sanitizeSheetName(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "[", with: "(")
            .replacingOccurrences(of: "]", with: ")")
        return String(cleaned.prefix(31))
    }

    private static func escapeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func escapeAttr(_ value: String) -> String { escapeXML(value) }

    private static func formatOz(_ oz: Double) -> String {
        if abs(oz.rounded() - oz) < 0.05 { return "\(Int(oz.rounded()))oz" }
        return String(format: "%.1foz", oz)
    }
}
