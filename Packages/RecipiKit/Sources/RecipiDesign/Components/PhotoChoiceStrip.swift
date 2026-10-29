import SwiftUI

/// A row of photo thumbnails to pick from, the picked one outlined in the
/// accent, with an optional "No photo" tile at the end. Used when an
/// imported page offers more than one photo.
public struct PhotoChoiceStrip<ID: Hashable>: View {
    public struct Choice: Identifiable {
        public var id: ID
        public var image: Image

        public init(id: ID, image: Image) {
            self.id = id
            self.image = image
        }
    }

    let choices: [Choice]
    @Binding var selection: ID?
    let allowsNone: Bool

    public init(choices: [Choice], selection: Binding<ID?>, allowsNone: Bool = true) {
        self.choices = choices
        self._selection = selection
        self.allowsNone = allowsNone
    }

    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 64

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(Array(choices.enumerated()), id: \.element.id) { index, choice in
                    Button {
                        selection = choice.id
                    } label: {
                        choice.image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(tileShape)
                            .overlay { outline(isSelected: selection == choice.id) }
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Photo \(index + 1) of \(choices.count)")
                    .accessibilityAddTraits(selection == choice.id ? .isSelected : [])
                }
                if allowsNone {
                    Button {
                        selection = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .accessibilityHidden(true)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(width: size, height: size)
                            .background(Theme.Colors.fill, in: tileShape)
                            .overlay { outline(isSelected: selection == nil) }
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("No photo")
                    .accessibilityAddTraits(selection == nil ? .isSelected : [])
                }
            }
            // Room for the selection outline.
            .padding(2)
        }
        .motion(Motion.snappy, value: selection)
    }

    private var tileShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
    }

    private func outline(isSelected: Bool) -> some View {
        tileShape.strokeBorder(isSelected ? Theme.Colors.accent : Theme.Colors.border, lineWidth: isSelected ? 2.5 : 0.5)
    }
}
