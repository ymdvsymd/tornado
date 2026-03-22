import { Codex } from "@openai/codex-sdk";
import {
  formatTurnCompletedLog,
  formatTurnFailedLog,
  normalizeItemComplete,
  normalizeItemStart,
  normalizeTurnCompleted,
  normalizeTurnFailed,
} from "./codex-normalizer.mjs";
export function createCodexAdapter(deps = {}) {
  return {
    tag: "Codex",
    async start(opts) {
      const codexClientOpts = opts.systemPrompt
        ? { config: { developer_instructions: opts.systemPrompt } }
        : undefined;
      const client = new (deps.CodexClient || Codex)(codexClientOpts);
      const threadOpts = {
        model: opts.model || undefined,
        workingDirectory: opts.cwd || process.cwd(),
        approvalPolicy: "never",
        sandboxMode: "workspace-write",
      };
      const { thread, log } = opts.threadId
        ? resumeThread(client, opts.threadId, threadOpts)
        : startThread(client, threadOpts);
      const logs = [log, `Thread: ${thread.id}`];
      const run = await thread.runStreamed(opts.prompt);
      return {
        sessionId: thread.id,
        initEvents: [
          {
            type: "system",
            subtype: "init",
            session_id: thread.id,
            model: opts.model || "default",
          },
        ],
        initLogs: logs,
        stream: run.events,
      };
    },
    emit(raw, sessionId) {
      switch (raw.type) {
        case "item.started":
          return emitItemStart(raw.item);
        case "item.completed":
          return emitItemComplete(raw.item);
        case "turn.completed": {
          const resultEvent = normalizeTurnCompleted(raw, sessionId);
          return [{ event: resultEvent, log: formatTurnCompletedLog(raw) }];
        }
        case "turn.failed": {
          const errorEvent = normalizeTurnFailed(raw, sessionId);
          return [{ event: errorEvent, log: formatTurnFailedLog(raw) }];
        }
        default:
          return [];
      }
    },
  };
}
function resumeThread(client, threadId, opts) {
  return {
    thread: client.resumeThread(threadId, opts),
    log: `Resuming thread: ${threadId}`,
  };
}
function startThread(client, opts) {
  return { thread: client.startThread(opts), log: "Starting new thread" };
}
function emitItemStart(item) {
  const normalized = normalizeItemStart(item || {});
  if (!normalized) return [];
  const display =
    typeof normalized._display === "string"
      ? normalized._display
      : item?.type || "item.started";
  return [{ event: normalized, log: display }];
}
function emitItemComplete(item) {
  const normalized = normalizeItemComplete(item || {});
  if (!normalized) return [];
  const display =
    typeof normalized._display === "string"
      ? normalized._display
      : item?.type || "item.completed";
  return [{ event: normalized, log: `Done: ${display}` }];
}
