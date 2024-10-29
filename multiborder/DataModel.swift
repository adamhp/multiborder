import SwiftUI
import PhotosUI
import Foundation

@MainActor final class DataModel: NSObject, ObservableObject  {
    @MainActor final class ImageAttachment: NSObject, ObservableObject, Identifiable {
        
        let parent: DataModel
        var index: Int
        
        struct Status {
            var loadingStatus: LoadingStatus = .unloaded
            var savingStatus: SavingStatus = .unsaved
            var thumbnailStatus: LoadingStatus = .unloaded
        }
        
        enum LoadingStatus {
            case unloaded
            case loading
            case finished(Image)
            case failed(Error)
            
            var isUnloaded: Bool {
                return switch self {
                    case .unloaded: true
                    default: false
                }
            }
            
            var isLoading: Bool {
                return switch self {
                    case .loading: true
                    default: false
                }
            }
            
            var isFinished: Bool {
                return switch self {
                    case .finished: true
                    default: false
                }
            }
            
            var isFailed: Bool {
                return switch self {
                    case .failed: true
                    default: false
                }
            }
        }
        
        enum LoadingError: Error {
            case contentTypeNotSupported
        }
        
        enum SavingStatus {
            case unsaved
            case saving
            case success
            case failed(SavingError)
            
            var isUnsaved: Bool {
                return switch self {
                    case .unsaved: true
                    default: false
                }
            }
            
            var isSaving: Bool {
                return switch self {
                    case .saving: true
                    default: false
                }
            }
            
            var isSuccess: Bool {
                return switch self {
                    case .success: true
                    default: false
                }
            }
            
            var isFailed: Bool {
                return switch self {
                    case .failed: true
                    default: false
                }
            }
        }
        
        enum SavingError: Error {
            case general(String)
        }

        private let pickerItem: PhotosPickerItem
        nonisolated var id: String {
            pickerItem.identifier
        }
        
        @Published var status: Status = Status()
        @Published var imageDescription: String = ""
        @Published var imageThumbnail: Image? = Image(systemName: "questionmark.diamond")
        @Published var originalImageWidth: Double?
        @Published var originalImageHeight: Double?
        @Published var originalImageAspectRatio: Double?
        
        @Environment(\.displayScale) private var displayScale
        
        init(_ pickerItem: PhotosPickerItem, _ parent: DataModel, _ index: Int) {
            self.pickerItem = pickerItem
            self.parent = parent
            self.index = index
        }
        
        func getPickerItem() -> PhotosPickerItem {
            return self.pickerItem
        }
        
        func loadThumbnail() async {
            guard status.thumbnailStatus.isUnloaded == true else {
                return
            }
            status.thumbnailStatus = .loading
            
            do {
                if let data = try await pickerItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    originalImageWidth = uiImage.size.width
                    originalImageHeight = uiImage.size.height
                    originalImageAspectRatio = uiImage.size.width / uiImage.size.height
                    if let resizedImage = uiImage.resized(to: CGSize(width: 200, height: 200 / originalImageAspectRatio!)) {
                        let resImage = Image(uiImage: resizedImage)
                        imageDescription = data.description
                        imageThumbnail = resImage
                        status.thumbnailStatus = .finished(resImage)
                    } else {
                        throw LoadingError.contentTypeNotSupported
                    }
                } else {
                    throw LoadingError.contentTypeNotSupported
                }
            } catch {
                status.thumbnailStatus = .failed(error)
            }
            self.objectWillChange.send()
        }
        
        @MainActor func exportImage() {
//            guard status.loadingStatus.isUnloaded == true else {
//                return
//            }
            status.loadingStatus = .loading
            Task {
                do {
                    if let data = try await pickerItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        originalImageWidth = uiImage.size.width
                        originalImageHeight = uiImage.size.height
                        originalImageAspectRatio = uiImage.size.width / uiImage.size.height
                        if let resizedImage = self.parent.desiredSize == 0 ? uiImage : uiImage.resized(to: CGSize(width: Double(self.parent.desiredSize), height: Double(self.parent.desiredSize) / originalImageAspectRatio!)) {
                            imageDescription = data.description
                            let desiredWidth: Double = self.parent.desiredSize == 0 ? originalImageWidth! : (originalImageWidth! >= Double(self.parent.desiredSize) ? Double(self.parent.desiredSize) : originalImageWidth!)
                            let paddingScale = desiredWidth / self.parent.originalContainerWidth
                            let aspectRatio: CGFloat = self.parent.desiredAspectRatio == -1 ? (originalImageWidth! / originalImageHeight!) : self.parent.desiredAspectRatio
                            let exportView = ImageExportView(image: resizedImage, desiredWidth: Int(desiredWidth), desiredAspectRatio: aspectRatio, desiredPadding: self.parent.desiredPadding * paddingScale, desiredBorderColor: self.parent.desiredBorderColor)
                            let renderer = ImageRenderer(content: exportView)
                            if let imageResult = renderer.uiImage {
                                UIImageWriteToSavedPhotosAlbum(imageResult, self, #selector(handleImageResult(_:didFinishSavingWithError:contextInfo:)), nil)
                            }
                            status.loadingStatus = .unloaded
                        } else {
                            throw LoadingError.contentTypeNotSupported
                        }
                    } else {
                        throw LoadingError.contentTypeNotSupported
                    }
                } catch {
                    status.loadingStatus = .failed(error)
                }
            }
        }
        
        func unloadThumbnail() async {
            self.imageThumbnail = Image(systemName: "questionmark.diamond")
            status.thumbnailStatus = .unloaded
            self.objectWillChange.send()
        }
        
        @objc func handleImageResult(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
            if let error = error {
                status.savingStatus = .failed(.general(error.localizedDescription))
            } else {
                status.savingStatus = .success
            }
            parent.handleImageResult(image, didFinishSavingWithError: error, contextInfo: contextInfo)
        }
    }
    
    // End ImageAttachment ----------
    
    enum SaveStatus {
        case unsaved
        case saving
        case success
        case failed(String)
        
        var isUnsaved: Bool {
            return switch self {
                case .unsaved: true
                default: false
            }
        }
        
        var isSaving: Bool {
            return switch self {
                case .saving: true
                default: false
            }
        }
        
        var isSuccess: Bool {
            return switch self {
                case .success: true
                default: false
            }
        }
        
        var isFailed: Bool {
            return switch self {
                case .failed: true
                default: false
            }
        }
    }
        
    @Published var saveStatus: SaveStatus = .unsaved
    
    @Published var processed: Int = -1 {
        didSet {
            guard self.processed != -1 else {
                return
            }
            if self.processed >= attachments.count {
                self.processed = -1
                self.saveStatus = .success
            } else {
                attachments[self.processed].exportImage()
            }
        }
    }
    
    @Published var helpTextShown: Bool = false
    @Published var selectedTab = 0
    
    /// User defined settings
    @Published var desiredAspectRatio: Double = 4/5
    @Published var desiredPadding: CGFloat = 0
    @Published var desiredBorderColor = Color.white
    @Published var desiredSize: Int = 0 {
        didSet {
            resetSaveStatus()
        }
    }
    @Published var originalContainerWidth: CGFloat = 0
    @Published var currentIndex: Int = 0 {
        didSet {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                Task {
                    for attachment in self.attachments {
                        if attachment.index >= self.currentIndex - 2 && attachment.index <= self.currentIndex + 2 {
                            await attachment.loadThumbnail()
                        } else {
                            await attachment.unloadThumbnail()
                        }
                    }
                }
            }
            self.objectWillChange.send()
        }
    }
    
    
    @Published var selection = [PhotosPickerItem]() {
        didSet {
            // Update the attachments according to the current picker selection.
            let newAttachments = selection.enumerated().map { (index, item) in
                // Access an existing attachment, if it exists; otherwise, create a new attachment.
                attachmentByIdentifier[item.identifier] ?? ImageAttachment(item, self, index)
                
            }
            // Update the saved attachments array for any new attachments loaded in scope.
            let newAttachmentByIdentifier = newAttachments.reduce(into: [:]) { partialResult, attachment in
                partialResult[attachment.id] = attachment
            }
            attachments = newAttachments
            attachmentByIdentifier = newAttachmentByIdentifier
            resetSaveStatus()
            self.objectWillChange.send()
        }
    }
    
    func resetSaveStatus() {
        processed = -1
        saveStatus = .unsaved
        for image in attachments {
            image.status.savingStatus = .unsaved
        }
    }
    
    public func tryLoadDefaults() {
        let desiredAspectRatio = UserDefaults.standard.double(forKey: "desiredAspectRatio")
        if desiredAspectRatio != 0 {
            setDesiredAspectRatio(desiredAspectRatio)
        } else {
            UserDefaults.standard.set(4/5, forKey: "desiredAspectRatio")
        }
        
        let desiredSize = UserDefaults.standard.integer(forKey: "desiredSize")
        if desiredSize != 0 {
            setDesiredSize(desiredSize)
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
        
        self.objectWillChange.send()
    }
    
    var attemptedSizeLabel: String = ""
    
    @Published var attachments = [ImageAttachment]() {
        didSet {
            if attachments.isEmpty {
                resetSaveStatus()
            }
        }
    }
    
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
    }
    
    public func removeCurrent() {
        if attachments.count == 0 {
            return
        }
        let removed = attachments.remove(at: self.currentIndex)
        attachmentByIdentifier.removeValue(forKey: removed.id)
        if (attachments.isEmpty) {
            clearSelection()
        } else {
            var counter = 0
            for attachment in attachments {
                attachment.index = counter
                counter += 1
            }
        }
        if (self.currentIndex >= 1) {
            self.currentIndex -= 1
        } else {
            // Re-set so we trigger loading of thumbnails
            self.currentIndex = self.currentIndex
        }
        self.objectWillChange.send()
    }
    
    public func getCurrent() -> ImageAttachment? {
        if attachments.count == 0 {
            return nil
        }
        return attachments[currentIndex]
    }
    
    public func setDesiredSize(_ value: Int) {
        desiredSize = value
        UserDefaults.standard.set(value, forKey: "desiredSize")
        self.objectWillChange.send()
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
    
    @objc func handleImageResult(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if processed == self.attachments.count {
            saveStatus = SaveStatus.success
        } else {
            processed += 1
        }
    }
}

extension Date {
    func currentTimeMillis() -> Int64 {
        return Int64(self.timeIntervalSince1970 * 1000)
    }
}

extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        self.draw(in: CGRect(origin: .zero, size: size))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
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
    
    let image: UIImage?
    let desiredWidth: Int
    let desiredAspectRatio: CGFloat
    let desiredPadding: Double
    let desiredBorderColor: Color
    
    
    
    var body: some View {
        Rectangle()
            .frame(width: CGFloat(desiredWidth), height: CGFloat(desiredWidth) * (1 / desiredAspectRatio))
            .foregroundColor(desiredBorderColor)
            .aspectRatio(desiredAspectRatio, contentMode: .fit)
            .overlay(
                ZStack {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(desiredPadding)
                    } else {
                        EmptyView()
                    }
                }
            )
    }
}
