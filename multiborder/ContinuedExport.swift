import BackgroundTasks
import os

/// Keeps a Download running after the user leaves the app, with the system's progress UI
/// (iOS 26+). The export itself always runs in `DataModel`; this only asks the system for
/// time to finish it in the background and mirrors its progress there. Below iOS 26, or when
/// the system declines, `start` returns nil and the export runs while the app is open, as before.
final class ContinuedExport {

    private static let log = Logger(subsystem: "com.adamhp.multiborder", category: "Export")

    private let identifier: String
    private let onExpire: () -> Void
    /// Set once the system launches the task; a `BGContinuedProcessingTask` on iOS 26.
    private var task: BGTask?
    private var completed = 0
    private var total: Int
    private var isFinished = false

    private init(identifier: String, total: Int, onExpire: @escaping () -> Void) {
        self.identifier = identifier
        self.total = total
        self.onExpire = onExpire
    }

    /// Asks the system to continue an export of `total` photos in the background.
    /// `onExpire` runs if the system runs out of time or the user cancels from the system UI.
    static func start(total: Int, onExpire: @escaping () -> Void) -> ContinuedExport? {
        guard #available(iOS 26, *) else { return nil }
        let identifier = "com.adamhp.multiborder.export.\(UUID().uuidString)"
        let export = ContinuedExport(identifier: identifier, total: total, onExpire: onExpire)
        // Each export uses a new identifier, so it's registered exactly once.
        let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { task in
            MainActor.assumeIsolated { export.launched(task) }
        }
        guard registered else {
            log.error("Couldn't register \(identifier, privacy: .public)")
            return nil
        }
        let request = BGContinuedProcessingTaskRequest(identifier: identifier,
                                                       title: export.title,
                                                       subtitle: export.subtitle)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            log.error("Couldn't submit the export task: \(error, privacy: .public)")
            return nil
        }
        return export
    }

    /// Reports that `completed` photos of the export are done.
    func update(completed: Int) {
        self.completed = completed
        guard #available(iOS 26, *), let task = task as? BGContinuedProcessingTask else { return }
        task.progress.completedUnitCount = Int64(completed)
        task.updateTitle(title, subtitle: subtitle)
    }

    /// Ends the background task. Call once, when the export stops for any reason.
    func finish(success: Bool) {
        guard !isFinished else { return }
        isFinished = true
        if let task {
            task.setTaskCompleted(success: success)
        } else {
            // Still queued: the export finished in the foreground first.
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        }
    }

    private func launched(_ task: BGTask) {
        guard #available(iOS 26, *), let task = task as? BGContinuedProcessingTask, !isFinished else {
            task.setTaskCompleted(success: isFinished)
            return
        }
        self.task = task
        task.expirationHandler = { [weak self] in
            Task { @MainActor in self?.onExpire() }
        }
        task.progress.totalUnitCount = Int64(total)
        update(completed: completed)
    }

    private var title: String {
        total == 1
            ? String(localized: "Saving 1 photo")
            : String(localized: "Saving \(total) photos")
    }

    private var subtitle: String {
        String(localized: "\(completed) of \(total) saved")
    }
}
