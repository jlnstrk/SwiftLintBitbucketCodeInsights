import Vapor
import ShellOut
import SwiftLintFramework

#if DEBUG
var env = try Environment.detect(
    arguments: [CommandLine.arguments.first ?? ".", "serve", "--env", "development", "--hostname", "0.0.0.0", "--port", "8080"]
)
#else
var env = try Environment.detect(
    arguments: [CommandLine.arguments.first ?? ".", "serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
)
#endif

try LoggingSystem.bootstrap(from: &env)

let app = Application(env)
defer {
    app.shutdown()
}

RuleRegistry.registerAllRulesOnce()
let context = Context.parseOrExit()

if let loglevel = context.loglevel {
    app.logger.logLevel = loglevel
}

app.post { request in
    try BitbucketEvent
        .create(from: request)
        .flatMapThrowing { bitbucketEvent -> EventLoopFuture<Void> in
            request.logger.notice("Parsed webhook request: \(bitbucketEvent.type)")
            return try bitbucketEvent.performSwiftLintBotActions(on: request)
                .map {
                    request.logger.notice("Done ✅")
                }
        }
        .transform(to: "Done ✅")
}

try app.run()
