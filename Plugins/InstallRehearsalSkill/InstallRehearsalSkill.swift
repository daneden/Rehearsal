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
/// project's `.claude/skills/rehearsal`.
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

	let skillsDirectory = projectDirectory
		.appendingPathComponent(".claude/skills", isDirectory: true)
	let destination = skillsDirectory
		.appendingPathComponent("rehearsal", isDirectory: true)

	try fileManager.createDirectory(at: skillsDirectory, withIntermediateDirectories: true)
	if fileManager.fileExists(atPath: destination.path) {
		try fileManager.removeItem(at: destination)
	}
	try fileManager.copyItem(at: skillSource, to: destination)

	print("Installed the Rehearsal agent skill at \(destination.path)")
}

private struct InstallError: Error, CustomStringConvertible {
	let description: String

	init(_ description: String) {
		self.description = description
	}
}
