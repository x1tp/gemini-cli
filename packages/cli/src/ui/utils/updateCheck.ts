/**
 * @license
 * Copyright 2025 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */

import updateNotifier from 'update-notifier';
import semver from 'semver';
import { getPackageJson } from '../../utils/package.js';

const CHECK_FOR_UPDATES_TIMEOUT_MS = 2000;

async function doCheckForUpdates(): Promise<string | null> {
  const packageJson = await getPackageJson();
  if (!packageJson || !packageJson.name || !packageJson.version) {
    return null;
  }
  const notifier = updateNotifier({
    pkg: {
      name: packageJson.name,
      version: packageJson.version,
    },
    // check every time
    updateCheckInterval: 0,
    // allow notifier to run in scripts
    shouldNotifyInNpmScript: true,
  });

  if (
    notifier.update &&
    semver.gt(notifier.update.latest, notifier.update.current)
  ) {
    return `Gemini CLI update available! ${notifier.update.current} → ${notifier.update.latest}\nRun npm install -g ${packageJson.name} to update`;
  }

  return null;
}

export async function checkForUpdates(): Promise<string | null> {
  try {
    return await new Promise((resolve, reject) => {
      const timeoutId = setTimeout(() => {
        reject(new Error('Update check timed out'));
      }, CHECK_FOR_UPDATES_TIMEOUT_MS);

      doCheckForUpdates()
        .then((result) => {
          clearTimeout(timeoutId);
          resolve(result);
        })
        .catch((err) => {
          clearTimeout(timeoutId);
          reject(err);
        });
    });
  } catch (_e) {
    // In case of timeout or any other error, just fail silently.
    return null;
  }
}
