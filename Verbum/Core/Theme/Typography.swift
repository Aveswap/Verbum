import SwiftUI

enum AppTypography {
    static let heroTitle  = Font.custom("Georgia-Bold", size: 32)
    static let wordTitle  = Font.system(size: 40, weight: .bold, design: .serif)
    static let phonetic   = Font.system(size: 15, weight: .regular, design: .monospaced)
    static let definition = Font.system(size: 18, weight: .regular)
    static let optionLabel = Font.system(size: 17, weight: .regular)
}
