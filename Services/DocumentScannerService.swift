import Foundation
import SwiftUI
import VisionKit
import PDFKit
import UIKit

// MARK: - Document Scanner Service
// Belge/fiş yakalama için iki yol sağlar:
//  1. VNDocumentCameraViewController — çok sayfalı kamera taraması (yerleşik).
//  2. PDF/foto import — PDF'ler PDFKit ile 2x ölçekte sayfa görüntülerine dönüştürülür.
// Tamamen cihaz üstü, ağ yok.
enum DocumentScannerService {

    // MARK: - PDF → görüntüler
    /// PDF verisini her sayfa için 2x ölçekli UIImage dizisine dönüştürür.
    static func renderPDFPages(from data: Data, scale: CGFloat = 2.0) -> [UIImage] {
        guard let document = PDFDocument(data: data) else { return [] }
        var images: [UIImage] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            let image = renderer.image { ctx in
                UIColor.white.set()
                ctx.fill(CGRect(origin: .zero, size: size))
                ctx.cgContext.translateBy(x: 0, y: size.height)
                ctx.cgContext.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            images.append(image)
        }
        return images
    }

    /// PDF veya görüntü dosyasını sayfa görüntülerine indirger.
    static func images(fromFileData data: Data, fileName: String) -> [UIImage] {
        if fileName.lowercased().hasSuffix(".pdf") {
            return renderPDFPages(from: data)
        }
        if let image = UIImage(data: data) {
            return [image]
        }
        return []
    }

    /// JPEG sıkıştırması — Receipt.pageImagesData için depolama dostu boyut.
    static func jpegData(for images: [UIImage], quality: CGFloat = 0.8) -> [Data] {
        images.compactMap { $0.jpegData(compressionQuality: quality) }
    }
}

// MARK: - Document Camera (SwiftUI wrapper)
// VNDocumentCameraViewController'ı SwiftUI'a bağlar. Çok sayfalı yakalama yerleşiktir.
struct DocumentCameraView: UIViewControllerRepresentable {
    let onComplete: ([UIImage]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onComplete: ([UIImage]) -> Void
        let onCancel: () -> Void

        init(onComplete: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onComplete = onComplete
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for index in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: index))
            }
            onComplete(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onCancel()
        }
    }
}
