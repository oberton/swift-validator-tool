//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 27.08.2021.
//

import Foundation
import ArgumentParser
import TonClientSwift
import FileUtils

extension ValidatorTool {
    struct Message: ParsableCommand, ValidatorToolOptionsPrtcl {

            @OptionGroup var options: ValidatorToolOptions

        @Option(name: [.long, .customShort("m")], help: "Calling method")
        var method: String

        @Option(name: [.long, .customShort("p")], help: "Params")
        var paramsJSON: String = "{}"

        @Option(name: [.long, .customShort("b")], help: "Path to abi file")
        var abiPath: String

        public func run() throws {
            try makeResult()
        }

        @discardableResult
        func makeResult() throws -> String {
            try setClient(options: options)
            var functionResult: String = ""
            let group: DispatchGroup = .init()
            group.enter()

            var params: AnyValue!
            do {
                params = try paramsJsonToDictionary(paramsJSON).toAnyValue()
            } catch {
                fatalError( error.localizedDescription )
            }
            let abi: TSDKAbi = .init(type: .Serialized, value: readAbi(abiPath))
            let callSet: TSDKCallSet = .init(function_name: method,
                                             input: params)
            let signer: TSDKSigner = .init(type: .None)
            let paramsOfEncodeMessageBody: TSDKParamsOfEncodeMessageBody = .init(abi: abi,
                                                                                 call_set: callSet,
                                                                                 is_internal: true,
                                                                                 signer: signer,
                                                                                 processing_try_index: nil)
            client.abi.encode_message_body(paramsOfEncodeMessageBody)
            { (response: TSDKBindingResponse<TSDKResultOfEncodeMessageBody, TSDKClientError>) in
                if let error = response.error {
                    fatalError( error.localizedDescription )
                }
                if response.finished {
                    let boc: String = response.result!.body
                    functionResult = boc
                    group.leave()
                }
            }
            group.wait()

            let stdout: FileHandle = FileHandle.standardOutput
            stdout.write(functionResult.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8) ?? Data())
            return functionResult
        }

        private func paramsJsonToDictionary(_ params: String) throws -> [String: Any] {
            guard let data: Data = params.data(using: .utf8)
            else { fatalError("Bad params json, it must be valid json") }
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any]

            return json ?? [:]
        }
    }
}

