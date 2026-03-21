import test from 'node:test';
import assert from 'node:assert/strict';

import { createCodexAdapter } from './codex-adapter.mjs';

test('createCodexAdapter passes systemPrompt as developer_instructions', async () => {
  const constructed = [];
  const fakeThread = {
    id: 'thread-1',
    async runStreamed() {
      return { events: emptyAsync() };
    },
  };

  class FakeCodex {
    constructor(opts) {
      constructed.push(opts);
    }

    startThread(opts) {
      assert.equal(opts.workingDirectory, process.cwd());
      return fakeThread;
    }

    resumeThread() {
      throw new Error('resumeThread should not be called');
    }
  }

  const adapter = createCodexAdapter({ CodexClient: FakeCodex });
  const result = await adapter.start({
    prompt: 'Implement auth',
    systemPrompt: 'Follow the brief',
  });

  assert.deepEqual(constructed, [
    { config: { developer_instructions: 'Follow the brief' } },
  ]);
  assert.equal(result.sessionId, 'thread-1');
});

test('createCodexAdapter creates Codex with no config when systemPrompt is absent', async () => {
  const constructed = [];
  const fakeThread = {
    id: 'thread-2',
    async runStreamed() {
      return { events: emptyAsync() };
    },
  };

  class FakeCodex {
    constructor(opts) {
      constructed.push(opts);
    }

    startThread() {
      return fakeThread;
    }

    resumeThread() {
      throw new Error('resumeThread should not be called');
    }
  }

  const adapter = createCodexAdapter({ CodexClient: FakeCodex });
  const result = await adapter.start({
    prompt: 'Implement auth',
  });

  assert.deepEqual(constructed, [undefined]);
  assert.equal(result.sessionId, 'thread-2');
});

async function* emptyAsync() {}
