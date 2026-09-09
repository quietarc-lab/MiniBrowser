import WebKit

enum InputAutoZoomPreventionService {
    static let scriptSource = PageMarkerNamespace.neutralize(#"""
    (() => {
      "use strict";

      if (window.__miniBrowserInputAutoZoomPreventionInstalled) return;
      window.__miniBrowserInputAutoZoomPreventionInstalled = true;

      const className = "minibrowser-input-no-auto-zoom";
      const selector = [
        "input:not([type])",
        'input[type="text"]',
        'input[type="search"]',
        'input[type="email"]',
        'input[type="url"]',
        'input[type="tel"]',
        'input[type="password"]',
        'input[type="number"]',
        'input[type="date"]',
        'input[type="datetime-local"]',
        'input[type="month"]',
        'input[type="week"]',
        'input[type="time"]',
        'input[type="file"]',
        "textarea",
        "select",
        '[contenteditable]:not([contenteditable="false"])'
      ].join(",");

      const style = document.createElement("style");
      style.id = "minibrowser-input-auto-zoom-style";
      style.textContent = `.${className} { font-size: 16px !important; }`;
      (document.head || document.documentElement).appendChild(style);

      function update(control) {
        if (!(control instanceof Element) || !control.matches(selector)) return;

        // Measure without our override so controls already at 16 px or larger
        // retain the website's intended size.
        control.classList.remove(className);
        const fontSize = Number.parseFloat(getComputedStyle(control).fontSize);
        if (Number.isFinite(fontSize) && fontSize < 16) {
          control.classList.add(className);
        }
      }

      function updateTree(root) {
        if (!(root instanceof Element) && root !== document) return;
        if (root instanceof Element) update(root);
        root.querySelectorAll(selector).forEach(update);
      }

      updateTree(document);

      // Pages often add forms after load. Apply the same minimum only to new
      // controls, and re-check a control immediately before it receives focus.
      const observer = new MutationObserver(records => {
        records.forEach(record => {
          record.addedNodes.forEach(node => updateTree(node));
        });
      });
      observer.observe(document.documentElement, { childList: true, subtree: true });
      document.addEventListener("focusin", event => update(event.target), true);
    })();
    """#)

    static func install(on controller: WKUserContentController) {
        controller.addUserScript(WKUserScript(source: scriptSource,
                                              injectionTime: .atDocumentEnd,
                                              forMainFrameOnly: false))
    }
}
