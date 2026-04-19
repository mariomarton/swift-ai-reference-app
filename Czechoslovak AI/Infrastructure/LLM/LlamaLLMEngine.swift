import Foundation
#if canImport(LlamaFramework)
import LlamaFramework
#elseif canImport(llama)
import llama
#else
#error("No llama module found. Add Vendor/LlamaBinary as a local package dependency.")
#endif

/// Concrete `LLMEngine` backed by llama.cpp for fully on-device inference.
///
/// ## Swift Package prerequisite
/// Before this file compiles, add the local package at `Vendor/LlamaBinary`
/// to the app target in Xcode.
///
/// This wrapper pins the official llama.cpp XCFramework release `b8579`.
///
/// ## Supported models
/// Any GGUF-quantised model using the **ChatML** or **Llama-3** prompt format.
/// Prompt formatting is selected from model identity heuristics.
///
/// ## Concurrency
/// `LlamaLLMEngine` is not thread-safe.  Never call `generateResponse` again
/// while a previous stream is still being consumed.  In practice, the chat UI
/// only sends one message at a time, which satisfies this constraint.
public final class LlamaLLMEngine: LLMEngine {

    enum PromptTemplateProfile {
        case chatML
        case llama3

        var stopSequences: [String] {
            switch self {
            case .chatML:
                return [
                    "<|im_end|>",
                    "<|im_start|>user",
                    "<|im_start|>system",
                    "<|im_start|>assistant"
                ]
            case .llama3:
                return [
                    "<|eot_id|>",
                    "<|start_header_id|>user<|end_header_id|>",
                    "<|start_header_id|>system<|end_header_id|>",
                    "<|start_header_id|>assistant<|end_header_id|>"
                ]
            }
        }

        var controlMarkers: [String] {
            switch self {
            case .chatML:
                return ["<|im_start|>", "<|im_end|>"]
            case .llama3:
                return ["<|begin_of_text|>", "<|start_header_id|>", "<|end_header_id|>", "<|eot_id|>"]
            }
        }
    }

    // MARK: - Stored state

    private let llamaModel:   OpaquePointer
    private let llamaContext: OpaquePointer
    private let contextWindow: Int32
    private let prefillBatchSize: Int32
    private let maxGeneratedTokens: Int

    // MARK: - Init / deinit

    /// Loads a GGUF model file and creates an inference context.
    ///
    /// - Parameter modelPath: absolute path to the `.gguf` model file on disk.
    /// - Throws: `LlamaError.modelNotFound` if the file does not exist,
    ///           `LlamaError.modelLoadFailed` / `LlamaError.contextCreationFailed` on
    ///           llama.cpp-level failures.
    public init(modelPath: String) throws {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw LlamaError.modelNotFound(path: modelPath)
        }

        llama_backend_init()

        let modelParams = llama_model_default_params()
        guard let model = llama_model_load_from_file(modelPath, modelParams) else {
            llama_backend_free()
            throw LlamaError.modelLoadFailed
        }

        if llama_model_has_encoder(model) {
            let architectureDescription: String
            if llama_model_has_decoder(model) {
                architectureDescription = "encoder-decoder model"
            } else {
                architectureDescription = "encoder-only model"
            }

            llama_model_free(model)
            llama_backend_free()
            throw LlamaError.unsupportedModelArchitecture(description: architectureDescription)
        }

        var ctxParams      = llama_context_default_params()
        ctxParams.n_ctx    = 4096  // tokens in the context window
        ctxParams.n_batch  = 512   // prompt-processing batch size

        guard let ctx = llama_init_from_model(model, ctxParams) else {
            llama_model_free(model)
            llama_backend_free()
            throw LlamaError.contextCreationFailed
        }

        self.llamaModel   = model
        self.llamaContext = ctx
        self.contextWindow = Int32(ctxParams.n_ctx)
        self.prefillBatchSize = Int32(ctxParams.n_batch)
        self.maxGeneratedTokens = 1024
    }

    deinit {
        llama_free(llamaContext)
        llama_model_free(llamaModel)
        llama_backend_free()
    }

    // MARK: - LLMEngine

    public func generateResponse(
        for messages:  [Message],
        model: LLMModel?
    ) -> AsyncThrowingStream<String, Error> {
        // Capture C-level pointers by value.
        // `self` is guaranteed to outlive the stream because the caller awaits it.
        let llamaModel   = self.llamaModel
        let llamaContext = self.llamaContext
        let contextWindow = self.contextWindow
        let prefillBatchSize = self.prefillBatchSize
        let maxGeneratedTokens = self.maxGeneratedTokens

        return AsyncThrowingStream { continuation in
            // Run inference off the calling actor so llama's CPU-bound work
            // does not block the main actor.
            Task.detached(priority: .userInitiated) {
                do {
                    let profile = Self.resolvePromptTemplateProfile(for: model)
                    let prompt = Self.formatPrompt(messages: messages, profile: profile)
                    try await Self.runInferenceLoop(
                        prompt:       prompt,
                        model:        llamaModel,
                        context:      llamaContext,
                        promptProfile: profile,
                        contextWindow: contextWindow,
                        prefillBatchSize: prefillBatchSize,
                        maxGeneratedTokens: maxGeneratedTokens,
                        continuation: continuation
                    )
                } catch let err as LlamaError {
                    continuation.finish(throwing: err)
                } catch {
                    continuation.finish(throwing: LlamaError.inferenceFailed(error))
                }
            }
        }
    }

    // MARK: - Inference loop (static — no implicit capture of self)

    private static func runInferenceLoop(
        prompt:       String,
        model:        OpaquePointer,
        context:      OpaquePointer,
        promptProfile: PromptTemplateProfile,
        contextWindow: Int32,
        prefillBatchSize: Int32,
        maxGeneratedTokens: Int,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) throws {

        // ── 1. Tokenise ──────────────────────────────────────────────────────

        guard let vocab = llama_model_get_vocab(model) else {
            throw LlamaError.inferenceFailed(
                NSError(domain: "ai.czechoslovak.llama", code: 10,
                        userInfo: [NSLocalizedDescriptionKey: "Could not retrieve model vocab"])
            )
        }

        let maxPromptTokens = prompt.utf8.count + 64
        var tokens = [llama_token](repeating: 0, count: maxPromptTokens)

        let nTokens = prompt.withCString { cStr in
            llama_tokenize(
                vocab, cStr, Int32(prompt.utf8.count),
                &tokens, Int32(maxPromptTokens),
                /* add_special  */ true,
                /* parse_special */ true
            )
        }
        guard nTokens > 0 else { throw LlamaError.tokenizationFailed }
        tokens = Array(tokens.prefix(Int(nTokens)))

        // Keep the newest prompt tokens so prefill + generation remains within n_ctx.
        let trimStart = trimmedPromptStartIndex(
            totalTokenCount: tokens.count,
            contextWindow: Int(contextWindow),
            maxNewTokens: maxGeneratedTokens
        )
        if trimStart > 0 {
            tokens = Array(tokens[trimStart...])
        }

        // ── 2. Clear KV cache from any previous call ─────────────────────────

        guard let memory = llama_get_memory(context) else {
            throw LlamaError.inferenceFailed(
                NSError(domain: "ai.czechoslovak.llama", code: 14,
                        userInfo: [NSLocalizedDescriptionKey: "Could not access context memory"])
            )
        }
        llama_memory_clear(memory, false)

        // ── 3. Prefill: decode the whole prompt in one batch ─────────────────

        let batchCapacity = max(1, Int(prefillBatchSize))
        var batch = llama_batch_init(Int32(batchCapacity), 0, 1)
        defer { llama_batch_free(batch) }

        for range in prefillChunkRanges(totalTokens: tokens.count, batchSize: batchCapacity) {
            batch.n_tokens = 0
            for i in range {
                appendToken(&batch, token: tokens[i], pos: Int32(i),
                            seqId: 0, logits: i == tokens.count - 1)
            }

            guard llama_decode(context, batch) == 0 else {
                throw LlamaError.inferenceFailed(
                    NSError(domain: "ai.czechoslovak.llama", code: 11,
                            userInfo: [NSLocalizedDescriptionKey: "Prompt prefill failed"])
                )
            }
        }

        // ── 4. Build sampler chain ────────────────────────────────────────────
        //
        // Ownership: llama_sampler_chain_add transfers ownership of each
        // sub-sampler to the chain.  llama_sampler_free(chain) frees all of them.

        let chainParams = llama_sampler_chain_default_params()
        guard let sampler = llama_sampler_chain_init(chainParams) else {
            throw LlamaError.inferenceFailed(
                NSError(domain: "ai.czechoslovak.llama", code: 12,
                        userInfo: [NSLocalizedDescriptionKey: "Sampler chain init failed"])
            )
        }
        defer { llama_sampler_free(sampler) }

        llama_sampler_chain_add(sampler, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.95, 1))
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.8))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(
            UInt32.random(in: 0 ..< UInt32.max)
        ))

        var nPos      = Int32(tokens.count)
        let maxNew    = maxGeneratedTokens
        var outputPolicy = StreamOutputPolicy(profile: promptProfile)

        // ── 5. Auto-regressive decode loop ───────────────────────────────────

        for _ in 0 ..< maxNew {
            let newToken = llama_sampler_sample(sampler, context, -1)
            llama_sampler_accept(sampler, newToken)

            if llama_vocab_is_eog(vocab, newToken) { break }

            if let piece = tokenToPiece(vocab: vocab, token: newToken), !piece.isEmpty {
                let result = outputPolicy.process(piece: piece)
                if !result.output.isEmpty {
                    continuation.yield(result.output)
                }
                if result.shouldStop {
                    break
                }
            }

            // Prepare single-token batch for the next step
            batch.n_tokens = 0
            appendToken(&batch, token: newToken, pos: nPos, seqId: 0, logits: true)
            nPos += 1

            guard llama_decode(context, batch) == 0 else {
                throw LlamaError.inferenceFailed(
                    NSError(domain: "ai.czechoslovak.llama", code: 13,
                            userInfo: [NSLocalizedDescriptionKey: "Decode failed at pos \(nPos)"])
                )
            }
        }

        let trailingOutput = outputPolicy.finish()
        if !trailingOutput.isEmpty {
            continuation.yield(trailingOutput)
        }

        continuation.finish()
    }

    // MARK: - Prompt/window helpers

    static func resolvePromptTemplateProfile(for model: LLMModel?) -> PromptTemplateProfile {
        let candidates = [model?.id, model?.name, model?.path]
            .compactMap { $0?.lowercased() }

        if candidates.contains(where: { $0.contains("llama-3") || $0.contains("llama3") || $0.contains("meta-llama") }) {
            return .llama3
        }
        return .chatML
    }

    static func formatPrompt(messages: [Message], profile: PromptTemplateProfile) -> String {
        switch profile {
        case .chatML:
            return ChatMLFormatter.format(messages)
        case .llama3:
            return Llama3Formatter.format(messages)
        }
    }

    /// Computes prompt trim start so prompt + planned generation fits into context window.
    static func trimmedPromptStartIndex(
        totalTokenCount: Int,
        contextWindow: Int,
        maxNewTokens: Int
    ) -> Int {
        guard totalTokenCount > 0 else { return 0 }
        let availablePromptBudget = max(1, contextWindow - maxNewTokens - 1)
        if totalTokenCount <= availablePromptBudget { return 0 }
        return totalTokenCount - availablePromptBudget
    }

    /// Produces contiguous prefill decode chunks that never exceed batch size.
    static func prefillChunkRanges(totalTokens: Int, batchSize: Int) -> [Range<Int>] {
        guard totalTokens > 0 else { return [] }
        let effectiveBatchSize = max(1, batchSize)

        var result: [Range<Int>] = []
        var start = 0
        while start < totalTokens {
            let end = min(start + effectiveBatchSize, totalTokens)
            result.append(start..<end)
            start = end
        }
        return result
    }

    static func processPiecesForTesting(
        pieces: [String],
        profile: PromptTemplateProfile
    ) -> (output: String, didStop: Bool) {
        var policy = StreamOutputPolicy(profile: profile)
        var output = ""
        var didStop = false

        for piece in pieces {
            let result = policy.process(piece: piece)
            output += result.output
            if result.shouldStop {
                didStop = true
                break
            }
        }

        if !didStop {
            output += policy.finish()
        }

        return (output, didStop)
    }

    struct StreamOutputPolicy {
        private let stopSequences: [String]
        private let controlMarkers: [String]
        private let holdbackLength: Int
        private var buffer = ""

        init(profile: PromptTemplateProfile) {
            self.stopSequences = profile.stopSequences
            self.controlMarkers = profile.controlMarkers
            self.holdbackLength = max(
                1,
                (stopSequences + controlMarkers).map(\.count).max() ?? 1
            ) - 1
        }

        mutating func process(piece: String) -> (output: String, shouldStop: Bool) {
            guard !piece.isEmpty else { return ("", false) }
            buffer += piece

            if let stopRange = earliestStopRange(in: buffer) {
                let rawOutput = String(buffer[..<stopRange.lowerBound])
                buffer.removeAll(keepingCapacity: true)
                return (sanitize(rawOutput), true)
            }

            guard buffer.count > holdbackLength else {
                return ("", false)
            }

            let splitIndex = buffer.index(buffer.endIndex, offsetBy: -holdbackLength)
            let rawOutput = String(buffer[..<splitIndex])
            buffer = String(buffer[splitIndex...])
            return (sanitize(rawOutput), false)
        }

        mutating func finish() -> String {
            defer { buffer.removeAll(keepingCapacity: true) }
            return sanitize(buffer)
        }

        private func earliestStopRange(in text: String) -> Range<String.Index>? {
            var earliest: Range<String.Index>?

            for stop in stopSequences where !stop.isEmpty {
                guard let range = text.range(of: stop) else { continue }
                guard let candidate = earliest else {
                    earliest = range
                    continue
                }

                if range.lowerBound < candidate.lowerBound {
                    earliest = range
                }
            }

            return earliest
        }

        private func sanitize(_ raw: String) -> String {
            controlMarkers.reduce(raw) { partial, marker in
                partial.replacingOccurrences(of: marker, with: "")
            }
        }
    }

    // MARK: - C-level helpers
    //
    // `llama_batch_add` is a C static-inline function and therefore not bridged
    // to Swift.  We replicate its body here.

    private static func appendToken(
        _ batch:  inout llama_batch,
        token:    llama_token,
        pos:      llama_pos,
        seqId:    llama_seq_id,
        logits:   Bool
    ) {
        let i = Int(batch.n_tokens)
        batch.token![i]      = token
        batch.pos![i]        = pos
        batch.n_seq_id![i]   = 1
        batch.seq_id![i]![0] = seqId
        batch.logits![i]     = logits ? 1 : 0
        batch.n_tokens      += 1
    }

    /// Converts a `llama_token` id to its UTF-8 string piece.
    private static func tokenToPiece(vocab: OpaquePointer, token: llama_token) -> String? {
        var buf = [CChar](repeating: 0, count: 256)
        let len = llama_token_to_piece(vocab, token, &buf, Int32(buf.count), 0, true)
        guard len > 0 else { return nil }
        return String(bytes: buf.prefix(Int(len)).map { UInt8(bitPattern: $0) }, encoding: .utf8)
    }
}
