import Foundation
import QuickLook

protocol QuickLookPreviewControllerDataSource: QLPreviewControllerDataSource {
    var previewController: QuickLookPreviewController? { get set }
}

class QuickLookPreviewController: QLPreviewController {
    var dataSourceStorage: QuickLookPreviewControllerDataSource?
}
