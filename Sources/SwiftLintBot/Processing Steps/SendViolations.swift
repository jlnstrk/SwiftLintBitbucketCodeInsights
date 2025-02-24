//
//  File.swift
//  
//
//  Created by Paul Schmiedmayer on 12/23/20.
//

import Vapor
import SwiftLintFramework

extension BitbucketEvent {
    private var reportURL: URI {
        "\(context.baseURL)/insights/latest/projects/\(project.key)/repos/\(repository.key)/commits/\(pullRequest.commitHash)/reports/\(context.slug)"
    }
    
    private var annotationsURL: URI {
        "\(reportURL)/annotations"
    }
    
    private var violationsChunkSize: Int {
        25
    }
    
    
    func send(_ violations: [StyleViolation], on request: Request) throws -> EventLoopFuture<Void> {
        try deleteAllAnnotations(on: request)
            .flatMap { () -> EventLoopFuture<Void> in
                do {
                    return try updateInsightsReport(basedOn: violations, on: request)
                } catch {
                    return request.eventLoop.makeFailedFuture(error)
                }
            }
            .flatMap { () -> EventLoopFuture<Void> in
                do {
                    return try postAllAnnotations(basedOn: violations, on: request)
                } catch {
                    return request.eventLoop.makeFailedFuture(error)
                }
            }
            .flatMapAlways { result in
                do {
                    if case let .failure(error) = result {
                        request.logger.error("Could not send data to Bitbucket: \(error)")
                    }
                    request.logger.info("Finished sending data to BitBucket")
                    return try cleanup(on: request)
                } catch {
                    request.logger.error("Could not Cleanup the working directory at \(sourceCodeDirectory)")
                    return request.eventLoop.makeSucceededFuture(Void())
                }
            }
    }
    
    private func deleteAllAnnotations(on request: Request) throws -> EventLoopFuture<Void> {
        request.client.delete(annotationsURL, headers: try context.requestHeader(project: project.key))
            .flatMapThrowing { response in
                guard response.status == .noContent else {
                    request.logger.error("Could not delete the annotations from bitbucket: \(response.status). \((try? response.content.decode(String.self)) ?? "No error description provided")")
                    throw Abort(.internalServerError, reason: "Could not delete the annotations from bitbucket")
                }
                if request.logger.logLevel <= .debug, let body = response.body {
                    request.logger.debug("BitBucket Reponse: \(body.getString(at: body.readerIndex, length: body.readableBytes) ?? "")")
                }
                request.logger.info("Successfuly deleted all annotations")
            }
    }
    
    private func postAllAnnotations(basedOn violations: [StyleViolation], on request: Request) throws -> EventLoopFuture<Void> {
        // swiftlint:disable:next array_init
        try stride(from: 0, to: violations.count, by: violationsChunkSize)
            .map {
                violations[$0 ..< min($0 + violationsChunkSize, violations.count)]
            }
            .map { chunkedViolations in
                request.client.post(annotationsURL, headers: try context.requestHeader(project: project.key)) { clientRequest in
                        try clientRequest.content.encode(
                            [
                                "annotations": chunkedViolations.map {
                                    try Annotation($0, relativeTo: URL(fileURLWithPath: sourceCodeDirectory))
                                }
                            ]
                        )
                }
                    .flatMapThrowing { response in
                        guard response.status == .noContent else {
                            request.logger.error("Could not post the annotations: \(response.status). \((try? response.content.decode(String.self)) ?? "No error description provided")")
                            throw Abort(.internalServerError, reason: "Could not post the annotations")
                        }
                        if request.logger.logLevel <= .debug, let body = response.body {
                            request.logger.debug("BitBucket Reponse: \(body.getString(at: body.readerIndex, length: body.readableBytes) ?? "")")
                        }
                        request.logger.info("Successfuly posted the annotations for \(chunkedViolations.count) violations")
                    }
            }
            .map { test in
                test
            }
            .flatten(on: request.eventLoop)
    }
    
    private func updateInsightsReport(basedOn violations: [StyleViolation], on request: Request) throws -> EventLoopFuture<Void> {
        request.client.put(reportURL, headers: try context.requestHeader(project: project.key)) { clientRequest in
            try clientRequest.content.encode(InsightsReport(violations))
        }
            .flatMapThrowing { response in
                guard response.status == .ok else {
                    request.logger.error("Could not update the insights report: \(response.status). \((try? response.content.decode(String.self)) ?? "No error description provided")")
                    throw Abort(.internalServerError, reason: "Could not update the insights report")
                }
                if request.logger.logLevel <= .debug, let body = response.body {
                    request.logger.debug("BitBucket Reponse: \(body.getString(at: body.readerIndex, length: body.readableBytes) ?? "")")
                }
                request.logger.info("Successfuly updated the insights report")
            }
    }
}
