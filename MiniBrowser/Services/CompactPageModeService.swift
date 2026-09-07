import WebKit

enum CompactPageModeService {
    static let scriptSource = #"""
    (() => {
      "use strict";

      if (location.hostname !== "img.2chan.net" ||
          !/^\/[^/]+\/res\/\d+\.htm$/.test(location.pathname)) {
        return;
      }

      const doc = document;

      function initializeCompactPage() {
        const thread = doc.querySelector("div.thre");
        const form = Array.from(doc.forms).find(candidate =>
          candidate.querySelector('textarea[name="com"]')
        );
        if (!thread || !form) return false;
        if (form.dataset.minibrowserCompactInitialized === "true") return true;
        form.dataset.minibrowserCompactInitialized = "true";

      let viewport = doc.querySelector('meta[name="viewport"]');
      if (!viewport) {
        viewport = doc.createElement("meta");
        viewport.name = "viewport";
        doc.head.appendChild(viewport);
      }
      viewport.content = "width=device-width, initial-scale=1";

      if (!doc.getElementById("minibrowser-targetpage-style")) {
        const style = doc.createElement("style");
        style.id = "minibrowser-targetpage-style";
        style.textContent = `
          html, body {
            width: 100% !important;
            min-width: 0 !important;
            max-width: 100% !important;
            overflow-x: hidden !important;
            box-sizing: border-box !important;
          }
          body {
            margin: 0 !important;
            padding: 0 4px !important;
          }
          #minibrowser-targetpage-compose {
            display: grid !important;
            grid-template-columns: minmax(88px, 30vw) minmax(0, 1fr) !important;
            gap: 8px !important;
            align-items: start !important;
            width: 100% !important;
            box-sizing: border-box !important;
            margin: 4px 0 8px !important;
          }
          #minibrowser-targetpage-compose.minibrowser-no-context {
            grid-template-columns: minmax(0, 1fr) !important;
          }
          #minibrowser-targetpage-context {
            display: flex !important;
            flex-direction: column !important;
            gap: 6px !important;
            width: 100% !important;
            min-width: 0 !important;
            box-sizing: border-box !important;
          }
          #minibrowser-targetpage-starter {
            display: block !important;
            width: 100% !important;
            margin: 0 !important;
          }
          #minibrowser-targetpage-starter img {
            display: block !important;
            width: 100% !important;
            max-width: 100% !important;
            height: auto !important;
            max-height: 180px !important;
            margin: 0 !important;
            object-fit: contain !important;
          }
          #minibrowser-targetpage-opener {
            display: -webkit-box !important;
            width: 100% !important;
            max-width: 100% !important;
            margin: 0 !important;
            padding: 6px !important;
            border: 1px solid rgba(128, 64, 48, 0.35) !important;
            background: rgba(255, 255, 255, 0.45) !important;
            color: inherit !important;
            box-sizing: border-box !important;
            font-size: 14px !important;
            line-height: 1.35 !important;
            overflow: hidden !important;
            overflow-wrap: anywhere !important;
            -webkit-box-orient: vertical !important;
            -webkit-line-clamp: 4 !important;
          }
          .minibrowser-targetpage-form {
            position: static !important;
            display: block !important;
            visibility: visible !important;
            width: 100% !important;
            min-width: 0 !important;
            margin: 0 !important;
            box-sizing: border-box !important;
          }
          .minibrowser-targetpage-form .ftbl,
          .minibrowser-targetpage-form table.ftbl {
            position: static !important;
            width: 100% !important;
            min-width: 0 !important;
            margin: 0 !important;
            box-sizing: border-box !important;
          }
          .minibrowser-targetpage-form .ftdc {
            width: 4.5em !important;
            white-space: normal !important;
          }
          .minibrowser-targetpage-form textarea,
          .minibrowser-targetpage-form input[type="text"],
          .minibrowser-targetpage-form input[type="password"],
          .minibrowser-targetpage-form input[type="file"],
          .minibrowser-targetpage-form select {
            max-width: 100% !important;
            box-sizing: border-box !important;
            font-size: 16px !important;
          }
          .minibrowser-targetpage-form textarea,
          .minibrowser-targetpage-form input[type="text"] {
            width: 100% !important;
          }
          .minibrowser-targetpage-form textarea[name="com"] {
            height: 3.2em !important;
            min-height: 3.2em !important;
            max-height: 3.2em !important;
            overflow-y: auto !important;
            resize: none !important;
          }
          .minibrowser-targetpage-email-row,
          .minibrowser-targetpage-delete-help,
          #reszb {
            display: none !important;
          }
          #minibrowser-targetpage-comment-actions {
            display: flex !important;
            justify-content: flex-end !important;
            align-items: center !important;
            gap: 6px !important;
            width: 100% !important;
            margin: -3px 0 2px !important;
          }
          #minibrowser-targetpage-comment-actions > input[type="submit"],
          #minibrowser-targetpage-comment-actions > button {
            flex: 0 0 68px !important;
            width: 68px !important;
            min-width: 68px !important;
            min-height: 26px !important;
            box-sizing: border-box !important;
          }
          #minibrowser-targetpage-draft-toggle {
            padding: 2px 6px !important;
            border: 1px solid #888 !important;
            border-radius: 5px !important;
            background: #eee !important;
            color: #333 !important;
            font-size: 12px !important;
          }
          #retmestip {
            display: none !important;
          }
          #minibrowser-targetpage-draft-toggle[data-enabled="true"] {
            border-color: #087be6 !important;
            background: #087be6 !important;
            color: #fff !important;
          }
          .minibrowser-targetpage-form .ftb2 {
            display: none !important;
          }
          .minibrowser-targetpage-thread-extra {
            display: none !important;
          }
          .minibrowser-targetpage-page-extra,
          #hdp,
          #contres,
          #ufm {
            display: none !important;
          }
          div.thre {
            width: 100% !important;
            min-width: 0 !important;
            margin: 0 !important;
            font-size: 0 !important;
            line-height: 0 !important;
          }
          div.thre > table {
            display: none !important;
          }
          div.thre > table.minibrowser-own-response {
            display: table !important;
            width: 100% !important;
            max-width: 100% !important;
            margin: 4px 0 !important;
            font-size: 14px !important;
            line-height: normal !important;
            table-layout: fixed !important;
          }
          div.thre > table.minibrowser-own-response .rtd,
          div.thre > table.minibrowser-own-response blockquote {
            max-width: 100% !important;
            overflow-wrap: anywhere !important;
            box-sizing: border-box !important;
          }
          div.thre > table.minibrowser-own-response img {
            max-width: 100% !important;
            height: auto !important;
          }
        `;
        doc.head.appendChild(style);
      }

      form.classList.add("minibrowser-targetpage-form");
      const infoTable = form.querySelector(".ftb2");
      if (infoTable) infoTable.setAttribute("aria-hidden", "true");

      const emailInput = form.querySelector('input[name="email"]');
      const textarea = form.querySelector('textarea[name="com"]');
      const submitButton = Array.from(form.querySelectorAll(
        'input[type="submit"], button[type="submit"]'
      )).find(button => /返信|送信/.test(button.value || button.textContent || ""));

      function clearEmail() {
        if (!emailInput) return;
        if (emailInput.value !== "") emailInput.value = "";
        if (emailInput.defaultValue !== "") emailInput.defaultValue = "";
        if (emailInput.getAttribute("value")) emailInput.setAttribute("value", "");
        if (emailInput.getAttribute("autocomplete") !== "off") {
          emailInput.setAttribute("autocomplete", "off");
        }
      }

      clearEmail();
      if (emailInput && !emailInput.dataset.minibrowserEmptyGuard) {
        emailInput.dataset.minibrowserEmptyGuard = "true";
        emailInput.addEventListener("input", clearEmail, true);
        emailInput.addEventListener("change", clearEmail, true);
        const emailRow = emailInput.closest("tr");
        if (emailRow) {
          emailRow.classList.add("minibrowser-targetpage-email-row");
          emailRow.setAttribute("aria-hidden", "true");
        }
      }
      form.addEventListener("submit", clearEmail, true);

      const deleteInput = form.querySelector('input[name="pwd"]');
      // This value belongs to the page and its user. Do not overwrite it on
      // load, edit, or submit; the browser only hides the surrounding help.
      function preserveDeleteKey() {
        if (!deleteInput) return;
        if (deleteInput.getAttribute("autocomplete") !== "off") {
          deleteInput.setAttribute("autocomplete", "off");
        }
      }
      preserveDeleteKey();

      const deleteHelp = deleteInput && deleteInput.parentElement &&
        deleteInput.parentElement.querySelector("small");
      if (deleteHelp) {
        deleteHelp.classList.add("minibrowser-targetpage-delete-help");
        deleteHelp.setAttribute("aria-hidden", "true");
      }

      function disableFormPositionToggle() {
        const toggle = doc.getElementById("reszb");
        if (!toggle) return;
        if (toggle.hasAttribute("onclick")) toggle.removeAttribute("onclick");
        if (toggle.getAttribute("aria-hidden") !== "true") {
          toggle.setAttribute("aria-hidden", "true");
        }
        if (!toggle.hasAttribute("inert")) toggle.setAttribute("inert", "");
        if (!toggle.dataset.minibrowserDisabled) {
          toggle.dataset.minibrowserDisabled = "true";
          toggle.addEventListener("click", event => {
            event.preventDefault();
            event.stopImmediatePropagation();
          }, true);
        }
      }
      disableFormPositionToggle();

      if (textarea) textarea.rows = 2;

      const draftEnabledKey = "MiniBrowser.TargetPageDraftEnabled";
      const draftTextKey = "MiniBrowser.TargetPageDraftText";
      let draftEnabled = false;
      try {
        draftEnabled = localStorage.getItem(draftEnabledKey) === "true";
      } catch (_) {}

      let actions = doc.getElementById("minibrowser-targetpage-comment-actions");
      if (!actions && textarea) {
        actions = doc.createElement("div");
        actions.id = "minibrowser-targetpage-comment-actions";
      }
      const formTable = form.querySelector(".ftbl");
      if (actions && actions.parentElement !== form) {
        form.insertBefore(actions, formTable || form.firstChild);
      } else if (actions && formTable && actions.nextElementSibling !== formTable) {
        form.insertBefore(actions, formTable);
      }
      if (actions && submitButton) actions.appendChild(submitButton);

      let draftToggle = doc.getElementById("minibrowser-targetpage-draft-toggle");
      if (!draftToggle && actions) {
        draftToggle = doc.createElement("button");
        draftToggle.type = "button";
        draftToggle.id = "minibrowser-targetpage-draft-toggle";
        actions.appendChild(draftToggle);
      }

      try { localStorage.removeItem("MiniBrowser.TargetPageFormPlacement"); } catch (_) {}

      function updateDraftToggle() {
        if (!draftToggle) return;
        draftToggle.textContent = draftEnabled ? "保持 ON" : "保持 OFF";
        draftToggle.dataset.enabled = draftEnabled ? "true" : "false";
        draftToggle.setAttribute("aria-pressed", draftEnabled ? "true" : "false");
      }

      function saveDraft() {
        if (!draftEnabled || !textarea) return;
        try { localStorage.setItem(draftTextKey, textarea.value); } catch (_) {}
      }

      if (textarea && draftEnabled) {
        try {
          const savedDraft = localStorage.getItem(draftTextKey);
          if (savedDraft !== null) {
            textarea.value = savedDraft;
          } else {
            saveDraft();
          }
        } catch (_) {}
      }

      let submittedDraft = null;
      let submittedDraftRestoreTimers = [];
      let userEditedAfterSubmission = false;
      let canvasWasOpenAtSubmission = false;
      let postCompletionReported = false;

      function restoreSubmittedDraft() {
        if (!draftEnabled || !textarea || submittedDraft === null ||
            userEditedAfterSubmission || textarea.value !== "") return;
        textarea.value = submittedDraft;
      }

      function scheduleSubmittedDraftRestore() {
        while (submittedDraftRestoreTimers.length) {
          clearTimeout(submittedDraftRestoreTimers.pop());
        }
        [0, 250, 1000].forEach(delay => {
          submittedDraftRestoreTimers.push(setTimeout(restoreSubmittedDraft, delay));
        });
      }

      function notifyPostCompletion() {
        if (postCompletionReported) return;
        const status = doc.getElementById("retmestip");
        if (!status || String(status.textContent || "").trim() !== "完了") return;
        postCompletionReported = true;
        const handler = window.webkit && window.webkit.messageHandlers &&
          window.webkit.messageHandlers.miniBrowserHandwriting;
        if (handler) {
          handler.postMessage({
            type: "postCompleted",
            canvasWasOpen: canvasWasOpenAtSubmission
          });
        }
      }

      function capturePostState() {
        if (!textarea) return;
        submittedDraft = draftEnabled ? textarea.value : null;
        userEditedAfterSubmission = false;
        canvasWasOpenAtSubmission = Boolean(doc.querySelector("canvas#oejs"));
        postCompletionReported = false;
        if (draftEnabled) {
          saveDraft();
          scheduleSubmittedDraftRestore();
        }
      }

      if (textarea && !textarea.dataset.minibrowserDraftTracking) {
        textarea.dataset.minibrowserDraftTracking = "true";
        textarea.addEventListener("input", event => {
          if (!draftEnabled) return;
          if (event.isTrusted) {
            userEditedAfterSubmission = true;
            submittedDraft = null;
          }
          saveDraft();
        }, true);
      }

      if (draftToggle && !draftToggle.dataset.minibrowserBound) {
        draftToggle.dataset.minibrowserBound = "true";
        draftToggle.addEventListener("click", () => {
          draftEnabled = !draftEnabled;
          try { localStorage.setItem(draftEnabledKey, draftEnabled ? "true" : "false"); } catch (_) {}
          if (draftEnabled) {
            saveDraft();
          } else {
            submittedDraft = null;
            try { localStorage.removeItem(draftTextKey); } catch (_) {}
            if (textarea) {
              textarea.value = "";
              textarea.dispatchEvent(new Event("input", { bubbles: true }));
              textarea.dispatchEvent(new Event("change", { bubbles: true }));
            }
          }
          updateDraftToggle();
        }, true);
      }
      updateDraftToggle();

      form.addEventListener("submit", capturePostState, true);

      if (submitButton && !submitButton.dataset.minibrowserPostCapture) {
        submitButton.dataset.minibrowserPostCapture = "true";
        submitButton.addEventListener("click", capturePostState, true);
      }

      const formObserver = new MutationObserver(() => {
        clearEmail();
        disableFormPositionToggle();
        restoreSubmittedDraft();
        notifyPostCompletion();
      });
      formObserver.observe(form, { childList: true, subtree: true, attributes: true });

      function previousModeHeader(element) {
        let candidate = element.previousElementSibling;
        while (candidate) {
          if (candidate.tagName === "TABLE" &&
              /レス送信モード/.test(candidate.textContent || "")) {
            return candidate;
          }
          candidate = candidate.previousElementSibling;
        }
        return null;
      }

      function hideRange(first, stopExclusive = null) {
        let element = first;
        while (element && element !== stopExclusive) {
          const next = element.nextElementSibling;
          element.classList.add("minibrowser-targetpage-page-extra");
          element = next;
        }
      }

      const modeHeader = previousModeHeader(form);
      if (modeHeader) {
        modeHeader.classList.add("minibrowser-targetpage-page-extra");
        modeHeader.setAttribute("aria-hidden", "true");
      }

      let compose = doc.getElementById("minibrowser-targetpage-compose");
      if (!compose) {
        compose = doc.createElement("div");
        compose.id = "minibrowser-targetpage-compose";
        form.parentNode.insertBefore(compose, form);

        const starterLink = Array.from(thread.children).find(element =>
          element.tagName === "A" && element.querySelector("img")
        );
        const opener = Array.from(thread.children).find(element =>
          element.tagName === "BLOCKQUOTE"
        );

        if (starterLink || opener) {
          const context = doc.createElement("div");
          context.id = "minibrowser-targetpage-context";
          compose.appendChild(context);

          if (starterLink) {
            starterLink.id = "minibrowser-targetpage-starter";
            context.appendChild(starterLink);
          }

          if (opener) {
            opener.id = "minibrowser-targetpage-opener";
            context.appendChild(opener);
          } else {
            const placeholder = doc.createElement("div");
            placeholder.id = "minibrowser-targetpage-opener";
            placeholder.textContent = "本文なし";
            context.appendChild(placeholder);
          }
        } else {
          compose.classList.add("minibrowser-no-context");
        }

        compose.appendChild(form);
      }

      if (modeHeader && modeHeader.parentElement === doc.body) {
        hideRange(doc.body.firstElementChild, modeHeader);
      }
      if (compose.parentElement === doc.body && thread.parentElement === doc.body) {
        hideRange(compose.nextElementSibling, thread);
        hideRange(thread.nextElementSibling);
      }

      Array.from(thread.children).forEach(element => {
        if (element.tagName !== "TABLE") {
          element.classList.add("minibrowser-targetpage-thread-extra");
        }
      });

      const storageKey = "MiniBrowser.TargetPageOwnPosts:" + location.pathname;
      const pendingStorageKey = "MiniBrowser.TargetPagePendingPost:" + location.pathname;
      const defaultImageComments = new Set([
        "ｷﾀ━━━(ﾟ∀ﾟ)━━━!!",
        "ｷﾀ━━━━━━(ﾟ∀ﾟ)━━━━━━ !!!!!",
        "本文無し"
      ]);

      function normalizedText(value) {
        return String(value || "")
          .replace(/\r\n?/g, "\n")
          .replace(/[ \t]+$/gm, "")
          .trim();
      }

      function loadState() {
        try {
          const parsed = JSON.parse(localStorage.getItem(storageKey) || "{}");
          const pending = JSON.parse(sessionStorage.getItem(pendingStorageKey) || "[]");
          return {
            ownNumbers: Array.isArray(parsed.ownNumbers) ? parsed.ownNumbers.map(String) : [],
            pending: Array.isArray(pending) ? pending : []
          };
        } catch (_) {
          return { ownNumbers: [], pending: [] };
        }
      }

      function saveState(state) {
        try {
          localStorage.setItem(storageKey, JSON.stringify({ ownNumbers: state.ownNumbers }));
          if (state.pending.length) {
            sessionStorage.setItem(pendingStorageKey, JSON.stringify(state.pending));
          } else {
            sessionStorage.removeItem(pendingStorageKey);
          }
        } catch (_) {}
      }

      function responseInfo(table) {
        const deletionMarker = table.querySelector('[id^="delcheck"]');
        const numberFromID = deletionMarker && deletionMarker.id.match(/^delcheck(\d+)$/);
        const textMarker = table.querySelector(".cno, .no_quote");
        const numberFromText = textMarker && textMarker.textContent.match(/(\d+)$/);
        const match = numberFromID || numberFromText;
        const blockquote = table.querySelector(".rtd blockquote, blockquote");
        if (!match || !blockquote) return null;
        return {
          table,
          number: match[1],
          numericNumber: Number(match[1]),
          body: normalizedText(blockquote.innerText || blockquote.textContent)
        };
      }

      function responseInfos() {
        return Array.from(thread.children)
          .filter(element => element.tagName === "TABLE")
          .map(responseInfo)
          .filter(Boolean);
      }

      let state = loadState();

      function reconcileAndRender() {
        const infos = responseInfos();
        const own = new Set(state.ownNumbers.map(String));
        const now = Date.now();
        const remaining = [];

        state.pending.forEach(pending => {
          if (!pending || now - Number(pending.createdAt || 0) > 10 * 60 * 1000) return;
          const body = normalizedText(pending.body);
          const candidates = infos.filter(info => {
            if (own.has(info.number) || info.numericNumber <= Number(pending.afterNumber || 0)) {
              return false;
            }
            return body ? info.body === body : defaultImageComments.has(info.body);
          });
          const match = candidates.sort((a, b) => a.numericNumber - b.numericNumber).pop();
          if (match) {
            own.add(match.number);
          } else {
            remaining.push(pending);
          }
        });

        state.ownNumbers = Array.from(own);
        state.pending = remaining;
        saveState(state);

        infos.forEach(info => {
          info.table.classList.toggle("minibrowser-own-response", own.has(info.number));
        });
      }

      if (!form.dataset.minibrowserOwnPostTracking) {
        form.dataset.minibrowserOwnPostTracking = "true";
        let lastRecordedAt = 0;
        const recordPendingPost = () => {
          const now = Date.now();
          if (now - lastRecordedAt < 1000) return;
          lastRecordedAt = now;
          const infos = responseInfos();
          const afterNumber = infos.reduce((maximum, info) =>
            Math.max(maximum, info.numericNumber), 0
          );
          state.pending.push({
            body: normalizedText(textarea && textarea.value),
            afterNumber,
            createdAt: now
          });
          state.pending = state.pending.slice(-10);
          saveState(state);
        };
        form.addEventListener("submit", recordPendingPost, true);
        if (submitButton) {
          submitButton.addEventListener("click", recordPendingPost, true);
        }
      }

      reconcileAndRender();
        const responseObserver = new MutationObserver(() => reconcileAndRender());
        responseObserver.observe(thread, { childList: true, subtree: true });
        return true;
      }

      if (initializeCompactPage()) return;

      let retryCount = 0;
      const retryInitialization = () => {
        retryCount += 1;
        if (initializeCompactPage() || retryCount >= 20) {
          retryObserver.disconnect();
          clearInterval(retryTimer);
        }
      };
      const retryObserver = new MutationObserver(retryInitialization);
      retryObserver.observe(doc.documentElement, { childList: true, subtree: true });
      const retryTimer = setInterval(retryInitialization, 100);
    })();
    """#

    static func install(on controller: WKUserContentController) {
        controller.addUserScript(WKUserScript(source: scriptSource,
                                              injectionTime: .atDocumentEnd,
                                              forMainFrameOnly: true))
    }
}
