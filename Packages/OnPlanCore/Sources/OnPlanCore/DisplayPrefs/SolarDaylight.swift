import Foundation

/// Approximate local sunrise/sunset from timezone (no location permission).
public enum SolarDaylight {
    public static func isDaylight(at date: Date, timeZone: TimeZone = .current) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let coords = estimatedCoordinates(for: timeZone)
        guard let window = sunriseSunset(on: date, latitude: coords.lat, longitude: coords.lon, timeZone: timeZone) else {
            let hour = calendar.component(.hour, from: date)
            return (7..<19).contains(hour)
        }
        return date >= window.sunrise && date < window.sunset
    }

    public static func estimatedCoordinates(for timeZone: TimeZone) -> (lat: Double, lon: Double) {
        let hours = Double(timeZone.secondsFromGMT()) / 3600.0
        return (lat: 40.0, lon: hours * 15.0)
    }

    /// Compact sunrise/sunset estimate (temperate latitudes). Values are local clock times.
    public static func sunriseSunset(
        on date: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone
    ) -> (sunrise: Date, sunset: Date)? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let dayStart = calendar.startOfDay(for: date)
        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: dayStart) ?? 1)

        // Declination of the sun (radians).
        let decl = 23.44 * .pi / 180 * sin(2 * .pi * (284 + dayOfYear) / 365)
        let latRad = latitude * .pi / 180
        let cosHA = -tan(latRad) * tan(decl)
        // Polar day/night fallback.
        guard cosHA > -1, cosHA < 1 else { return nil }
        let hourAngleHours = acos(cosHA) * 12 / .pi

        // Equation of time (~minutes) + longitude offset from timezone meridian.
        let b = 2 * .pi * (dayOfYear - 81) / 364
        let eot = 9.87 * sin(2 * b) - 7.53 * cos(b) - 1.5 * sin(b)
        let tzMeridian = Double(timeZone.secondsFromGMT(for: dayStart)) / 240.0 // seconds → degrees (360/24h)
        let longitudeCorrectionHours = (tzMeridian - longitude) / 15.0
        let solarNoonHours = 12 + longitudeCorrectionHours - eot / 60.0

        let sunriseHours = solarNoonHours - hourAngleHours
        let sunsetHours = solarNoonHours + hourAngleHours

        func clockTime(fromHours hours: Double) -> Date? {
            let clamped = min(max(hours, 0), 23.99)
            let h = Int(clamped)
            let m = Int((clamped - Double(h)) * 60)
            return calendar.date(bySettingHour: h, minute: m, second: 0, of: dayStart)
        }

        guard let sunrise = clockTime(fromHours: sunriseHours),
              let sunset = clockTime(fromHours: sunsetHours) else { return nil }
        return (sunrise, sunset)
    }
}
