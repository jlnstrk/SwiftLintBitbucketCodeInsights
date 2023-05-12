//
//  File 2.swift
//  
//
//  Created by Paul Schmiedmayer on 12/21/20.
//

import ArgumentParser
import ShellOut
import SwiftLintFramework
import Vapor


struct Context: ParsableCommand {
    @ArgumentParser.Option(help: "The Bitbucket instance that is used. E.g.: bitbucket.schmiedmayer.com.")
    var bitbucket: String
    
    @ArgumentParser.Option(
        help: """
        The Bitbucket project secrets used to authenticate with the Bitbucket instance.
        Pass comma separated string of mappings "[PROJECTID1]=[SECRET1],[PROJECTID2]=[SECRET2]".
        """,
        transform: readSecretsMapping
)
    var secrets: [String: String]
    
    @ArgumentParser.Option(
        help: """
        The Bitbucket slug that should be used to identify this insighs tool.
        The default value is com.schmiedmayer.swiftlintbot
        """
    )
    var slug: String = "com.schmiedmayer.swiftlintbot"
    
    @ArgumentParser.Option(
        help: """
        The SwiftLint configuration file that should be used if there is no .swiftlint.yml file in the repository that should be evaluated.
        The default behaviour is to execute SwiftLint with no configuration.
        You can use `default` to use the swiftlint configuration file bundled with the SwiftLint Bitbucket Code Insights tool.
        """,
        transform: readConfigurationFile
    )
    var configuration: URL?
    
    
    @ArgumentParser.Option(
        help: """
        Defines the log level of the SwiftLint Bitbucket Code Insights bot.
        Possible values are: \(Logger.Level.allCases.map { $0.rawValue }.joined(separator: ", "))
        """,
        transform: readLogLevel
    )
    var loglevel: Logger.Level?
    
    var baseURL: String {
        "https://\(bitbucket)/rest"
    }
    
    func requestHeader(project: String) throws -> HTTPHeaders {
        var headers = HTTPHeaders()
        guard let secret = context.secrets[project] else {
            throw Abort(.internalServerError, reason: "Missing secret for project \(project)")
        }
        headers.add(name: .authorization, value: "Bearer \(secret)")
        headers.add(name: "X-Atlassian-Token", value: "no-check")
        return headers
    }
    
    
    private static func readConfigurationFile(_ string: String) throws -> URL? {
        let potentialConfigurationFile: URL
        
        if string == "default",
           let potentialConfigurationFilePath = Bundle.module.url(forResource: "swiftlint", withExtension: "yml") {
            potentialConfigurationFile = potentialConfigurationFilePath
        } else {
            potentialConfigurationFile = URL(fileURLWithPath: string)
        }
        
        let relativePath = potentialConfigurationFile.relativePath(to: Bundle.module.bundleURL)
        app.logger.notice("Trying to load the default SwiftLint configuration at \(relativePath)")
        _ = Configuration(configurationFiles: [potentialConfigurationFile.path])
        
        return potentialConfigurationFile
    }

    private static func readSecretsMapping(_ string: String) throws -> [String: String] {
        app.logger.notice("Trying to load the project secrets mapping")

        var map: [String: String] = [:]
        string
            .split(separator: ",")
            .forEach {
                let components = $0.split(separator: "=")
                map[String(components[0])] = String(components[1])
            }
        return map
    }
    
    private static func readLogLevel(_ string: String) throws -> Logger.Level? {
        Logger.Level(rawValue: string)
    }
}
