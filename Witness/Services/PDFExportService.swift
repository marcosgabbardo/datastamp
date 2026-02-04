import Foundation
import UIKit
import PDFKit
import CoreImage.CIFilterBuiltins

/// Service for generating PDF certificates of timestamps
actor PDFExportService {
    
    private let storageService = StorageService()
    
    // MARK: - PDF Generation
    
    /// Generate a PDF certificate for a timestamp
    func generateCertificate(
        for item: WitnessItemSnapshot,
        contentImage: UIImage? = nil
    ) async throws -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // Letter size
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        let pdfData = renderer.pdfData { context in
            context.beginPage()
            drawCertificate(in: context.cgContext, pageRect: pageRect, item: item, contentImage: contentImage)
        }
        
        return pdfData
    }
    
    /// Save PDF certificate to a temporary file and return URL
    func saveCertificateToFile(
        data: Data,
        itemId: UUID
    ) async throws -> URL {
        let filename = "Witness_Certificate_\(itemId.uuidString.prefix(8)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }
    
    // MARK: - Drawing
    
    private func drawCertificate(
        in context: CGContext,
        pageRect: CGRect,
        item: WitnessItemSnapshot,
        contentImage: UIImage?
    ) {
        let margin: CGFloat = 50
        let contentWidth = pageRect.width - (margin * 2)
        var yPosition = pageRect.height - margin
        
        // Colors
        let primaryColor = UIColor(red: 0.95, green: 0.6, blue: 0.1, alpha: 1.0) // Orange
        let textColor = UIColor.black
        let subtitleColor = UIColor.darkGray
        let borderColor = UIColor.lightGray
        
        // === HEADER ===
        
        // Top border line
        context.setStrokeColor(primaryColor.cgColor)
        context.setLineWidth(3)
        context.move(to: CGPoint(x: margin, y: yPosition))
        context.addLine(to: CGPoint(x: pageRect.width - margin, y: yPosition))
        context.strokePath()
        
        yPosition -= 40
        
        // Title
        let titleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
        let title = "Timestamp Certificate"
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: textColor
        ]
        let titleSize = title.size(withAttributes: titleAttr)
        title.draw(at: CGPoint(x: (pageRect.width - titleSize.width) / 2, y: pageRect.height - yPosition - titleSize.height), withAttributes: titleAttr)
        
        yPosition -= titleSize.height + 10
        
        // Subtitle
        let subtitleFont = UIFont.systemFont(ofSize: 14, weight: .regular)
        let subtitle = "Powered by OpenTimestamps & Bitcoin"
        let subtitleAttr: [NSAttributedString.Key: Any] = [
            .font: subtitleFont,
            .foregroundColor: subtitleColor
        ]
        let subtitleSize = subtitle.size(withAttributes: subtitleAttr)
        subtitle.draw(at: CGPoint(x: (pageRect.width - subtitleSize.width) / 2, y: pageRect.height - yPosition - subtitleSize.height), withAttributes: subtitleAttr)
        
        yPosition -= subtitleSize.height + 30
        
        // === STATUS BADGE ===
        
        let badgeHeight: CGFloat = 36
        let badgeWidth: CGFloat = 180
        let badgeX = (pageRect.width - badgeWidth) / 2
        let badgeY = pageRect.height - yPosition - badgeHeight
        
        let badgeColor: UIColor
        let badgeText: String
        let badgeIcon: String
        
        switch item.status {
        case .confirmed, .verified:
            badgeColor = UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
            badgeText = "✓ VERIFIED"
            badgeIcon = "checkmark.seal.fill"
        case .submitted:
            badgeColor = UIColor(red: 0.95, green: 0.6, blue: 0.1, alpha: 1.0)
            badgeText = "⏳ PENDING"
            badgeIcon = "clock.fill"
        case .pending:
            badgeColor = UIColor.gray
            badgeText = "○ DRAFT"
            badgeIcon = "circle"
        case .failed:
            badgeColor = UIColor.red
            badgeText = "✗ FAILED"
            badgeIcon = "xmark.circle.fill"
        }
        
        let badgePath = UIBezierPath(roundedRect: CGRect(x: badgeX, y: badgeY, width: badgeWidth, height: badgeHeight), cornerRadius: badgeHeight / 2)
        context.setFillColor(badgeColor.cgColor)
        context.addPath(badgePath.cgPath)
        context.fillPath()
        
        let badgeFont = UIFont.systemFont(ofSize: 16, weight: .bold)
        let badgeAttr: [NSAttributedString.Key: Any] = [
            .font: badgeFont,
            .foregroundColor: UIColor.white
        ]
        let badgeTextSize = badgeText.size(withAttributes: badgeAttr)
        badgeText.draw(at: CGPoint(x: badgeX + (badgeWidth - badgeTextSize.width) / 2, y: badgeY + (badgeHeight - badgeTextSize.height) / 2), withAttributes: badgeAttr)
        
        yPosition -= badgeHeight + 40
        
        // === CONTENT PREVIEW ===
        
        if let image = contentImage {
            let maxImageHeight: CGFloat = 150
            let maxImageWidth: CGFloat = contentWidth - 100
            let aspectRatio = image.size.width / image.size.height
            
            var imageWidth = maxImageWidth
            var imageHeight = imageWidth / aspectRatio
            
            if imageHeight > maxImageHeight {
                imageHeight = maxImageHeight
                imageWidth = imageHeight * aspectRatio
            }
            
            let imageX = (pageRect.width - imageWidth) / 2
            let imageY = pageRect.height - yPosition - imageHeight
            
            // Draw border
            context.setStrokeColor(borderColor.cgColor)
            context.setLineWidth(1)
            context.stroke(CGRect(x: imageX - 2, y: imageY - 2, width: imageWidth + 4, height: imageHeight + 4))
            
            // Draw image
            image.draw(in: CGRect(x: imageX, y: imageY, width: imageWidth, height: imageHeight))
            
            yPosition -= imageHeight + 30
        } else if let textContent = item.textContent {
            // Draw text content in a box
            let textBoxHeight: CGFloat = 80
            let textBoxY = pageRect.height - yPosition - textBoxHeight
            
            context.setStrokeColor(borderColor.cgColor)
            context.setLineWidth(1)
            context.stroke(CGRect(x: margin + 20, y: textBoxY, width: contentWidth - 40, height: textBoxHeight))
            
            let contentFont = UIFont.systemFont(ofSize: 12, weight: .regular)
            let truncatedText = String(textContent.prefix(500)) + (textContent.count > 500 ? "..." : "")
            let contentAttr: [NSAttributedString.Key: Any] = [
                .font: contentFont,
                .foregroundColor: textColor
            ]
            
            let textRect = CGRect(x: margin + 30, y: textBoxY + 10, width: contentWidth - 60, height: textBoxHeight - 20)
            truncatedText.draw(in: textRect, withAttributes: contentAttr)
            
            yPosition -= textBoxHeight + 30
        }
        
        // === DETAILS SECTION ===
        
        yPosition = drawSectionHeader("Document Information", at: yPosition, in: context, pageRect: pageRect, margin: margin, color: primaryColor)
        
        // Title
        if let title = item.title {
            yPosition = drawDetailRow("Title:", title, at: yPosition, in: context, pageRect: pageRect, margin: margin)
        }
        
        // Type
        let typeString: String
        switch item.contentType {
        case .text: typeString = "Text Document"
        case .photo: typeString = "Photograph"
        case .file: typeString = "File (\(item.contentFileName ?? "unknown"))"
        }
        yPosition = drawDetailRow("Type:", typeString, at: yPosition, in: context, pageRect: pageRect, margin: margin)
        
        // Created
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .medium
        yPosition = drawDetailRow("Created:", dateFormatter.string(from: item.createdAt), at: yPosition, in: context, pageRect: pageRect, margin: margin)
        
        yPosition -= 20
        
        // === CRYPTOGRAPHIC PROOF ===
        
        yPosition = drawSectionHeader("Cryptographic Proof", at: yPosition, in: context, pageRect: pageRect, margin: margin, color: primaryColor)
        
        // Hash
        yPosition = drawDetailRow("SHA-256 Hash:", "", at: yPosition, in: context, pageRect: pageRect, margin: margin)
        yPosition = drawMonospaceText(item.hashHex, at: yPosition, in: context, pageRect: pageRect, margin: margin)
        
        // Calendar
        if let calendarUrl = item.calendarUrl {
            yPosition = drawDetailRow("Calendar Server:", calendarUrl, at: yPosition, in: context, pageRect: pageRect, margin: margin)
        }
        
        // Submitted
        if let submittedAt = item.submittedAt {
            yPosition = drawDetailRow("Submitted:", dateFormatter.string(from: submittedAt), at: yPosition, in: context, pageRect: pageRect, margin: margin)
        }
        
        yPosition -= 20
        
        // === BITCOIN ATTESTATION ===
        
        if item.status == .confirmed || item.status == .verified {
            yPosition = drawSectionHeader("Bitcoin Blockchain Attestation", at: yPosition, in: context, pageRect: pageRect, margin: margin, color: primaryColor)
            
            if let blockHeight = item.bitcoinBlockHeight {
                yPosition = drawDetailRow("Block Height:", "#\(blockHeight)", at: yPosition, in: context, pageRect: pageRect, margin: margin)
            }
            
            if let blockTime = item.bitcoinBlockTime {
                yPosition = drawDetailRow("Block Time:", dateFormatter.string(from: blockTime), at: yPosition, in: context, pageRect: pageRect, margin: margin)
            }
            
            if let txId = item.bitcoinTxId, !txId.isEmpty {
                yPosition = drawDetailRow("Transaction:", "", at: yPosition, in: context, pageRect: pageRect, margin: margin)
                yPosition = drawMonospaceText(txId, at: yPosition, in: context, pageRect: pageRect, margin: margin)
            }
            
            yPosition -= 20
        }
        
        // === QR CODE ===
        
        if let qrImage = generateQRCode(for: item) {
            let qrSize: CGFloat = 100
            let qrX = pageRect.width - margin - qrSize
            let qrY: CGFloat = margin + 20
            
            qrImage.draw(in: CGRect(x: qrX, y: qrY, width: qrSize, height: qrSize))
            
            // QR label
            let qrLabelFont = UIFont.systemFont(ofSize: 8, weight: .regular)
            let qrLabel = "Verify on blockchain"
            let qrLabelAttr: [NSAttributedString.Key: Any] = [
                .font: qrLabelFont,
                .foregroundColor: subtitleColor
            ]
            let qrLabelSize = qrLabel.size(withAttributes: qrLabelAttr)
            qrLabel.draw(at: CGPoint(x: qrX + (qrSize - qrLabelSize.width) / 2, y: qrY + qrSize + 4), withAttributes: qrLabelAttr)
        }
        
        // === FOOTER ===
        
        // Bottom border
        context.setStrokeColor(primaryColor.cgColor)
        context.setLineWidth(2)
        context.move(to: CGPoint(x: margin, y: margin))
        context.addLine(to: CGPoint(x: pageRect.width - margin, y: margin))
        context.strokePath()
        
        // Footer text
        let footerFont = UIFont.systemFont(ofSize: 9, weight: .regular)
        let footerText = "This certificate was generated by Witness app. Verify authenticity using the .ots proof file and opentimestamps.org"
        let footerAttr: [NSAttributedString.Key: Any] = [
            .font: footerFont,
            .foregroundColor: subtitleColor
        ]
        let footerRect = CGRect(x: margin, y: margin + 10, width: contentWidth, height: 30)
        footerText.draw(in: footerRect, withAttributes: footerAttr)
        
        // Witness logo text
        let logoFont = UIFont.systemFont(ofSize: 10, weight: .bold)
        let logoText = "WITNESS"
        let logoAttr: [NSAttributedString.Key: Any] = [
            .font: logoFont,
            .foregroundColor: primaryColor
        ]
        logoText.draw(at: CGPoint(x: margin, y: margin + 30), withAttributes: logoAttr)
    }
    
    private func drawSectionHeader(
        _ text: String,
        at yPosition: CGFloat,
        in context: CGContext,
        pageRect: CGRect,
        margin: CGFloat,
        color: UIColor
    ) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let attr: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let size = text.size(withAttributes: attr)
        
        let y = pageRect.height - yPosition - size.height
        text.draw(at: CGPoint(x: margin, y: y), withAttributes: attr)
        
        // Underline
        context.setStrokeColor(color.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: margin, y: y + size.height + 2))
        context.addLine(to: CGPoint(x: pageRect.width - margin, y: y + size.height + 2))
        context.strokePath()
        
        return yPosition - size.height - 15
    }
    
    private func drawDetailRow(
        _ label: String,
        _ value: String,
        at yPosition: CGFloat,
        in context: CGContext,
        pageRect: CGRect,
        margin: CGFloat
    ) -> CGFloat {
        let labelFont = UIFont.systemFont(ofSize: 11, weight: .medium)
        let valueFont = UIFont.systemFont(ofSize: 11, weight: .regular)
        
        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor.darkGray
        ]
        let valueAttr: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: UIColor.black
        ]
        
        let labelSize = label.size(withAttributes: labelAttr)
        let y = pageRect.height - yPosition - labelSize.height
        
        label.draw(at: CGPoint(x: margin + 10, y: y), withAttributes: labelAttr)
        
        if !value.isEmpty {
            value.draw(at: CGPoint(x: margin + 120, y: y), withAttributes: valueAttr)
        }
        
        return yPosition - labelSize.height - 8
    }
    
    private func drawMonospaceText(
        _ text: String,
        at yPosition: CGFloat,
        in context: CGContext,
        pageRect: CGRect,
        margin: CGFloat
    ) -> CGFloat {
        let font = UIFont.monospacedSystemFont(ofSize: 8, weight: .regular)
        let attr: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
            .backgroundColor: UIColor(white: 0.95, alpha: 1.0)
        ]
        
        // Split into lines if too long
        let maxCharsPerLine = 70
        var currentY = yPosition
        var index = text.startIndex
        
        while index < text.endIndex {
            let endIndex = text.index(index, offsetBy: min(maxCharsPerLine, text.distance(from: index, to: text.endIndex)))
            let line = String(text[index..<endIndex])
            
            let size = line.size(withAttributes: attr)
            let y = pageRect.height - currentY - size.height
            
            // Background
            context.setFillColor(UIColor(white: 0.95, alpha: 1.0).cgColor)
            context.fill(CGRect(x: margin + 10, y: y - 2, width: size.width + 10, height: size.height + 4))
            
            line.draw(at: CGPoint(x: margin + 15, y: y), withAttributes: attr)
            
            currentY -= size.height + 4
            index = endIndex
        }
        
        return currentY - 8
    }
    
    private func generateQRCode(for item: WitnessItemSnapshot) -> UIImage? {
        // Generate QR code with blockchain verification URL
        var urlString: String
        
        if let txId = item.bitcoinTxId, !txId.isEmpty {
            urlString = "https://blockstream.info/tx/\(txId)"
        } else if let blockHeight = item.bitcoinBlockHeight {
            urlString = "https://blockstream.info/block-height/\(blockHeight)"
        } else {
            // Use OTS verification URL
            urlString = "https://opentimestamps.org"
        }
        
        guard let data = urlString.data(using: .utf8) else { return nil }
        
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else { return nil }
        
        // Scale up the QR code
        let scale = 10.0
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Snapshot Model

/// Immutable snapshot of WitnessItem for thread-safe PDF generation
struct WitnessItemSnapshot: Sendable {
    let id: UUID
    let createdAt: Date
    let contentType: ContentType
    let contentHash: Data
    let contentFileName: String?
    let textContent: String?
    let title: String?
    let status: WitnessStatus
    let calendarUrl: String?
    let submittedAt: Date?
    let confirmedAt: Date?
    let bitcoinBlockHeight: Int?
    let bitcoinBlockTime: Date?
    let bitcoinTxId: String?
    
    var hashHex: String {
        contentHash.map { String(format: "%02x", $0) }.joined()
    }
    
    init(from item: WitnessItem) {
        self.id = item.id
        self.createdAt = item.createdAt
        self.contentType = item.contentType
        self.contentHash = item.contentHash
        self.contentFileName = item.contentFileName
        self.textContent = item.textContent
        self.title = item.title
        self.status = item.status
        self.calendarUrl = item.calendarUrl
        self.submittedAt = item.submittedAt
        self.confirmedAt = item.confirmedAt
        self.bitcoinBlockHeight = item.bitcoinBlockHeight
        self.bitcoinBlockTime = item.bitcoinBlockTime
        self.bitcoinTxId = item.bitcoinTxId
    }
    
    /// Memberwise initializer for testing and direct construction
    init(
        id: UUID,
        createdAt: Date,
        contentType: ContentType,
        contentHash: Data,
        contentFileName: String?,
        textContent: String?,
        title: String?,
        status: WitnessStatus,
        calendarUrl: String?,
        submittedAt: Date?,
        confirmedAt: Date?,
        bitcoinBlockHeight: Int?,
        bitcoinBlockTime: Date?,
        bitcoinTxId: String?
    ) {
        self.id = id
        self.createdAt = createdAt
        self.contentType = contentType
        self.contentHash = contentHash
        self.contentFileName = contentFileName
        self.textContent = textContent
        self.title = title
        self.status = status
        self.calendarUrl = calendarUrl
        self.submittedAt = submittedAt
        self.confirmedAt = confirmedAt
        self.bitcoinBlockHeight = bitcoinBlockHeight
        self.bitcoinBlockTime = bitcoinBlockTime
        self.bitcoinTxId = bitcoinTxId
    }
}
