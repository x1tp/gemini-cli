/**
 * @license
 * Copyright 2025 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */

import { vi, describe, it, expect, beforeEach, afterEach } from 'vitest';
import { checkForUpdates } from './updateCheck.js';

const getPackageJson = vi.hoisted(() => vi.fn());
vi.mock('../../utils/package.js', () => ({
  getPackageJson,
}));

const updateNotifier = vi.hoisted(() => vi.fn());
vi.mock('update-notifier', () => ({
  default: updateNotifier,
}));

describe('checkForUpdates', () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('should return null if package.json is missing', async () => {
    getPackageJson.mockResolvedValue(null);
    const result = await checkForUpdates();
    expect(result).toBeNull();
  });

  it('should return null if there is no update', async () => {
    getPackageJson.mockResolvedValue({
      name: 'test-package',
      version: '1.0.0',
    });
    updateNotifier.mockReturnValue({ update: null });
    const result = await checkForUpdates();
    expect(result).toBeNull();
  });

  it('should return a message if a newer version is available', async () => {
    getPackageJson.mockResolvedValue({
      name: 'test-package',
      version: '1.0.0',
    });
    updateNotifier.mockReturnValue({
      update: { current: '1.0.0', latest: '1.1.0' },
    });
    const result = await checkForUpdates();
    expect(result).toContain('1.0.0 → 1.1.0');
  });

  it('should return null if the latest version is the same as the current version', async () => {
    getPackageJson.mockResolvedValue({
      name: 'test-package',
      version: '1.0.0',
    });
    updateNotifier.mockReturnValue({
      update: { current: '1.0.0', latest: '1.0.0' },
    });
    const result = await checkForUpdates();
    expect(result).toBeNull();
  });

  it('should return null if the latest version is older than the current version', async () => {
    getPackageJson.mockResolvedValue({
      name: 'test-package',
      version: '1.1.0',
    });
    updateNotifier.mockReturnValue({
      update: { current: '1.1.0', latest: '1.0.0' },
    });
    const result = await checkForUpdates();
    expect(result).toBeNull();
  });

  it('should handle errors gracefully', async () => {
    getPackageJson.mockRejectedValue(new Error('test error'));
    const result = await checkForUpdates();
    expect(result).toBeNull();
  });

  it('should return null if the check times out', async () => {
    vi.useFakeTimers();
    getPackageJson.mockResolvedValue({
      name: 'test-package',
      version: '1.0.0',
    });
    // Simulate a long-running check that will cause a timeout.
    updateNotifier.mockImplementation(() => new Promise(() => {}));

    const promise = checkForUpdates();
    vi.advanceTimersToNextTimer(); // Fire the timeout
    const result = await promise;

    expect(result).toBeNull();
  });
});
