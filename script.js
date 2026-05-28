const transcriptOutput = document.querySelector("#transcript-output");
const interimOutput = document.querySelector("#interim-output");
const statusText = document.querySelector("#status-text");
const supportPill = document.querySelector("#support-pill");
const pulseDot = document.querySelector("#pulse-dot");
const recordButton = document.querySelector("#record-button");
const stopButton = document.querySelector("#stop-button");
const languageSelect = document.querySelector("#language-select");
const modeSelect = document.querySelector("#mode-select");
const wordCount = document.querySelector("#word-count");
const tidyButton = document.querySelector("#tidy-button");
const notesButton = document.querySelector("#notes-button");
const emailButton = document.querySelector("#email-button");
const meetingButton = document.querySelector("#meeting-button");
const todoButton = document.querySelector("#todo-button");
const socialButton = document.querySelector("#social-button");
const rewriteButton = document.querySelector("#rewrite-button");
const copyButton = document.querySelector("#copy-button");
const saveButton = document.querySelector("#save-button");
const clearButton = document.querySelector("#clear-button");
const historyList = document.querySelector("#history-list");
const refreshHistoryButton = document.querySelector("#refresh-history");
const clearHistoryButton = document.querySelector("#clear-history");
const autoCopyToggle = document.querySelector("#auto-copy-toggle");
const autoInsertToggle = document.querySelector("#auto-insert-toggle");
const targetOutput = document.querySelector("#target-output");
const targetStatus = document.querySelector("#target-status");

const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
const HISTORY_KEY = "echotype-history";

let recognition = null;
let isRecording = false;

function updateSupportState() {
  if (SpeechRecognition) {
    supportPill.textContent = "Speech ready";
    supportPill.classList.remove("unsupported");
    statusText.textContent = "Ready. Click start and allow microphone access.";
    recordButton.disabled = false;
    return;
  }

  supportPill.textContent = "Browser unsupported";
  supportPill.classList.add("unsupported");
  statusText.textContent = "This browser does not expose the Web Speech API. You can still type into the editor and test the product shell.";
  recordButton.disabled = true;
  stopButton.disabled = true;
}

function createRecognition() {
  if (!SpeechRecognition) {
    return null;
  }

  const instance = new SpeechRecognition();
  instance.continuous = true;
  instance.interimResults = true;
  instance.lang = languageSelect.value;

  instance.onstart = () => {
    isRecording = true;
    pulseDot.classList.add("active");
    statusText.textContent = "Listening now. Speak naturally.";
    recordButton.disabled = true;
    stopButton.disabled = false;
  };

  instance.onend = () => {
    isRecording = false;
    pulseDot.classList.remove("active");
    statusText.textContent = "Stopped. You can review, edit, or start again.";
    recordButton.disabled = false;
    stopButton.disabled = true;
  };

  instance.onerror = (event) => {
    isRecording = false;
    pulseDot.classList.remove("active");
    recordButton.disabled = false;
    stopButton.disabled = true;

    const messageMap = {
      "not-allowed": "Microphone access was blocked. Allow microphone permission and try again.",
      "audio-capture": "No microphone was detected. Check your input device and try again.",
      "no-speech": "No speech was heard. Try again and speak a little closer to the microphone.",
      "network": "Speech recognition had a network problem. Try again in a moment.",
    };

    statusText.textContent = messageMap[event.error] || "Speech recognition stopped unexpectedly. Try again.";
  };

  instance.onresult = (event) => {
    let finalText = "";
    let interimText = "";

    for (let i = event.resultIndex; i < event.results.length; i += 1) {
      const snippet = event.results[i][0].transcript;
      if (event.results[i].isFinal) {
        finalText += snippet;
      } else {
        interimText += snippet;
      }
    }

    if (finalText) {
      const current = transcriptOutput.value.trim();
      const appended = normalizeDictation(finalText, languageSelect.value);
      transcriptOutput.value = current ? `${current}\n${appended}` : appended;
      updateWordCount();
    }

    interimOutput.textContent = interimText || "Waiting for more speech...";
  };

  return instance;
}

function normalizeDictation(text, language) {
  let next = text.trim();

  if (language.startsWith("en")) {
    next = next
      .replace(/\bnew line\b/gi, "\n")
      .replace(/\bcomma\b/gi, ",")
      .replace(/\bperiod\b/gi, ".")
      .replace(/\bquestion mark\b/gi, "?");
    next = tidyText(next);
  }

  return next;
}

function tidyText(text) {
  return text
    .replace(/\s+/g, " ")
    .replace(/\s+([,.!?;:])/g, "$1")
    .replace(/([,.!?])([A-Za-z])/g, "$1 $2")
    .replace(/^\s*[a-z]/, (match) => match.toUpperCase())
    .replace(/(^|[.!?]\s+)([a-z])/g, (_, prefix, letter) => `${prefix}${letter.toUpperCase()}`)
    .trim();
}

function formatAsNotes(text) {
  const cleaned = tidyText(text);
  if (!cleaned) {
    return "";
  }

  return cleaned
    .split(/[.!?]\s+/)
    .map((part) => part.trim())
    .filter(Boolean)
    .map((part) => `- ${part.replace(/[.!?]$/, "")}`)
    .join("\n");
}

function formatAsEmail(text) {
  const cleaned = tidyText(text);
  if (!cleaned) {
    return "";
  }

  const mode = modeSelect.value;
  const openers = {
    email: "Hi,",
    chat: "Hi,",
    notes: "Summary:",
    ideas: "Idea draft:",
  };

  return `${openers[mode] || "Hi,"}\n\n${cleaned}\n\nBest,`;
}

function formatAsMeetingNotes(text) {
  const cleaned = tidyText(text);
  if (!cleaned) {
    return "";
  }

  const sections = cleaned
    .split(/[.!?]\s+/)
    .map((part) => part.trim())
    .filter(Boolean);

  const bullets = sections.map((section) => `- ${section.replace(/[.!?]$/, "")}`).join("\n");
  return `Meeting notes\n\nKey points\n${bullets}`;
}

function formatAsTodo(text) {
  const cleaned = tidyText(text);
  if (!cleaned) {
    return "";
  }

  return cleaned
    .split(/[.!?]\s+/)
    .map((part) => part.trim())
    .filter(Boolean)
    .map((part) => `[] ${part.replace(/[.!?]$/, "")}`)
    .join("\n");
}

function formatAsSocial(text) {
  const cleaned = tidyText(text);
  if (!cleaned) {
    return "";
  }

  return `${cleaned}\n\n#idea #draft`;
}

function rewriteCleanly(text) {
  const cleaned = tidyText(text);
  if (!cleaned) {
    return "";
  }

  return cleaned
    .replace(/\bi need to\b/gi, "I need to")
    .replace(/\bjust wanted to\b/gi, "I wanted to");
}

function copyText() {
  navigator.clipboard.writeText(transcriptOutput.value).then(() => {
    statusText.textContent = "Copied to clipboard.";
  }).catch(() => {
    statusText.textContent = "Copy failed in this browser. You can still select and copy manually.";
  });
}

function updateWordCount() {
  const words = transcriptOutput.value.trim().split(/\s+/).filter(Boolean);
  wordCount.textContent = `${words.length} words`;
}

function applyAutoActions() {
  if (autoInsertToggle.checked) {
    targetOutput.value = transcriptOutput.value;
    targetStatus.textContent = "Auto-insert active";
  } else {
    targetStatus.textContent = "Manual mode";
  }

  if (autoCopyToggle.checked) {
    copyText();
  }
}

function readHistory() {
  try {
    return JSON.parse(localStorage.getItem(HISTORY_KEY) || "[]");
  } catch {
    return [];
  }
}

function writeHistory(items) {
  localStorage.setItem(HISTORY_KEY, JSON.stringify(items));
}

function renderHistory() {
  const items = readHistory();

  if (!items.length) {
    historyList.innerHTML = '<p class="empty-history">No saved snippets yet. Dictate or type something, then save a snapshot.</p>';
    return;
  }

  historyList.innerHTML = items
    .map((item) => `
      <article class="history-item">
        <header>
          <h4>${escapeHtml(item.title)}</h4>
          <span class="history-meta">${escapeHtml(item.savedAt)}</span>
        </header>
        <p>${escapeHtml(item.preview)}</p>
      </article>
    `)
    .join("");
}

function saveSnapshot() {
  const value = transcriptOutput.value.trim();
  if (!value) {
    statusText.textContent = "There is nothing to save yet.";
    return;
  }

  const items = readHistory();
  const preview = value.replace(/\n+/g, " ").slice(0, 160);
  const title = `${labelForMode(modeSelect.value)} snapshot`;
  items.unshift({
    title,
    preview,
    savedAt: new Date().toLocaleString(),
  });

  writeHistory(items.slice(0, 10));
  renderHistory();
  statusText.textContent = "Saved to local history on this device.";
}

function labelForMode(mode) {
  const labels = {
    notes: "Notes",
    chat: "Chat",
    email: "Email",
    ideas: "Ideas",
  };

  return labels[mode] || "Transcript";
}

function escapeHtml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function startDictation() {
  if (!SpeechRecognition) {
    return;
  }

  if (!recognition) {
    recognition = createRecognition();
  }

  recognition.lang = languageSelect.value;
  interimOutput.textContent = "Listening...";
  recognition.start();
}

function stopDictation() {
  if (recognition && isRecording) {
    recognition.stop();
  }
}

function transformText(transformer, successMessage) {
  transcriptOutput.value = transformer(transcriptOutput.value);
  updateWordCount();
  applyAutoActions();
  statusText.textContent = successMessage;
}

recordButton.addEventListener("click", startDictation);
stopButton.addEventListener("click", stopDictation);

tidyButton.addEventListener("click", () => transformText(tidyText, "Text cleaned up."));
notesButton.addEventListener("click", () => transformText(formatAsNotes, "Formatted as notes."));
emailButton.addEventListener("click", () => transformText(formatAsEmail, "Formatted as a lightweight email draft."));
meetingButton.addEventListener("click", () => transformText(formatAsMeetingNotes, "Formatted as meeting notes."));
todoButton.addEventListener("click", () => transformText(formatAsTodo, "Formatted as a to-do list."));
socialButton.addEventListener("click", () => transformText(formatAsSocial, "Formatted as a social post draft."));
rewriteButton.addEventListener("click", () => transformText(rewriteCleanly, "Rewritten more cleanly."));

copyButton.addEventListener("click", copyText);

saveButton.addEventListener("click", saveSnapshot);

clearButton.addEventListener("click", () => {
  transcriptOutput.value = "";
  interimOutput.textContent = "Waiting for speech...";
  targetOutput.value = "";
  updateWordCount();
  statusText.textContent = "Workspace cleared.";
});

transcriptOutput.addEventListener("input", updateWordCount);
autoInsertToggle.addEventListener("change", applyAutoActions);
autoCopyToggle.addEventListener("change", () => {
  statusText.textContent = autoCopyToggle.checked ? "Auto-copy enabled for formatting actions." : "Auto-copy disabled.";
});

refreshHistoryButton.addEventListener("click", renderHistory);
clearHistoryButton.addEventListener("click", () => {
  writeHistory([]);
  renderHistory();
  statusText.textContent = "Local history cleared.";
});

document.addEventListener("keydown", (event) => {
  const modifier = event.ctrlKey || event.metaKey;
  if (!modifier || !event.shiftKey) {
    return;
  }

  const key = event.key.toLowerCase();

  if (key === "r") {
    event.preventDefault();
    if (isRecording) {
      stopDictation();
    } else {
      startDictation();
    }
  }

  if (key === "c") {
    event.preventDefault();
    copyText();
  }

  if (key === "s") {
    event.preventDefault();
    saveSnapshot();
  }
});

updateSupportState();
renderHistory();
updateWordCount();
