// swift-tools-version: 6.0
// Rehearsal — interactive SwiftUI previews with an auto-generated control panel.

import PackageDescription

let package = Package(
	name: "Rehearsal",
	platforms: [.iOS(.v16), .macOS(.v13), .visionOS(.v1), .macCatalyst(.v16)],
	products: [
		.library(
			name: "Rehearsal",
			targets: ["Rehearsal"]
		),
		// Exposed as a product so Xcode includes the example previews in the
		// package's schemes.
		.library(
			name: "RehearsalExamples",
			targets: ["RehearsalExamples"]
		),
		// Copies the bundled agent skill (skills/rehearsal) into a consuming
		// project's .claude/skills directory.
		.plugin(
			name: "InstallRehearsalSkill",
			targets: ["InstallRehearsalSkill"]
		),
	],
	dependencies: [
		// Build-plugin only (nothing links into consumers): recognizes the
		// .docc catalog and enables `swift package generate-documentation`.
		.package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
	],
	targets: [
		.target(name: "Rehearsal"),

		// Example views exercising every supported parameter type.
		.target(
			name: "RehearsalExamples",
			dependencies: ["Rehearsal"],
			path: "Examples/RehearsalExamples"
		),

		.testTarget(
			name: "RehearsalTests",
			dependencies: ["Rehearsal"]
		),

		.plugin(
			name: "InstallRehearsalSkill",
			capability: .command(
				intent: .custom(
					verb: "install-rehearsal-skill",
					description: "Copies the Rehearsal agent skill into this project's .claude/skills directory"
				),
				permissions: [
					.writeToPackageDirectory(reason: "Installs the Rehearsal agent skill into .claude/skills"),
				]
			)
		),
	]
)
