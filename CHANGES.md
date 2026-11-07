# Changes from the original Prophit app

The original was a React Native / Expo app built for another bank's hackathon track. Nova is a new native iOS app in SwiftUI with the same features, rebranded for NatWest.

## 1. Platform and architecture

| Original (Prophit) | New (Nova) |
|---|---|
| React Native + Expo SDK 54, TypeScript | SwiftUI, Swift 6, Xcode 27.2 |
| iOS, Android and web | iOS only (iPhone), iOS 17.2 and later |
| Expo Router file-based navigation | `TabView` + `NavigationStack` |
| React contexts (Arena, UserData, Pro, Solana) | One `@Observable` `AppModel` plus one view model per screen (MVVM) |
| Services call APIs directly | Protocol-based service layer with mock implementations (`Services/Protocols`, `Services/Mock`) |
| react-native-chart-kit + react-native-svg | Swift Charts |
| AsyncStorage | JSON files in Application Support (mock layer only) |
| React Native app in `frontend/` | Removed from the repo (still in git history). Replaced by the SwiftUI app in `Nova/`. The Python backend in `test-backend/` is kept |

## 2. Renamed

| Original | New |
|---|---|
| App name "Prophit" | **Nova** (display name, Xcode project, target, scheme and all in-app text) |
| "The Prophit" chat assistant | **Ask Nova** |
| "Talk to Prophit" card | **Ask Nova** card |
| `TalkToProphit` component | `TalkToNovaCard` |
| `prophit-ashy.vercel.app`, `@prophit_*` storage keys | Removed. Mock services and `nova.*` keys |
| "Prophit v1.0.0" footer | "Nova 1.0.0" with the NatWest logo |
| Bundle ID (Expo default) | `com.natwest.nova` |

## 3. Previous bank branding removed

| Previous branding | What happened |
|---|---|
| Previous hackathon and bank track (README) | Removed |
| Design system inspired by the previous bank (README) | Replaced by the NatWest brand guide plus Apple's design guide |
| Previous bank colours: Hot Coral `#FF4F40`, Deep Navy `#112231`, Soft White `#F2F8F3`, Deep Teal `#004E60`, Neon Yellow `#C3FF34`, Mid Orange `#FE8B18` | Removed. Replaced with NatWest colour tokens (see section 4) |
| Previous bank as an option in the bank list | Removed (see "Banks" below) |
| 24pt+ corners everywhere | NatWest radii: pill buttons, 16pt panels, 8pt controls |

A search of the repository finds no mention of the previous bank. The original code had no "pots" logic; the closest idea was the Solana wallet holding arena stakes, which now maps to a NatWest savings account (see section 5).

## 4. NatWest items added

- **Logo and symbol:** the NatWest logo (`Images/NatWest-Logo-496x330.png`, trimmed) and the NatWest symbol (`Images/og-logo-nw.png`) are in the asset catalog. The symbol is the app icon and appears on the launch, sign-in, onboarding, briefing and bank screens. The full logo is in the Profile footer. In Dark Mode the logo switches to the symbol with a white wordmark, so it stays readable.
- **Colours (from `docs/natwest-brand-guide.md`):**
  - Action: bright purple `#5E10B1` (Dark Mode `#BE99E6`)
  - Headings and hero bands: champion purple `#5A287D`, regal purple `#3C1053`
  - Tints: lilac `#F2EAF9`, ground grey `#F2F2F8`
  - Feedback: success `#008E4E`, error `#DF2B40`, warning, info `#0B72D0`
  - Charts: the NatWest data-visualisation ramps (aubergine, blueberry, broccoli, watermelon, tangerine, yolk)
  - Dark Mode values from section 3 of the brand guide
- **Components:** pill primary and secondary buttons, white inverse button on purple bands, notification boxes with an 8pt status-coloured left bar, 48pt inputs with 8pt corners, and progress bars with a purple fill on a lilac track.
- **Banks:** NatWest, Royal Bank of Scotland and Ulster Bank (marked "NatWest Group"), plus Barclays, Lloyds, HSBC UK and Santander UK. NatWest is selected by default. This replaces the original list of Irish and fintech banks.
- **Savings account:** a "Flexible Saver" account (sort code and masked account number, balance, interest rate and activity) replaces the Solana wallet.
- **Design docs:** `docs/natwest-brand-guide.md` and `docs/DESIGN-apple.md` are included in the repo.

## 5. Features adapted

| Feature | Original | Nova |
|---|---|---|
| Location | Irish city | Manchester, UK |
| Currency | Non-sterling | Pound sterling (£) everywhere, `en_GB` formatting |
| Demo data | 100 Irish datasets (Irish supermarkets, trams and cafés) | A year of Manchester data (Pret, Grindsmith, Tesco, Sainsbury's, Metrolink, Bee Network buses, Mowgli, Octopus Energy, United Utilities, council tax…) with UK salary and rent |
| Categorising transactions | Irish merchants | UK merchants (Metrolink, Bee Network, Pret, Sainsbury's, Deliveroo…) |
| Arena stakes | Real SOL on the Solana devnet: per-user keypairs, 0.15 SOL airdrop, PDA escrow, Explorer links | **Pounds held in the NatWest savings account.** Joining moves the stake out of the Flexible Saver; the winner's pot is paid back in with a NatWest transfer reference |
| Arena results | Solana transaction signature | Payment reference and settlement time |
| Pro tier | 1.99/month via Stripe | **£1.99/month**, 7-day free trial, mock card form behind `SubscriptionServicing` |
| Text to speech | ElevenLabs (Rachel voice) | Built-in iOS voice (`AVSpeechSynthesizer`, en-GB) behind `VoiceServicing` |
| Voice input | Groq Whisper | Mock transcription behind `VoiceServicing`, ready for the backend |
| Chat | Groq Llama 3.3 70B | Mock replies from your real summary behind `ChatServicing`. Keeps the 20-message history limit |
| Predictions, runway, tips | Vercel FastAPI backend (Claude, Gemini, GPT consensus) | Computed on-device by `MockInsightsService` from your transactions. Shows "N of 3 models agree" like the original |
| Simulator what-ifs | Irish examples (suburb rents, tram pass) | Manchester examples (Stretford, Eccles and Levenshulme rents, Metrolink and Bee Network fares, Cycle to Work scheme) |
| Auth and realtime | Supabase | Mock auth behind `AuthServicing`; arenas behind `ArenaServicing` |
| Profile tab | Sixth tab | Avatar button at the top right of every tab. iOS shows at most 5 tabs before adding a "More" tab |

## 6. Features kept (all present in Nova)

- **Home:** expected spend today, Manchester weather and its effect on spending, morning briefing card with Listen/Pause and sound wave, today's predictions with probability bars, week-ahead calendar, spending alerts, Ask Nova entry, add transaction.
- **Insights:** job quit runway ring (savings, monthly spending, savings rate), seasonal spending bars, monthly spending trajectory with a dashed projection, weekly recap with accuracy ring (Pro), this week vs last week, top spending.
- **History:** Week / Month / Year toggle (Month and Year are Pro), total spent, this week vs last week, category donut you can tap, unusual spike alerts, searchable transaction list grouped by day, delete manual entries.
- **Simulator:** "What if I quit my job?" runway slider, what-if questions with suggestion chips (1 free question, unlimited with Pro), expandable scenario cards with before/after and confidence, AI budget tips.
- **Arena:** Budget Guardian, Vice Streak and Savings Sprint modes; create (name, mode, target or vice, stake, end date); join with a 6-digit code and preview; detail with standings, at-risk and eliminated states, invite code and share sheet; sync spending; settle and pay the winner; results screen; first-visit explainer. Winner and tie-break rules are ported exactly from `arenaSettlementService.ts`.
- **Morning briefing:** full-screen briefing with greeting, weather, expected spend, top prediction, nudge, and voice playback.
- **Ask Nova chat:** text and voice input, read-aloud toggle, typing indicator, suggested questions.
- **Onboarding:** welcome, bank choice, upload a statement (JSON, CSV, PDF) or use demo data, connecting progress steps.
- **Login:** sign in and create account.
- **Upgrade:** Free vs Pro comparison and card payment step. Locked-feature sheet for Pro features.
- **Add transaction:** import a file (merged with existing data) or log an expense by hand with automatic categorising.
- **Profile:** plan badge, stats, savings account details, account info, import data, clear all data, cancel Pro, sign out.

## 7. New in Nova

- Full **Dark Mode** using NatWest's dark tokens.
- **Dynamic Type** on every screen.
- **VoiceOver** labels for charts, rings, calendar days and custom controls. **Reduce Motion** is respected.
- Pull to refresh on Home, Insights, Arena and arena detail.
- Search in History.
- Share sheet for arena invite codes.
