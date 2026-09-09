import fs from "node:fs";
import path from "node:path";

const projectRoot = process.argv[2];
if (!projectRoot) {
  throw new Error("Usage: node Validate-InjectedJavaScript.mjs <project-root>");
}

const sources = [
  ["MiniBrowser/Services/CompactPageModeService.swift", "scriptSource"],
  ["MiniBrowser/Services/CompactPageModeService.swift", "currentPostStateScript"],
  ["MiniBrowser/Services/CompactPageModeService.swift", "submitReadinessScript"],
  ["MiniBrowser/Services/CompactPageModeService.swift", "autoSubmitScript"],
  ["MiniBrowser/Services/CanvasImageSessionService.swift", "scriptSource"],
  ["MiniBrowser/Services/CanvasImageSessionService.swift", "openExistingCanvasScript"],
  ["MiniBrowser/Services/InputAutoZoomPreventionService.swift", "scriptSource"]
];

function rawSwiftScript(filePath, property) {
  const source = fs.readFileSync(filePath, "utf8");
  const declaration = source.indexOf(`static let ${property}`);
  if (declaration < 0) {
    throw new Error(`Raw JavaScript property not found: ${filePath} (${property})`);
  }

  const scriptStartMarker = '#"""';
  const scriptStart = source.indexOf(scriptStartMarker, declaration);
  if (scriptStart < 0) {
    throw new Error(`Raw JavaScript literal not found: ${filePath} (${property})`);
  }
  const scriptContentStart = scriptStart + scriptStartMarker.length;
  const scriptEnd = source.indexOf('\"\"\"#', scriptContentStart);
  if (scriptEnd < 0) {
    throw new Error(`Raw JavaScript terminator not found: ${filePath} (${property})`);
  }
  return source.slice(scriptContentStart, scriptEnd);
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
