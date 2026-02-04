import Foundation
import UIKit
import PDFKit
import CoreImage.CIFilterBuiltins

/// Service for generating PDF certificates of timestamps
actor PDFExportService {
    
    // MARK: - Brand Colors
    
    private let bitcoinOrange = UIColor(red: 247/255, green: 147/255, blue: 26/255, alpha: 1.0)
    private let darkText = UIColor(red: 30/255, green: 30/255, blue: 30/255, alpha: 1.0)
    private let mediumText = UIColor(red: 80/255, green: 80/255, blue: 80/255, alpha: 1.0)
    private let lightText = UIColor(red: 130/255, green: 130/255, blue: 130/255, alpha: 1.0)
    private let borderGold = UIColor(red: 212/255, green: 175/255, blue: 55/255, alpha: 1.0)
    private let backgroundCream = UIColor(red: 253/255, green: 251/255, blue: 247/255, alpha: 1.0)
    
    // MARK: - PDF Generation
    
    /// Generate a PDF certificate for a timestamp
    func generateCertificate(
        for item: DataStampItemSnapshot,
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
        let filename = "DataStamp_Certificate_\(itemId.uuidString.prefix(8)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }
    
    // MARK: - Main Drawing
    
    private func drawCertificate(
        in context: CGContext,
        pageRect: CGRect,
        item: DataStampItemSnapshot,
        contentImage: UIImage?
    ) {
        let margin: CGFloat = 40
        let innerMargin: CGFloat = 55
        var yPosition: CGFloat = margin
        
        // === BACKGROUND ===
        context.setFillColor(backgroundCream.cgColor)
        context.fill(pageRect)
        
        // === DECORATIVE BORDER (Triple line - certificate style) ===
        drawCertificateBorder(context: context, pageRect: pageRect, margin: margin)
        
        // === CORNER ORNAMENTS ===
        drawCornerOrnaments(context: context, pageRect: pageRect, margin: margin)
        
        yPosition += 25
        
        // === HEADER SEAL ===
        let sealSize: CGFloat = 60
        let sealX = (pageRect.width - sealSize) / 2
        let sealY = pageRect.height - yPosition - sealSize
        drawBitcoinSeal(context: context, at: CGPoint(x: sealX, y: sealY), size: sealSize)
        
        yPosition += sealSize + 15
        
        // === TITLE ===
        let titleFont = UIFont(name: "Georgia-Bold", size: 26) ?? UIFont.systemFont(ofSize: 26, weight: .bold)
        let title = "CERTIFICATE OF EXISTENCE"
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: darkText,
            .kern: 2.0
        ]
        let titleSize = title.size(withAttributes: titleAttr)
        let titleX = (pageRect.width - titleSize.width) / 2
        let titleY = pageRect.height - yPosition - titleSize.height
        title.draw(at: CGPoint(x: titleX, y: titleY), withAttributes: titleAttr)
        
        yPosition += titleSize.height + 6
        
        // === SUBTITLE ===
        let subtitleFont = UIFont(name: "Georgia-Italic", size: 11) ?? UIFont.italicSystemFont(ofSize: 11)
        let subtitle = "Cryptographic Proof Anchored to the Bitcoin Blockchain"
        let subtitleAttr: [NSAttributedString.Key: Any] = [
            .font: subtitleFont,
            .foregroundColor: mediumText
        ]
        let subtitleSize = subtitle.size(withAttributes: subtitleAttr)
        let subtitleX = (pageRect.width - subtitleSize.width) / 2
        let subtitleY = pageRect.height - yPosition - subtitleSize.height
        subtitle.draw(at: CGPoint(x: subtitleX, y: subtitleY), withAttributes: subtitleAttr)
        
        yPosition += subtitleSize.height + 8
        
        // === DECORATIVE LINE ===
        drawDecorativeLine(context: context, y: pageRect.height - yPosition, pageRect: pageRect, margin: innerMargin + 30)
        
        yPosition += 20
        
        // === STATUS BADGE ===
        let badgeY = pageRect.height - yPosition - 28
        drawStatusBadge(context: context, status: item.status, centerX: pageRect.width / 2, y: badgeY)
        
        yPosition += 38
        
        // === CERTIFICATE NUMBER ===
        let certNumFont = UIFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        let certNum = "Certificate No. \(item.id.uuidString.prefix(8).uppercased())"
        let certNumAttr: [NSAttributedString.Key: Any] = [
            .font: certNumFont,
            .foregroundColor: lightText
        ]
        let certNumSize = certNum.size(withAttributes: certNumAttr)
        certNum.draw(at: CGPoint(x: (pageRect.width - certNumSize.width) / 2, y: pageRect.height - yPosition - certNumSize.height), withAttributes: certNumAttr)
        
        yPosition += certNumSize.height + 20
        
        // === MAIN CONTENT AREA ===
        let contentStartY = yPosition
        
        // Left column - Document Info
        let leftColumnX = innerMargin
        let columnWidth = (pageRect.width - innerMargin * 2 - 30) / 2
        
        yPosition = drawSection(
            context: context,
            title: "DOCUMENT",
            items: buildDocumentItems(item),
            startY: yPosition,
            x: leftColumnX,
            width: columnWidth,
            pageRect: pageRect
        )
        
        // Right column - Blockchain Proof
        var rightYPosition = contentStartY
        rightYPosition = drawSection(
            context: context,
            title: "BLOCKCHAIN ATTESTATION",
            items: buildBlockchainItems(item),
            startY: rightYPosition,
            x: leftColumnX + columnWidth + 30,
            width: columnWidth,
            pageRect: pageRect
        )
        
        yPosition = max(yPosition, rightYPosition) + 10
        
        // === HASH DISPLAY (Full Width) ===
        yPosition = drawHashSection(context: context, hash: item.hashHex, y: yPosition, pageRect: pageRect, margin: innerMargin)
        
        // === QR CODE SECTION ===
        yPosition += 5
        drawQRSection(context: context, item: item, y: yPosition, pageRect: pageRect, margin: innerMargin)
        
        // === FOOTER ===
        drawFooter(context: context, pageRect: pageRect, margin: margin)
    }
    
    // MARK: - Border & Ornaments
    
    private func drawCertificateBorder(context: CGContext, pageRect: CGRect, margin: CGFloat) {
        // Outer border
        context.setStrokeColor(borderGold.cgColor)
        context.setLineWidth(3)
        context.stroke(pageRect.insetBy(dx: margin - 5, dy: margin - 5))
        
        // Middle border
        context.setStrokeColor(bitcoinOrange.cgColor)
        context.setLineWidth(1)
        context.stroke(pageRect.insetBy(dx: margin + 5, dy: margin + 5))
        
        // Inner border
        context.setStrokeColor(borderGold.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(0.5)
        context.stroke(pageRect.insetBy(dx: margin + 10, dy: margin + 10))
    }
    
    private func drawCornerOrnaments(context: CGContext, pageRect: CGRect, margin: CGFloat) {
        let ornamentSize: CGFloat = 15
        let inset = margin + 2
        
        context.setStrokeColor(borderGold.cgColor)
        context.setLineWidth(2)
        
        // Top-left
        context.move(to: CGPoint(x: inset, y: pageRect.height - inset - ornamentSize))
        context.addLine(to: CGPoint(x: inset, y: pageRect.height - inset))
        context.addLine(to: CGPoint(x: inset + ornamentSize, y: pageRect.height - inset))
        context.strokePath()
        
        // Top-right
        context.move(to: CGPoint(x: pageRect.width - inset - ornamentSize, y: pageRect.height - inset))
        context.addLine(to: CGPoint(x: pageRect.width - inset, y: pageRect.height - inset))
        context.addLine(to: CGPoint(x: pageRect.width - inset, y: pageRect.height - inset - ornamentSize))
        context.strokePath()
        
        // Bottom-left
        context.move(to: CGPoint(x: inset, y: inset + ornamentSize))
        context.addLine(to: CGPoint(x: inset, y: inset))
        context.addLine(to: CGPoint(x: inset + ornamentSize, y: inset))
        context.strokePath()
        
        // Bottom-right
        context.move(to: CGPoint(x: pageRect.width - inset - ornamentSize, y: inset))
        context.addLine(to: CGPoint(x: pageRect.width - inset, y: inset))
        context.addLine(to: CGPoint(x: pageRect.width - inset, y: inset + ornamentSize))
        context.strokePath()
    }
    
    private func drawBitcoinSeal(context: CGContext, at point: CGPoint, size: CGFloat) {
        let centerX = point.x + size / 2
        let centerY = point.y + size / 2
        
        // Outer circle
        context.setFillColor(bitcoinOrange.cgColor)
        context.fillEllipse(in: CGRect(x: point.x, y: point.y, width: size, height: size))
        
        // Inner circle
        let innerSize = size - 8
        let innerOffset = (size - innerSize) / 2
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2)
        context.strokeEllipse(in: CGRect(x: point.x + innerOffset, y: point.y + innerOffset, width: innerSize, height: innerSize))
        
        // Bitcoin "₿" symbol
        let btcFont = UIFont.systemFont(ofSize: size * 0.45, weight: .bold)
        let btcAttr: [NSAttributedString.Key: Any] = [
            .font: btcFont,
            .foregroundColor: UIColor.white
        ]
        let btcText = "₿"
        let btcSize = btcText.size(withAttributes: btcAttr)
        btcText.draw(at: CGPoint(x: centerX - btcSize.width / 2, y: centerY - btcSize.height / 2), withAttributes: btcAttr)
    }
    
    private func drawDecorativeLine(context: CGContext, y: CGFloat, pageRect: CGRect, margin: CGFloat) {
        let centerX = pageRect.width / 2
        let lineLength: CGFloat = 80
        
        context.setStrokeColor(borderGold.cgColor)
        context.setLineWidth(1)
        
        // Left line
        context.move(to: CGPoint(x: margin, y: y))
        context.addLine(to: CGPoint(x: centerX - lineLength / 2 - 10, y: y))
        context.strokePath()
        
        // Right line
        context.move(to: CGPoint(x: centerX + lineLength / 2 + 10, y: y))
        context.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
        context.strokePath()
        
        // Center diamond
        let diamondSize: CGFloat = 6
        context.move(to: CGPoint(x: centerX, y: y + diamondSize))
        context.addLine(to: CGPoint(x: centerX + diamondSize, y: y))
        context.addLine(to: CGPoint(x: centerX, y: y - diamondSize))
        context.addLine(to: CGPoint(x: centerX - diamondSize, y: y))
        context.closePath()
        context.setFillColor(bitcoinOrange.cgColor)
        context.fillPath()
    }
    
    // MARK: - Status Badge
    
    private func drawStatusBadge(context: CGContext, status: DataStampStatus, centerX: CGFloat, y: CGFloat) {
        let badgeHeight: CGFloat = 28
        let badgeWidth: CGFloat = 180
        let badgeX = centerX - badgeWidth / 2
        
        let (badgeColor, badgeText, icon): (UIColor, String, String)
        
        switch status {
        case .confirmed, .verified:
            badgeColor = UIColor(red: 34/255, green: 139/255, blue: 34/255, alpha: 1.0)
            badgeText = "BLOCKCHAIN VERIFIED"
            icon = "✓"
        case .submitted:
            badgeColor = bitcoinOrange
            badgeText = "PENDING CONFIRMATION"
            icon = "◐"
        case .pending:
            badgeColor = UIColor.gray
            badgeText = "DRAFT"
            icon = "○"
        case .failed:
            badgeColor = UIColor(red: 180/255, green: 0, blue: 0, alpha: 1.0)
            badgeText = "FAILED"
            icon = "✗"
        }
        
        // Badge background
        let badgePath = UIBezierPath(roundedRect: CGRect(x: badgeX, y: y, width: badgeWidth, height: badgeHeight), cornerRadius: badgeHeight / 2)
        context.setFillColor(badgeColor.cgColor)
        context.addPath(badgePath.cgPath)
        context.fillPath()
        
        // Badge border
        context.setStrokeColor(badgeColor.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(1)
        context.addPath(UIBezierPath(roundedRect: CGRect(x: badgeX - 2, y: y - 2, width: badgeWidth + 4, height: badgeHeight + 4), cornerRadius: (badgeHeight + 4) / 2).cgPath)
        context.strokePath()
        
        // Badge text
        let badgeFont = UIFont.systemFont(ofSize: 11, weight: .bold)
        let fullText = "\(icon)  \(badgeText)"
        let badgeAttr: [NSAttributedString.Key: Any] = [
            .font: badgeFont,
            .foregroundColor: UIColor.white,
            .kern: 1.0
        ]
        let textSize = fullText.size(withAttributes: badgeAttr)
        fullText.draw(at: CGPoint(x: centerX - textSize.width / 2, y: y + (badgeHeight - textSize.height) / 2), withAttributes: badgeAttr)
    }
    
    // MARK: - Sections
    
    private func buildDocumentItems(_ item: DataStampItemSnapshot) -> [(String, String)] {
        var items: [(String, String)] = []
        
        if let title = item.title, !title.isEmpty {
            items.append(("Title", title))
        }
        
        let typeString: String
        switch item.contentType {
        case .text: typeString = "Text Document"
        case .photo: typeString = "Photograph"
        case .file: typeString = "File"
        }
        items.append(("Type", typeString))
        
        if let fileName = item.contentFileName {
            items.append(("Filename", fileName))
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM yyyy, HH:mm:ss"
        items.append(("Created", dateFormatter.string(from: item.createdAt)))
        
        if let submittedAt = item.submittedAt {
            items.append(("Submitted", dateFormatter.string(from: submittedAt)))
        }
        
        return items
    }
    
    private func buildBlockchainItems(_ item: DataStampItemSnapshot) -> [(String, String)] {
        var items: [(String, String)] = []
        
        if let blockHeight = item.bitcoinBlockHeight {
            items.append(("Block Height", "#\(formatNumber(blockHeight))"))
        }
        
        if let blockTime = item.bitcoinBlockTime {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "d MMM yyyy, HH:mm"
            items.append(("Block Time", dateFormatter.string(from: blockTime)))
        }
        
        if let txId = item.bitcoinTxId, !txId.isEmpty {
            let shortTx = "\(txId.prefix(16))...\(txId.suffix(8))"
            items.append(("Transaction", shortTx))
        }
        
        if let calendarUrl = item.calendarUrl {
            let calendarName = calendarUrl
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: ".btc.calendar.opentimestamps.org", with: "")
                .replacingOccurrences(of: ".calendar.eternitywall.com", with: "")
                .capitalized
            items.append(("Calendar", calendarName))
        }
        
        // Confirmations estimate (blocks since confirmation)
        if let blockHeight = item.bitcoinBlockHeight {
            // Approximate current block (rough estimate: 6 blocks/hour since 2009)
            let estimatedCurrentBlock = 880000 // Update periodically
            let confirmations = max(0, estimatedCurrentBlock - blockHeight)
            if confirmations > 0 {
                items.append(("Confirmations", "~\(formatNumber(confirmations))+"))
            }
        }
        
        return items
    }
    
    private func drawSection(
        context: CGContext,
        title: String,
        items: [(String, String)],
        startY: CGFloat,
        x: CGFloat,
        width: CGFloat,
        pageRect: CGRect
    ) -> CGFloat {
        var yPosition = startY
        
        // Section title
        let titleFont = UIFont.systemFont(ofSize: 9, weight: .bold)
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: bitcoinOrange,
            .kern: 1.5
        ]
        let titleY = pageRect.height - yPosition - 12
        title.draw(at: CGPoint(x: x, y: titleY), withAttributes: titleAttr)
        
        // Underline
        context.setStrokeColor(bitcoinOrange.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: x, y: titleY - 3))
        context.addLine(to: CGPoint(x: x + width, y: titleY - 3))
        context.strokePath()
        
        yPosition += 22
        
        // Items
        let labelFont = UIFont.systemFont(ofSize: 9, weight: .medium)
        let valueFont = UIFont.systemFont(ofSize: 9, weight: .regular)
        
        for (label, value) in items {
            let labelAttr: [NSAttributedString.Key: Any] = [
                .font: labelFont,
                .foregroundColor: mediumText
            ]
            let valueAttr: [NSAttributedString.Key: Any] = [
                .font: valueFont,
                .foregroundColor: darkText
            ]
            
            let itemY = pageRect.height - yPosition - 12
            label.draw(at: CGPoint(x: x, y: itemY), withAttributes: labelAttr)
            
            let valueX = x + 75
            let maxValueWidth = width - 75
            let valueRect = CGRect(x: valueX, y: itemY, width: maxValueWidth, height: 14)
            value.draw(in: valueRect, withAttributes: valueAttr)
            
            yPosition += 16
        }
        
        return yPosition
    }
    
    // MARK: - Hash Section
    
    private func drawHashSection(context: CGContext, hash: String, y: CGFloat, pageRect: CGRect, margin: CGFloat) -> CGFloat {
        var yPosition = y
        
        // Title
        let titleFont = UIFont.systemFont(ofSize: 9, weight: .bold)
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: bitcoinOrange,
            .kern: 1.5
        ]
        let title = "SHA-256 DOCUMENT FINGERPRINT"
        let titleY = pageRect.height - yPosition - 12
        title.draw(at: CGPoint(x: margin, y: titleY), withAttributes: titleAttr)
        
        yPosition += 20
        
        // Hash box
        let boxHeight: CGFloat = 32
        let boxY = pageRect.height - yPosition - boxHeight
        let boxWidth = pageRect.width - margin * 2
        
        // Background
        let boxPath = UIBezierPath(roundedRect: CGRect(x: margin, y: boxY, width: boxWidth, height: boxHeight), cornerRadius: 4)
        context.setFillColor(UIColor(white: 0.97, alpha: 1.0).cgColor)
        context.addPath(boxPath.cgPath)
        context.fillPath()
        
        // Border
        context.setStrokeColor(borderGold.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(1)
        context.addPath(boxPath.cgPath)
        context.strokePath()
        
        // Hash text (split in two lines for readability)
        let hashFont = UIFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        let hashAttr: [NSAttributedString.Key: Any] = [
            .font: hashFont,
            .foregroundColor: darkText,
            .kern: 0.5
        ]
        
        let line1 = String(hash.prefix(32))
        let line2 = String(hash.suffix(32))
        
        line1.draw(at: CGPoint(x: margin + 10, y: boxY + 5), withAttributes: hashAttr)
        line2.draw(at: CGPoint(x: margin + 10, y: boxY + 17), withAttributes: hashAttr)
        
        return yPosition + boxHeight + 5
    }
    
    // MARK: - QR Section
    
    private func drawQRSection(context: CGContext, item: DataStampItemSnapshot, y: CGFloat, pageRect: CGRect, margin: CGFloat) {
        let qrSize: CGFloat = 90
        let sectionY = pageRect.height - y - qrSize - 40
        
        // Generate QR
        guard let qrImage = generateQRCode(for: item) else { return }
        
        // QR code with border
        let qrX = margin
        context.setStrokeColor(borderGold.cgColor)
        context.setLineWidth(2)
        context.stroke(CGRect(x: qrX - 3, y: sectionY - 3, width: qrSize + 6, height: qrSize + 6))
        
        qrImage.draw(in: CGRect(x: qrX, y: sectionY, width: qrSize, height: qrSize))
        
        // Verification text
        let textX = qrX + qrSize + 15
        let textWidth = pageRect.width - textX - margin
        
        let verifyTitleFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
        let verifyTitleAttr: [NSAttributedString.Key: Any] = [
            .font: verifyTitleFont,
            .foregroundColor: darkText
        ]
        "Verify This Certificate".draw(at: CGPoint(x: textX, y: sectionY + qrSize - 14), withAttributes: verifyTitleAttr)
        
        let instructionFont = UIFont.systemFont(ofSize: 8, weight: .regular)
        let instructionAttr: [NSAttributedString.Key: Any] = [
            .font: instructionFont,
            .foregroundColor: mediumText
        ]
        
        let instructions = """
        1. Scan QR code to view blockchain transaction
        2. Compare document hash with on-chain data
        3. Verify using opentimestamps.org with .ots file
        """
        
        let instructionRect = CGRect(x: textX, y: sectionY + 5, width: textWidth, height: qrSize - 25)
        instructions.draw(in: instructionRect, withAttributes: instructionAttr)
        
        // URL
        let urlFont = UIFont.monospacedSystemFont(ofSize: 7, weight: .regular)
        let urlAttr: [NSAttributedString.Key: Any] = [
            .font: urlFont,
            .foregroundColor: bitcoinOrange
        ]
        
        let url: String
        if let txId = item.bitcoinTxId, !txId.isEmpty {
            url = "blockstream.info/tx/\(txId.prefix(20))..."
        } else {
            url = "opentimestamps.org"
        }
        url.draw(at: CGPoint(x: textX, y: sectionY - 5), withAttributes: urlAttr)
    }
    
    // MARK: - Footer
    
    private func drawFooter(context: CGContext, pageRect: CGRect, margin: CGFloat) {
        let footerY: CGFloat = margin + 15
        
        // Decorative line
        drawDecorativeLine(context: context, y: footerY + 25, pageRect: pageRect, margin: margin + 30)
        
        // Legal text
        let legalFont = UIFont.systemFont(ofSize: 7, weight: .regular)
        let legalAttr: [NSAttributedString.Key: Any] = [
            .font: legalFont,
            .foregroundColor: lightText
        ]
        
        let legalText = "This certificate attests that the referenced document existed at the time indicated by the Bitcoin blockchain timestamp. The cryptographic proof is independently verifiable using the OpenTimestamps protocol. This certificate does not verify the content, accuracy, or legal validity of the document itself."
        
        let legalRect = CGRect(x: margin + 15, y: footerY - 8, width: pageRect.width - margin * 2 - 100, height: 30)
        legalText.draw(in: legalRect, withAttributes: legalAttr)
        
        // DataStamp branding
        let brandFont = UIFont.systemFont(ofSize: 10, weight: .bold)
        let brandAttr: [NSAttributedString.Key: Any] = [
            .font: brandFont,
            .foregroundColor: bitcoinOrange,
            .kern: 1.0
        ]
        let brand = "DATASTAMP"
        let brandSize = brand.size(withAttributes: brandAttr)
        brand.draw(at: CGPoint(x: pageRect.width - margin - brandSize.width - 5, y: footerY + 5), withAttributes: brandAttr)
        
        let taglineFont = UIFont.systemFont(ofSize: 6, weight: .regular)
        let taglineAttr: [NSAttributedString.Key: Any] = [
            .font: taglineFont,
            .foregroundColor: lightText
        ]
        let tagline = "Powered by Bitcoin"
        let taglineSize = tagline.size(withAttributes: taglineAttr)
        tagline.draw(at: CGPoint(x: pageRect.width - margin - taglineSize.width - 5, y: footerY - 5), withAttributes: taglineAttr)
    }
    
    // MARK: - Helpers
    
    private func generateQRCode(for item: DataStampItemSnapshot) -> UIImage? {
        var urlString: String
        
        if let txId = item.bitcoinTxId, !txId.isEmpty {
            urlString = "https://blockstream.info/tx/\(txId)"
        } else if let blockHeight = item.bitcoinBlockHeight {
            urlString = "https://blockstream.info/block-height/\(blockHeight)"
        } else {
            urlString = "https://opentimestamps.org"
        }
        
        guard let data = urlString.data(using: .utf8) else { return nil }
        
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "H" // High correction for better scanning
        
        guard let outputImage = filter.outputImage else { return nil }
        
        let scale = 10.0
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Snapshot Model

/// Immutable snapshot of DataStampItem for thread-safe PDF generation
struct DataStampItemSnapshot: Sendable {
    let id: UUID
    let createdAt: Date
    let contentType: ContentType
    let contentHash: Data
    let contentFileName: String?
    let textContent: String?
    let title: String?
    let status: DataStampStatus
    let calendarUrl: String?
    let submittedAt: Date?
    let confirmedAt: Date?
    let bitcoinBlockHeight: Int?
    let bitcoinBlockTime: Date?
    let bitcoinTxId: String?
    
    var hashHex: String {
        contentHash.map { String(format: "%02x", $0) }.joined()
    }
    
    init(from item: DataStampItem) {
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
    
    init(
        id: UUID,
        createdAt: Date,
        contentType: ContentType,
        contentHash: Data,
        contentFileName: String?,
        textContent: String?,
        title: String?,
        status: DataStampStatus,
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
