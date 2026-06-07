import Foundation

extension String {
    var weatherSentenceCased: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}
