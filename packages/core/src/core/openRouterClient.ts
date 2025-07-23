/**
 * @license
 * Copyright 2025 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */

import { LLMClient } from './multiModelClient.js';

/** Simple client for calling models via OpenRouter. */
export class OpenRouterClient implements LLMClient {
  constructor(private apiKey: string, public name: string) {}

  async generate(prompt: string): Promise<string> {
    const body = {
      model: this.name,
      messages: [{ role: 'user', content: prompt }],
    };

    const resp = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    const json = await resp.json();
    return (
      json.choices?.[0]?.message?.content || ''
    ) as string;
  }
}

