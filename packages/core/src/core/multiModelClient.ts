/**
 * @license
 * Copyright 2025 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */

import { Config } from '../config/config.js';
import { GeminiClient } from './client.js';
import { OpenRouterClient } from './openRouterClient.js';

export interface LLMClient {
  generate(prompt: string): Promise<string>;
  name: string;
}

/**
 * MultiModelClient dispatches the same prompt to multiple models in parallel
 * and returns the response chosen by a secondary voting model. If no voting
 * model is available, the longest response is used.
 */
export class MultiModelClient {
  private clients: LLMClient[] = [];
  private voter: LLMClient | null = null;

  constructor(private config: Config) {
    const apiKey = process.env.OPENROUTER_API_KEY;
    for (const model of config.getModels()) {
      if (model.startsWith('gemini')) {
        this.clients.push({
          name: model,
          generate: async (prompt: string) => {
            config.setModel(model);
            const chat = await config.getGeminiClient().getChat();
            const resp = await chat.sendMessage([ { text: prompt } ]);
            return resp.candidates?.[0]?.content?.parts?.map(p => p.text).join('') || '';
          },
        });
      } else if (apiKey) {
        this.clients.push(new OpenRouterClient(apiKey, model));
      }
    }

    if (apiKey) {
      this.voter = new OpenRouterClient(apiKey, 'gpt-3.5-turbo');
    }
  }

  async generate(prompt: string): Promise<string> {
    const responses = await Promise.all(
      this.clients.map((c) => c.generate(prompt)),
    );

    if (this.voter) {
      const votePrompt =
        'Choose the best response for the user question. ' +
        'Return the number of the best answer.\n\nQuestion:' +
        ` ${prompt}\n` +
        this.clients
          .map((c, i) => `Answer ${i}: ${responses[i]}`)
          .join('\n');

      const vote = await this.voter.generate(votePrompt);
      const match = vote.match(/\d+/);
      if (match) {
        const idx = parseInt(match[0], 10);
        if (!isNaN(idx) && idx >= 0 && idx < responses.length) {
          return responses[idx];
        }
      }
    }

    // Fallback heuristic: choose longest response
    let best = responses[0] || '';
    for (const resp of responses) {
      if (resp.length > best.length) best = resp;
    }
    return best;
  }
}

