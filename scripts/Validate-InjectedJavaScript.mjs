import fs from "node:fs";
import path from "node:path";

const projectRoot = process.argv[2];
if (!projectRoot) {
  throw new Error("Usage: node Validate-InjectedJavaScript.mjs <project-root>");
}

const sources = [
  ["MiniBrowser/Services/CompactPageModeService.swift", "scriptSource"],
  ["MiniBrowser/Services/CompactPageModeService.swift", "currentPostStateScript"],
  ["MiniBrowser/Services/CompactPageModeService.swift", "autoSubmitScript"],
  ["MiniBrowser/Services/CanvasImageSessionService.swift", "scriptSource"],
  ["MiniBrowser/Services/CanvasImageSessionService.swift", "openExistingCanvasScript"],
  ["MiniBrowser/Services/InputAutoZoomPreventionService.swift", "scriptSource"]
];

function rawSwiftScript(filePath, property) {
  const source = fs.readFileSync(filePath, "utf8");
  const marker = `static let ${property} = #\"\"\"`;
  const start = source.indexOf(marker);
  if (start < 0) {
    throw new Error(`Raw JavaScript property not found: ${filePath} (${property})`);
  }

  const scriptStart = start + marker.length;
  const scriptEnd = source.indexOf('\"\"\"#', scriptStart);
  if (scriptEnd < 0) {
    throw new Error(`Raw JavaScript terminator not found: ${filePath} (${property})`);
  }
  return source.slice(scriptStart, scriptEnd);
}

for (const [relativePath, property] of sources) {
  const filePath = path.join(projectRoot, relativePath);
  const script = rawSwiftScript(filePath, property);
  try {
    new Function(script);
  } catch (error) {
    throw new Error(`${relativePath} (${property}) has invalid JavaScript: ${error.message}`);
  }
}

console.log(`Injected JavaScript syntax checks passed (${sources.length} scripts).`);
