# Payment Setup

## Recommendation

Start with Stripe Payment Links first.

Why this is the best first payment entrance for this project:

- no-code hosted checkout
- easy to create one link per package
- cleaner for a service business than building a full cart
- easier to swap into the current site

Keep Gumroad as a fallback if you want a second checkout option later.

## What to create first

Create three one-time payment links:

1. Starter - $59
2. Best seller - $129
3. Seasonal drop - $249

## Suggested product names

- Candle Listing Turbo Starter
- Candle Listing Turbo Best Seller Pack
- Candle Listing Turbo Seasonal Drop Pack

## Suggested product descriptions

### Starter

1 candle listing rewrite with 3 title options, 13 tags, a rewritten opening paragraph, and a buyer-friendly FAQ block.

### Best seller

3 candle listing rewrites with stronger title angles, scent-led hooks, image text ideas, and one promo caption or email angle.

### Seasonal drop

5 listing rewrites for a candle launch or seasonal collection, including collection voice alignment and promo angle suggestions.

## Setup checklist in Stripe

1. Create or activate your Stripe account.
2. Go to Payment Links in the Stripe Dashboard.
3. Create a new product for each package.
4. Set each one as a one-time payment.
5. Use the prices listed above.
6. Copy each generated payment link.
7. Paste the links into `script.js`:
   - `starterCheckout`
   - `growthCheckout`
   - `launchCheckout`
   - `primaryCheckout` should usually point to the best seller package

## Recommended link mapping

- `starterCheckout`: Starter payment link
- `growthCheckout`: Best seller payment link
- `launchCheckout`: Seasonal drop payment link
- `primaryCheckout`: Best seller payment link

## While links are not ready

The current site points all main buttons to the order form section. The order form sends inquiries to `lainaqie@gmail.com`.

## After links are ready

Replace the placeholder values in `script.js` and test:

- top navigation CTA
- hero CTA
- pricing card buttons
- bottom CTA
