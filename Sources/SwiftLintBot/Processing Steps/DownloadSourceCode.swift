//
//  DownloadSourceCode.swift
//  
//
//  Created by Paul Schmiedmayer on 12/21/20.
//

import Vapor
import ShellOut

extension BitbucketEvent {
    private var archiveRequestURL: URI {
        "\(context.baseURL)/api/latest/projects/\(project.key)/repos/\(repository.key)/archive?at=\(pullRequest.commitHash)&filename=\(pullRequest.commitHash).zip&format=zip"
    }
    
    func downloadSourceCode(on request: Request) throws -> EventLoopFuture<Void> {
        request.logger.info("Create a working directory at \(workingDirectory)")
        try shellOut(to: "mkdir -p \(self.workingDirectory)")
        
        request.logger.info("Send request to \(archiveRequestURL)")
        
        return request.client
            .get(archiveRequestURL, headers: try context.requestHeader(project: project.key))
            .flatMapThrowing { response -> ByteBuffer? in
                guard response.status == .ok else {
                    request.logger.error("Could not download the .zip from \(archiveRequestURL)")
                    throw Abort(.internalServerError, reason: "Could not download the .zip archieve from BitBucket")
                }
                
                request.logger.debug("Recieved Zip Archive from Bitbucket (\(response.body?.readableBytes ?? 0) B)")
                return response.body
            }
            .unwrap(or: Abort(.badRequest, reason: "Could not parse the pull request body"))
            .flatMap { byteBuffer in
                request.fileio.writeFile(byteBuffer, at: "\(workingDirectory)/\(pullRequest.commitHash).zip")
            }
            .flatMap {
                do {
                    request.logger.info("Wrote file to \(workingDirectory)/\(pullRequest.commitHash).zip")
                    return try unzipSourceCode(on: request)
                } catch {
                    return request.eventLoop.makeFailedFuture(error)
                }
            }
    }
}
