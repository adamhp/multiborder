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
    
    @Published var selectedTab = 0
    
    /// User settings
    @Published var desiredAspectRatio: Double = 4/5
    @Published var desiredPadding: CGFloat = 0
    @Published var desiredBorderColor = Color(.sRGB, red: 1.0, green: 1.0, blue: 1.0)
    @Published var originalContainerWidth: CGFloat = 0
    
    @Published var currentIndex = 0
    
    @Published var rendered = [Image]()
    
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
    
    @Published var attachments = [ImageAttachment]()
    
    @Published var saveSuccesses = 0
    @Published var saveFailures = 0
    @Published var saveResults = 0
    @Published var failureMessage = ""
    
    private var attachmentByIdentifier = [String: ImageAttachment]()
    
    public func clearSelection() {
        selection = []
        attachments = []
        saveSuccesses = 0
        saveFailures = 0
        saveResults = 0
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
    
    public func setDesiredPadding(value: CGFloat) {
        desiredPadding = value
        self.objectWillChange.send()
    }
    
    public func setDesiredAspectRatio(value: Double) {
        desiredAspectRatio = value
        self.objectWillChange.send()
    }
    
    public func setDesiredBorderColor(value: Color) {
        desiredBorderColor = value
        self.objectWillChange.send()
    }
    
    @MainActor public func render(size: Int) {
        for imageAttachment in attachments {
            switch imageAttachment.imageStatus {
                case .finished(let image):
                    let paddingScale = originalContainerWidth / (size != 0 ? CGFloat(size) : 1.0)
                    let aspectRatio: CGFloat = desiredAspectRatio == -1 ? (imageAttachment.originalImageWidth / imageAttachment.originalImageHeight) : desiredAspectRatio
                    let renderer = ImageRenderer(content: ImageExportView(image: image, desiredWidth: size, desiredAspectRatio: aspectRatio, desiredPadding: desiredPadding * paddingScale, desiredBorderColor: desiredBorderColor))
                    renderer.scale = 1.0
                    if let result = renderer.uiImage {
                        rendered.append(Image(uiImage: result))
                    }
                case .failed:
                    return
                default:
                    return
            }
        }
    }
    
    @MainActor public func renderAndSave(size: Int) {
        for imageAttachment in attachments {
            switch imageAttachment.imageStatus {
                case .finished(let image):
                    let paddingScale = (size != 0 ? CGFloat(size) : 1.0) / originalContainerWidth
                    let aspectRatio: CGFloat = desiredAspectRatio == -1 ? (imageAttachment.originalImageWidth / imageAttachment.originalImageHeight) : desiredAspectRatio
                    let renderer = ImageRenderer(content: ImageExportView(image: image, desiredWidth: size, desiredAspectRatio: aspectRatio, desiredPadding: desiredPadding * paddingScale, desiredBorderColor: desiredBorderColor))
                    renderer.scale = 1.0
                    if let result = renderer.uiImage {
                        UIImageWriteToSavedPhotosAlbum(result, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
                    }
                case .failed:
                    return
                default:
                    return
            }
        }
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            self.saveFailures += 1
            self.saveResults += 1
            self.failureMessage = error.localizedDescription
        } else {
            self.saveSuccesses += 1
            self.saveResults += 1
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

class WriteImageToFileResponder: NSObject {
    typealias WriteImageToFileResponderCompletion = ((UIImage?, Error?) -> Void)?
    var completion: WriteImageToFileResponderCompletion = nil
    
    override init() {
        super.init()
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if (completion != nil) {
            error == nil ? completion?(image, error) : completion?(nil, error)
            completion = nil
        }
    }
    func addCompletion(completion:WriteImageToFileResponderCompletion) {
        self.completion = completion
    }
}
