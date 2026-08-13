import SwiftUI

struct ElapsedTimer: View {
    var range: ClosedRange<Date>
    var size: CGFloat
    var width: CGFloat
    var align: Alignment

    var body: some View {
        let textAlign: TextAlignment = align == .trailing ? .trailing : .leading
        return Text(timerInterval: range, countsDown: false, showsHours: true)
            .font(.system(size: size, weight: .heavy).monospacedDigit())
            .foregroundStyle(Theme.accentOn)
            .multilineTextAlignment(textAlign)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: width, height: size + 4, alignment: align)
            .clipped()
    }
}
