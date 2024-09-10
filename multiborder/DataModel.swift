import SwiftUI
import PhotosUI
import Foundation

@MainActor final class DataModel: NSObject, ObservableObject  {
    @MainActor final class ImageAttachment: ObservableObject, Identifiable {
        
        /// Statuses that indicate the app's progress in loading a selected photo.
        enum Status {

            /// A status indicating that the app has requested a photo.
            case loading
            
            /// A status indicating that the app has loaded a photo.
            case finished(Image)
            
            /// A status indicating that the photo has failed to load.
            case failed(Error)
            
            case saved
            
            case saveFailed(Error)
            
            /// Determines whether the photo has failed to load.
            var isFailed: Bool {
                return switch self {
                case .failed: true
                default: false
                }
            }
            
            var asIndex : Double {
                switch self {
                    case .finished(_): return 0
                    case .loading: return 1
                    case .failed(_): return 2
                    case .saveFailed(_): return 3
                    case .saved: return 4
                        
                }
            }
        }
        
        /// An error that indicates why a photo has failed to load.
        enum LoadingError: Error {
            case contentTypeNotSupported
        }
        
        /// A reference to a selected photo in the picker.
        private let pickerItem: PhotosPickerItem
        
        /// A load progress for the photo.
        @Published var imageStatus: Status?
        
        @Published var imageDescription: String = ""
        @Published var imageSize: String = ""
        @Published var originalImageWidth: Double = 0
        @Published var originalImageHeight: Double = 0
        
        /// An identifier for the photo.
        nonisolated var id: String {
            pickerItem.identifier
        }
        
        /// Creates an image attachment for the given picker item.
        init(_ pickerItem: PhotosPickerItem) {
            self.pickerItem = pickerItem
        }
        
        func getPickerItem() -> PhotosPickerItem {
            return self.pickerItem
        }
        /// Loads the photo that the picker item features.
        func loadImage() async {
            guard imageStatus == nil || imageStatus?.isFailed == true else {
                return
            }
            imageStatus = .loading
            do {
                if let data = try await pickerItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    imageStatus = .finished(Image(uiImage: uiImage))
                    imageDescription = data.description
                    originalImageWidth = uiImage.size.width
                    originalImageHeight = uiImage.size.height
                    let size: Int64? = Int64(data.description.components(separatedBy: " ")[0])
                    let byteFormat = ByteCountFormatStyle(style: .memory,
                                                          allowedUnits: [.mb],
                                                          spellsOutZero: true,
                                                          includesActualByteCount: false,
                                                          locale: Locale(identifier: "en_US"))
                    imageSize = byteFormat.format(size ?? 0)
                    self.objectWillChange.send()
                } else {
                    throw LoadingError.contentTypeNotSupported
                }
            } catch {
                imageStatus = .failed(error)
            }
        }
    }
    
    public final let supportedSizes: [ExportSize] = [
        ExportSize(label: "1024", width: 1024.0),
        ExportSize(label: "2048", width: 2048.0),
        ExportSize(label: "4096", width: 4096.0),
        ExportSize(label: "Original", width: nil)
    ]
    
    @Published var helpTextShown: Bool = false
    @Published var selectedTab = 0
    @Published var desiredAspectRatio: Double = 4/5
    @Published var desiredPadding: CGFloat = 0
    @Published var desiredBorderColor = Color.white
    @Published var originalContainerWidth: CGFloat = 0
    @Published var currentIndex = 0
    @Published var selection = [PhotosPickerItem]() {
        didSet {
            // Update the attachments according to the current picker selection.
            let newAttachments = selection.map { item in
                // Access an existing attachment, if it exists; otherwise, create a new attachment.
                attachmentByIdentifier[item.identifier] ?? ImageAttachment(item)
            }
            // Update the saved attachments array for any new attachments loaded in scope.
            let newAttachmentByIdentifier = newAttachments.reduce(into: [:]) { partialResult, attachment in
                partialResult[attachment.id] = attachment
            }
            attachments = newAttachments
            attachmentByIdentifier = newAttachmentByIdentifier
            self.objectWillChange.send()
        }
    }
    
    public func tryLoadDefaults() {
        let desiredAspectRatio = UserDefaults.standard.double(forKey: "desiredAspectRatio")
        if desiredAspectRatio != 0 {
            setDesiredAspectRatio(desiredAspectRatio)
        } else {
            UserDefaults.standard.set(4/5, forKey: "desiredAspectRatio")
        }
        let desiredPadding = CGFloat(UserDefaults.standard.float(forKey: "desiredPadding"))
        if desiredPadding != 0 {
            setDesiredPadding(desiredPadding)
        }
        if !UserDefaults.standard.bool(forKey: "colorStored") {
            UserDefaults.standard.set(true, forKey: "colorStored")
            UserDefaults.standard.set(1.0, forKey: "colorR")
            UserDefaults.standard.set(1.0, forKey: "colorG")
            UserDefaults.standard.set(1.0, forKey: "colorB")
        } else {
            let desiredBorderColor = Color(.sRGB, red: UserDefaults.standard.double(forKey: "colorR"), green: UserDefaults.standard.double(forKey: "colorG"), blue: UserDefaults.standard.double(forKey: "colorB"))
            setDesiredBorderColor(desiredBorderColor)
        }
    }
    
    var attemptedSizeLabel: String = ""
    
    @Published var attachments = [ImageAttachment]()
    
    @Published var rendered:[String:[UIImage]] = [
        "1024": [],
        "2048": [],
        "4096": [],
        "Original": []
    ]
    
    @Published var saveSuccesses: [String:Int] = [
        "1024": 0,
        "2048": 0,
        "4096": 0,
        "Original": 0
    ]
    @Published var saveFailures: [String:Int] = [
        "1024": 0,
        "2048": 0,
        "4096": 0,
        "Original": 0
    ]
    @Published var saveResults: [String:Int] = [
        "1024": 0,
        "2048": 0,
        "4096": 0,
        "Original": 0
    ]
    
    @Published var error: Error? = nil {
        didSet {
            if error != nil {
                self.hasError = true
            } else {
                self.hasError = false
            }
        }
    }
    
    @Published var hasError: Bool = false
    
    private var attachmentByIdentifier = [String: ImageAttachment]()
    
    public func clearSelection() {
        selection = []
        attachments = []
        resetSizeResults()
    }
    
    public func resetSizeResults() {
        self.saveSuccesses = [
            "1024": 0,
            "2048": 0,
            "4096": 0,
            "Original": 0
        ]
        self.saveFailures = [
            "1024": 0,
            "2048": 0,
            "4096": 0,
            "Original": 0
        ]
        self.saveResults = [
            "1024": 0,
            "2048": 0,
            "4096": 0,
            "Original": 0
        ]
    }
    
    public func removeCurrent() {
        if attachments.count == 0 {
            return
        }
        let removed = attachments.remove(at: currentIndex)
        attachmentByIdentifier.removeValue(forKey: removed.id)
        if (currentIndex >= 1) {
            currentIndex -= 1
        }
        if (attachments.isEmpty) {
            clearSelection()
        }
    }
    
    public func getCurrent() -> ImageAttachment? {
        if attachments.count == 0 {
            return nil
        }
        return attachments[currentIndex]
    }
    
    public func setDesiredPadding(_ value: CGFloat) {
        desiredPadding = value
        UserDefaults.standard.set(value, forKey: "desiredPadding")
        self.objectWillChange.send()
    }
    
    public func setDesiredAspectRatio(_ value: Double) {
        desiredAspectRatio = value
        UserDefaults.standard.set(value, forKey: "desiredAspectRatio")
        self.objectWillChange.send()
    }
    
    public func setDesiredBorderColor(_ value: Color) {
        desiredBorderColor = value
        let components = UIColor(value).cgColor.components!
        UserDefaults.standard.set(true, forKey:"colorStored")
        UserDefaults.standard.set(components[0], forKey: "colorR")
        UserDefaults.standard.set(components[1], forKey: "colorG")
        UserDefaults.standard.set(components[2], forKey: "colorB")
        self.objectWillChange.send()
    }
    
    public func renderImagesForSize(_ size: ExportSize) {
        for imageAttachment in attachments {
            switch imageAttachment.imageStatus {
                case .finished(let image):
                    let renderer = prepareRenderer(image: image, imageAttachment: imageAttachment, size: size)
                    if let result = renderer.uiImage {
                        rendered[size.label]!.append(result)
                    }
                case .failed:
                    return
                default:
                    return
            }
        }
    }
    
    private func saveImage(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(handleImageResult(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    private func saveRenderedImages(_ size: ExportSize) {
        for image in rendered[size.label]! {
            saveImage(image)
        }
    }
    
    public func renderAndSave(_ size: ExportSize) async {
        self.attemptedSizeLabel = size.label
        renderImagesForSize(size)
        saveRenderedImages(size)
    }
    
    private func prepareRenderer(image: Image, imageAttachment: ImageAttachment, size: ExportSize) -> ImageRenderer<ImageExportView> {
        // Use original width if selected, or if original width is less than desired size
        let desiredWidth: Double = size.label == "Original" ? imageAttachment.originalImageWidth : (imageAttachment.originalImageWidth >= size.width! ? size.width! : imageAttachment.originalImageWidth)
        let paddingScale = desiredWidth / originalContainerWidth
        let aspectRatio: CGFloat = desiredAspectRatio == -1 ? (imageAttachment.originalImageWidth / imageAttachment.originalImageHeight) : desiredAspectRatio
        let renderer = ImageRenderer(content: ImageExportView(image: image, desiredWidth: Int(desiredWidth), desiredAspectRatio: aspectRatio, desiredPadding: desiredPadding * paddingScale, desiredBorderColor: desiredBorderColor))
        renderer.scale = 1.0
        return renderer
    }
    
    @objc func handleImageResult(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            self.saveFailures[self.attemptedSizeLabel]! += 1
            self.saveResults[self.attemptedSizeLabel]! += 1
            self.error = error
        } else {
            self.saveSuccesses[self.attemptedSizeLabel]! += 1
            self.saveResults[self.attemptedSizeLabel]! += 1
        }
    }
}


private extension PhotosPickerItem {
    var identifier: String {
        guard let identifier = itemIdentifier else {
            fatalError("The photos picker lacks a photo library.")
        }
        return identifier
    }
}

struct ImageExportView: View {
    
    let image: Image
    let desiredWidth: Int
    let desiredAspectRatio: CGFloat
    let desiredPadding: Double
    let desiredBorderColor: Color
    
    var body: some View {
        Rectangle()
            .frame(width: CGFloat(desiredWidth), height: CGFloat(desiredWidth) * (1 / desiredAspectRatio))
            .foregroundColor(desiredBorderColor)
            .aspectRatio(desiredAspectRatio, contentMode: .fit)
            .overlay(ImageView(image: image, desiredPadding: desiredPadding))
    }
}

struct ImageView: View {
    
    let image: Image
    let desiredPadding: Double
    
    var body: some View {
        ZStack {
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(desiredPadding)
        }
    }
}

struct ExportSize {
    var label: String
    var width: Optional<Double>
}

extension ExportSize: Identifiable {
    var id: String {
        label
    }
}
