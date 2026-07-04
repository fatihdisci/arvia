import Foundation

// MARK: - Recent Record Item
struct RecentRecordItem: Identifiable {
    let id: UUID; let type: RecordType; let title: String; let subtitle: String; let date: Date; let icon: String
    enum RecordType { case expense; case service }
}
