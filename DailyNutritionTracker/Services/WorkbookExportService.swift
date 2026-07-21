import Foundation

/// Builds real Office Open XML (`.xlsx`) workbooks — one worksheet per day.
enum WorkbookExportService {
    static func writeTemporaryFile(
        logs: [DailyLog],
        weights: [WeightEntry],
        settings: AppSettings,
        filenameStem: String
    ) throws -> URL {
        let url = try ExportFileStore.uniqueURL(stem: filenameStem, ext: "xlsx")
        let package = try buildPackage(logs: logs, weights: weights, settings: settings)
        try ZipStoreWriter.write(entries: package, to: url)
        return url
    }

    // MARK: - Package

    private static func buildPackage(
        logs: [DailyLog],
        weights: [WeightEntry],
        settings: AppSettings
    ) throws -> [(path: String, data: Data)] {
        let sheets: [(name: String, rows: [[String]])]
        if logs.isEmpty {
            sheets = [(name: "Empty", rows: [["No daily logs in this range"]])]
        } else {
            sheets = logs.map { log in
                let weight = weights.first(where: { DateHelpers.isSameDay($0.date, log.date) })
                return (
                    name: sheetTitle(for: log.date),
                    rows: dayRows(log: log, weight: weight, settings: settings)
                )
            }
        }

        var entries: [(path: String, data: Data)] = []
        entries.append(("[Content_Types].xml", data(contentTypesXML(sheetCount: sheets.count))))
        entries.append(("_rels/.rels", data(rootRelsXML)))
        entries.append(("xl/workbook.xml", data(workbookXML(sheets: sheets.map(\.name)))))
        entries.append(("xl/_rels/workbook.xml.rels", data(workbookRelsXML(sheetCount: sheets.count))))
        entries.append(("xl/styles.xml", data(stylesXML)))

        for (index, sheet) in sheets.enumerated() {
            let path = "xl/worksheets/sheet\(index + 1).xml"
            entries.append((path, data(worksheetXML(rows: sheet.rows))))
        }
        return entries
    }

    // MARK: - Day layout (row arrays)

    private static func dayRows(log: DailyLog, weight: WeightEntry?, settings: AppSettings) -> [[String]] {
        var rows: [[String]] = []
        rows.append(["\(AppIdentity.displayName) Log"])
        rows.append([])
        rows.append(["Date", DateHelpers.formattedDay(log.date)])
        rows.append(["Protein Goal (kcal)", "\(log.proteinGoal)"])
        rows.append(["Total Protein Calories", "\(log.totalProteinCalories)"])
        rows.append(["Ketosis", log.ketosis ? "Y" : "N"])
        rows.append(["Followed Plan", log.followedPlan ? "Y" : "N"])
        if !log.offPlanReasons.isEmpty {
            rows.append(["Off-plan reasons", log.offPlanReasons.joined(separator: ", ")])
        }
        rows.append(["Notes", log.notes])
        rows.append([])

        if let weight {
            var bmi = ""
            if let value = BMICalculator.bmi(weightLbs: weight.weightLbs, heightInches: settings.heightInches) {
                bmi = String(format: "%.1f (%@)", value, BMICalculator.category(for: value))
            }
            rows.append(["Weight & BMI"])
            rows.append(["Weight (lb)", String(format: "%.1f", weight.weightLbs)])
            if let goal = settings.goalWeightLbs {
                rows.append(["Goal (lb)", String(format: "%.1f", goal)])
                rows.append(["To go (lb)", String(format: "%.1f", weight.weightLbs - goal)])
            }
            rows.append(["BMI", bmi])
            rows.append([])
        }

        rows.append(["Feelings & Cravings"])
        rows.append(["Type", "Time", "Note"])
        if log.sortedFeelings.isEmpty {
            rows.append(["—", "", ""])
        } else {
            for feeling in log.sortedFeelings {
                rows.append([
                    feeling.type,
                    DateHelpers.formattedTime(feeling.timeLogged),
                    feeling.note
                ])
            }
        }
        rows.append([])

        rows.append(["Protein Source"])
        rows.append(["Protein Source", "Time", "Serving Size", "Protein Calories", "Hunger Before", "Hunger After"])
        if log.sortedProteins.isEmpty {
            rows.append(["—", "", "", "", "", ""])
        } else {
            for protein in log.sortedProteins {
                rows.append([
                    protein.name,
                    DateHelpers.formattedTime(protein.time),
                    protein.servingSize,
                    "\(protein.calories)",
                    "\(protein.hungerBefore)",
                    "\(protein.hungerAfter)"
                ])
            }
        }
        rows.append([])

        rows.append(["Fats, Fruits & Vegetables"])
        rows.append(["Category", "Item", "Amount"])
        let veg = log.checkedFatsAndVeggies.filter { raw in
            let name = ChecklistStorage.name(of: raw)
            return FoodCatalog.vegetables.contains(where: { $0.name == name })
        }
        let fats = log.checkedFatsAndVeggies.filter { raw in
            let name = ChecklistStorage.name(of: raw)
            return FoodCatalog.fats.contains(where: { $0.name == name })
        }
        if veg.isEmpty && fats.isEmpty && log.checkedFruits.isEmpty {
            rows.append(["—", "", ""])
        } else {
            for raw in veg {
                let parsed = ChecklistStorage.parse(raw)
                rows.append(["Vegetable", parsed.name, parsed.amount])
            }
            for raw in fats {
                let parsed = ChecklistStorage.parse(raw)
                rows.append(["Fat", parsed.name, parsed.amount])
            }
            for raw in log.checkedFruits {
                let parsed = ChecklistStorage.parse(raw)
                rows.append(["Fruit", parsed.name, parsed.amount])
            }
        }
        rows.append([])

        rows.append(["Miscellaneous Items"])
        rows.append(["Item", "Amount"])
        if log.checkedMiscItems.isEmpty {
            rows.append(["—", ""])
        } else {
            for raw in log.checkedMiscItems {
                let parsed = ChecklistStorage.parse(raw)
                rows.append([parsed.name, parsed.amount])
            }
        }
        rows.append([])

        rows.append(["Activity / Workout"])
        rows.append(["Activity", "Duration (minutes)", "Time"])
        if log.sortedWorkouts.isEmpty {
            rows.append(["—", "", ""])
        } else {
            for workout in log.sortedWorkouts {
                rows.append([
                    workout.activityName,
                    "\(workout.durationMinutes)",
                    DateHelpers.formattedTime(workout.timeLogged)
                ])
            }
        }
        rows.append([])

        rows.append(["Supplements"])
        rows.append(["Supplement", "Completed", "Planned"])
        let defs = settings.supplements.filter(\.isEnabled)
        if defs.isEmpty {
            rows.append(["—", "", ""])
        } else {
            for def in defs {
                let done = (0..<def.dosesPerDay).filter { log.completedSupplements.contains(def.doseKey($0)) }.count
                rows.append([def.name, "\(done)", "\(def.dosesPerDay)"])
            }
        }
        rows.append([])

        rows.append(["Hydration"])
        rows.append(["Total oz", "\(log.waterOz)"])
        rows.append(["Target oz", "\(settings.hydrationTargetOz)"])
        let drinks = log.waterDrinks.map { formatOz($0) }.joined(separator: ", ")
        rows.append(["Drinks", drinks.isEmpty ? "—" : drinks])
        rows.append([])

        if settings.smokingMode.showsSection || log.cigarettesSmoked > 0 || !log.cigaretteUrges.isEmpty {
            rows.append(["Smoking"])
            rows.append(["Cigarettes", "\(log.cigarettesSmoked)"])
            rows.append(["Packs", CigarettePackMath.packsLabel(cigarettes: log.cigarettesSmoked)])
            if let limit = settings.effectiveDailyCigaretteLimit {
                rows.append(["Daily max", "\(limit) cigs"])
            }
            if settings.smokingMode == .quit, let quit = settings.quitDate {
                rows.append(["Quit date", DateHelpers.formattedDay(quit)])
            }
            rows.append(["Entry", "Time", "Amount"])
            if log.cigaretteEvents.isEmpty {
                rows.append(["—", "", ""])
            } else {
                for event in log.cigaretteEvents {
                    rows.append(["Smoke", DateHelpers.formattedTime(event.timeLogged), event.label])
                }
            }
            rows.append(["Urge", "Time", "Note"])
            if log.cigaretteUrges.isEmpty {
                rows.append(["—", "", ""])
            } else {
                for urge in log.cigaretteUrges {
                    rows.append(["Urge", DateHelpers.formattedTime(urge.timeLogged), urge.note])
                }
            }
            rows.append([])
        }

        if settings.drinkingMode.showsSection || log.drinksLogged > 0 || !log.drinkUrges.isEmpty {
            rows.append(["Drinking"])
            rows.append(["Drinks", "\(log.drinksLogged)"])
            if let limit = settings.effectiveDailyDrinkLimit {
                rows.append(["Daily max", "\(limit)"])
            }
            if settings.drinkingMode == .quit, let quit = settings.alcoholQuitDate {
                rows.append(["Quit date", DateHelpers.formattedDay(quit)])
            }
            rows.append(["Entry", "Time", "Amount"])
            if log.drinkEvents.isEmpty {
                rows.append(["—", "", ""])
            } else {
                for event in log.drinkEvents {
                    rows.append(["Drink", DateHelpers.formattedTime(event.timeLogged), event.label])
                }
            }
            rows.append(["Urge", "Time", "Note"])
            if log.drinkUrges.isEmpty {
                rows.append(["—", "", ""])
            } else {
                for urge in log.drinkUrges {
                    rows.append(["Urge", DateHelpers.formattedTime(urge.timeLogged), urge.note])
                }
            }
        }
        return rows
    }

    // MARK: - OOXML fragments

    private static func contentTypesXML(sheetCount: Int) -> String {
        var overrides = """
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        """
        for index in 1...max(sheetCount, 1) {
            overrides += """
            <Override PartName="/xl/worksheets/sheet\(index).xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
            """
        }
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          \(overrides)
        </Types>
        """
    }

    private static let rootRelsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
    </Relationships>
    """

    private static func workbookXML(sheets: [String]) -> String {
        var sheetTags = ""
        for (index, name) in sheets.enumerated() {
            let sheetId = index + 1
            sheetTags += """
            <sheet name="\(escapeXML(sanitizeSheetName(name)))" sheetId="\(sheetId)" r:id="rId\(sheetId)"/>
            """
        }
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
         xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>
            \(sheetTags)
          </sheets>
        </workbook>
        """
    }

    private static func workbookRelsXML(sheetCount: Int) -> String {
        var relationships = ""
        for index in 1...max(sheetCount, 1) {
            relationships += """
            <Relationship Id="rId\(index)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet\(index).xml"/>
            """
        }
        let stylesId = sheetCount + 1
        relationships += """
        <Relationship Id="rId\(stylesId)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        """
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          \(relationships)
        </Relationships>
        """
    }

    private static let stylesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      <fonts count="2">
        <font><sz val="11"/><name val="Calibri"/></font>
        <font><b/><sz val="11"/><name val="Calibri"/></font>
      </fonts>
      <fills count="2">
        <fill><patternFill patternType="none"/></fill>
        <fill><patternFill patternType="gray125"/></fill>
      </fills>
      <borders count="1"><border/></borders>
      <cellStyleXfs count="1"><xf/></cellStyleXfs>
      <cellXfs count="2">
        <xf fontId="0" fillId="0" borderId="0"/>
        <xf fontId="1" fillId="0" borderId="0" applyFont="1"/>
      </cellXfs>
    </styleSheet>
    """

    private static func worksheetXML(rows: [[String]]) -> String {
        var sheetData = ""
        for (rowIndex, values) in rows.enumerated() {
            let r = rowIndex + 1
            var cells = ""
            for (colIndex, value) in values.enumerated() {
                let ref = cellReference(column: colIndex, row: r)
                let bold = rowIndex == 0 || looksLikeSectionHeader(values) || looksLikeColumnHeader(values)
                let styleAttr = bold ? " s=\"1\"" : ""
                cells += "<c r=\"\(ref)\" t=\"inlineStr\"\(styleAttr)><is><t xml:space=\"preserve\">\(escapeXML(value))</t></is></c>"
            }
            sheetData += "<row r=\"\(r)\">\(cells)</row>"
        }
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
            \(sheetData)
          </sheetData>
        </worksheet>
        """
    }

    private static func looksLikeSectionHeader(_ values: [String]) -> Bool {
        guard values.count == 1 else { return false }
        let title = values[0]
        return [
            "Weight & BMI",
            "Feelings & Cravings",
            "Protein Source",
            "Fats, Fruits & Vegetables",
            "Miscellaneous Items",
            "Activity / Workout",
            "Supplements",
            "Hydration",
            "Smoking",
            "Drinking"
        ].contains(title)
    }

    private static func looksLikeColumnHeader(_ values: [String]) -> Bool {
        values == ["Type", "Time", "Note"]
            || values == ["Protein Source", "Time", "Serving Size", "Protein Calories", "Hunger Before", "Hunger After"]
            || values == ["Category", "Item", "Amount"]
            || values == ["Item", "Amount"]
            || values == ["Activity", "Duration (minutes)", "Time"]
            || values == ["Supplement", "Completed", "Planned"]
            || values == ["Urge", "Time", "Note"]
            || values == ["Entry", "Time", "Amount"]
    }

    // MARK: - Helpers

    private static func sheetTitle(for date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
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

    private static func cellReference(column: Int, row: Int) -> String {
        var index = column
        var letters = ""
        repeat {
            letters = String(UnicodeScalar(65 + (index % 26))!) + letters
            index = index / 26 - 1
        } while index >= 0
        return "\(letters)\(row)"
    }

    private static func formatOz(_ oz: Double) -> String {
        if abs(oz.rounded() - oz) < 0.05 { return "\(Int(oz.rounded()))oz" }
        return String(format: "%.1foz", oz)
    }

    private static func data(_ string: String) -> Data {
        Data(string.utf8)
    }
}

enum ExportFileStore {
    static func exportsDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func uniqueURL(stem: String, ext: String) throws -> URL {
        let stamp = Int(Date().timeIntervalSince1970)
        return try exportsDirectory().appendingPathComponent("\(stem)-\(stamp).\(ext)")
    }
}
