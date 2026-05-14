#!/usr/bin/env swift
// scripts/check-audio-manifest.swift
//
// Enforces the audio asset manifest invariants from spec `audio-playback`:
//   1. Every file under Resources/Audio/ (excluding _candidates/) is listed
//      in Resources/Audio/manifest.json with a matching `path`.
//   2. Every CC-BY entry carries an `attribution` field.
//   3. Every `file` reference in Resources/Audio/bindings.json matches a
//      manifest entry.
//
// Tolerant of missing manifest / bindings — Phase 1 ships no audio content,
// and a fresh checkout has nothing to validate.
//
// Exit codes:
//   0 — clean (including the empty / no-content case)
//   1 — at least one violation; offending paths are printed to stderr

import Foundation

let auditExtensions: Set<String> = ["mp3", "m4a", "caf", "wav", "aac"]

let cwd = FileManager.default.currentDirectoryPath
let audioDir = URL(fileURLWithPath: cwd).appendingPathComponent("Resources/Audio")
let manifestURL = audioDir.appendingPathComponent("manifest.json")
let bindingsURL = audioDir.appendingPathComponent("bindings.json")

func failure(_ message: String) {
    FileHandle.standardError.write(Data("check-audio-manifest: \(message)\n".utf8))
}

guard FileManager.default.fileExists(atPath: audioDir.path) else {
    // Phase 0/early: no Resources/Audio at all.
    exit(0)
}

// Walk the audio dir.
var bundledFiles: [String] = []
if let enumerator = FileManager.default.enumerator(
    at: audioDir,
    includingPropertiesForKeys: [.isRegularFileKey],
    options: [.skipsHiddenFiles]
) {
    for case let url as URL in enumerator {
        let path = url.path
        if path.contains("/Resources/Audio/_candidates/") { continue }
        let ext = url.pathExtension.lowercased()
        guard auditExtensions.contains(ext) else { continue }
        guard
            let isFile = try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
            isFile == true
        else { continue }
        // Store the path relative to Resources/Audio/ so it matches the
        // `path` value in manifest.json.
        let relative = String(path.dropFirst(audioDir.path.count + 1))
        bundledFiles.append(relative)
    }
}

// Load manifest if present.
struct ManifestEntry: Codable {
    let path: String
    let title: String
    let author: String
    let source: String
    let license: String
    let attribution: String?
}

struct Manifest: Codable {
    let version: Int
    let entries: [ManifestEntry]
}

var manifest: Manifest?
if FileManager.default.fileExists(atPath: manifestURL.path) {
    do {
        let data = try Data(contentsOf: manifestURL)
        manifest = try JSONDecoder().decode(Manifest.self, from: data)
    } catch {
        failure("manifest.json could not be parsed: \(error.localizedDescription)")
        exit(1)
    }
}

var problems: [String] = []

// 1. Every bundled file has a manifest entry.
let manifestPaths = Set(manifest?.entries.map(\.path) ?? [])
for file in bundledFiles where !manifestPaths.contains(file) {
    problems.append("audio file '\(file)' has no entry in manifest.json")
}

// 2. CC-BY (and other non-CC0) entries require attribution.
let attributionLicenses: Set<String> = ["CC-BY-3.0", "CC-BY-4.0", "Pixabay-Content", "proprietary"]
for entry in manifest?.entries ?? [] where attributionLicenses.contains(entry.license) {
    if (entry.attribution ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
        problems.append("manifest entry '\(entry.path)' uses license \(entry.license) but has no attribution")
    }
}

// 3. Bindings file references must be in the manifest.
if FileManager.default.fileExists(atPath: bindingsURL.path) {
    // `file` is optional: Phase 2 introduced stop-action cues that have
    // no associated file. They contribute no manifest reference and are
    // skipped below.
    struct Cue: Codable { let file: String? }
    struct MusicTrack: Codable { let file: String }
    struct MusicSection: Codable { let tracks: [MusicTrack]? }
    struct AmbientSection: Codable { let tracks: [MusicTrack]? }
    struct Bindings: Codable {
        let bindings: [String: [Cue]]?
        let music: MusicSection?
        let ambient: AmbientSection?
    }
    do {
        let data = try Data(contentsOf: bindingsURL)
        let bindings = try JSONDecoder().decode(Bindings.self, from: data)
        var referenced: [String] = []
        for cues in (bindings.bindings ?? [:]).values {
            for cue in cues {
                if let file = cue.file, !file.isEmpty {
                    referenced.append(file)
                }
            }
        }
        referenced.append(contentsOf: bindings.music?.tracks?.map(\.file) ?? [])
        referenced.append(contentsOf: bindings.ambient?.tracks?.map(\.file) ?? [])
        for path in referenced where !manifestPaths.contains(path) {
            problems.append("bindings.json references file '\(path)' which has no manifest entry")
        }
    } catch {
        failure("bindings.json could not be parsed: \(error.localizedDescription)")
        exit(1)
    }
}

if problems.isEmpty {
    exit(0)
} else {
    for line in problems { failure(line) }
    exit(1)
}
