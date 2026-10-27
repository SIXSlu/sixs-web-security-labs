"use strict";

/**
 * Deep-merges a source object into a target object. Used to apply user
 * theme presets on top of the defaults without mutating the defaults.
 */
function isMergeable(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function deepMerge(target, ...sources) {
  if (!isMergeable(target)) {
    target = {};
  }
  for (const source of sources) {
    for (const key in source) {
      if (isMergeable(source[key]) && isMergeable(target[key])) {
        // both sides are objects: recurse so nested presets merge cleanly
        deepMerge(target[key], source[key]);
      } else {
        target[key] = source[key];
      }
    }
  }
  return target;
}

module.exports = { deepMerge };