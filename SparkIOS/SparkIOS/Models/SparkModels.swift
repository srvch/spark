import SwiftUI

enum SparkCategory: String, CaseIterable, Identifiable {
    case sports = "Sports"
    case transit = "Transit"
    case fun = "Fun"
    case culture = "Culture"
    case life = "Life"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .sports: SparkTheme.Colors.success
        case .transit: SparkTheme.Colors.transit
        case .fun: SparkTheme.Colors.fun
        case .culture: SparkTheme.Colors.culture
        case .life: SparkTheme.Colors.life
        }
    }

    var icon: String {
        switch self {
        case .sports: "figure.run"
        case .transit: "car.fill"
        case .fun: "sparkles"
        case .culture: "music.note"
        case .life: "house.fill"
        }
    }
}

struct SparkEvent: Identifiable {
    let id = UUID()
    let title: String
    let category: SparkCategory
    let subtitle: String
    let location: String
    let spotsLeft: Int
    let distance: String
}

extension SparkEvent {
    static let sample: [SparkEvent] = [
        SparkEvent(title: "Box cricket at Turf 27", category: .sports, subtitle: "Starts in 2h", location: "Indiranagar", spotsLeft: 3, distance: "4 km"),
        SparkEvent(title: "Airport ride split to T1", category: .transit, subtitle: "Leaves in 35 min", location: "Domlur pickup", spotsLeft: 2, distance: "2.2 km"),
        SparkEvent(title: "Board game table at Cubby", category: .fun, subtitle: "7:15 PM tonight", location: "100 Feet Road", spotsLeft: 4, distance: "1.6 km"),
        SparkEvent(title: "Late comedy room at Third Wave", category: .culture, subtitle: "8:00 PM", location: "CMH Road", spotsLeft: 1, distance: "2.9 km"),
        SparkEvent(title: "Sunday house hunting loop", category: .life, subtitle: "Tomorrow morning", location: "South block", spotsLeft: 2, distance: "5.3 km")
    ]
}
