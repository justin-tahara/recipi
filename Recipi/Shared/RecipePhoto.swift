import RecipiDesign
import SwiftUI
import UIKit

/// A recipe's photo, or a soft colored tile when it has none. The tile's
/// color comes from the title, so each recipe keeps its own.
///
/// VoiceOver reads a photo as "Photo of <title>" (or `photoLabel`,
/// when given) and skips the tile, which only decorates. Where the title is
/// read right next to the photo, hide the photo instead.
struct RecipePhoto: View {
    let data: Data?
    var title: String = ""
    /// What VoiceOver calls the photo, if not "Photo of <title>".
    var photoLabel: String?

    var body: some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .accessibilityLabel(photoLabel ?? (title.isEmpty ? "Recipe photo" : "Photo of \(title)"))
        } else {
            let color = TagColor.forName(title)
            Rectangle()
                .fill(color.background)
                .overlay {
                    Image(systemName: "fork.knife")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(color.foreground)
                }
                .accessibilityHidden(true)
        }
    }
}

enum RecipeFormat {
    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}
