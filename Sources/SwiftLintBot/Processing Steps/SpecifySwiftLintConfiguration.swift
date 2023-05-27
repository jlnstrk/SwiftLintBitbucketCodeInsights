//
//  SpecifySwiftLintConfiguration.swift
//  
//
//  Created by Paul Schmiedmayer on 12/21/20.
//

import ShellOut
import Vapor


extension BitbucketEvent {
    func specifySwiftLintConfiguration(on request: Request) throws -> EventLoopFuture<Void> {
        func enumeratePossibleFileURLs() throws -> [URL] {
            let topLevelFiles = try FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: sourceCodeDirectory),
                includingPropertiesForKeys: [.isRegularFileKey]
            )
            let secondLevelFiles = try FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: sourceCodeDirectory),
                includingPropertiesForKeys: [.isDirectoryKey]
            )
                .filter { directory in
                    let resourceValues = try directory.resourceValues(forKeys: [.isDirectoryKey])
                    return resourceValues.isDirectory ?? false
                }
                .flatMap { directory in
                    try FileManager.default.contentsOfDirectory(
                        at: directory,
                        includingPropertiesForKeys: [.isRegularFileKey]
                    )
                }
            return topLevelFiles + secondLevelFiles
        }
        let fileURLs = try enumeratePossibleFileURLs()

        if let configurationFile = fileURLs.first(where: { $0.lastPathComponent == ".swiftlint.yml" }) {
            let relativePath = configurationFile.relativePath(to: URL(fileURLWithPath: sourceCodeDirectory))
            request.logger.info("Found a .swiftlint.yml file that will be used: \(relativePath)")
            return try executeSwiftLint(on: request, configurationFile: configurationFile.path)
        }
        
        guard let defaultSwiftLintConfiguration = context.configuration else {
            request.logger.info("No .swiftlint.yml file was found")
            return try executeSwiftLint(on: request, configurationFile: nil)
        }
        
        request.logger.info("No .swiftlint.yml file was found. Replacing it with a default file.")
        try shellOut(to: "cp \"\(defaultSwiftLintConfiguration.path)\" \"\(sourceCodeDirectory)/.swiftlint.yml\"")
        
        return try executeSwiftLint(on: request, configurationFile: sourceCodeDirectory + "/.swiftlint.yml")
    }
}
