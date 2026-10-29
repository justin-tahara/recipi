import SwiftUI

// The library-to-recipe zoom. When Reduce Motion is on, recipes push the
// standard way instead.

extension View {
    /// Marks the view a recipe zooms out of.
    func zoomTransitionSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        matchedTransitionSource(id: id, in: namespace)
    }

    /// Zooms a pushed screen out of its source.
    @ViewBuilder
    func zoomTransition(sourceID: some Hashable, in namespace: Namespace.ID, isEnabled: Bool) -> some View {
        if isEnabled {
            navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            self
        }
    }
}
