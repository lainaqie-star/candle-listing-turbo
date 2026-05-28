const siteConfig = {
  brandEmail: "lainaqie@gmail.com",
  starterCheckout: "https://buy.stripe.com/6oUbIUbTz5Ptf695aT1RC00",
  growthCheckout: "https://buy.stripe.com/00w3cog9Pb9Nf691YH1RC01",
  launchCheckout: "https://buy.stripe.com/00waEQ6zfdhV0bfcDl1RC02",
  primaryCheckout: "https://buy.stripe.com/00w3cog9Pb9Nf691YH1RC01",
};

const styleVoices = {
  warm: {
    tone: "warm, cozy, and reassuring",
    opener: "Turn an everyday corner into a softer, calmer ritual.",
    imageText: "Cozy glow, slow burn, gift-ready feel",
  },
  clean: {
    tone: "clean, minimal, and polished",
    opener: "A simplified product experience that feels thoughtful from the first glance.",
    imageText: "Minimal design, elevated detail, clutter-free mood",
  },
  playful: {
    tone: "fun, bright, and giftable",
    opener: "Made to spark an instant smile before the package is even opened.",
    imageText: "Giftable, cheerful, easy to love",
  },
  luxury: {
    tone: "premium, refined, and indulgent",
    opener: "Designed to feel elevated, intentional, and worth lingering over.",
    imageText: "Refined finish, premium feel, small indulgence",
  },
};

const titleEl = document.querySelector("#preview-title");
const hookEl = document.querySelector("#preview-hook");
const descriptionEl = document.querySelector("#preview-description");
const tagsEl = document.querySelector("#preview-tags");
const imageTextEl = document.querySelector("#preview-image-text");
const formEl = document.querySelector("#listing-form");
const orderFormEl = document.querySelector("#order-form");

function applyCheckoutLinks() {
  const linkMap = new Map([
    ["#nav-order-link", siteConfig.primaryCheckout],
    ["#hero-order-link", siteConfig.primaryCheckout],
    ["#starter-link", siteConfig.starterCheckout],
    ["#growth-link", siteConfig.growthCheckout],
    ["#launch-link", siteConfig.launchCheckout],
    ["#cta-order-link", siteConfig.primaryCheckout],
  ]);

  linkMap.forEach((href, selector) => {
    const node = document.querySelector(selector);
    if (node) {
      node.href = href;
    }
  });
}

function uniqTags(words) {
  return [...new Set(words.map((word) => word.trim()).filter(Boolean))].slice(0, 13);
}

function generatePreview({ product, audience, style, feature }) {
  const voice = styleVoices[style] || styleVoices.warm;
  const productTitle = product.trim();
  const audienceText = audience.trim();
  const featureText = feature.trim();

  const title = `${capitalize(productTitle)} for ${capitalizeShort(audienceText)} | ${capitalizeShort(featureText)}`;
  const hook = `${voice.opener} This ${productTitle} is positioned for ${audienceText} with a ${voice.tone} angle.`;
  const description = `Created for ${audienceText}, this ${productTitle} stands out through ${featureText}. The copy should highlight the emotional payoff first, then quickly make the practical details easy to trust. That structure helps the buyer picture the product in their life before they compare specs.`;
  const rawTags = uniqTags([
    productTitle,
    audienceText,
    featureText,
    `${productTitle} gift`,
    `${productTitle} etsy`,
    "small business gift",
    "shop update",
    "etsy listing help",
    "giftable home item",
    "keyword refresh",
    "product description",
  ]);

  return {
    title,
    hook,
    description,
    tags: rawTags.join(" | "),
    imageText: voice.imageText,
  };
}

function capitalize(text) {
  return text
    .split(" ")
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ");
}

function capitalizeShort(text) {
  const cleaned = capitalize(text);
  return cleaned.length > 38 ? `${cleaned.slice(0, 35)}...` : cleaned;
}

function renderPreview(payload) {
  titleEl.textContent = payload.title;
  hookEl.textContent = payload.hook;
  descriptionEl.textContent = payload.description;
  tagsEl.textContent = payload.tags;
  imageTextEl.textContent = payload.imageText;
}

function handleOrderForm(event) {
  event.preventDefault();

  const formData = new FormData(orderFormEl);
  const selectedPackage = formData.get("order-package");
  const shopName = formData.get("shop-name");
  const shopUrl = formData.get("shop-url");
  const mainScent = formData.get("main-scent");
  const replyEmail = formData.get("reply-email");

  const subject = encodeURIComponent(`Amber Script Order - ${selectedPackage}`);
  const body = encodeURIComponent(
    [
      `Package: ${selectedPackage}`,
      `Shop name: ${shopName}`,
      `Shop URL: ${shopUrl}`,
      `Main product or scent: ${mainScent}`,
      `Best reply email: ${replyEmail}`,
      "",
      "Please send me the next steps, payment link, and delivery timeline.",
    ].join("\n"),
  );

  window.location.href = `mailto:${siteConfig.brandEmail}?subject=${subject}&body=${body}`;
}

formEl.addEventListener("submit", (event) => {
  event.preventDefault();

  const formData = new FormData(formEl);
  const preview = generatePreview({
    product: formData.get("product"),
    audience: formData.get("audience"),
    style: formData.get("style"),
    feature: formData.get("feature"),
  });

  renderPreview(preview);
});

orderFormEl.addEventListener("submit", handleOrderForm);

applyCheckoutLinks();
renderPreview(
  generatePreview({
    product: "soy candle",
    audience: "women buying cozy home gifts",
    style: "warm",
    feature: "amber jar and slow burn scent throw",
  }),
);
