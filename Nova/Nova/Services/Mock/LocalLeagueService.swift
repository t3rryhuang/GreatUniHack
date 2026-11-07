import Foundation

/// Demo leagues: the signed-in teen plus friends and classmates.
final class LocalLeagueService: LeagueServicing {
    func leagues(me: LeagueEntry) async -> [League] {
        let friends = [
            LeagueEntry(name: "Maya Ahmed", rank: .gold, badges: 2, weeklyPoints: 140, improvement: 35),
            LeagueEntry(name: "Leo Byrne", rank: .silver, badges: 1, weeklyPoints: 95, improvement: 60),
            LeagueEntry(name: "Zara Khan", rank: .silver, badges: 0, weeklyPoints: 60, improvement: 12),
            LeagueEntry(name: "Sam Hughes", rank: .bronze, badges: 1, weeklyPoints: 30, improvement: 48)
        ]
        let school = friends + [
            LeagueEntry(name: "Aisha Rahman", rank: .platinum, badges: 4, weeklyPoints: 150, improvement: 20),
            LeagueEntry(name: "Tom Okafor", rank: .gold, badges: 3, weeklyPoints: 120, improvement: 8),
            LeagueEntry(name: "Ellie Clarke", rank: .bronze, badges: 0, weeklyPoints: 15, improvement: 70),
            LeagueEntry(name: "Jack Murphy", rank: .silver, badges: 2, weeklyPoints: 75, improvement: -5)
        ]
        return [
            League(kind: .friends, name: "Friends", entries: LeagueRules.ranked(friends + [me])),
            League(kind: .school, name: "Year 12 league", entries: LeagueRules.ranked(school + [me]))
        ]
    }
}
