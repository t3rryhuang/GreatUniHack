# NatWest Nova

A personal spending prediction app for 20-somethings. NatWest Nova connects to your bank data, pulls in external signals like weather and local events, and uses a council of LLMs to generate probabilistic daily spending forecasts, so you can see where your money's going before it's gone.

Built at **GreatUniHack 2026**, NatWest track: AI-powered financial inclusion and resilience.

Nova is a native iOS app built with SwiftUI (`Nova/`), backed by a Python multi-LLM API (`test-backend/`) on Vercel. By default the app uses the backend for arenas, AI insights, chat and voice, and keeps everything else on the phone. Launch it with `-NovaOffline` to run fully on-device. See [CHANGES.md](CHANGES.md) for everything that changed from the original Prophit app.

**Money Readiness** turns Nova into a path from 16 to a first real credit product: one character and one 0-1000 **Readiness Score**, plus a **Teen mode** for 16 and 17-year-olds with a money game, a shake-to-hear Piggy Bank and family loans. Under-16s are out of scope (that's NatWest's Rooster Money, a partnership idea only).

> Hackathon concept. Not an official NatWest product.

---

## Features

### Money Readiness (everyone)
- **Readiness Score (0-1000)** from five stats, each 0-200 and each mirroring a real-world credit factor: **Reliability** (payment history), **Balance** (utilisation), **Endurance** (length of history), **Resilience** (affordability) and **Wisdom** (restraint and money skills). Ranks: Bronze, Silver, Gold, Platinum, Diamond. *This is a readiness score, not a credit score*: it's never shared with credit reference agencies and doesn't create or change a credit file.
- **Character** drawn with SF Symbols that changes pose and badge with your rank, a score ring, stat bars with their real-world equivalent (tap one to see how to raise it), a 30-day chart and rank perks.
- **Daily quest** from today's predictions ("Spend under £8 on transport today"), checked at the end of the day. Quests build a **streak**, and one **shield** a month covers a missed day ("Your shield saved your 21-day streak").
- **Weekly boss:** the next bill due in the next 7 days. Pay it on time to defeat it.
- Cards on Home and at the top of Profile.

### Teen mode (16-17)
Chosen from the date of birth at sign-up (optional; under-16s can't pick a date). On the 18th birthday the app moves to the full version with a one-off welcome; the score, streak and history carry over.
- **Money Quest:** a game hub with 10 UK chapters of 2-3 minute levels (life events + quick questions, an explanation after every answer, unlimited retries, no timers). Everyone gets the same virtual £300 budget. Points are capped per day, chapter badges, and up to 3 new levels a day raise Wisdom. "Ask Nova about this" opens the teen chat with the topic filled in.
- **Piggy Bank:** a savings pot with a goal suggested from your own income. **Shake the phone** to hear coins: the sound, haptics and animation grow with progress to *your* goal, never the £ amount. Add money from £1, a weekly **promise to myself**, an example matched bonus for reaching your goal, and "hide amount until I tap" (on by default).
- **Family:** borrow from or share bills with any trusted adult (parent, carer, grandparent, key worker), from £1. The adult approves in the demo after a short delay. Every on-time payment raises Reliability, whatever the size.
- **Borrowing sandbox** in the Simulator: "Borrow £200, repay over 3 months" with an example APR, the monthly cost and what one missed payment would do.
- **Road to 18:** a countdown, a checklist (register to vote, bill streak, a month's buffer, the sandbox) and a one-page **Readiness Report** PDF you can share only after a consent switch.
- **What your parent sees:** weekly totals, loan and bill progress, Piggy Bank % and safety alerts. Never individual transactions.
- **Leagues** with friends and school, ranked by points and improvement only.
- **Arenas** without money: Most Improved, Budget Guardian and Savings Sprint against your own baseline or target, with standings in % and ranks only.
- **Ask Nova** never recommends credit products to teens and keeps answers short.

### Daily Predictions (Home)
- Weather-aware spending predictions for Manchester
- Probability bars for predicted spend categories (coffee, lunch, drinks, transport)
- Week-ahead calendar from multi-LLM consensus (Claude + Gemini + GPT-4o Mini), showing how many models agree
- Morning Briefing card with voice playback
- Spending alerts for unusual spikes and rising categories

### Long Horizon Insights
- Job quit runway: a ring showing how long your savings would last without income
- Seasonal spending comparison in pastel bars (winter, spring, summer, autumn), with your priciest season and the current one
- Monthly spend trajectory with a projection line
- Weekly recap with an accuracy ring and predicted vs actual, in soft pastels
- This week vs last week, and top spending categories

### Spending History & Patterns
- Week / Month / Year toggle
- This week vs last week comparison bars
- Category breakdown donut chart (tap a slice for details)
- Unusual spike alerts with merchant details
- Searchable transaction list grouped by day

### Scenario Simulator
- "What if I quit my job?" runway slider
- What-if questions with suggestion chips: cut eating out by 50%, move somewhere cheaper, cycle to work, make coffee at home and more
- AI-generated budget tips from your spending patterns

### Arena: Social Savings in Pounds
Create or join savings challenges with friends. Stakes are in pounds (£) and held in your NatWest savings account.

**Arena Modes:**
- **Budget Guardian:** stay under your spending target. The lowest spender under budget wins.
- **Vice Streak:** avoid your vice category (coffee, dining, drinks, shopping, entertainment). The last one standing wins.
- **Savings Sprint:** first to reach the savings target wins the pot. Can be settled early when someone crosses the line.
- **Most Improved:** the biggest % cut in spending compared with your own previous period of the same length wins, so everyone starts level.

Stakes are optional: with £0 nobody's money moves and the winner earns points and a badge. Teen arenas never use money.

**Arena Flow:**
1. Create an arena: name, mode, target (or vice), stake per person and end date
2. Your stake moves from your Flexible Saver into the arena pot
3. Share the 6-digit join code with friends
4. Sync spending to update the standings
5. At the end date (or early for Savings Sprint), settle the arena: the winner's pot is paid into their savings account with a NatWest payment reference

### Morning Briefing
- Full-screen briefing with a time-of-day greeting, Manchester weather, expected spend, top prediction and a nudge
- Read aloud (ElevenLabs voice, iOS voice as fallback), with play/pause and an animated sound wave

### AI Chat: "Ask Nova"
- Conversational financial assistant that knows your spending summary
- Voice input and a read-aloud toggle
- Suggested questions and a 20-message conversation history

### Everything free
- All features are unlocked for everyone: there's no paywall or free trial. The Pro code is kept (`AppModel.allFeaturesUnlocked`) so a paid plan could be switched back on later.

### Onboarding
- Optional date of birth: 16 and 17-year-olds start in Teen mode
- Bank selection: NatWest, Royal Bank of Scotland, Ulster Bank, and other UK banks
- Upload a bank statement (JSON, CSV, PDF) or use 12 months of demo data
- Guided connect flow with progress steps

---

## Fairness principles

The score and the teen features are built so habits count and money doesn't:

1. **F1, relative not absolute.** Limits, targets and resilience compare you with your own spending, income and goals.
2. **F2, size doesn't matter.** A £1 bill, loan instalment or deposit counts exactly as much as a £100 one: Reliability is an on-time rate.
3. **F3, no points for wealth or borrowing.** A bigger balance on its own, or borrowing more, never raises the score. Teens' Resilience is "weeks of your own essentials covered" (2 weeks = full marks).
4. **F4, same game, same budget.** Money Quest gives everyone the same virtual budget, and right answers never depend on having money.
5. **F5, private by default.** Leagues and teen arenas show points, % and ranks, never £. Parents see totals and %, not transactions.
6. **F6, behaviour unlocks rewards.** Rank perks depend on rank (habits). The matched-savings bonus is fixed and the same for everyone (an example for the pitch, not a real offer).
7. **F7, everyone can take part.** Any trusted adult can lend or share a bill; teens with nobody to borrow from can use a promise-to-myself transfer instead. Daily caps stop points being about free time.
8. **F8, hardship protection.** If income drops by more than 30% month on month, goals are eased and the weekly limit follows the last 4 weeks, with a kind message.

The DEBUG-only **Fairness check** (Profile > Demo) scores Teen A (about £15 a week pocket money) and Teen B (about £100 a week from a job) with the same habits side by side, plus Teen B with poor habits. Current result: **Teen A 648, Teen B 648, both Gold; Teen B with poor habits 389, Silver.**

---

## Tech Stack

### iOS app (`Nova/`)
| Layer | Technology |
|---|---|
| UI | SwiftUI, Swift 6 |
| Tooling | Xcode 27.2 |
| Minimum iOS | 17.2 |
| Architecture | MVVM: `@Observable` view models + protocol-based service layer |
| Charts | Swift Charts |
| Voice | ElevenLabs via the backend, AVSpeechSynthesizer (en-GB) as fallback |
| Piggy Bank | AVAudioEngine (coin sounds synthesised in code), UIKit haptics, shake detection |
| Report | ImageRenderer to PDF, ShareLink |
| Local storage | JSON files in Application Support (on-device services) |

### Backend (`test-backend/`)
| Layer | Technology |
|---|---|
| Runtime | Python (FastAPI + Gradio) |
| LLMs | Claude Haiku 4.5, Gemini 2.5 Flash Lite, GPT-4o Mini |
| Deployment | Vercel |
| Context | Open-Meteo weather + UK public holidays |

### AI models
| Service | Model | Used for |
|---|---|---|
| Anthropic | Claude Haiku 4.5 | Transaction analysis, consensus synthesis |
| Google | Gemini 2.5 Flash Lite | Parallel transaction analysis |
| OpenAI | GPT-4o Mini | Spending pattern detection |

### Design System
Nova follows two guides together, both in [`docs/`](docs):

- **[natwest-brand-guide.md](docs/natwest-brand-guide.md)** for colour, logo and brand tone
- **[DESIGN-apple.md](docs/DESIGN-apple.md)** for layout and interaction

| Token | Value |
|---|---|
| Action (buttons, links, selected) | Bright purple `#5E10B1` (Dark Mode `#BE99E6`) |
| Headings / hero bands | Champion purple `#5A287D`, regal purple `#3C1053` |
| Tint | Lilac `#F2EAF9` |
| Page background | Ground grey `#F2F2F8` (Dark Mode `#121212`) |
| Feedback | Success `#008E4E`, error `#DF2B40`, info `#0B72D0` |
| Charts | NatWest data-visualisation palette |
| Buttons | Pills that shrink to 95% when pressed |
| Cards | Flat, 1pt hairline, 16pt corners, no shadows |
| Font | SF Pro via Dynamic Type (NatWest's licensed fonts aren't bundled) |

The app supports Light and Dark Mode, Dynamic Type, VoiceOver and Reduce Motion. The app icon and in-app logo use the NatWest assets.

---

## Project Structure

```
GreatUniHack/
├── Nova/                          # Native iOS app (SwiftUI)
│   ├── Nova.xcodeproj
│   ├── scripts/make_money_quest.py  # Writes Resources/MoneyQuest/chapters.json
│   └── Nova/
│       ├── App/                   # NovaApp, RootView, AppModel (shared state), DEBUG screen launcher
│       ├── DesignSystem/          # Colours (incl. pastels), spacing, type, buttons, cards
│       ├── Models/                # Transaction, Arena, Readiness (+ ReadinessRules), Family,
│       │                          # MoneyQuest, PiggyBank, League, LifeStage, DemoProfile
│       ├── Services/
│       │   ├── Protocols/         # One protocol per area. The UI only uses these
│       │   ├── Remote/            # Backend implementations (arenas, insights, chat, voice)
│       │   ├── Mock/              # On-device implementations and demo data
│       │   └── ServiceContainer.swift  # .live(baseURL:) and .mock()
│       ├── ViewModels/            # One @Observable view model per screen
│       ├── Views/                 # Home, Insights, History, Arena, Simulator, Profile, Readiness,
│       │                          # Family, Parent, Graduation, MoneyQuest, PiggyBank, Demo, ...
│       └── Resources/             # Assets.xcassets, MoneyQuest/chapters.json
├── test-backend/                  # FastAPI + Gradio backend
│   ├── main.py                    # App, Gradio UI, original endpoints
│   ├── nova_api.py                # /nova JSON API for the iOS app
│   ├── arena.py                   # /arenas API (Upstash Redis)
│   ├── llm.py                     # LLM calls (Runware or native keys)
│   ├── tests/                     # pytest
│   ├── api/index.py               # Vercel entrypoint
│   └── requirements.txt
├── docs/                          # NatWest brand guide + Apple design guide
├── CHANGES.md                     # Everything that changed
└── README.md
```

---

## Getting Started

### iOS app

**Requirements:** a Mac with Xcode 27.2 or later and the iOS 27.2 Simulator runtime (Xcode → Settings → Components).

**Run in the Simulator (iPhone 15 Pro Max or iPhone 17 Pro Max):**

1. Open the project:
   ```bash
   open Nova/Nova.xcodeproj
   ```
2. In the Xcode toolbar, pick the **Nova** scheme and the **iPhone 15 Pro Max** or **iPhone 17 Pro Max** simulator.
   If it isn't listed: Window → Devices and Simulators → Simulators → **+**, then choose iPhone 15 Pro Max or iPhone 17 Pro Max.
3. Press **⌘R**.

Or from the command line:
```bash
cd Nova
xcodebuild -project Nova.xcodeproj -scheme Nova \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max' build
# or: -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

**Run on a real iPhone 15 Pro Max or iPhone 17 Pro Max:**

1. Connect the iPhone with a cable, unlock it and tap **Trust**.
2. On the iPhone, turn on **Developer Mode** (Settings → Privacy & Security → Developer Mode) and restart when asked.
3. In Xcode, select the **Nova** target → **Signing & Capabilities**, tick **Automatically manage signing** and choose your **Team** (a free Apple ID works; add it in Xcode → Settings → Accounts). If the bundle ID `com.natwest.nova` is taken, change it to something unique, such as `com.yourname.nova`.
4. Choose your iPhone as the run destination and press **⌘R**.
5. If the iPhone says the developer is untrusted: Settings → General → VPN & Device Management → your Apple ID → **Trust**.

**Using the demo:**

- Sign in with any email and a password of 6 or more characters. Add a date of birth to start in Teen mode, or skip it.
- Pick a bank and tap **Use demo data**, or upload a JSON, CSV or PDF statement.
- **Profile > Demo** switches between **Adult**, **Teen A** and **Teen B** (same habits, different money) and has **Complete today's quest**, **Simulate 18th birthday** (Teen mode) and the DEBUG **Fairness check**.
- Join an arena with the demo codes `246810` or `135790` (adult, with stakes) or `112233` (teen, no money).
- **Shake** the Piggy Bank: in the Simulator use **Device > Shake** (or tap the Shake button).
- Profile is the avatar button at the top right of every tab.

**Launch arguments** (Xcode > Product > Scheme > Edit Scheme > Arguments):

| Argument | What it does |
|---|---|
| `-NovaOffline` | Everything on-device (no backend) |
| `-NovaDemo` | Skip sign-in as Alex (adult) with demo data |
| `-NovaTeenDemo` | Start as Jamie, 17 (Teen B) |
| `-NovaTeenADemo` | Start as Riley, 16 (Teen A) |
| `-NovaBackendURL http://localhost:8000` | Use a local backend |
| `-NovaScreen <name>` | DEBUG: open a screen at launch: `readiness`, `family`, `parent`, `graduation`, `report`, `quest`, `level`, `piggy`, `league`, `fairness`, `seasons`, `insights`, `arena`, `simulator`, `chat`, `profile` |
| `-NovaAutoplay` / `-NovaAutoShake` | DEBUG: play a Money Quest level / shake the Piggy Bank automatically |

**2-minute demo:** launch with `-NovaTeenDemo` → Home shows Jamie's Readiness Score, daily quest, weekly boss, Money Quest and Piggy Bank → open the Piggy Bank and shake → play chapter 7 level 1 (money mules) → Profile > Demo > Fairness check (Teen A and Teen B both 648) → Road to 18 and the Readiness Report → Profile > Demo > Simulate 18th birthday.

### Backend Setup (local dev only)

```bash
cd test-backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements-dev.txt
```

Create a `.env` file in `test-backend/`:
```env
ANTHROPIC_API_KEY=your_anthropic_key
GEMINI_API_KEY=your_gemini_key
OPENAI_API_KEY=your_openai_key
```

Run the Gradio UI:
```bash
python ui.py
```

Or run the FastAPI server:
```bash
uvicorn main:app --reload --port 8001
```

### Deploying the backend to Vercel

The backend in `test-backend/` is ready for Vercel (`api/index.py` entrypoint + `vercel.json`).

1. Import the repo in Vercel and set **Root Directory** to `test-backend`.
2. Add environment variables: `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `OPENAI_API_KEY` (optional: `USER_COUNTRY`, `USER_SUBDIVISION`, `USER_LAT`, `USER_LON`; `.env.example` uses Manchester).
3. Deploy, then point the iOS app's service layer at the deployment URL (see below).

Alternatively, without the GitHub integration: `cd test-backend && npx vercel --prod`.

`requirements.txt` holds only what the API needs; Gradio and pytest live in `requirements-dev.txt` (`pip install -r requirements-dev.txt` for local UI/tests).

---

## Connecting the iOS app to the backend

The iOS app talks only to the protocols in `Nova/Nova/Services/Protocols/ServiceProtocols.swift`. `ServiceContainer.live(baseURL:)` is used by default and `.mock()` with `-NovaOffline`.

| Protocol | Covers | Live | Offline |
|---|---|---|---|
| `InsightsServicing` | Week-ahead, briefing, alerts, recap, runway, tips, what-ifs, weather | `RemoteInsightsService` (`/nova/*`, falls back on-device) | `MockInsightsService` |
| `ChatServicing` | Ask Nova (adult or teen stage) | `RemoteChatService` (`/nova/chat`) | `MockChatService` |
| `VoiceServicing` | Read aloud, voice input | `ElevenLabsVoiceService` (`/nova/tts`, `/nova/transcribe`) | `SystemVoiceService` |
| `ArenaServicing` | Create, join, sync, settle arenas | `RemoteArenaService` (`/arenas`) | `MockArenaService` |
| `AuthServicing`, `TransactionServicing`, `SavingsServicing`, `SubscriptionServicing` | Session, transactions, savings account and Piggy Bank, plan | On-device | On-device |
| `ReadinessServicing` | Readiness Score, quests, streak, shields, Wisdom | `LocalReadinessService` | same |
| `FamilyServicing` | Family loans and shared bills | `LocalFamilyService` | same |
| `GameServicing` | Money Quest points, badges, levels | `LocalGameService` | same |
| `LeagueServicing` | Friend and school leagues | `LocalLeagueService` (demo data) | same |

---

## Backend API

Production base URL: `https://nova-backend-silk.vercel.app`

### Nova JSON API (used by the iOS app)

| Endpoint | Purpose |
|---|---|
| `POST /nova/chat` | Ask Nova. Optional `stage`: `"teen"` or `"adult"` (default). Teen replies never recommend credit products |
| `POST /nova/tts`, `POST /nova/transcribe` | ElevenLabs read-aloud and speech-to-text |
| `POST /nova/week-ahead`, `/nova/budget-tips`, `/nova/runway`, `/nova/what-if`, `GET /nova/weather` | AI insights and live weather |
| `GET/POST /arenas`, `GET /arenas/code/{code}`, `POST /arenas/join`, `GET /arenas/{id}`, `POST /arenas/{id}/sync`, `POST /arenas/{id}/settle` | Shared arenas. Modes include `most_improved`; `teen: true` arenas use each member's `baselineSpend` / `personalTarget` |

### Gradio API (original endpoints)

All endpoints follow the Gradio async pattern:

```typescript
// Step 1: Submit
const { event_id } = await fetch('/gradio_api/call/{endpoint}', {
  method: 'POST',
  body: JSON.stringify({ data: [...args] }),
}).then(r => r.json());

// Step 2: Poll for result (SSE stream)
const text = await fetch(`/gradio_api/call/{endpoint}/${event_id}`).then(r => r.text());
const result = JSON.parse(text.split('\n').find(l => l.startsWith('data: ')).slice(6));
```

### Endpoints

| Endpoint | Input | Output | Used for |
|---|---|---|---|
| `/analyse_uploaded` | Transaction file (JSON/CSV/PDF/TXT) | 3× markdown analyses (Claude, Gemini, OpenAI) | Insights, History screens |
| `/calendar_uploaded` | Transaction file | Week-ahead calendar markdown + JSON predictions | Home screen predictions |
| `/get_tips` | Spending pattern text | AI budget tips (markdown) | Simulator, Chat |
| `/get_runway` | Financial summary text | Income runway analysis (markdown) | Insights runway ring |
| `/_runway_summary_from_file` | Transaction file | Financial summary text | Feed into `/get_runway` |

### Calendar JSON shape

```json
{
  "week_start": "2026-03-01",
  "daily_predictions": [
    {
      "date": "2026-03-02",
      "day": "Monday",
      "predictions": [
        {
          "behavior": "Coffee",
          "likelihood": 83,
          "avg_spend": 5.50,
          "agreed_by": ["claude", "openai"]
        }
      ]
    }
  ]
}
```

This maps to the iOS `DayPrediction` / `PredictionItem` models (`likelihood` → `probability`, `avg_spend` → `amount`, `agreed_by` → `agreedBy`).

---

## How the Multi-LLM Engine Works

1. **File parsing:** transactions enriched with `day_of_week`
2. **Parallel analysis:** Claude, Gemini and GPT-4o Mini each analyse the full history at the same time
3. **Pattern detection:** each model finds recurring spending behaviours by day and category
4. **Consensus calendar:** Claude combines all three outputs into a single week-ahead calendar
5. **Deduplication:** duplicate merchants merged, most accurate predictions surfaced

---

## How the Arena Settlement Works

1. The creator sets the mode, target, stake in pounds and end date
2. Each member's stake moves from their NatWest savings account into the arena pot when they create or join
3. During the arena, members sync their spending to update the standings
4. At the end date (or early for Savings Sprint), the arena is settled:
   - **Budget Guardian:** the member with the lowest spend under target wins; if everyone went over, the last to go over wins
   - **Vice Streak:** members who avoided their vice win over those who didn't; among those who slipped, the last to slip wins
   - **Savings Sprint:** the first member to reach the target wins; if nobody did, the highest saver wins
   - **Most Improved:** the biggest % cut versus your own previous period of the same length wins; ties go to the lower current spend, then name
5. The prize pot is paid into the winner's savings account, and the results screen shows the payment reference. With a £0 stake nothing moves and the winner earns points and a badge.

**Teen arenas** (`teen: true`): Budget Guardian ranks by % under each member's own limit (their own previous spending), Savings Sprint by progress to each member's own target (10% of their own income over the arena), and ties are broken by name, never by £. The same rules are in `ArenaRules` (Swift, offline) and `arena.py` (backend).

---

## Environment Variables

| Variable | Where | Purpose |
|---|---|---|
| `RUNWARE_API_KEY` | `test-backend/.env` | One key for Claude, Gemini and GPT (preferred) |
| `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `OPENAI_API_KEY` | `test-backend/.env` | Native keys if Runware isn't set |
| `ELEVENLABS_API_KEY` (and optional `ELEVENLABS_VOICE_ID`) | `test-backend/.env` | Read-aloud and speech-to-text |
| `KV_REST_API_URL`, `KV_REST_API_TOKEN` | Vercel (Upstash integration) | Arena storage; without them arenas are kept in memory |
| `USER_LAT`, `USER_LON`, `USER_COUNTRY`, `USER_SUBDIVISION` | `test-backend/.env` | Location for weather and holidays (optional) |

The iOS app needs no environment variables.

### Backend tests

```bash
cd test-backend
uv venv --python 3.12 .venv   # or python3.12 -m venv .venv
uv pip install --python .venv/bin/python -r requirements-dev.txt
.venv/bin/python -m pytest -q
```

The arena and chat tests use in-memory storage and a stand-in for the LLM, so they need no keys or Redis.

Never commit `.env` files. They are in `.gitignore`.
