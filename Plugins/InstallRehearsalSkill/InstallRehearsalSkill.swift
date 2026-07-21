import Foundation
import PackagePlugin

@main
struct InstallRehearsalSkill: CommandPlugin {
	func performCommand(context: PluginContext, arguments _: [String]) async throws {
		try installSkill(into: context.package.directoryURL)
	}
}

#if canImport(XcodeProjectPlugin)
	import XcodeProjectPlugin

	extension InstallRehearsalSkill: XcodeCommandPlugin {
		func performCommand(context: XcodePluginContext, arguments _: [String]) throws {
			try installSkill(into: context.xcodeProject.directoryURL)
		}
	}
#endif

/// Copies the skill shipped at `skills/rehearsal` into the consuming
/// project's `.agents/skills/rehearsal` — the vendor-neutral Agent Skills
/// location read by Codex, Gemini CLI, and OpenCode — and bridges Claude
/// Code (which only scans `.claude/skills`, but follows symlinks) with a
/// relative symlink at `.claude/skills/rehearsal`.
///
/// The skill source is located relative to `#filePath`: command plugins are
/// always compiled from source on the consumer's machine, so the path baked
/// in at compile time exists at run time. Neither plugin context exposes a
/// dependency's checkout directory (`XcodePluginContext` has no package graph
/// at all), so this is the only lookup that works for both SwiftPM and Xcode
/// project consumers.
private func installSkill(into projectDirectory: URL) throws {
	let skillSource = URL(fileURLWithPath: #filePath)
		.deletingLastPathComponent() // InstallRehearsalSkill/
		.deletingLastPathComponent() // Plugins/
		.deletingLastPathComponent() // package root
		.appendingPathComponent("skills/rehearsal", isDirectory: true)

	let fileManager = FileManager.default
	guard fileManager.fileExists(atPath: skillSource.path) else {
		throw InstallError("Expected the skill at \(skillSource.path), but it isn't there. Was the skills directory moved without updating the plugin?")
	}

	let canonical = projectDirectory
		.appendingPathComponent(".agents/skills/rehearsal", isDirectory: true)
	try fileManager.createDirectory(at: canonical.deletingLastPathComponent(), withIntermediateDirectories: true)
	try? fileManager.removeItem(at: canonical)
	try fileManager.copyItem(at: skillSource, to: canonical)

	// A relative link target survives the project directory moving or being
	// checked out at a different path.
	let claudeLink = projectDirectory
		.appendingPathComponent(".claude/skills/rehearsal", isDirectory: true)
	try fileManager.createDirectory(at: claudeLink.deletingLastPathComponent(), withIntermediateDirectories: true)
	try? fileManager.removeItem(at: claudeLink)
	try fileManager.createSymbolicLink(atPath: claudeLink.path, withDestinationPath: "../../.agents/skills/rehearsal")

	print("Installed the Rehearsal agent skill at \(canonical.path)")
	print("Symlinked \(claudeLink.path) for Claude Code")
}

private struct InstallError: Error, CustomStringConvertible {
	let description: String

	init(_ description: String) {
		self.description = description
	}
}
