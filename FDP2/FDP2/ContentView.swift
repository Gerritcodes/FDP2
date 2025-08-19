//
//  ContentView.swift
//  FDP2
//
//  Created by Gerrit Jan van den Bosch on 25.06.25.
//

import SwiftUI
import EventKit
import UserNotifications

final class CalendarManager: ObservableObject {
    private let store = EKEventStore()

    @Published var calendars: [EKCalendar] = []
    @Published var accessGranted: Bool = false
    @Published var nextCheckIn: EKEvent?
    @Published var statusMessage: String = ""

    // Keywords to detect check-in style events
    private let keywords = ["checkin", "check-in", "c/i", "ci", "report"]

    func requestAccess() {
        if #available(iOS 17.0, *) {
            // New API on iOS 17+: request full access to calendars (events)
            store.requestFullAccessToEvents { granted, error in
                DispatchQueue.main.async {
                    self.accessGranted = granted
                    if granted {
                        self.loadCalendars()
                    } else {
                        self.statusMessage = error?.localizedDescription.isEmpty == false
                            ? "Calendar access denied: \(error!.localizedDescription)"
                            : "Calendar access denied."
                    }
                }
            }
        } else {
            // Older iOS: legacy API
            store.requestAccess(to: .event) { granted, error in
                DispatchQueue.main.async {
                    self.accessGranted = granted
                    if granted {
                        self.loadCalendars()
                    } else {
                        self.statusMessage = error?.localizedDescription.isEmpty == false
                            ? "Calendar access denied: \(error!.localizedDescription)"
                            : "Calendar access denied."
                    }
                }
            }
        }
    }
    
    func loadCalendars() {
        calendars = store.calendars(for: .event)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func findNextCheckIn(in calendarID: String?) {
        guard accessGranted else {
            statusMessage = "No access to calendars."
            nextCheckIn = nil
            return
        }
        let all = store.calendars(for: .event)
        let selected: [EKCalendar]
        if let calendarID, let match = all.first(where: { $0.calendarIdentifier == calendarID }) {
            selected = [match]
        } else {
            selected = all
        }

        let start = Date()
        let end = Calendar.current.date(byAdding: .hour, value: 36, to: start) ?? start.addingTimeInterval(36*3600)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: selected)

        let events = store.events(matching: predicate)
            .filter { ev in
                let title = ev.title.lowercased()
                return keywords.contains(where: { title.contains($0) })
            }
            .sorted { $0.startDate < $1.startDate }

        DispatchQueue.main.async {
            self.nextCheckIn = events.first
            self.statusMessage = events.first == nil ? "No check-in style events found in the next 36h." : ""
        }
    }
}

struct ContentView: View {
    @State private var reportTime = Date()
    @State private var sectors = 2
    @State private var useDiscretion = false
    @State private var onStandby = false
    @State private var standbyStart = Date()
    // Advanced and table source state
    @State private var customTableStatusMessage: String = ""
    @State private var customTableStatusOK: Bool = false
    @State private var showAdvancedOptions = false
    @State private var selectedTableSource = "EASA"
    @AppStorage("customFDPTable") private var customFDPTableData: String = ""
    @State private var showCustomTableEditor = false
    @State private var showFileImporter = false
    @State private var extendedFDP: Bool = false
    @State private var positioningBeforeDuty: Bool = false
    @State private var inFlightRest: Bool = false
    @State private var restClass: Int = 1       // 1, 2, or 3
    @State private var numPilots: Int = 3       // 3 or 4
    @State private var debugSource: String = ""
    @State private var debugBand: String = ""
    @StateObject private var calendarManager = CalendarManager()
    @AppStorage("selectedCalendarID") private var selectedCalendarID: String = ""
    @State private var reminderStatus: String = ""
    @State private var showCustomTableEditor = false
    @State private var showFileImporter = false
    
    var calculatedFDP: Int {
        // EASA FDP Table in minutes for 1-2 to 10 sectors (indices 0...9)
        // Each tuple: (ClosedRange<Int>, [Int]) where [Int] is for sectors 1-2, 3, ..., 10
        let fdpTable: [(ClosedRange<Int>, [Int])] = [
            // 0500–0514
            (300...314, [720, 720, 690, 660, 630, 600, 570, 540, 540, 540]),
            // 0515–0529
            (315...329, [735, 735, 705, 675, 645, 615, 585, 555, 540, 540]),
            // 0530–0544
            (330...344, [750, 750, 720, 690, 660, 630, 600, 570, 540, 540]),
            // 0545–0559
            (345...359, [765, 765, 735, 705, 675, 645, 615, 585, 555, 540]),
            // 0600–1329
            (360...809, [780, 780, 750, 720, 690, 660, 630, 600, 570, 540]),
            // 1330–1359
            (810...839, [765, 765, 735, 705, 675, 645, 615, 585, 555, 540]),
            // 1400–1429
            (840...869, [750, 750, 720, 690, 660, 630, 600, 570, 540, 540]),
            // 1430–1459
            (870...899, [735, 735, 705, 675, 645, 615, 585, 555, 540, 540]),
            // 1500–1529
            (900...929, [720, 720, 690, 660, 630, 600, 570, 540, 540, 540]),
            // 1530–1559
            (930...959, [705, 705, 675, 645, 615, 585, 555, 540, 540, 540]),
            // 1600–1629
            (960...989, [690, 690, 660, 630, 600, 570, 540, 540, 540, 540]),
            // 1630–1659
            (990...1019, [675, 675, 645, 615, 585, 555, 540, 540, 540, 540]),
            // 1700–2359
            (1020...1439, [660, 660, 630, 600, 570, 540, 540, 540, 540, 540]),
            // 0000–0459
            (0...299,     [660, 660, 630, 600, 570, 540, 540, 540, 540, 540])
        ]

        // Extended FDP Table for sectors 1-5 (indices 0...4)
        let fdpExtendedTable: [(ClosedRange<Int>, [Int])] = [
            // 0615–0629
            (375...389, [795, 795, 765, 735, 705]),
            // 0630–0644
            (390...404, [810, 810, 780, 750, 720]),
            // 0645–0659
            (405...419, [825, 825, 795, 765, 735]),
            // 0700–1329
            (420...809, [840, 840, 810, 780, 750]),
            // 1330–1359
            (810...839, [825, 825, 795, 765, 0]),
            // 1400-1429
            (840...869, [810, 810, 780, 750, 0]),
            // 1430-1459
            (870...899, [795, 795, 765, 735, 0]),
            // 1500-1529
            (900...929, [780, 780, 750, 720, 0]),
            // 1530-1559
            (930...959, [765, 765, 0, 0, 0]),
            // 1600-1629
            (960...989, [750, 750, 0, 0, 0]),
            // 1630-1659
            (990...1019, [735, 735, 0, 0, 0]),
            // 1700-1729
            (1020...1049, [720, 720, 0, 0, 0]),
            // 1730-1759
            (1050...1079, [705, 705, 0, 0, 0]),
            // 1800-1829
            (1080...1109, [690, 690, 0, 0, 0]),
            // 1830-1859
            (1110...1139, [675, 675, 0, 0, 0]),
            // 1900-2359
            (1140...1439, [0, 0, 0, 0, 0]),
        ]
        
        // In-Flight Rest FDP (minutes) by number of pilots and rest class.
        // Index: [Class1, Class2, Class3]
        let inFlightRestTable: [Int: [Int]] = [
            3: [16*60, 15*60, 14*60], // 3 pilots: 16h, 15h, 14h
            4: [17*60, 16*60, 15*60]  // 4 pilots: 17h, 16h, 15h
        ]
        // Debug placeholders for which table/band matched
        var dbgSource = ""
        var dbgBand = ""
        func hhmm(_ m: Int) -> String { formattedTime(minutes: m) }
        

        // --- Custom FDP table parsing (from @AppStorage JSON) ---
        /// FDP value that may be an Int (minutes), an HH:MM String, or null
        enum FDPValue: Decodable {
            case minutes(Int)
            case hhmm(String)
            case null

            init(from decoder: Decoder) throws {
                let c = try decoder.singleValueContainer()
                if c.decodeNil() {
                    self = .null
                } else if let i = try? c.decode(Int.self) {
                    self = .minutes(i)
                } else if let s = try? c.decode(String.self) {
                    self = .hhmm(s)
                } else {
                    self = .null
                }
            }
        }

        struct CustomEntry: Decodable {
            let range: String?
            let timeBand: String?
            let fdp: [FDPValue]?
        }

        func parseHHMM(_ s: String) -> Int? {
            let parts = s.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
            guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]), (0..<24).contains(h), (0..<60).contains(m) else { return nil }
            return h * 60 + m
        }

        func parseTimeBandToRange(_ band: String) -> ClosedRange<Int>? {
            // Accept formats like "HH:MM - HH:MM" or with an en dash
            let cleaned = band.replacingOccurrences(of: "–", with: "-")
            let parts = cleaned.split(separator: "-")
            guard parts.count == 2,
                  let s = parseHHMM(String(parts[0])),
                  let e = parseHHMM(String(parts[1])) else { return nil }
            return s...e
        }

        var customRanges: [(ClosedRange<Int>, [Int])] = []
        if selectedTableSource == "Custom", let data = customFDPTableData.data(using: .utf8) {
            if let entries = try? JSONDecoder().decode([CustomEntry].self, from: data) {
                for entry in entries {
                    guard let raw = entry.fdp, !raw.isEmpty else { continue }
                    // Convert FDPValue -> minutes; drop null/invalids
                    let values: [Int] = raw.compactMap { v in
                        switch v {
                        case .minutes(let m):
                            return m
                        case .hhmm(let s):
                            return parseHHMM(s)
                        case .null:
                            return nil
                        }
                    }
                    guard !values.isEmpty else { continue }

                    var rangeOpt: ClosedRange<Int>? = nil
                    if let r = entry.range {
                        // Expecting minute range format like "300-359"
                        let parts = r.replacingOccurrences(of: " ", with: "").split(separator: "-")
                        if parts.count == 2, let s = Int(parts[0]), let e = Int(parts[1]) { rangeOpt = s...e }
                    }
                    if rangeOpt == nil, let tb = entry.timeBand { rangeOpt = parseTimeBandToRange(tb) }
                    if let rr = rangeOpt { customRanges.append((rr, values)) }
                }
                // Keep ranges ordered for predictable matching
                customRanges.sort { $0.0.lowerBound < $1.0.lowerBound }
            }
        }
        // --- End Custom FDP parsing ---

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: reportTime)
        let minute = calendar.component(.minute, from: reportTime)
        let totalMinutes = hour * 60 + minute

        let sectorIndex: Int
        if extendedFDP {
            sectorIndex = min(max(sectors, 1), 5) - 1
        } else {
            if sectors <= 2 {
                sectorIndex = 0
            } else if sectors >= 10 {
                sectorIndex = 9
            } else {
                sectorIndex = sectors - 1
            }
        }

        var baseFDP: Int = 0

        if inFlightRest {
            // EASA: augmented FDP valid for max 3 sectors
            if sectors > 3 {
                baseFDP = 0 // not allowed
                dbgSource = "In-Flight Rest"
                dbgBand = "Not allowed (>3 sectors)"
            } else if let classValues = inFlightRestTable[numPilots],
                      (1...3).contains(restClass) {
                baseFDP = classValues[restClass - 1]
                dbgSource = "In-Flight Rest"
                dbgBand = "Class \(restClass), \(numPilots) pilots"
            } else {
                baseFDP = 0
                dbgSource = "In-Flight Rest"
                dbgBand = "Invalid selection"
            }
        } else if extendedFDP {
            for (range, values) in fdpExtendedTable {
                if range.contains(totalMinutes) {
                    baseFDP = values[sectorIndex]
                    dbgSource = "Extended FDP"
                    dbgBand = "\(hhmm(range.lowerBound))–\(hhmm(range.upperBound))"
                    break
                }
            }
        } else {
            if selectedTableSource == "Custom", !customRanges.isEmpty {
                // Use custom table: pick value by sectors with clamping to values.count
                for (range, values) in customRanges {
                    if range.contains(totalMinutes) {
                        let idx = (sectors <= 2) ? 0 : min(sectors - 1, max(0, values.count - 1))
                        baseFDP = values[min(idx, values.count - 1)]
                        dbgSource = "Custom"
                        dbgBand = "\(hhmm(range.lowerBound))–\(hhmm(range.upperBound))"
                        break
                    }
                }
                if baseFDP == 0 {
                    // No matching custom range found — fall back to EASA minimum
                    baseFDP = 510
                }
            } else {
                // Use built-in EASA table
                baseFDP = 510 // fallback to minimum
                for (range, values) in fdpTable {
                    if range.contains(totalMinutes) {
                        baseFDP = values[sectorIndex]
                        dbgSource = "EASA"
                        dbgBand = "\(hhmm(range.lowerBound))–\(hhmm(range.upperBound))"
                        break
                    }
                }
            }
        }

        var adjusted = baseFDP

        // Do NOT subtract 15 min per sector anymore!

        if onStandby {
            let diff = Int(reportTime.timeIntervalSince(standbyStart) / 60)
            if diff > 360 {
                adjusted -= diff - 360
            }
        }

        if useDiscretion {
            adjusted += 120
        }
        DispatchQueue.main.async {
            self.debugSource = dbgSource
            self.debugBand = dbgBand
        }
        return max(adjusted, 0)
    }

    var latestOnBlock: Date {
        return Calendar.current.date(byAdding: .minute, value: calculatedFDP, to: reportTime) ?? reportTime
    }

    // MARK: - Local Notifications (Reminder 1h before FDP end)
    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                completion(true)
            case .denied:
                completion(false)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    completion(granted)
                }
            @unknown default:
                completion(false)
            }
        }
    }

    func scheduleFDPReminderOneHourBeforeEnd() {
        let end = latestOnBlock
        let triggerDate = Calendar.current.date(byAdding: .minute, value: -60, to: end) ?? end.addingTimeInterval(-3600)
        let seconds = triggerDate.timeIntervalSinceNow

        guard seconds > 5 else {
            DispatchQueue.main.async { self.reminderStatus = "❗ The 1‑hour mark has already passed." }
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "FDP Reminder"
        content.body = "1 hour left in your FDP. Latest on‑block: \(formattedDate(date: end))"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: "fdp_one_hour_left", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.reminderStatus = "❌ Couldn't schedule: \(error.localizedDescription)"
                } else {
                    self.reminderStatus = "✅ Reminder set for \(formattedDate(date: triggerDate))"
                }
            }
        }
    }

    /// Lightweight validator for the Custom FDP JSON without relying on types inside `calculatedFDP`.
    /// Returns (ok, count, message)
    func validateCustomJSONString(_ json: String) -> (Bool, Int, String) {
        guard let data = json.data(using: .utf8) else {
            return (false, 0, "Invalid text encoding.")
        }
        do {
            let any = try JSONSerialization.jsonObject(with: data, options: [])
            guard let arr = any as? [Any] else {
                return (false, 0, "JSON must be an array.")
            }
            var validCount = 0
            for case let dict as [String: Any] in arr {
                let hasRange = (dict["range"] as? String)?.isEmpty == false
                let hasTimeBand = (dict["timeBand"] as? String)?.isEmpty == false
                guard hasRange || hasTimeBand else { continue }
                if let fdp = dict["fdp"] as? [Any], !fdp.isEmpty {
                    validCount += 1
                }
            }
            if validCount == 0 {
                return (false, 0, "No valid entries found.")
            }
            return (true, validCount, "Loaded \(validCount) ranges.")
        } catch {
            return (false, 0, "JSON parse error: \(error.localizedDescription)")
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                FDPDesignSystem.primaryGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Compact Header
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("FDP Calculator")
                                    .font(.system(.title, design: .rounded, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.white, .white.opacity(0.9)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text("Flight Duty Period")
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            Spacer()
                            Button(action: {}) {
                                Image(systemName: "gearshape.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        LinearGradient(
                                            colors: [.white.opacity(0.25), .white.opacity(0.15)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        // Compact Main Content - Everything in one view
                        VStack(spacing: 16) {
                            // Input Parameters Card - Compact
                            FDPCard {
                                VStack(spacing: 16) {
                                    // Header
                                    HStack {
                                        FDPIcon("clock.fill", color: FDPDesignSystem.primary, size: 20)
                                        Text("Flight Parameters")
                                            .font(.system(.headline, design: .rounded, weight: .semibold))
                                            .foregroundColor(FDPDesignSystem.textPrimary)
                                        Spacer()
                                    }
                                    
                                    // Compact Input Grid
                                    LazyVGrid(columns: [
                                        GridItem(.flexible()),
                                        GridItem(.flexible())
                                    ], spacing: 12) {
                                        // Report Time
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Report Time")
                                                .font(.system(.caption, design: .rounded, weight: .medium))
                                                .foregroundColor(FDPDesignSystem.textSecondary)
                                            DatePicker("", selection: $reportTime, displayedComponents: .hourAndMinute)
                                                .datePickerStyle(CompactDatePickerStyle())
                                                .accentColor(FDPDesignSystem.primary)
                                                .scaleEffect(0.9)
                                        }
                                        
                                        // Sectors
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Sectors")
                                                .font(.system(.caption, design: .rounded, weight: .medium))
                                                .foregroundColor(FDPDesignSystem.textSecondary)
                                            HStack {
                                                Text("\(sectors)")
                                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                                    .foregroundStyle(
                                                        LinearGradient(
                                                            colors: [FDPDesignSystem.accent, FDPDesignSystem.accent.opacity(0.8)],
                                                            startPoint: .leading,
                                                            endPoint: .trailing
                                                        )
                                                    )
                                                Spacer()
                                                Stepper("", value: $sectors, in: 1...10)
                                                    .labelsHidden()
                                                    .accentColor(FDPDesignSystem.accent)
                                                    .scaleEffect(0.8)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                LinearGradient(
                                                    colors: [FDPDesignSystem.background, FDPDesignSystem.background.opacity(0.8)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .cornerRadius(10)
                                        }
                                        
                                        // FDP Table Source
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("FDP Table")
                                                .font(.system(.caption, design: .rounded, weight: .medium))
                                                .foregroundColor(FDPDesignSystem.textSecondary)
                                            Picker("FDP Table", selection: $selectedTableSource) {
                                                Text("EASA").tag("EASA")
                                                Text("Custom").tag("Custom")
                                            }
                                            .pickerStyle(SegmentedPickerStyle())
                                            .accentColor(FDPDesignSystem.primary)
                                            .scaleEffect(0.9)
                                        }
                                        
                                                                                 // Calendar Integration (if needed)
                                         if !calendarManager.accessGranted {
                                             VStack(alignment: .leading, spacing: 4) {
                                                 Text("Calendar")
                                                     .font(.system(.caption, design: .rounded, weight: .medium))
                                                     .foregroundColor(FDPDesignSystem.textSecondary)
                                                 Button("Connect") {
                                                     calendarManager.requestAccess()
                                                 }
                                                 .font(.system(.caption, design: .rounded, weight: .medium))
                                                 .foregroundColor(FDPDesignSystem.accent)
                                                 .padding(.horizontal, 12)
                                                 .padding(.vertical, 6)
                                                 .background(FDPDesignSystem.accent.opacity(0.1))
                                                 .cornerRadius(8)
                                             }
                                         }
                                         
                                         // Custom Table (if selected)
                                         if selectedTableSource == "Custom" {
                                             VStack(alignment: .leading, spacing: 4) {
                                                 Text("Custom Table")
                                                     .font(.system(.caption, design: .rounded, weight: .medium))
                                                     .foregroundColor(FDPDesignSystem.textSecondary)
                                                 HStack(spacing: 8) {
                                                     Button("Edit") {
                                                         showCustomTableEditor = true
                                                     }
                                                     .font(.system(.caption, design: .rounded, weight: .medium))
                                                     .foregroundColor(FDPDesignSystem.accent)
                                                     .padding(.horizontal, 8)
                                                     .padding(.vertical, 4)
                                                     .background(FDPDesignSystem.accent.opacity(0.1))
                                                     .cornerRadius(6)
                                                     
                                                     Button("Import") {
                                                         showFileImporter = true
                                                     }
                                                     .font(.system(.caption, design: .rounded, weight: .medium))
                                                     .foregroundColor(FDPDesignSystem.accent)
                                                     .padding(.horizontal, 8)
                                                     .padding(.vertical, 4)
                                                     .background(FDPDesignSystem.accent.opacity(0.1))
                                                     .cornerRadius(6)
                                                 }
                                             }
                                         }
                                    }
                                    
                                    // Compact Advanced Options
                                    VStack(spacing: 12) {
                                        HStack {
                                            Text("Advanced Options")
                                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                                .foregroundColor(FDPDesignSystem.textPrimary)
                                            Spacer()
                                            Button(action: { showAdvancedOptions.toggle() }) {
                                                Image(systemName: showAdvancedOptions ? "chevron.up" : "chevron.down")
                                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                                    .foregroundColor(FDPDesignSystem.primary)
                                                    .frame(width: 24, height: 24)
                                                    .background(FDPDesignSystem.background)
                                                    .clipShape(Circle())
                                            }
                                        }
                                        
                                        if showAdvancedOptions {
                                            LazyVGrid(columns: [
                                                GridItem(.flexible()),
                                                GridItem(.flexible())
                                            ], spacing: 8) {
                                                // Standby
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Toggle(isOn: $onStandby) {
                                                        Text("Standby")
                                                            .font(.system(.caption, design: .rounded, weight: .medium))
                                                    }
                                                    .toggleStyle(SwitchToggleStyle(tint: FDPDesignSystem.primary))
                                                    .scaleEffect(0.9)
                                                    
                                                    if onStandby {
                                                        DatePicker("Start", selection: $standbyStart, displayedComponents: .hourAndMinute)
                                                            .datePickerStyle(CompactDatePickerStyle())
                                                            .accentColor(FDPDesignSystem.primary)
                                                            .scaleEffect(0.8)
                                                    }
                                                }
                                                
                                                // Extended FDP
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Toggle(isOn: $extendedFDP) {
                                                        Text("Extended FDP")
                                                            .font(.system(.caption, design: .rounded, weight: .medium))
                                                    }
                                                    .toggleStyle(SwitchToggleStyle(tint: FDPDesignSystem.primary))
                                                    .scaleEffect(0.9)
                                                }
                                                
                                                // In-Flight Rest
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Toggle(isOn: $inFlightRest) {
                                                        Text("In‑Flight Rest")
                                                            .font(.system(.caption, design: .rounded, weight: .medium))
                                                    }
                                                    .toggleStyle(SwitchToggleStyle(tint: FDPDesignSystem.primary))
                                                    .scaleEffect(0.9)
                                                }
                                                
                                                // Commander's Discretion
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Toggle(isOn: $useDiscretion) {
                                                        Text("Discretion")
                                                            .font(.system(.caption, design: .rounded, weight: .medium))
                                                    }
                                                    .toggleStyle(SwitchToggleStyle(tint: FDPDesignSystem.primary))
                                                    .scaleEffect(0.9)
                                                }
                                                
                                                if inFlightRest {
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text("Rest Class")
                                                            .font(.system(.caption, design: .rounded, weight: .medium))
                                                            .foregroundColor(FDPDesignSystem.textSecondary)
                                                        Picker("Rest Class", selection: $restClass) {
                                                            Text("1").tag(1)
                                                            Text("2").tag(2)
                                                            Text("3").tag(3)
                                                        }
                                                        .pickerStyle(SegmentedPickerStyle())
                                                        .accentColor(FDPDesignSystem.primary)
                                                        .scaleEffect(0.8)
                                                    }
                                                    
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text("Pilots")
                                                            .font(.system(.caption, design: .rounded, weight: .medium))
                                                            .foregroundColor(FDPDesignSystem.textSecondary)
                                                        Picker("Pilots", selection: $numPilots) {
                                                            Text("3").tag(3)
                                                            Text("4").tag(4)
                                                        }
                                                        .pickerStyle(SegmentedPickerStyle())
                                                        .accentColor(FDPDesignSystem.primary)
                                                        .scaleEffect(0.8)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Results Card - Compact
                            FDPCard {
                                VStack(spacing: 16) {
                                    HStack {
                                        FDPIcon("chart.bar.fill", color: FDPDesignSystem.primary, size: 20)
                                        Text("Results")
                                            .font(.system(.headline, design: .rounded, weight: .semibold))
                                            .foregroundColor(FDPDesignSystem.textPrimary)
                                        Spacer()
                                    }
                                    
                                    // Compact Results Grid
                                    LazyVGrid(columns: [
                                        GridItem(.flexible()),
                                        GridItem(.flexible())
                                    ], spacing: 12) {
                                        // Max FDP
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Max FDP")
                                                .font(.system(.caption, design: .rounded, weight: .medium))
                                                .foregroundColor(FDPDesignSystem.textSecondary)
                                            Text(formattedTime(minutes: calculatedFDP))
                                                .font(.system(.title2, design: .rounded, weight: .bold))
                                                .foregroundStyle(
                                                    LinearGradient(
                                                        colors: [FDPDesignSystem.accent, FDPDesignSystem.accent.opacity(0.8)],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            LinearGradient(
                                                colors: [FDPDesignSystem.accent.opacity(0.1), FDPDesignSystem.accent.opacity(0.05)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [FDPDesignSystem.accent.opacity(0.3), FDPDesignSystem.accent.opacity(0.1)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                        .cornerRadius(12)
                                        
                                        // Latest On Block
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("On Block")
                                                .font(.system(.caption, design: .rounded, weight: .medium))
                                                .foregroundColor(FDPDesignSystem.textSecondary)
                                            Text(formattedDate(date: latestOnBlock))
                                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                                .foregroundColor(FDPDesignSystem.textPrimary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            LinearGradient(
                                                colors: [FDPDesignSystem.background, FDPDesignSystem.background.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [FDPDesignSystem.border.opacity(0.5), FDPDesignSystem.border.opacity(0.2)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                        .cornerRadius(12)
                                    }
                                    
                                    // Debug Info and Reminder
                                    VStack(spacing: 8) {
                                        if !debugSource.isEmpty {
                                            HStack {
                                                FDPBadge(debugSource, color: FDPDesignSystem.accent)
                                                if !debugBand.isEmpty {
                                                    FDPBadge(debugBand, color: FDPDesignSystem.secondary)
                                                }
                                                Spacer()
                                            }
                                        }
                                        
                                        Button("Set 1-Hour Reminder") {
                                            requestNotificationPermission { granted in
                                                if granted { self.scheduleFDPReminderOneHourBeforeEnd() }
                                                else {
                                                    DispatchQueue.main.async { self.reminderStatus = "❌ Notifications disabled" }
                                                }
                                            }
                                        }
                                        .primaryButtonStyle()
                                        
                                        if !reminderStatus.isEmpty {
                                            HStack {
                                                Image(systemName: reminderStatus.contains("✅") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                    .foregroundColor(reminderStatus.contains("✅") ? FDPDesignSystem.success : FDPDesignSystem.danger)
                                                Text(reminderStatus)
                                                    .font(.system(.caption, design: .rounded))
                                                    .foregroundColor(reminderStatus.contains("✅") ? FDPDesignSystem.success : FDPDesignSystem.danger)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background((reminderStatus.contains("✅") ? FDPDesignSystem.success : FDPDesignSystem.danger).opacity(0.1))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                            
                            // Calendar Integration Card (if connected)
                            if calendarManager.accessGranted {
                                FDPCard {
                                    VStack(spacing: 12) {
                                        HStack {
                                            FDPIcon("calendar", color: FDPDesignSystem.primary, size: 20)
                                            Text("Calendar")
                                                .font(.system(.headline, design: .rounded, weight: .semibold))
                                                .foregroundColor(FDPDesignSystem.textPrimary)
                                            Spacer()
                                        }
                                        
                                        if let ev = calendarManager.nextCheckIn {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text("Next Check‑In")
                                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                                    .foregroundColor(FDPDesignSystem.textSecondary)
                                                Text("\(formattedDate(date: ev.startDate)) • \(ev.title)")
                                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                                    .foregroundColor(FDPDesignSystem.textPrimary)
                                                Button("Use as Report Time") {
                                                    reportTime = ev.startDate
                                                }
                                                .font(.system(.caption, design: .rounded, weight: .medium))
                                                .foregroundColor(FDPDesignSystem.accent)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(FDPDesignSystem.accent.opacity(0.1))
                                                .cornerRadius(8)
                                            }
                                        } else {
                                            Button("Find Next Check‑In") {
                                                let id: String? = selectedCalendarID.isEmpty ? nil : selectedCalendarID
                                                calendarManager.findNextCheckIn(in: id)
                                            }
                                            .secondaryButtonStyle()
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 20)
                    }
                }
            }
            .navigationBarHidden(true)
            // Sheet for editing custom table
            .sheet(isPresented: $showCustomTableEditor) {
                NavigationView {
                    VStack {
                        Text("Custom FDP Table Editor")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .padding()
                        
                        TextEditor(text: $customFDPTableData)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(FDPDesignSystem.background)
                            .cornerRadius(12)
                            .padding()
                        
                        HStack {
                            Button("Cancel") {
                                showCustomTableEditor = false
                            }
                            .secondaryButtonStyle()
                            
                            Button("Save") {
                                let (ok, count, msg) = validateCustomJSONString(customFDPTableData)
                                customTableStatusOK = ok
                                customTableStatusMessage = ok ? "Loaded \(count) ranges." : msg
                                showCustomTableEditor = false
                            }
                            .primaryButtonStyle()
                        }
                        .padding()
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                let (ok, count, msg) = validateCustomJSONString(customFDPTableData)
                                customTableStatusOK = ok
                                customTableStatusMessage = ok ? "Loaded \(count) ranges." : msg
                                showCustomTableEditor = false
                            }
                        }
                    }
                }
            }
            // File importer for custom table
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json]) { result in
                do {
                    let selectedFile: URL = try result.get()
                    let data = try Data(contentsOf: selectedFile)
                    if let jsonString = String(data: data, encoding: .utf8) {
                        customFDPTableData = jsonString
                        let (ok, count, msg) = validateCustomJSONString(jsonString)
                        customTableStatusOK = ok
                        customTableStatusMessage = ok ? "Loaded \(count) ranges." : msg
                    } else {
                        customTableStatusOK = false
                        customTableStatusMessage = "Unsupported file encoding."
                    }
                } catch {
                    customTableStatusOK = false
                    customTableStatusMessage = "Import failed: \(error.localizedDescription)"
                }
            }
            .onAppear {
                if calendarManager.accessGranted {
                    calendarManager.loadCalendars()
                    let id: String? = selectedCalendarID.isEmpty ? nil : selectedCalendarID
                    calendarManager.findNextCheckIn(in: id)
                }
            }
        }
    }

    func formattedTime(minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    func formattedDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SettingsView: View {
    var body: some View {
        ZStack {
            FDPDesignSystem.background
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                FDPCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            FDPIcon("info.circle.fill", color: FDPDesignSystem.primary, size: 24)
                            Text("Disclaimer")
                                .font(.system(.headline, design: .rounded, weight: .semibold))
                                .foregroundColor(FDPDesignSystem.textPrimary)
                        }
                        
                        Text("This app is for informational purposes only and does not replace official documents.")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(FDPDesignSystem.textSecondary)
                    }
                }
                
                FDPCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            FDPIcon("envelope.fill", color: FDPDesignSystem.primary, size: 24)
                            Text("Feedback")
                                .font(.system(.headline, design: .rounded, weight: .semibold))
                                .foregroundColor(FDPDesignSystem.textPrimary)
                        }
                        
                        Text("Coming soon: email link or feedback form.")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(FDPDesignSystem.textSecondary)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    ContentView()
}
