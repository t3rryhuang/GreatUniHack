# NatWest Brand and Style Guide

A reference for NatWest's web look and feel: colour, type, spacing, radius, motion, layout and components. Everything here was read out of the CSS that natwest.com serves.

> **Source:** 103 stylesheets (about 1.6 MB minified) loaded by the NatWest home, savings, credit card, loans, current account, mortgage and support pages, downloaded on **7 November 2026**. Values are copied from the CSS, not estimated from screenshots. Hex counts come from the stylesheets themselves.

---

## Contents

1. [How NatWest's CSS is organised](#1-how-natwests-css-is-organised)
2. [Colour](#2-colour)
3. [Dark mode](#3-dark-mode)
4. [Typography](#4-typography)
5. [Spacing](#5-spacing)
6. [Sizing](#6-sizing)
7. [Corner radius](#7-corner-radius)
8. [Borders, strokes and focus](#8-borders-strokes-and-focus)
9. [Elevation and shadow](#9-elevation-and-shadow)
10. [Motion](#10-motion)
11. [Layout, grid and breakpoints](#11-layout-grid-and-breakpoints)
12. [Components](#12-components)
13. [Icons, logo and imagery](#13-icons-logo-and-imagery)
14. [Ready-to-use tokens](#14-ready-to-use-tokens)
15. [Appendix: full primitive palette](#appendix-full-primitive-palette)

---

## 1. How NatWest's CSS is organised

The site runs two token systems side by side.

**1. OBDS tokens: the newer design system.** The `<html>` element carries the class `obds-brand-nw`, which switches on the NatWest brand. Tokens come in three tiers:

| Tier | Prefix | Example | Purpose |
|---|---|---|---|
| Primitive | `--ob-pri-*` | `--ob-pri-color-regalpurple-400: #5e10b1` | Raw values: colours, sizes, font sizes |
| Generic (semantic) | `--ob-gen-*` | `--ob-gen-color-bg-brand: var(--ob-pri-color-regalpurple-400)` | Meaning: page background, body text, brand |
| Component | `--ob-cmp-*` | `--ob-cmp-color-button-bg-primary-hover` | Per-component, per-state values |

The token set includes 86 colour primitives, 249 component colour tokens, and full type, spacing, size and radius scales. The same system also contains fonts for Coutts, another NatWest Group brand, so it is a group-wide system themed per brand.

**2. Champion tokens: the older theme.** These are named `--colour-*`, `--spacing-*`, `--corner-radius-*` and so on, and are defined on `:root`. Most of the live page components still use hard-coded values from this theme. "Champion" is NatWest's internal name for this brand theme.

**One gotcha.** The live site sets `html { font-size: 10px }`, a Bootstrap 3 leftover. The champion spacing tokens were written for that root, so `--spacing-16: 1.6rem` means 16px. The OBDS tokens were written for a 16px root, so `--ob-pri-space-16: 1rem` is meant to be 16px too. **Every pixel value in this guide is the intended pixel value**, which matches the number in each token's name.

---

## 2. Colour

### 2.1 Core brand purples

These five purples carry the brand. Bright purple alone appears about 1,100 times in the CSS, second only to white.

| Swatch name (NatWest's) | Hex | OBDS token | Champion token | Used for |
|---|---|---|---|---|
| **Bright purple** | `#5E10B1` | `regalpurple-400` | `--colour-brand-bright-purple` | Primary buttons, links, focus rings, selected controls, icons. **The action colour** |
| **Champion purple** | `#5A287D` | `regalpurple-800` | `--colour-brand-champion-purple` | All headings (h1 to h3), main nav bar, footer, brand text, dark section backgrounds |
| **Regal purple** | `#3C1053` | `regalpurple-900` | `--colour-brand-regal-purple` | Hover and pressed states, top utility bar, outer focus outline, darkest backgrounds |
| **Secondary purple** | `#8B3FB2` | n/a | `--colour-brand-secondary-purple` | Banner teaser backgrounds, utility bar dividers |
| **Lilac** | `#F2EAF9` | `regalpurple-50` | `--colour-brand-lilac` | Hover fill for secondary buttons and tabs, nav dropdown background, light brand panels |

Supporting purples:

| Name | Hex | Token | Used for |
|---|---|---|---|
| Bright purple 700 | `#BE99E6` | `regalpurple-200`, `--colour-secondary-purple-bright-purple-700` | Primary action colour **in dark mode**, progress bars, slider tracks |
| Champion purple 600 | `#724890` | `regalpurple-700` | Secondary hover and press accents |
| Champion purple 700 | `#9C7EB1` | `regalpurple-600` | Disabled controls on dark backgrounds, keylines on purple |
| Champion purple 800 | `#E6DEEB` | n/a | Tab background |
| Champion purple 100 | `#481A64` | n/a | Search field on purple |
| Purple 100 | `#BF9FE0` | `regalpurple-100` | Light accent |
| Purple 300 | `#9F7BC3` | `regalpurple-300` | Mid accent |
| Purple 500 | `#4A0E8E` | `regalpurple-500` | Deep accent |

`regalpurple-200` is defined twice. The base theme sets it to `#BE99E6` and one component file overrides it with `#724890`. Use `#BE99E6`, which is what every dark-mode token expects.

### 2.2 Neutrals

| Role | Hex | Token | Notes |
|---|---|---|---|
| White | `#FFFFFF` | `mono-0`, `--colour-mono-white` | Default surface. The most used colour on the site |
| **Body text** | `#646068` | `--colour-mono-grey-500`, `--aem-paragraph-text-color` | All paragraph copy on the live site. A warm grey with a slight purple cast |
| Body text, OBDS | `#616161` | `mono-750` | OBDS semantic body colour, very close to the above |
| **Dark text** | `#333333` | `--colour-mono-grey-300` | h4 to h6, table values, notification text |
| Heading, OBDS | `#2C2C2C` | `mono-1000` | OBDS semantic heading colour |
| **Ground grey** | `#F2F2F8` | `powderblue-100`, `--colour-brand-ground-grey` | Page background and tonal containers. Very slightly blue |
| Keyline | `#CCCFD0` | `--colour-mono-grey-700` | Dividers and card borders |
| Keyline light | `#E9E9F1` | `--colour-mono-grey-800` | Subtle dividers |
| Light grey | `#F5F5F5` | `--colour-mono-grey-900` | Info notification background, current date in pickers |
| Disabled | `#B3B3B3` | `--colour-mono-grey-600` | Disabled buttons and inputs |
| Disabled text | `#5C5C5C` | n/a | Text on disabled primary buttons |
| Dark surface | `#1E1E1E` | `mono-1050` | Dark-mode cards |
| Darkest surface | `#121212` | `--colour-mono-grey-100` | Dark-mode backgrounds |
| Black | `#000000` | `mono-1200` | Rare |

The full OBDS grey ramp is `mono-0` to `mono-1200`: `#FFF`, `#F2F2F2`, `#E5E5E5`, `#CCC`, `#B2B2B2`, `#9A9A9A`, `#828282`, `#6C6C6C`, `#616161`, `#565656`, `#414141`, `#2C2C2C`, `#1E1E1E`, `#191919`, `#000`.

### 2.3 Background tints

NatWest alternates white sections with soft pastel bands. These are the only non-purple section backgrounds.

| Name | Hex | Token | Used for |
|---|---|---|---|
| Ground grey | `#F2F2F8` | `--colour-background-background-secondary` | Default alternate band |
| Lilac | `#F2EAF9` | `--colour-background-background-04` | Brand-tinted band |
| Mist | `#DBEDFA` | `--colour-background-background-05`, theme "aqua" | Cool band |
| Sand | `#FFEAE6` | `--colour-background-background-06`, theme "gold" | Warm band, notification badges |
| Blush | `#FFDBEC` | `--colour-background-background-07`, theme "rose" | Pink band |
| Champion purple | `#5A287D` | `--colour-background-background-01` | Dark brand band, white text |
| Secondary purple | `#8B3FB2` | `--colour-background-background-02` | Dark brand band, white text |
| Regal purple | `#3C1053` | `--colour-background-background-03` | Darkest brand band, white text |

### 2.4 Feedback colours

The two systems use slightly different hues. OBDS is the newer one.

| Status | Strong (OBDS) | Strong (champion) | Light background (champion) | Notes |
|---|---|---|---|---|
| Error | `#DF2B40` cardinal-600 | `#CF223F` red-500 | `#FAE9EC` red-800 | Error text, invalid inputs, destructive buttons. Hover `#74121D` |
| Success | `#008E4E` forestgreen-800 | `#429448` green-500 | `#ECF4ED` green-800 | |
| Warning | `#F8B400` goldenyellow-400 | `#FCB900` yellow-500 | `#FFF8E5` yellow-800 | Icon stroke on warning is black |
| Info | `#0B72D0` brightblue-600 | `#333333` | `#F5F5F5` | Dark mode uses `#2D90FD` |

Notifications use an **8px left border** in the status colour with 1px borders elsewhere.

### 2.5 Secondary (illustration and promo) palette

Seven named ramps. The `500` step is the pure colour. Steps go darker below 500 and lighter above.

| Ramp | 200 | 300 | 400 | **500** | 600 | 700 | 800 |
|---|---|---|---|---|---|---|---|
| Watermelon | `#3C1323` | `#661333` | `#911444` | **`#E51565`** | `#EF73A3` | `#F5A1C1` | `#FAD0E0` |
| Tangerine | `#3A190E` | `#62210B` | `#8B2807` | **`#DB3700`** | `#E98766` | `#F1AF99` | `#F8D7CC` |
| Yolk | `#41320E` | `#6F520B` | `#9E7207` | **`#FBB200`** | `#FDD166` | `#FEE099` | `#FEF0CC` |
| Pineapple | `#413F0E` | `#716C0B` | `#A09807` | **`#FFF200`** | `#FFF766` | `#FFFA99` | `#FFFCCC` |
| Blueberry | `#0E253C` | `#0B3767` | `#074A91` | **`#006FE6`** | `#66A9F0` | `#99C5F5` | `#CCE2FA` |
| Aubergine | `#281A3B` | `#3E2164` | `#55298E` | **`#8138E0`** | `#B388EC` | `#CDAFF3` | `#E6D7F9` |
| Broccoli | `#1A3920` | `#225F2D` | `#2A863B` | **`#3AD356`** | `#89E59A` | `#B0EDBB` | `#D8F6DD` |

The product card promo tags use these 500 values as solid fills: blueberry, watermelon, pineapple and broccoli. White text sits on blueberry and watermelon. Dark text sits on pineapple and broccoli.

### 2.6 Data visualisation

NatWest defines a chart palette in series order. Each series has 100%, 60%, 40% and 20% steps, which are the ramp's 500, 600, 700 and 800 values.

| Series | Token | 100% | 60% | 40% | 20% |
|---|---|---|---|---|---|
| Base 1 | `datavis-00-01` | `#5A287D` champion purple | | | |
| Base 2 | `datavis-00-02` | `#F2F2F8` ground grey | | | |
| Base 3 | `datavis-00-03` | `#FFFFFF` | | | |
| Base 4 | `datavis-00-04` | `#646068` | | | |
| 1 | `datavis-01` | `#FFF200` pineapple | `#FFF766` | `#FFFA99` | `#FFFCCC` |
| 2 | `datavis-02` | `#FBB200` yolk | `#FDD166` | `#FEE099` | `#FEF0CC` |
| 3 | `datavis-03` | `#DB3700` tangerine | `#E98766` | `#F1AF99` | `#F8D7CC` |
| 4 | `datavis-04` | `#E51565` watermelon | `#EF73A3` | `#F5A1C1` | `#FAD0E0` |
| 5 | `datavis-05` | `#8138E0` aubergine | `#B388EC` | `#CDAFF3` | `#E6D7F9` |
| 6 | `datavis-06` | `#006FE6` blueberry | `#66A9F0` | `#99C5F5` | `#CCE2FA` |
| 7 | `datavis-07` | `#3AD356` broccoli | `#89E59A` | `#B0EDBB` | `#D8F6DD` |

Pineapple and yolk have poor contrast on white. Put them on champion purple or give them a dark outline.

### 2.7 Semantic colour map (light mode)

These are OBDS generic tokens under `:root.obds-brand-nw`.

| Semantic token | Value | Hex |
|---|---|---|
| `bg-page` | powderblue-100 | `#F2F2F8` |
| `bg-container-neutral` | mono-0 | `#FFFFFF` |
| `bg-container-tonal` | powderblue-100 | `#F2F2F8` |
| `bg-brand` | regalpurple-400 | `#5E10B1` |
| `bg-inverse-page` | regalpurple-800 | `#5A287D` |
| `text-heading` | mono-1000 | `#2C2C2C` |
| `text-body` | mono-750 | `#616161` |
| `text-brand` | regalpurple-800 | `#5A287D` |
| `text-error` | cardinal-600 | `#DF2B40` |
| `text-inverse-*` | mono-0 | `#FFFFFF` |
| `outline-outer-focus` | regalpurple-900 | `#3C1053` |
| `outline-inner-focus` | mono-0 | `#FFFFFF` |

---

## 3. Dark mode

NatWest supports dark mode in two ways. It follows `prefers-color-scheme: dark` when the page opts in with the `allow-prefers-dark` class. It can also be forced with the `obds-color-pref-dark` class.

| Semantic token | Light | Dark |
|---|---|---|
| Page background | `#F2F2F8` | `#191919` mono-1100 |
| Card / container | `#FFFFFF` | `#1E1E1E` mono-1050 |
| Tonal container | `#F2F2F8` | `#191919` |
| Inverse page | `#5A287D` | `#3C1053` |
| Heading text | `#2C2C2C` | `#FFFFFF` |
| Body text | `#616161` | `#CCCCCC` mono-300 |
| Brand text | `#5A287D` | `#FFFFFF` |
| Outer focus ring | `#3C1053` | `#FFFFFF` |
| Primary button fill | `#5E10B1` | `#BE99E6` |
| Primary button text | `#FFFFFF` | `#3C1053` |
| Primary button hover | `#3C1053` fill | `#FFFFFF` fill |
| Secondary button border and text | `#5E10B1` | `#BE99E6` |
| Secondary button hover fill | `#F2EAF9` | `#2C2C2C` |
| Links | `#5E10B1` | `#BE99E6`, hover white |
| Selected checkbox or radio | `#5E10B1` | `#BE99E6` |
| Table header | `#F2F2F2` bg, `#2C2C2C` text | `#1E1E1E` bg, white text |
| Table border | `#CCCCCC` | `#616161` |
| Info notification border | `#0B72D0` | `#2D90FD` |

The pattern: in dark mode, bright purple becomes light lilac `#BE99E6`, and hover states flip to white.

---

## 4. Typography

### 4.1 Typefaces

| Family | Files served | Role |
|---|---|---|
| **RN House Sans** | `RNHouseSansRegular`, `RNHouseSansBold`, `RNHouseSansLight` | Everything except big headlines: body, h4 to h6, buttons, nav, labels, tables |
| **Knile** | `knileblack`, `knilebold`, `knilesemibold` | Display headings only: h1 uses Black, h2 and h3 use Bold |
| nw-icons | `nw-icons` | Icon font |

**Both are proprietary.** RN House Sans is NatWest Group's corporate typeface. Knile is a licensed commercial typeface. Neither is on Google Fonts, and you cannot ship either without a licence. Suggested stand-ins:

| NatWest font | Closest free alternatives | Why |
|---|---|---|
| RN House Sans | **Source Sans 3**, Inter, Open Sans | Humanist sans with open apertures. OBDS itself lists Open Sans as a primitive |
| Knile Black / Bold | **Manrope ExtraBold**, Plus Jakarta Sans ExtraBold, Poppins Bold | Heavy, wide, slightly geometric display sans |

Font stacks as written in the CSS:

```css
font-family: "RNHouseSansRegular", sans-serif;   /* body */
font-family: "RNHouseSansBold", sans-serif;      /* bold UI text */
font-family: "knileblack", sans-serif;           /* h1 */
font-family: "knilebold", sans-serif;            /* h2, h3 */
```

Headings set `font-weight: normal` and get their weight from the font file. If you use a variable font as a stand-in, set the weight explicitly instead.

### 4.2 Live site type scale (responsive)

This is what natwest.com renders today, from the champion base theme. Sizes are px, written as size / line-height.

| Style | Font | Colour | ≥1256px | 1024 to 1255px | 768 to 1023px | <768px |
|---|---|---|---|---|---|---|
| **h1** | Knile Black | `#5A287D` | 46 / 58 | 42 / 54 | 34 / 44 | 32 / 40 |
| **Hero h1** (home banner) | Knile Black | white or `#5A287D` | 52 / 64 | 42 / 54 | 34 / 44 | 34 / 44 |
| **h2** | Knile Bold | `#5A287D` | 46 / 58 | 42 / 54 | 34 / 44 | 32 / 40 |
| **h2 custom** (section titles) | Knile Bold | `#5A287D` | 40 / 50 | 38 / 48 | 28 / 38 | 32 / 40 |
| **h3** | Knile Bold | `#5A287D` | 30 / 40 | 26 / 36 | 24 / 32 | 24 / 32 |
| **h3 custom** | RN House Sans | `#5A287D` | 26 / 34 | 24 / 32 | 24 / 32 | 24 / 32 |
| **h4** | RN House Sans | `#333333` | 22 / 32 | 22 / 32 | 18 / 26 | 18 / 26 |
| **h5** | RN House Sans | `#333333` | 14 / 15.4 | same | same | same |
| **h6** | RN House Sans | `#333333` | 12 / 13.2 | same | same | same |
| **Body** | RN House Sans Regular | `#646068` | 18 / 26 | 18 / 26 | 18 / 26 | 18 / 26 |
| **Body small** | RN House Sans Regular | `#646068` | 16 / 26 | same | same | same |
| **Caption / legal** | RN House Sans Regular | `#646068` | 14 / 18 | same | same | same |
| **Button** | RN House Sans Regular | per button | 18 / 26 | same | same | same |
| **Footer links** | RN House Sans Regular | white | 14 / 30 | same | same | same |
| **Footer column heading** | RN House Sans Regular | white | 22 / 32 | same | same | same |
| **Card title** | RN House Sans Bold | `#5A287D` | 22 (18 on mobile) / 26 | | | |

Letter spacing:

- Body text and h4: **+0.2px**.
- h1, h2, h3 in Knile: **−0.2px**.
- Paragraph spacing: `margin: 0 0 10px`. Headings have `margin: 0` and rely on component spacing.

The most common size and line-height pairs in the whole CSS are 14/18 (107 rules), 18/26 (101), 16/26 (61), 22/32 (21) and 24/32 (20). Body copy is big by default, 18px, which is a deliberate accessibility choice.

### 4.3 OBDS type scale (the newer system)

Defined under `:root.obds-brand-nw`, each with a matching utility class such as `.ob-gen-text-heading-large`.

| Style | Family | Weight | Size | Line height |
|---|---|---|---|---|
| Display large | Knile | 700 | 70 | 84 |
| Display medium | Knile | 700 | 56 | 67 |
| Display small | Knile | 700 | 48 | 58 |
| Heading large | RN House Sans | 700 | 40 | 48 |
| Heading medium | RN House Sans | 700 | 32 | 38 |
| Heading small | RN House Sans | 700 | 24 | 29 |
| Title large | RN House Sans | 700 | 18 | 27 |
| Title medium | RN House Sans | 700 | 16 | 24 |
| Title small | RN House Sans | 700 | 14 | 21 |
| Body xlarge | RN House Sans | 400 | 18 | 27 |
| Body large | RN House Sans | 400 | 16 | 24 |
| Body medium | RN House Sans | 400 | 14 | 21 |
| Body small | RN House Sans | 400 | 12 | 18 |
| Label large | RN House Sans | 400 | 18 | 22 |
| Label medium | RN House Sans | 400 | 16 | 24 |
| Label condensed medium | RN House Sans | 400 | 16 | 19 |
| Label small | RN House Sans | 400 | 14 | 21 |
| Label xsmall | RN House Sans | 400 | 12 | 19 |
| Button medium | RN House Sans | 400 | 18 | 21 |
| Button small | RN House Sans | 400 | 14 | 17 |
| Link | RN House Sans | 400 | 16 | 24 |
| Table | RN House Sans | 400 | 16 | 19 |

Weights available: Light 300, Regular 400, Semibold 600, Bold 700.

Every primitive font size: 12, 14, 16, 18, 20, 22, 24, 25, 26, 27, 32, 34, 40, 48, 53, 56, 70, 83.

Line height ratio is roughly **1.5 for body** and **1.2 for display and headings**.

---

## 5. Spacing

### 5.1 OBDS spacing scale (4px base)

Generic, named steps:

| Token | px |
|---|---|
| `--ob-gen-space-05x` | 2 |
| `--ob-gen-space-1x` | 4 |
| `--ob-gen-space-2x` | 8 |
| `--ob-gen-space-3x` | 12 |
| `--ob-gen-space-4x` | 16 |
| `--ob-gen-space-5x` | 24 |
| `--ob-gen-space-6x` | 32 |

Full primitive scale: 0, 1, 2, 4, 8, 12, 16, 18, 20, 24, 32, 40, 48, 56, 64, 78.

### 5.2 Champion padding presets

| Token | px |
|---|---|
| `padding-3-xs` | 2 |
| `padding-2-xs` | 4 |
| `padding-xs` | 8 |
| `padding-s` | 12 |
| `padding-m` | 16 |
| `padding-l` | 20 |
| `padding-xl` | 24 |
| `padding-2-xl` | 32 |
| `padding-3-xl` | 40 |
| `padding-4-xl` | 48 |

The underlying champion spacing scale is 0, 2, 4, 8, 12, 16, 20, 24, 32, 36, 40, 44, 48, 56, 60, 64, 72, 80, 88, 96 and 104px, plus 27.5px for inputs.

### 5.3 Spacing in practice

The most used vertical gaps in the CSS are **24px**, **16px**, **20px** and **8px**, in that order.

| Situation | Value |
|---|---|
| Card padding | 24 on all sides |
| Gap between items inside a card | 16 |
| Text input padding | 8 top and bottom, 16 left and right |
| Table cell padding | 16 top and bottom, 24 left and right |
| Tab item padding | 24 left and right |
| Accordion header padding | 16 all round, 8 gap |
| Accordion panel | 48 left indent, 24 bottom |
| Notification gaps | 16 between blocks, 8 between lines |
| Field label to control | 12 |
| Field label to hint | 4 |
| Primary button padding | 14 top, 10 bottom, 32 left and right |
| Section padding (desktop) | 32 to 48 vertical |
| Page side gutter | 16 mobile, 24 tablet, 30 desktop |

Button padding is asymmetric, 14px above and 10px below, to optically centre RN House Sans. Use equal padding with a stand-in font.

---

## 6. Sizing

| Thing | px |
|---|---|
| Minimum touch target | **48** |
| Icon sizes | 16, 24 (default), 32 |
| Text input height | 48 |
| Textarea minimum height | 64 |
| Checkbox and radio | 24 × 24 |
| Small tab height | 48 |
| Medium tab height | 64 |
| Tab selected indicator | 4 thick |
| Table row minimum height | 56 |
| Accordion header max height | 96 |
| Readable text column max width | 640 |
| Button minimum width | 96 |
| Button maximum width | 292 |
| Top utility bar height | 48 |
| Main nav bar height | 61 |
| Icon card image height | 32 |

---

## 7. Corner radius

| Use | Radius | Token |
|---|---|---|
| **Buttons** | **100px (full pill)** | `--ob-cmp-radius-button` |
| Circular icon buttons | 100px | `--ob-cmp-radius-iconbutton-circle` |
| **Cards** | **8px** | `--ob-cmp-radius-card` |
| Inputs and controls | 8px | `--ob-cmp-radius-control` |
| Notifications | 8px | `--ob-cmp-radius-notification` |
| Tables | 8px top and bottom | `--ob-cmp-radius-table-*` |
| Accordion | 8px, square bottom when open | `--ob-cmp-radius-accordion-*` |
| Tabs | 8px top corners | `--ob-cmp-radius-tabs-*` |
| Square icon buttons | 8px | |
| Checkbox | 4px | `--ob-cmp-radius-checkbox` |
| Dynamic promo cards (home page) | 24px | |
| Large feature panels | 16px | |

Usage counts across the CSS: 8px (171), 16px (50), 100px (35), 24px (17), 4px (16).

The OBDS radius scale is 0, 2, 4, 8, 10, 12, 16, 24, 32, 40, 48 and 100. The champion corner scale is 0, 4, 8, 12, 16, 24, 32, 40, 44 and 48, plus a 25px button corner.

**The signature look is pill buttons with gently rounded 8px cards.**

---

## 8. Borders, strokes and focus

| Stroke | Width | Colour |
|---|---|---|
| Default keyline, card or table border | 1px | `#CCCFD0` or `#CCCCCC` |
| Input border, default | 1px | `#616161` |
| Input border, hover, focus or error | 2px | `#5E10B1`, error `#DF2B40` |
| Secondary button border | 2px (1.5px small) | `#5E10B1` |
| Notification left accent | 8px | status colour |
| Tab divider | 1px | `#E5E5E5` |
| Tab controller border | 2px | `#5E10B1` |

**Focus treatment:**

- Buttons and links: `outline: 2px solid #5E10B1; outline-offset: 2px`.
- OBDS double ring: 2px inner ring in white, 2px outer ring in `#3C1053`. On dark backgrounds the inner ring is `#5A287D` and the outer ring is `#F2EAF9`.
- Some components use `box-shadow: 0 0 0 4px #3C1053`.

Focus is always visible. Do not remove it.

---

## 9. Elevation and shadow

NatWest is a **flat** brand. `--elevation-elevation-01` is 0, and most components set `box-shadow: none`. Depth comes from colour bands and borders, not shadows.

The few shadows in use:

| Use | Shadow |
|---|---|
| Floating card or dropdown | `0 12px 20px 0 rgba(33,33,33,0.12)` |
| Raised element | `0 8px 10px 0 rgba(0,0,0,0.09)` |
| Sticky bottom bar | `0 -2px 10px 0 rgba(0,0,0,0.14)` |
| Tooltip | `0 0 5px #666` |

---

## 10. Motion

Motion is subtle and short. The site respects `prefers-reduced-motion: reduce` in 77 media queries.

| Animation | Value |
|---|---|
| **Link underline** (the signature effect) | `background-size 180ms ease-in-out`. The underline is drawn with a gradient and shrinks to nothing on hover |
| Hover colour changes | `background-color .15s ease-in-out, border-color .15s ease-in-out` |
| Small transforms | `transform 100–150ms ease-in-out` with staggered delays |
| Fades | `opacity 250–300ms cubic-bezier(0.15, 0.43, 0.34, 0.99)` |
| Panels and accordions | `400ms ease-in-out` |
| Width changes (progress bars) | `width .3s ease` |

The house easing curve is `cubic-bezier(0.15, 0.43, 0.34, 0.99)`, a fast start with a soft landing.

Link underline technique, simplified:

```css
.link {
  color: #5E10B1;
  text-decoration: none;
  background-image: linear-gradient(transparent 95%, #5E10B1 95%);
  background-size: 100% 100%;
  background-repeat: no-repeat;
  transition: background-size 180ms ease-in-out;
}
.link:hover  { background-size: 0 100%; }
.link:active { color: #3C1053; }
```

---

## 11. Layout, grid and breakpoints

### Breakpoints

| Name | Range | Usage count in CSS |
|---|---|---|
| Mobile | `max-width: 767px` | 534 |
| Tablet | `768px` to `1023px` | 326 |
| Small desktop | `1024px` to `1255px` | 262 |
| Large desktop | `min-width: 1256px` | 174 |

Minor breakpoints also appear at 374/375px for small phones, and at Bootstrap's 576, 992 and 1200px in legacy code.

### Containers

| Breakpoint | Container width | Side padding |
|---|---|---|
| Mobile | fluid | 16px |
| Tablet | 720 to 756px | 24px |
| Small desktop | 956 to 972px | 30px |
| Large desktop | 1212px | 30px |
| Content max width | **1164px** (`--max-fluid-grid`), 335px on mobile | |

The grid is AEM's 12-column responsive grid (`aem-Grid--12`). Product pages split text and image across the 12 columns, for example 7 + 5 on the Fixed Term Savings page.

---

## 12. Components

### 12.1 Buttons

All buttons are pills with a radius of 100px and RN House Sans at 18/26.

**Primary**

```css
.btn-primary {
  background: #5E10B1;
  color: #FFFFFF;
  border-radius: 100px;
  padding: 14px 32px 10px;
  min-width: 96px;
  max-width: 292px;
  font: 18px/26px "RNHouseSansRegular", sans-serif;
  text-align: center;
}
.btn-primary:hover, .btn-primary:active { background: #3C1053; }
.btn-primary:focus-visible { outline: 2px solid #5E10B1; outline-offset: 2px; }
.btn-primary:disabled { background: #B3B3B3; color: #5C5C5C; }
```

**Secondary (outline)**

```css
.btn-secondary {
  background: transparent;
  color: #5E10B1;
  border: 2px solid #5E10B1;
  border-radius: 100px;
  padding: 12px 32px 8px;   /* 2px less to allow for the border */
}
.btn-secondary:hover { background: #F2EAF9; color: #3C1053; border-color: #3C1053; }
.btn-secondary:disabled { border: 1px solid #B3B3B3; color: #B3B3B3; }
```

**Tertiary (text link button):** bright purple text with the animated underline from section 10. It is 18/26, or 16/28 in the small size. Padding is 6px top and bottom, 2px sides.

**Destructive:** `#DF2B40` fill, white text, hover `#74121D`.

**On purple backgrounds (inverse):** the primary button becomes a white fill with `#5E10B1` text, and hover becomes `#F2EAF9` with `#3C1053` text. The secondary button becomes a white outline with white text.

**External link buttons** show a 24px "opens in new tab" icon 32px from the left, with left padding increased to 76px.

### 12.2 Header

| Bar | Height | Background | Content |
|---|---|---|---|
| Top utility bar | 48px | `#3C1053` regal purple | Personal / Premier / Business / Corporates switcher. `#8B3FB2` dividers |
| Main nav | 61px | `#5A287D` champion purple | Logo, product menu, search, Log in button |
| Mega-menu dropdown | | `#F2EAF9` lilac, white sub-panels | Product links |

The Log in control in the header is not a pill. It is a transparent link with white text, a login icon on the left, and `padding: 7px 20px 7px 49px`. On hover it gets a `#724890` fill and a 1px white outline. Its dropdown is white, with `#F2EAF9` hover rows outlined in 1px `#5E10B1`.

### 12.3 Footer

- Background `#5A287D` champion purple, white text.
- Column headings are 22/32 and links are 14/30.
- Three columns at 33.3% each, or four at 25%.

### 12.4 Cards

| Card | Background | Radius | Padding | Title |
|---|---|---|---|---|
| Icon card | `#FFFFFF` on a ground-grey band | 8px | 24px | `#5A287D`, 32px icon above |
| Product card (credit cards, savings) | `#FFFFFF` | 8px | 24px | RN House Sans Bold 22px, 18px mobile |
| Promo card (purple) | Purple theme band | not set in its own CSS | 24px above image and button | White. Primary button is white with `#5E10B1` text and 190px minimum width. Secondary hover fill is `#724890` |
| Dynamic card (home page carousel) | Sand, mist, blush or `#121212` | **24px** | 16px | `#5A287D` |

Product cards have a coloured **promo tag** strip on top, such as "0% offer all-round", filled with a secondary 500 colour. The right-hand side holds a **"Representative example"** block: label in `#646068`, value in `#333333`, one per row.

### 12.5 Notifications and "Information Message" boxes

- 8px left border in the status colour, 1px border on the other sides, 8px radius.
- 24px status icon on the left.
- Text is 16px. Gaps are 16px between blocks and 8px between lines.
- The compliance "Information Message" box under rate figures uses the info style with a 24px info icon.

### 12.6 Accordions (FAQs)

- No borders or shadows. Panels are separated by spacing only.
- Header text is bright purple `#5E10B1`, hover `#3C1053`, with the expand icon on the left.
- Panel body is 18/26 body text, indented 32 to 48px to line up with the header text, with 20 to 24px bottom padding.

### 12.7 Tables (rate tables)

- Header row: `#F2F2F2` background, `#2C2C2C` text.
- Cells: white background, `#616161` text, 16/19.
- 1px `#CCCCCC` borders, 8px outer corner radius.
- Cell padding is 16px vertical and 24px horizontal, with a 56px minimum row height.

### 12.8 Tabs and filters

- Tab text is bright purple. The selected tab text is `#3C1053` with a 4px `#3C1053` underline indicator.
- Hover and pressed backgrounds are `#F2EAF9`.
- 1px `#E5E5E5` divider under the tab row.
- Heights are 48px small or 64px medium.

### 12.9 Form controls

| Element | Default | Hover | Focus | Error | Disabled |
|---|---|---|---|---|---|
| Input border | 1px `#616161` | 2px `#5E10B1` | 2px `#5E10B1` | 2px `#DF2B40` | `#B2B2B2` |
| Input background | `#FFFFFF` | | | | |
| Checkbox or radio selected | `#5E10B1` fill, white tick | | | `#DF2B40` | `#B2B2B2` |
| Toggle switch | Track `#646068` | `#3C1053` | | | |
| Toggle switch on | Track `#5E10B1`, white thumb | `#3C1053` | | | |
| Slider | Active `#5E10B1`, track `#BE99E6` | | | Minimum marker `#CF223F` | |
| Progress bar | Fill `#5A287D`, track `#BE99E6` | | | | |

Field label to control gap is 12px. Label to hint gap is 4px. Inputs are 48px tall with 8px corners.

---

## 13. Icons, logo and imagery

- **Icons:** the custom `nw-icons` icon font plus inline SVGs. Line style, default 24px, in bright purple `#5E10B1` or white on purple. 16px and 32px variants exist.
- **Logo:** the white-on-purple horizontal logo is served at `https://www.natwest.com/content/dam/championlogos/Natwest_Secondary_Horizontal_RGB_NEG.svg`. The favicon is `responsive_natwest_personal_favicon.png`.
- **Imagery:** product pages pair flat illustration and "photography" layouts. Card headers are flagged `illustration` or `photography` in the markup. Illustrations use the secondary palette on lilac or ground-grey backgrounds.

**Trademark.** The NatWest name, logo, the "daisy" symbol, and the RN House Sans and Knile fonts are NatWest Group property. Use this guide to borrow the *feel*, meaning palette logic, spacing and component patterns. Do not ship anything that could be mistaken for a NatWest product. That means no NatWest logo, no proprietary fonts, and no exact NatWest purple as your primary colour unless NatWest has approved it.

---

## 14. Ready-to-use tokens

### 14.1 CSS custom properties

```css
:root {
  /* Brand */
  --nw-bright-purple: #5E10B1;     /* actions, links */
  --nw-champion-purple: #5A287D;   /* headings, nav, footer */
  --nw-regal-purple: #3C1053;      /* hover, pressed, darkest */
  --nw-secondary-purple: #8B3FB2;
  --nw-lilac: #F2EAF9;             /* hover fills, light panels */
  --nw-purple-light: #BE99E6;      /* dark-mode action */

  /* Neutrals */
  --nw-white: #FFFFFF;
  --nw-ground-grey: #F2F2F8;       /* page background */
  --nw-text-body: #646068;
  --nw-text-dark: #333333;
  --nw-keyline: #CCCFD0;
  --nw-disabled: #B3B3B3;

  /* Tints */
  --nw-mist: #DBEDFA;
  --nw-sand: #FFEAE6;
  --nw-blush: #FFDBEC;

  /* Feedback */
  --nw-error: #DF2B40;
  --nw-success: #008E4E;
  --nw-warning: #F8B400;
  --nw-info: #0B72D0;

  /* Type */
  --nw-font-body: "Source Sans 3", "RN House Sans", system-ui, sans-serif;
  --nw-font-display: "Manrope", "Knile", system-ui, sans-serif;
  --nw-body-size: 18px;
  --nw-body-line: 26px;
  --nw-body-tracking: 0.2px;
  --nw-heading-tracking: -0.2px;

  /* Space (4px base) */
  --nw-space-1: 4px;  --nw-space-2: 8px;  --nw-space-3: 12px;
  --nw-space-4: 16px; --nw-space-5: 24px; --nw-space-6: 32px;
  --nw-space-7: 48px; --nw-space-8: 64px;

  /* Radius */
  --nw-radius-sm: 4px;
  --nw-radius-md: 8px;     /* cards, inputs */
  --nw-radius-lg: 16px;
  --nw-radius-xl: 24px;
  --nw-radius-pill: 100px; /* buttons */

  /* Motion */
  --nw-ease: cubic-bezier(0.15, 0.43, 0.34, 0.99);
  --nw-fast: 150ms;
  --nw-medium: 250ms;
}
```

### 14.2 React Native theme (same shape as Prophit's theme file)

```ts
// NatWest-inspired theme. Values extracted from natwest.com CSS, 7 Nov 2026.
export const natwestTheme = {
  colors: {
    primary: '#5E10B1',          // bright purple: buttons, links
    primaryPressed: '#3C1053',   // regal purple
    heading: '#5A287D',          // champion purple
    secondaryPurple: '#8B3FB2',
    lilac: '#F2EAF9',
    purpleLight: '#BE99E6',

    background: '#F2F2F8',       // ground grey
    cardBackground: '#FFFFFF',
    text: '#333333',
    textSecondary: '#646068',
    keyline: '#CCCFD0',
    disabled: '#B3B3B3',
    white: '#FFFFFF',

    mist: '#DBEDFA',
    sand: '#FFEAE6',
    blush: '#FFDBEC',

    error: '#DF2B40',
    success: '#008E4E',
    warning: '#F8B400',
    info: '#0B72D0',
  },

  dark: {
    background: '#191919',
    cardBackground: '#1E1E1E',
    text: '#FFFFFF',
    textSecondary: '#CCCCCC',
    primary: '#BE99E6',
    onPrimary: '#3C1053',
    heading: '#FFFFFF',
  },

  // NatWest data-vis series order
  chart: ['#5A287D', '#E51565', '#006FE6', '#3AD356', '#8138E0', '#DB3700', '#FBB200', '#FFF200'],

  spacing: { xxs: 2, xs: 4, sm: 8, md: 16, lg: 24, xl: 32, xxl: 48, xxxl: 64 },

  borderRadius: { xs: 4, sm: 8, md: 16, lg: 24, full: 100 },

  typography: {
    display:  { fontSize: 46, lineHeight: 58, letterSpacing: -0.2, fontWeight: '800' as const },
    h1Mobile: { fontSize: 32, lineHeight: 40, letterSpacing: -0.2, fontWeight: '800' as const },
    h2:       { fontSize: 40, lineHeight: 50, letterSpacing: -0.2, fontWeight: '700' as const },
    h3:       { fontSize: 24, lineHeight: 32, letterSpacing: -0.2, fontWeight: '700' as const },
    h4:       { fontSize: 18, lineHeight: 26, letterSpacing: 0.2,  fontWeight: '400' as const },
    body:     { fontSize: 18, lineHeight: 26, letterSpacing: 0.2,  fontWeight: '400' as const },
    bodySmall:{ fontSize: 16, lineHeight: 26, letterSpacing: 0.2,  fontWeight: '400' as const },
    caption:  { fontSize: 14, lineHeight: 18, letterSpacing: 0.2,  fontWeight: '400' as const },
    button:   { fontSize: 18, lineHeight: 26, fontWeight: '400' as const },
    label:    { fontSize: 14, lineHeight: 21, fontWeight: '400' as const },
  },

  sizes: { touchTarget: 48, inputHeight: 48, icon: 24, iconSmall: 16, iconLarge: 32 },

  button: {
    primary:   { backgroundColor: '#5E10B1', color: '#FFFFFF', pressed: '#3C1053', borderRadius: 100, paddingHorizontal: 32, paddingVertical: 12, minWidth: 96 },
    secondary: { borderColor: '#5E10B1', borderWidth: 2, color: '#5E10B1', pressedBackground: '#F2EAF9', borderRadius: 100 },
    disabled:  { backgroundColor: '#B3B3B3', color: '#5C5C5C' },
  },

  card: { backgroundColor: '#FFFFFF', borderRadius: 8, padding: 24, gap: 16, borderColor: '#CCCFD0', borderWidth: 1 },

  motion: { fast: 150, medium: 250, slow: 400, easing: [0.15, 0.43, 0.34, 0.99] as const },
};
```

---

## Appendix: full primitive palette

Every `--ob-pri-color-*` value defined on natwest.com, for completeness.

| Family | Steps |
|---|---|
| regalpurple | 50 `#F2EAF9` · 100 `#BF9FE0` · 200 `#BE99E6` · 300 `#9F7BC3` · 400 `#5E10B1` · 500 `#4A0E8E` · 600 `#9C7EB1` · 700 `#724890` · 800 `#5A287D` · 900 `#3C1053` · 1100 `#9B8FA3` · 1200 `#5F5566` · 1300 `#352D3D` · 1400 `#1C1521` |
| mono | 0 `#FFFFFF` · 100 `#F2F2F2` · 200 `#E5E5E5` · 300 `#CCCCCC` · 400 `#B2B2B2` · 500 `#9A9A9A` · 600 `#828282` · 700 `#6C6C6C` · 750 `#616161` · 800 `#565656` · 900 `#414141` · 1000 `#2C2C2C` · 1050 `#1E1E1E` · 1100 `#191919` · 1200 `#000000` |
| powderblue | 100 `#F2F2F8` |
| sand | 100 `#FFF9F6` · 200 `#F6EDE7` · 300 `#EBE1DB` |
| ink | 50 `#F2F2F2` · 100 `#F1F6FB` · 200 `#002245` |
| cardinal (reds) | 300 `#F8A19B` · 400 `#F67B78` · 600 `#DF2B40` · 650 `#D72D41` · 700 `#BF2436` · 800 `#971A29` · 900 `#74121D` · 997 `#FF4D35` · 998 `#E64530` · 999 `#CC3E2A` |
| persianred | 100 `#D32F2F` · 150 `#CA2B2B` · 200 `#EA3434` |
| chilli | 100 `#EA9588` · 200 `#E2523E` · 300 `#CB3100` |
| burgundy | 100 `#5D061F` · 200 `#400718` · 300 `#24030C` |
| forestgreen | 600 `#01B867` · 800 `#008E4E` · 900 `#016435` |
| kellygreen | 100 `#7DD27D` · 500 `#22BD05` · 600 `#50A530` · 800 `#178303` · 900 `#136803` · 950 `#0F5402` |
| aquagreen | 50 `#E7F6EE` · 100 `#46FFC6` · 300 `#00D593` · 350 `#00A874` · 375 `#00B981` · 800 `#045F1D` · 850 `#045319` · 1100 `#042110` |
| goldenyellow | 400 `#F8B400` · 700 `#B78400` · 750 `#B28100` |
| lightningyellow | 100 `#FBC02D` |
| brightblue | 500 `#2D90FD` · 600 `#0B72D0` · 650 `#1476CC` · 800 `#065196` |
| mariner | 100 `#1476CC` |
| blueberry | 100 `#E6ECF9` · 200 `#083EC4` · 300 `#062F93` · 400 `#041F62` |

Some families, such as aquagreen and the cardinal 997 to 999 steps, are group-wide primitives used by other NatWest Group brands. The NatWest brand block maps its semantic tokens onto regalpurple, mono, powderblue, cardinal, forestgreen, goldenyellow and brightblue.
