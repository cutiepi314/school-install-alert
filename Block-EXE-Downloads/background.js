"use strict";

// Filename-based restriction, not executable-content inspection or application control.
function isExe(filename) {
  return /\.exe$/i.test(String(filename || "").replace(/[.\s]+$/g, ""));
}

const cancellations = new Map();
function cancelExe(id) {
  if (cancellations.has(id)) return cancellations.get(id);
  const work = new Promise((resolve) => {
    chrome.downloads.cancel(id, () => {
      const error = chrome.runtime.lastError;
      if (error) console.warn("EXE download could not be cancelled:", id, error.message);
      else console.info("EXE download cancelled:", id);
      resolve();
    });
  });
  // Bound memory use; browsers assign distinct download IDs.
  if (cancellations.size > 2048) cancellations.clear();
  cancellations.set(id, work);
  return work;
}

chrome.downloads.onDeterminingFilename.addListener((item, suggest) => {
  if (!isExe(item.filename)) { suggest(); return false; }
  // Keep filename determination pending until cancellation has completed.
  cancelExe(item.id).finally(() => suggest());
  return true;
});

chrome.downloads.onCreated.addListener((item) => {
  if (isExe(item.filename)) void cancelExe(item.id);
});

chrome.downloads.onChanged.addListener((delta) => {
  if (delta.filename && isExe(delta.filename.current)) void cancelExe(delta.id);
});
chrome.downloads.onErased.addListener((id) => cancellations.delete(id));
