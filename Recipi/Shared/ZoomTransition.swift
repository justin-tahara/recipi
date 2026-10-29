import SwiftUI

// The library-to-recipe zoom uses iOS 18 APIs. On iOS 17, and whenever
// Reduce Motion is on, recipes push the standard way instead.

extension View {
    /// Marks the view a recipe zooms out of.
    @ViewBuilder
    func zoomTransitionSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// Zooms a pushed screen out of its source.
    @ViewBuilder
    func zoomTransition(sourceID: some Hashable, in namespace: Namespace.ID, isEnabled: Bool) -> some View {
        if #available(iOS 18.0, *) {
            if isEnabled {
                navigationTransition(.zoom(sourceID: sourceID, in: namespace))
            } else {
                self
            }
        } else {
            self
        }
    }
}
