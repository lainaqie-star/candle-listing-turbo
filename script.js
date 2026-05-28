const transcriptOutput = document.querySelector("#transcript-output");
const interimOutput = document.querySelector("#interim-output");
const statusText = document.querySelector("#status-text");
const supportPill = document.querySelector("#support-pill");
const pulseDot = document.querySelector("#pulse-dot");
const recordButton = document.querySelector("#record-button");
const stopButton = document.querySelector("#stop-button");
const languageSelect = document.querySelector("#language-select");
const copyButton = document.querySelector("#copy-button");
const clearButton = document.querySelector("#clear-button");
const autoCopyToggle = document.querySelector("#auto-copy-toggle");
const autoInsertToggle = document.querySelector("#auto-insert-toggle");
const targetOutput = document.querySelector("#target-output");
const targetStatus = document.querySelector("#target-status");
const wordCount = document.querySelector("#word-count");

const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;

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
  statusText.textContent = "This browser does not support the Web Speech API. You can still type into the editor.";
  recordButton.disabled = true;
  stopButton.disabled = true;
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

function applyOutputBehaviors() {
  if (autoInsertToggle.checked) {
    targetOutput.value = transcriptOutput.value;
    targetStatus.textContent = "Auto-insert active";
  } else {
    targetStatus.textContent = "Manual mode";
  }

  if (autoCopyToggle.checked) {
    copyText(true);
  }
}

function updateWordCount() {
  const words = transcriptOutput.value.trim().split(/\s+/).filter(Boolean);
  wordCount.textContent = `${words.length} words`;
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
    statusText.textContent = "Listening now.";
    recordButton.disabled = true;
    stopButton.disabled = false;
  };

  instance.onend = () => {
    isRecording = false;
    pulseDot.classList.remove("active");
    statusText.textContent = "Stopped. Review, copy, or start again.";
    recordButton.disabled = false;
    stopButton.disabled = true;
  };

  instance.onerror = (event) => {
    isRecording = false;
    pulseDot.classList.remove("active");
    recordButton.disabled = false;
    stopButton.disabled = true;

    const messages = {
      "not-allowed": "Microphone access was blocked. Allow microphone permission and try again.",
      "audio-capture": "No microphone was detected. Check your input device and try again.",
      "no-speech": "No speech was heard. Try again and speak closer to the microphone.",
      "network": "Speech recognition hit a network problem. Try again in a moment.",
    };

    statusText.textContent = messages[event.error] || "Speech recognition stopped unexpectedly.";
  };

  instance.onresult = (event) => {
    let finalText = "";
    let interimText = "";

    for (let i = event.resultIndex; i < event.results.length; i += 1) {
      const part = event.results[i][0].transcript;
      if (event.results[i].isFinal) {
        finalText += part;
      } else {
        interimText += part;
      }
    }

    if (finalText) {
      const current = transcriptOutput.value.trim();
      const next = normalizeDictation(finalText, languageSelect.value);
      transcriptOutput.value = current ? `${current}\n${next}` : next;
      updateWordCount();
      applyOutputBehaviors();
    }

    interimOutput.textContent = interimText || "Waiting for speech...";
  };

  return instance;
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

function copyText(silent = false) {
  navigator.clipboard.writeText(transcriptOutput.value).then(() => {
    if (!silent) {
      statusText.textContent = "Copied to clipboard.";
    }
  }).catch(() => {
    if (!silent) {
      statusText.textContent = "Copy failed in this browser. You can still select and copy manually.";
    }
  });
}

recordButton.addEventListener("click", startDictation);
stopButton.addEventListener("click", stopDictation);
copyButton.addEventListener("click", () => copyText(false));

clearButton.addEventListener("click", () => {
  transcriptOutput.value = "";
  interimOutput.textContent = "Waiting for speech...";
  targetOutput.value = "";
  updateWordCount();
  statusText.textContent = "Cleared.";
});

transcriptOutput.addEventListener("input", () => {
  updateWordCount();
  applyOutputBehaviors();
});

autoInsertToggle.addEventListener("change", applyOutputBehaviors);
autoCopyToggle.addEventListener("change", () => {
  statusText.textContent = autoCopyToggle.checked ? "Auto-copy enabled." : "Auto-copy disabled.";
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
    copyText(false);
  }
});

updateSupportState();
updateWordCount();
applyOutputBehaviors();
