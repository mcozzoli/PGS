import WidgetKit
import SwiftUI

// MARK: - Modello

struct PGSEntry: TimelineEntry {
    let date: Date
    let label: String      // es. "🏀 Prossima partita" / "🔴 In diretta"
    let title: String      // es. "GIO 12 NOV" / "PGS 54 – 48"
    let line1: String      // es. "PGS Salgen · Guidonia"
    let line2: String      // es. "ore 20:45 · 🏠 Casa"
    let standing: String   // es. "1ª su 6 · 0 pt"
    let live: Bool

    static let sample = PGSEntry(
        date: Date(),
        label: "🏀 Prossima partita",
        title: "GIO 12 NOV",
        line1: "PGS Salgen · Guidonia",
        line2: "ore 20:45 · 🏠 Casa",
        standing: "1ª su 6 · 0 pt",
        live: false
    )
}

// MARK: - Dati dall'API del portale

enum PGSData {
    static let base = "https://basketsalgen.pages.dev/api"
    static let mesi = ["GEN","FEB","MAR","APR","MAG","GIU","LUG","AGO","SET","OTT","NOV","DIC"]
    static let giorni = ["DOM","LUN","MAR","MER","GIO","VEN","SAB"]

    static func fetch() async -> PGSEntry {
        do {
            // login tifoso (dati pubblici)
            var req = URLRequest(url: URL(string: "\(base)/login")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: ["fan": true])
            let (ld, _) = try await URLSession.shared.data(for: req)
            let token = ((try JSONSerialization.jsonObject(with: ld)) as? [String: Any])?["token"] as? String ?? ""

            // live
            if let live = try? await getJSON("\(base)/live", token: nil),
               let l = live["live"] as? [String: Any],
               (l["status"] as? String) == "live" {
                let (us, opp) = score(l)
                let period = l["period"] as? Int ?? 1
                return PGSEntry(date: Date(), label: "🔴 In diretta",
                               title: "PGS \(us) – \(opp)",
                               line1: "Quarto Q\(period)", line2: "", standing: "", live: true)
            }

            // bootstrap (prossima partita + classifica)
            let b = try await getJSON("\(base)/bootstrap", token: token)
            let games = (b["games"] as? [[String: Any]]) ?? []
            let now = Date().timeIntervalSince1970 * 1000 - 3*3600*1000
            let sorted = games.sorted { ($0["date"] as? String ?? "") < ($1["date"] as? String ?? "") }
            let next = sorted.first { g in
                (g["ourScore"] is NSNull || g["ourScore"] == nil) && msOf(g["date"]) >= now
            } ?? sorted.first { ($0["ourScore"] is NSNull || $0["ourScore"] == nil) }

            var label = "🏀 PGS Salgen", title = "Nessuna partita", line1 = "", line2 = ""
            if let g = next {
                let d = dateStr(g["date"] as? String ?? "")
                let home = (g["home"] as? Bool) ?? false
                let official = (g["phase"] as? String ?? "") != "Amichevole"
                label = official ? "🏀 Prossima partita" : "🤝 Prossima (amichevole)"
                title = d.0
                line1 = "PGS Salgen · \(g["opponent"] as? String ?? "")"
                line2 = "ore \(d.1) · \(home ? "🏠 Casa" : "🚌 Trasferta")"
            }

            var standing = ""
            if let st = (b["standings"] as? [String: Any])?["teams"] as? [[String: Any]] {
                let ranked = st.sorted {
                    let pa = $0["pts"] as? Int ?? 0, pb = $1["pts"] as? Int ?? 0
                    if pa != pb { return pa > pb }
                    return (($0["pf"] as? Int ?? 0)-($0["ps"] as? Int ?? 0)) > (($1["pf"] as? Int ?? 0)-($1["ps"] as? Int ?? 0))
                }
                if let idx = ranked.firstIndex(where: { ($0["us"] as? Bool) ?? false }) {
                    let pts = ranked[idx]["pts"] as? Int ?? 0
                    standing = "\(idx+1)ª su \(ranked.count) · \(pts) pt"
                }
            }
            return PGSEntry(date: Date(), label: label, title: title, line1: line1, line2: line2, standing: standing, live: false)
        } catch {
            return .sample
        }
    }

    static func getJSON(_ url: String, token: String?) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: url)!)
        if let t = token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        let (d, _) = try await URLSession.shared.data(for: req)
        return (try JSONSerialization.jsonObject(with: d) as? [String: Any]) ?? [:]
    }

    static func msOf(_ v: Any?) -> Double {
        guard let s = v as? String else { return 0 }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime]
        // "2026-11-12T20:45" senza secondi/zona: parse manuale
        let parts = s.split(separator: "T")
        guard parts.count == 2 else { return 0 }
        let dmy = parts[0].split(separator: "-").compactMap { Int($0) }
        let hm = parts[1].split(separator: ":").compactMap { Int($0) }
        guard dmy.count == 3, hm.count >= 2 else { return 0 }
        var c = DateComponents()
        c.year = dmy[0]; c.month = dmy[1]; c.day = dmy[2]; c.hour = hm[0]; c.minute = hm[1]
        return (Calendar.current.date(from: c)?.timeIntervalSince1970 ?? 0) * 1000
    }

    static func dateStr(_ s: String) -> (String, String) {
        let parts = s.split(separator: "T")
        guard parts.count == 2 else { return (s, "") }
        let dmy = parts[0].split(separator: "-").compactMap { Int($0) }
        let time = String(parts[1].prefix(5))
        guard dmy.count == 3 else { return (s, time) }
        var c = DateComponents(); c.year = dmy[0]; c.month = dmy[1]; c.day = dmy[2]
        let wd = Calendar.current.date(from: c).map { Calendar.current.component(.weekday, from: $0) } ?? 1
        let mon = mesi[(dmy[1]-1) % 12]
        return ("\(giorni[(wd-1) % 7]) \(dmy[2]) \(mon)", time)
    }

    static func score(_ l: [String: Any]) -> (Int, Int) {
        let keys = ["p2m":2,"p3m":3,"ftm":1]
        var us = 0, opp = 0
        for e in (l["events"] as? [[String: Any]]) ?? [] {
            let k = e["k"] as? String ?? ""
            if k.hasPrefix("op") { opp += Int(k.dropFirst(2)) ?? 0 }
            else if let p = keys[k] { us += p }
        }
        return (us, opp)
    }
}

// MARK: - Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> PGSEntry { .sample }
    func getSnapshot(in context: Context, completion: @escaping (PGSEntry) -> Void) {
        Task { completion(await PGSData.fetch()) }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PGSEntry>) -> Void) {
        Task {
            let entry = await PGSData.fetch()
            let refresh = Calendar.current.date(byAdding: .minute, value: entry.live ? 2 : 30, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        }
    }
}

// MARK: - Vista

struct PGSWidgetEntryView: View {
    var entry: PGSEntry
    @Environment(\.widgetFamily) var family

    let blue = Color(red: 0.043, green: 0.184, blue: 0.478)
    let blue2 = Color(red: 0.071, green: 0.251, blue: 0.659)
    let orange = Color(red: 0.969, green: 0.580, blue: 0.113)

    var body: some View {
        ZStack(alignment: .leading) {
            LinearGradient(colors: [blue2, blue], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.label).font(.system(size: 11, weight: .heavy)).foregroundColor(orange)
                Text(entry.title).font(.system(size: family == .systemSmall ? 18 : 22, weight: .heavy)).foregroundColor(.white).minimumScaleFactor(0.7)
                if !entry.line1.isEmpty { Text(entry.line1).font(.system(size: 13, weight: .semibold)).foregroundColor(.white).lineLimit(1) }
                if !entry.line2.isEmpty { Text(entry.line2).font(.system(size: 12)).foregroundColor(.white.opacity(0.8)).lineLimit(1) }
                if !entry.standing.isEmpty {
                    Spacer(minLength: 2)
                    Text("📊 \(entry.standing)").font(.system(size: 12, weight: .bold)).foregroundColor(orange).lineLimit(1)
                }
            }
            .padding(14)
        }
    }
}

// MARK: - Widget

struct PGSWidget: Widget {
    let kind = "PGSWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                PGSWidgetEntryView(entry: entry).containerBackground(.clear, for: .widget)
            } else {
                PGSWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("PGS Salgen")
        .description("Prossima partita, diretta e classifica.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct PGSWidgetBundle: WidgetBundle {
    var body: some Widget { PGSWidget() }
}
