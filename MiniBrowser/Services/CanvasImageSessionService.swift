import Foundation
import WebKit

/// Bridges the existing TargetPage handwriting bookmarklet to an in-memory native store.
/// The selected source image is deliberately never persisted, logged, or shared.
enum CanvasImageSessionService {
    static let messageHandlerName = "miniBrowserHandwriting"
    static let maximumImageDataByteCount = 3_000_000

    static let scriptSource = #"""
    (() => {
      "use strict";

      if (location.hostname !== "img.2chan.net" ||
          !/^\/[^/]+\/res\/\d+\.htm$/.test(location.pathname)) {
        return;
      }

      const handler = window.webkit && window.webkit.messageHandlers &&
        window.webkit.messageHandlers.miniBrowserHandwriting;
      if (!handler) return;

      const maximumBytes = 3000000;

      function captureSelectedImage(input) {
        if (!(input instanceof HTMLInputElement) || input.id !== "itgkfile") return;
        const file = input.files && input.files[0];
        if (!file || file.size > maximumBytes || !/^image\/(gif|jpe?g|png|webp)$/i.test(file.type)) {
          return;
        }
        const reader = new FileReader();
        reader.addEventListener("load", () => {
          if (typeof reader.result !== "string") return;
          handler.postMessage({ type: "selectedImage", dataURL: reader.result });
        }, { once: true });
        reader.readAsDataURL(file);
      }

      document.addEventListener("change", event => {
        captureSelectedImage(event.target);
      }, true);

      function notifyCanvasReady() {
        const canvas = document.querySelector("canvas#oejs");
        if (!canvas || canvas.dataset.minibrowserHandwritingRestoreRequested === "true") return;
        canvas.dataset.minibrowserHandwritingRestoreRequested = "true";
        handler.postMessage({ type: "canvasReady" });
      }

      const observer = new MutationObserver(notifyCanvasReady);
      observer.observe(document.documentElement, { childList: true, subtree: true });
      notifyCanvasReady();

      function notifyPageReady() {
        handler.postMessage({ type: "pageReady" });
      }
      if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", notifyPageReady, { once: true });
      } else {
        notifyPageReady();
      }
    })();
    """#

    static func install(on controller: WKUserContentController) {
        controller.addUserScript(WKUserScript(source: scriptSource,
                                              injectionTime: .atDocumentStart,
                                              forMainFrameOnly: true))
    }

    static func isTargetPageThreadURL(_ url: URL?) -> Bool {
        guard let url,
              url.host?.lowercased() == "img.2chan.net" else {
            return false
        }
        return url.path.range(of: #"^/[^/]+/res/\d+\.htm$"#,
                              options: .regularExpression) != nil
    }

    static let openExistingCanvasScript = #"""
    (() => {
      "use strict";

      const isVisible = element => {
        if (!(element instanceof Element)) return false;
        const style = window.getComputedStyle(element);
        return style.display !== "none" &&
          style.visibility !== "hidden" &&
          element.getClientRects().length > 0;
      };

      const canvasHost = document.getElementById("oe3");
      const canvas = document.querySelector("canvas#oejs");
      if (canvas && isVisible(canvasHost || canvas)) return;

      let clicked = false;
      let attempts = 0;
      const openExistingField = () => {
        const currentCanvas = document.querySelector("canvas#oejs");
        const currentHost = document.getElementById("oe3");
        if (currentCanvas && isVisible(currentHost || currentCanvas)) return;
        attempts += 1;
        if (!clicked) {
          const trigger = Array.from(document.querySelectorAll(
            "#oebtnj, [onclick*='ChangeDraw'], a, button, input[type='button'], input[type='submit']"
          )).find(element => {
            if (!isVisible(element)) return false;
            const text = String(element.value || element.textContent || "").replace(/\s+/g, "");
            const onclick = String(element.getAttribute("onclick") || "");
            return element.id === "oebtnj" ||
              /ChangeDraw\s*\(\s*['\"]j['\"]\s*\)/i.test(onclick) ||
              /手書きjs/.test(text);
          });
          if (trigger instanceof HTMLElement) {
            clicked = true;
            trigger.click();
          }
        }
        if (attempts < 50) {
          setTimeout(openExistingField, 120);
        }
      };
      openExistingField();
    })();
    """#
}

final class TargetPageHandwritingImageStore {
    private struct SessionImage {
        let mimeType: String
        let data: Data

        var dataURL: String {
            "data:\(mimeType);base64,\(data.base64EncodedString())"
        }
    }

    private static let supportedMimeTypes: Set<String> = [
        "image/gif", "image/jpeg", "image/png", "image/webp"
    ]

    private var image: SessionImage?

    var hasImage: Bool {
        image != nil
    }

    @discardableResult
    func replace(withDataURL dataURL: String) -> Bool {
        guard let parsed = Self.parseDataURL(dataURL),
              parsed.data.count <= CanvasImageSessionService.maximumImageDataByteCount else {
            return false
        }
        image = SessionImage(mimeType: parsed.mimeType, data: parsed.data)
        return true
    }

    func restorationScript() -> String? {
        guard let image,
              let dataURLLiteral = javaScriptStringLiteral(image.dataURL) else {
            return nil
        }

        return #"""
        (() => {
          const canvas = document.querySelector("canvas#oejs");
          if (!canvas) return;
          const source = new Image();
          source.onload = () => {
            let scale = 1;
            if (source.width > 400 || source.height > 400) {
              scale = source.width > source.height ? 400 / source.width : 400 / source.height;
            }
            canvas.width = Math.max(1, Math.round(source.width * scale));
            canvas.height = Math.max(1, Math.round(source.height * scale));
            const context = canvas.getContext("2d");
            if (!context) return;
            context.drawImage(source, 0, 0, source.width, source.height,
                              0, 0, canvas.width, canvas.height);
            const x = Math.floor(Math.random() * canvas.width);
            const y = Math.floor(Math.random() * canvas.height);
            context.fillStyle = "rgba(" + Math.floor(Math.random() * 256) + "," +
              Math.floor(Math.random() * 256) + "," + Math.floor(Math.random() * 256) + ",1)";
            context.fillRect(x, y, 1, 1);
          };
          source.src = \#(dataURLLiteral);
        })();
        """#
    }

    private static func parseDataURL(_ value: String) -> (mimeType: String, data: Data)? {
        guard let separator = value.firstIndex(of: ",") else { return nil }
        let header = String(value[..<separator]).lowercased()
        guard header.hasPrefix("data:"), header.hasSuffix(";base64") else { return nil }

        let mimeType = String(header.dropFirst("data:".count).dropLast(";base64".count))
        guard supportedMimeTypes.contains(mimeType),
              let data = Data(base64Encoded: String(value[value.index(after: separator)...]),
                              options: .ignoreUnknownCharacters),
              !data.isEmpty else {
            return nil
        }
        return (mimeType, data)
    }

    private func javaScriptStringLiteral(_ value: String) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
