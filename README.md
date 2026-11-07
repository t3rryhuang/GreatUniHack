# NatWest Nova

A personal spending prediction app for 20-somethings. NatWest Nova connects to your bank data, pulls in external signals like weather and local events, and uses a council of LLMs to generate probabilistic daily spending forecasts, so you can see where your money's going before it's gone.

Built at **GreatUniHack 2026**, NatWest track: AI-powered financial inclusion and resilience.

Nova is a native iOS app built with SwiftUI (`Nova/`), backed by a Python multi-LLM API (`test-backend/`). The iOS app currently runs on mock data behind a service layer, so it can be connected to the backend without changing any screens. See [CHANGES.md](CHANGES.md) for everything that changed from the original Prophit app.

> Hackathon concept. Not an official NatWest product.

---

## Features

### Daily Predictions (Home)
- Weather-aware spending predictions for Manchester
- Probability bars for predicted spend categories (coffee, lunch, drinks, transport)
- Week-ahead calendar from multi-LLM consensus (Claude + Gemini + GPT-4o Mini), showing how many models agree
- Morning Briefing card with voice playback
- Spending alerts for unusual spikes and rising categories

### Long Horizon Insights
- Job quit runway: a ring showing how long your savings would last without income
- Seasonal spending comparison (winter, spring, summer, autumn)
- Monthly spend trajectory with a projection line
- Weekly recap with AI accuracy score (Pro)
- This week vs last week, and top spending categories

### Spending History & Patterns
- Week / Month / Year toggle (Month and Year are Pro)
- This week vs last week comparison bars
- Category breakdown donut chart (tap a slice for details)
- Unusual spike alerts with merchant details
- Searchable transaction list grouped by day

### Scenario Simulator
- "What if I quit my job?" runway slider
- What-if questions with suggestion chips: cut eating out by 50%, move somewhere cheaper, cycle to work, make coffee at home and more (1 free question, unlimited with Pro)
- AI-generated budget tips from your spending patterns

### Arena: Social Savings in Pounds
Create or join savings challenges with friends. Stakes are in pounds (£) and held in your NatWest savings account.

**Arena Modes:**
- **Budget Guardian:** stay under your spending target. The lowest spender under budget wins.
- **Vice Streak:** avoid your vice category (coffee, dining, drinks, shopping, entertainment). The last one standing wins.
- **Savings Sprint:** first to reach the savings target wins the pot. Can be settled early when someone crosses the line.

**Arena Flow:**
1. Create an arena: name, mode, target (or vice), stake per person and end date
2. Your stake moves from your Flexible Saver into the arena pot
3. Share the 6-digit join code with friends
4. Sync spending to update the standings
5. At the end date (or early for Savings Sprint), settle the arena: the winner's pot is paid into their savings account with a NatWest payment reference

### Morning Briefing
- Full-screen briefing with a time-of-day greeting, Manchester weather, expected spend, top prediction and a nudge
- Read aloud with the built-in iOS voice (Pro), with play/pause and an animated sound wave

### AI Chat: "Ask Nova"
- Conversational financial assistant that knows your spending summary
- Voice input and a read-aloud toggle
- Suggested questions and a 20-message conversation history

### Pro Tier
- Free tier with core predictions
- Pro at **£1.99/month** with a 7-day free trial
- Pro unlocks: full spending history, weekly recap, unlimited what-ifs, voice briefings, Ask Nova chat and creating arenas

### Onboarding
- Bank selection: NatWest, Royal Bank of Scotland, Ulster Bank, and other UK banks
- Upload a bank statement (JSON, CSV, PDF) or use 12 months of demo data
- Guided connect flow with progress steps

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
| Voice | AVSpeechSynthesizer (en-GB) |
| Local storage | JSON files in Application Support (mock layer) |

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
│   └── Nova/
│       ├── App/                   # NovaApp, RootView, AppModel (shared state)
│       ├── DesignSystem/          # Colours, spacing, type, buttons, cards
│       ├── Models/                # Transaction, FinancialSummary, Predictions, Arena, User
│       ├── Services/
│       │   ├── Protocols/         # One protocol per backend area. The UI only uses these
│       │   ├── Mock/              # Mock implementations used today
│       │   └── ServiceContainer.swift
│       ├── ViewModels/            # One @Observable view model per screen
│       ├── Views/                 # Home, Insights, History, Arena, Simulator, Profile,
│       │                          # Chat, Briefing, Onboarding, Auth, Upgrade, Transactions
│       └── Resources/             # Assets.xcassets (app icon, NatWest logo, accent colour)
├── test-backend/                  # FastAPI + Gradio backend
│   ├── main.py
│   ├── ui.py
│   ├── api/index.py               # Vercel entrypoint
│   └── requirements.txt
├── docs/                          # NatWest brand guide + Apple design guide
├── CHANGES.md                     # Everything that changed from the original app
└── README.md
```

---

## Getting Started

### iOS app

**Requirements:** a Mac with Xcode 27.2 or later and the iOS 27.2 Simulator runtime (Xcode → Settings → Components).

**Run in the Simulator (iPhone 15 Pro Max):**

1. Open the project:
   ```bash
   open Nova/Nova.xcodeproj
   ```
2. In the Xcode toolbar, pick the **Nova** scheme and the **iPhone 15 Pro Max** simulator.
   If it isn't listed: Window → Devices and Simulators → Simulators → **+**, then choose iPhone 15 Pro Max.
3. Press **⌘R**.

Or from the command line:
```bash
cd Nova
xcodebuild -project Nova.xcodeproj -scheme Nova \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max' build
```

**Run on a real iPhone 15 Pro Max:**

1. Connect the iPhone with a cable, unlock it and tap **Trust**.
2. On the iPhone, turn on **Developer Mode** (Settings → Privacy & Security → Developer Mode) and restart when asked.
3. In Xcode, select the **Nova** target → **Signing & Capabilities**, tick **Automatically manage signing** and choose your **Team** (a free Apple ID works; add it in Xcode → Settings → Accounts). If the bundle ID `com.natwest.nova` is taken, change it to something unique, such as `com.yourname.nova`.
4. Choose your iPhone as the run destination and press **⌘R**.
5. If the iPhone says the developer is untrusted: Settings → General → VPN & Device Management → your Apple ID → **Trust**.

**Using the demo:**

- Sign in with any email and a password of 6 or more characters.
- Pick a bank and tap **Use demo data** (12 months of Manchester spending), or upload a JSON, CSV or PDF statement.
- To try Pro, tap **Start free trial** and use the test card `4242 4242 4242 4242` with any future expiry and CVC. `4000 0000 0000 0002` shows a declined card.
- Join an arena with the demo codes `246810` or `135790`.
- Profile is the avatar button at the top right of every tab.

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

The iOS app talks only to the protocols in `Nova/Nova/Services/Protocols/ServiceProtocols.swift`. Today each one has a mock implementation in `Services/Mock/`.

| Protocol | Covers | Backend endpoint |
|---|---|---|
| `TransactionServicing` | Load, import (JSON/CSV/PDF), add, delete, clear | `/analyse_uploaded` (file parsing) |
| `InsightsServicing` | Week-ahead predictions, briefing, alerts, recap, runway, tips, what-ifs | `/calendar_uploaded`, `/get_runway`, `/_runway_summary_from_file`, `/get_tips` |
| `ChatServicing` | Ask Nova replies | Chat LLM (to add) |
| `VoiceServicing` | Read aloud, voice input | iOS voice today; speech-to-text to add |
| `AuthServicing` | Sign in, sign up, sign out | Auth provider (to add) |
| `ArenaServicing` | Create, join, sync, settle arenas | Arena API (to add) |
| `SavingsServicing` | Savings account for stakes and prize pots | NatWest account API (to add) |
| `SubscriptionServicing` | Free / Pro plan and trial | Payments (to add) |

To connect, write a class that conforms to a protocol (for example `APIInsightsService` calling `/calendar_uploaded`), add it to a `ServiceContainer`, and pass that container in `NovaApp.swift` instead of `.mock()`. No views or view models need to change.

---

## Backend API

Production base URL: `https://your-project.vercel.app`

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
5. The prize pot is paid into the winner's savings account, and the results screen shows the payment reference

---

## Environment Variables

| Variable | Where | Purpose |
|---|---|---|
| `ANTHROPIC_API_KEY` | `test-backend/.env` | Claude API |
| `GEMINI_API_KEY` | `test-backend/.env` | Gemini API |
| `OPENAI_API_KEY` | `test-backend/.env` | OpenAI API |
| `USER_LAT`, `USER_LON`, `USER_COUNTRY`, `USER_SUBDIVISION` | `test-backend/.env` | Location for weather and holidays (optional) |

The iOS app needs no environment variables while it uses mock data.

Never commit `.env` files. They are in `.gitignore`.
