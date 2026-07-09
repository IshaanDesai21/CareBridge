import Foundation

/// Process-wide crash diagnostics.
///
/// A raw "abort signal terminated the process" message tells you nothing about
/// *where* it came from. This installs a last-resort handler for both uncaught
/// Objective-C/C++ exceptions and fatal Unix signals (SIGABRT, SIGILL, SIGSEGV,
/// SIGTRAP, SIGFPE, SIGBUS) so that the moment before the process dies we write
/// the reason plus a symbolicated call stack to a file. On the next launch that
/// report is read back and logged, turning a silent, unreproducible abort into a
/// concrete stack trace you can fix.
///
/// It does NOT try to keep the process alive — SIGABRT and Swift traps are not
/// safely recoverable. Its job is to make sure the next crash is never a mystery.
enum CrashReporter {
    private static let reportURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("carebridge_last_crash.log")
    }()

    /// Call once, as early as possible in app launch.
    static func install() {
        surfacePreviousCrash()

        NSSetUncaughtExceptionHandler { exception in
            let stack = exception.callStackSymbols.joined(separator: "\n")
            CrashReporter.write(
                kind: "Uncaught \(exception.name.rawValue)",
                reason: exception.reason ?? "(no reason)",
                stack: stack
            )
        }

        for sig in [SIGABRT, SIGILL, SIGSEGV, SIGTRAP, SIGFPE, SIGBUS] {
            signal(sig) { received in
                let frames = Thread.callStackSymbols.joined(separator: "\n")
                CrashReporter.write(
                    kind: "Signal \(received)",
                    reason: CrashReporter.name(for: received),
                    stack: frames
                )
                // Restore the default handler and re-raise so the OS still
                // produces its normal crash report / .ips for the App Store.
                signal(received, SIG_DFL)
                raise(received)
            }
        }
    }

    private static func name(for sig: Int32) -> String {
        switch sig {
        case SIGABRT: return "SIGABRT (abort — usually an uncaught Objective-C exception)"
        case SIGILL:  return "SIGILL (illegal instruction — often a Swift runtime trap: force-unwrap of nil, out-of-bounds, overflow)"
        case SIGSEGV: return "SIGSEGV (bad memory access)"
        case SIGTRAP: return "SIGTRAP (trap — Swift precondition / fatalError)"
        case SIGFPE:  return "SIGFPE (arithmetic error — e.g. divide by zero)"
        case SIGBUS:  return "SIGBUS (bad memory access)"
        default:      return "Signal \(sig)"
        }
    }

    /// Async-signal-safe-ish best effort: build the text and write it with a
    /// low-level file descriptor rather than Foundation's higher-level APIs.
    private static func write(kind: String, reason: String, stack: String) {
        let text = """
        === CareBridge crash ===
        Kind: \(kind)
        Reason: \(reason)

        Call stack:
        \(stack)
        ========================
        """
        guard let data = text.data(using: .utf8) else { return }
        let path = reportURL.path
        let fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        guard fd >= 0 else { return }
        data.withUnsafeBytes { _ = Foundation.write(fd, $0.baseAddress, $0.count) }
        close(fd)
    }

    /// If a report was written before the last termination, log it once and
    /// clear it so it's obvious in the console what took the app down.
    private static func surfacePreviousCrash() {
        guard let text = try? String(contentsOf: reportURL, encoding: .utf8) else { return }
        NSLog("⚠️ CareBridge recovered a crash report from the previous session:\n%@", text)
        try? FileManager.default.removeItem(at: reportURL)
    }
}
