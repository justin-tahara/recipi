import RecipiKit
import SwiftUI
import UIKit

/// Safari's share sheet entry point. Hosts a small SwiftUI view that
/// imports the shared link straight into the shared recipe store.
final class ShareViewController: UIViewController {
    private var model: ShareImportModel?

    override func viewDidLoad() {
        super.viewDidLoad()

        let model = ShareImportModel(extensionContext: extensionContext)
        self.model = model

        let host = UIHostingController(rootView: ShareImportView(model: model))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        Task { await model.run() }
    }
}
