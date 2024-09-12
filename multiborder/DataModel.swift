import SwiftUI
import PhotosUI
import Foundation

@MainActor final class DataModel: NSObject, ObservableObject  {
    @MainActor final class ImageAttachment: NSObject, ObservableObject, Identifiable {
        
        let parent: DataModel
        
        struct Status {
            var loadingStatus: LoadingStatus = .unloaded
            var savingStatus: SavingStatus = .unsaved
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
        
        struct RenderedImage {
            let image: UIImage
            let desiredSize: Int
            var status: SavingStatus = .unsaved
            
            init(_ image: UIImage, _ desiredSize: Int) {
                self.image = image
                self.desiredSize = desiredSize
            }
        }
        
        private let pickerItem: PhotosPickerItem
        nonisolated var id: String {
            pickerItem.identifier
        }
        
        @Published var status: Status = Status()
        @Published var imageDescription: String = ""
        @Published var rendered: [RenderedImage]?
        @Published var image: Image?
        @Published var originalImageWidth: Double?
        @Published var originalImageHeight: Double?
        
        init(_ pickerItem: PhotosPickerItem, _ parent: DataModel) {
            self.pickerItem = pickerItem
            self.parent = parent
        }
        
        func getPickerItem() -> PhotosPickerItem {
            return self.pickerItem
        }
        
        func load() async {
            guard status.loadingStatus.isUnloaded == true else {
                return
            }
            status.loadingStatus = .loading
            
            do {
                if let data = try await pickerItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    let resImage = Image(uiImage: uiImage)
                    imageDescription = data.description
                    image = resImage
                    originalImageWidth = uiImage.size.width
                    originalImageHeight = uiImage.size.height
                    status.loadingStatus = .finished(resImage)
                } else {
                    throw LoadingError.contentTypeNotSupported
                }
            } catch {
                status.loadingStatus = .failed(error)
            }
            self.objectWillChange.send()
        }
        
        @MainActor func save(size: Int, originalContainerWidth: Double, desiredPadding: Double, desiredAspectRatio: Double, desiredBorderColor: Color) async {
            guard status.loadingStatus.isFinished && status.savingStatus.isUnsaved else {
                return
            }
            status.savingStatus = .saving
            
            await renderImage(size: size, originalContainerWidth: originalContainerWidth, desiredPadding: desiredPadding, desiredAspectRatio: desiredAspectRatio, desiredBorderColor: desiredBorderColor)
                    
            /// Double unwrap, once for dictionary, twice for render result which should never be nil after line above
            await saveRenderedImages(desiredSize: size)
        }
        
        private func renderImage(size: Int, originalContainerWidth: Double, desiredPadding: Double, desiredAspectRatio: Double, desiredBorderColor: Color) async {
            guard status.loadingStatus.isFinished else {
                return
            }
            let renderer = prepareRenderer(image: image!, size: size, originalContainerWidth: originalContainerWidth, desiredPadding: desiredPadding, desiredAspectRatio: desiredAspectRatio, desiredBorderColor: desiredBorderColor)

            /// Unwrap is okay because of duplicate guards on loading status
            if let result = renderer!.uiImage {
                if rendered == nil {
                    rendered = []
                }
                rendered!.append(RenderedImage(result, size))
            }
        }
        
        private func prepareRenderer(image: Image, size: Int, originalContainerWidth: Double, desiredPadding: Double, desiredAspectRatio: Double, desiredBorderColor: Color) -> ImageRenderer<ImageExportView>? {
            guard status.loadingStatus.isFinished else {
                return nil
            }
            // Use original width if selected, or if original width is less than desired size
            let desiredWidth: Double = size == 0 ? originalImageWidth! : (originalImageWidth! >= Double(size) ? Double(size) : originalImageWidth!)
            let paddingScale = desiredWidth / originalContainerWidth
            let aspectRatio: CGFloat = desiredAspectRatio == -1 ? (originalImageWidth! / originalImageHeight!) : desiredAspectRatio
            let renderer = ImageRenderer(content: ImageExportView(image: image, desiredWidth: Int(desiredWidth), desiredAspectRatio: aspectRatio, desiredPadding: desiredPadding * paddingScale, desiredBorderColor: desiredBorderColor))
            renderer.scale = 1.0
            return renderer
        }
        
        private func saveRenderedImages(desiredSize: Int) async {
            guard rendered != nil else {
                return
            }
            for rendered in rendered!.filter({ $0.status.isUnsaved && $0.desiredSize == desiredSize }) {
                saveUIImageForSize(rendered.image, rendered.desiredSize)
            }
        }
        
        private func saveRenderedImages() {
            guard rendered != nil else {
                return
            }
            for rendered in rendered!.filter({ $0.status.isUnsaved }) {
                saveUIImageForSize(rendered.image, rendered.desiredSize)
            }
        }
        
        private func saveUIImageForSize(_ image: UIImage, _ desiredSize: Int) {
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(handleImageResult(_:didFinishSavingWithError:contextInfo:)), nil)
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
    @Published var processed: Int = 0
    
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
    @Published var currentIndex = 0
    @Published var selection = [PhotosPickerItem]() {
        didSet {
            // Update the attachments according to the current picker selection.
            let newAttachments = selection.map { item in
                // Access an existing attachment, if it exists; otherwise, create a new attachment.
                attachmentByIdentifier[item.identifier] ?? ImageAttachment(item, self)
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
    
    private func resetSaveStatus() {
        processed = 0
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
    
    public func renderAndSave() async {
        processed = 0
        saveStatus = .saving
        for imageAttachment in attachments {
            await imageAttachment.save(size: desiredSize, originalContainerWidth: originalContainerWidth, desiredPadding: desiredPadding, desiredAspectRatio: desiredAspectRatio, desiredBorderColor: desiredBorderColor)
        }
    }
    
    @objc func handleImageResult(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        processed += 1
    }
}

extension Date {
    func currentTimeMillis() -> Int64 {
        return Int64(self.timeIntervalSince1970 * 1000)
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
