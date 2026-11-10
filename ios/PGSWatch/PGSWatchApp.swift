import SwiftUI

// MARK: - App watchOS PGS Salgen

@main
struct PGSWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchHome()
        }
    }
}

// MARK: - Dati (legge la stessa API del portale)

struct WatchInfo {
    var label = "🏀 PGS Salgen"
    var title = "—"
    var line1 = ""
    var line2 = ""
    var standing = ""
    var live = false
}

enum WatchData {
    static let base = "https://basketsalgen.pages.dev/api"
    static let mesi = ["GEN","FEB","MAR","APR","MAG","GIU","LUG","AGO","SET","OTT","NOV","DIC"]
    static let giorni = ["DOM","LUN","MAR","MER","GIO","VEN","SAB"]

    static func load() async -> WatchInfo {
        var info = WatchInfo()
        do {
            var req = URLRequest(url: URL(string: "\(base)/login")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: ["fan": true])
            let (ld, _) = try await URLSession.shared.data(for: req)
            let token = ((try JSONSerialization.jsonObject(with: ld)) as? [String: Any])?["token"] as? String ?? ""

            if let live = try? await getJSON("\(base)/live", token: nil),
               let l = live["live"] as? [String: Any],
               (l["status"] as? String) == "live" {
                let (us, opp) = score(l)
                info.live = true
                info.label = "🔴 In diretta"
                info.title = "\(us) – \(opp)"
                info.line1 = "PGS Salgen"
                info.line2 = "Q\(l["period"] as? Int ?? 1)"
                return info
            }

            let b = try await getJSON("\(base)/bootstrap", token: token)
            let games = (b["games"] as? [[String: Any]]) ?? []
            let now = Date().timeIntervalSince1970 * 1000 - 3*3600*1000
            let sorted = games.sorted { ($0["date"] as? String ?? "") < ($1["date"] as? String ?? "") }
            let next = sorted.first { ($0["ourScore"] is NSNull || $0["ourScore"] == nil) && msOf($0["date"]) >= now }
                ?? sorted.first { ($0["ourScore"] is NSNull || $0["ourScore"] == nil) }
            if let g = next {
                let d = dateStr(g["date"] as? String ?? "")
                let home = (g["home"] as? Bool) ?? false
                info.label = ((g["phase"] as? String ?? "") != "Amichevole") ? "🏀 Prossima" : "🤝 Amichevole"
                info.title = d.0
                info.line1 = "vs \(g["opponent"] as? String ?? "")"
                info.line2 = "ore \(d.1) · \(home ? "🏠 Casa" : "🚌 Fuori")"
            } else {
                info.title = "Nessuna partita"
            }
            if let st = (b["standings"] as? [String: Any])?["teams"] as? [[String: Any]] {
                let ranked = st.sorted { ($0["pts"] as? Int ?? 0) > ($1["pts"] as? Int ?? 0) }
                if let idx = ranked.firstIndex(where: { ($0["us"] as? Bool) ?? false }) {
                    info.standing = "\(idx+1)ª su \(ranked.count) · \(ranked[idx]["pts"] as? Int ?? 0) pt"
                }
            }
        } catch { }
        return info
    }

    static func getJSON(_ url: String, token: String?) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: url)!)
        if let t = token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        let (d, _) = try await URLSession.shared.data(for: req)
        return (try JSONSerialization.jsonObject(with: d) as? [String: Any]) ?? [:]
    }
    static func msOf(_ v: Any?) -> Double {
        guard let s = v as? String else { return 0 }
        let p = s.split(separator: "T"); guard p.count == 2 else { return 0 }
        let dmy = p[0].split(separator: "-").compactMap { Int($0) }
        let hm = p[1].split(separator: ":").compactMap { Int($0) }
        guard dmy.count == 3, hm.count >= 2 else { return 0 }
        var c = DateComponents(); c.year = dmy[0]; c.month = dmy[1]; c.day = dmy[2]; c.hour = hm[0]; c.minute = hm[1]
        return (Calendar.current.date(from: c)?.timeIntervalSince1970 ?? 0) * 1000
    }
    static func dateStr(_ s: String) -> (String, String) {
        let p = s.split(separator: "T"); guard p.count == 2 else { return (s, "") }
        let dmy = p[0].split(separator: "-").compactMap { Int($0) }
        let time = String(p[1].prefix(5)); guard dmy.count == 3 else { return (s, time) }
        var c = DateComponents(); c.year = dmy[0]; c.month = dmy[1]; c.day = dmy[2]
        let wd = Calendar.current.date(from: c).map { Calendar.current.component(.weekday, from: $0) } ?? 1
        return ("\(giorni[(wd-1) % 7]) \(dmy[2]) \(mesi[(dmy[1]-1) % 12])", time)
    }
    static func score(_ l: [String: Any]) -> (Int, Int) {
        let keys = ["p2m":2,"p3m":3,"ftm":1]; var us = 0, opp = 0
        for e in (l["events"] as? [[String: Any]]) ?? [] {
            let k = e["k"] as? String ?? ""
            if k.hasPrefix("op") { opp += Int(k.dropFirst(2)) ?? 0 }
            else if let p = keys[k] { us += p }
        }
        return (us, opp)
    }
}

// MARK: - Vista

struct WatchHome: View {
    @State private var info = WatchInfo()
    @State private var loading = true

    let orange = Color(red: 0.969, green: 0.580, blue: 0.113)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text(info.label).font(.system(size: 12, weight: .heavy)).foregroundColor(orange)
                Text(info.title).font(.system(size: info.live ? 30 : 20, weight: .heavy)).foregroundColor(.white)
                if !info.line1.isEmpty { Text(info.line1).font(.system(size: 14, weight: .semibold)) }
                if !info.line2.isEmpty { Text(info.line2).font(.system(size: 13)).foregroundColor(.gray) }
                if !info.standing.isEmpty {
                    Divider()
                    Text("📊 \(info.standing)").font(.system(size: 13, weight: .bold)).foregroundColor(orange)
                }
                if loading { ProgressView().padding(.top, 4) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .task { await refresh() }
    }

    func refresh() async {
        loading = true
        info = await WatchData.load()
        loading = false
    }
}
