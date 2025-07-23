import { describe, it, expect, vi } from 'vitest';
import { MultiModelClient, LLMClient } from './multiModelClient.js';
import { Config } from '../config/config.js';

class FakeClient implements LLMClient {
  constructor(public name: string, private reply: string) {}
  async generate(): Promise<string> {
    return this.reply;
  }
}

describe('MultiModelClient', () => {
  it('selects the longest response when no voter is available', async () => {
    const config = new Config({
      sessionId: 's',
      targetDir: '.',
      debugMode: false,
      cwd: '.',
      model: 'gemini-2.5-flash',
      models: ['gemini-2.5-flash', 'other'],
    } as never);
    const client = new MultiModelClient(config);
    // Replace clients with fakes
    // @ts-expect-error accessing private field for test
    client.clients = [new FakeClient('a', 'short'), new FakeClient('b', 'much longer text')];
    const res = await client.generate('hi');
    expect(res).toBe('much longer text');
  });
});
