import RecipiDesign
import SwiftUI
import UIKit

/// A recipe's photo, or a soft colored tile when it has none. The tile's
/// color comes from the title, so each recipe keeps its own.
struct RecipePhoto: View {
    let data: Data?
    var title: String = ""

    var body: some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            let color = TagColor.forName(title)
            Rectangle()
                .fill(color.background)
                .overlay {
                    Image(systemName: "fork.knife")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(color.foreground)
                }
        }
    }
}

enum RecipeFormat {
    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}
