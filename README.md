# 🌐 CIRO+ (Crisis Intelligence & Response Orchestrator Plus)

CIRO+ is an enterprise-grade, next-generation emergency management and crisis response ecosystem designed to bridge multi-source real-world telemetry, automated AI-driven multi-agent cognitive reasoning, and human decision-making. 

From analyzing citizen calls in Roman Urdu to executing parallel strategy simulations and running live geofencing checks for family safety, CIRO+ delivers sub-second operational coordinates to first responders and emergency personnel via a unified **EOC Web Dashboard** and a high-fidelity **Flutter Mobile Client**.

---

## 🏗️ Architectural Overview & Data Flow

CIRO+ is engineered as a highly decoupled, four-tier reactive architecture that ensures absolute fault-tolerance, rapid ingestion processing, and auditability.

```mermaid
graph TD
    %% Ingestion Sources
    subgraph Data Ingestion [Hybrid Telemetry Ingest]
        RealAPI[Real APIs: OpenWeather, Reddit RSS, GDELT, TomTom Traffic, OpenAQ]
        MockAPI[Synthetic Fallback: 1122 Dispatch Telephony, Grid & River IoT Sensors, Fuel Feeds]
    end

    %% Backend Layer
    subgraph Backend [FastAPI Service Layer & DB]
        FastAPI[FastAPI Router Engine]
        DB[(PostgreSQL + PostGIS Database)]
        Session[SQLAlchemy ORM Session]
    end

    %% Intelligence Layer
    subgraph Intelligence [Gemini Cognitive Core]
        Orchestrator[Agent Orchestrator]
        AgentChain[14-Agent Sequential & Parallel Pipeline]
        auditLogs[(Agent Reasoning Trace DB Table)]
    end

    %% Client Layer
    subgraph Clients [Unified Interfaces]
        WebDash[Glassmorphic EOC Web Dashboard: static/index.html]
        Mobile[CrisisLink Flutter Companion: Riverpod + Glassmorphism]
    end

    %% Data Flow Vectors
    RealAPI -->|REST POST /signals| FastAPI
    MockAPI -->|REST POST /signals| FastAPI
    FastAPI --> Session
    Session --> DB
    FastAPI <-->|Run Chains / Slide Values| Orchestrator
    Orchestrator <--> AgentChain
    AgentChain -.->|Persist Reasoning Traces| auditLogs
    DB <--> FastAPI
    FastAPI <-->|REST APIs & SSE| WebDash
    FastAPI <-->|REST APIs & State Updates| Mobile
```

1. **Ingestion Layer:** Ingests live telemetry (JSON payloads) from real weather, traffic, news, and social feeds, or generates synthetic telemetry simulating municipal emergency channels.
2. **Intelligence Layer (Gemini-Powered):** Coordinated by a strict orchestrator, 14 specialized agents decompose the ingested signals, score credibility, verify facts, detect active crises, generate precautions, plan tasks, allocate physical assets, simulate outcomes, and compile human-readable alerts.
3. **Data Layer (Postgres + PostGIS):** Persists raw signals, active incidents, allocated resources, dynamic simulators, family safety parameters, and complete agent reasoning traces. Spatial coordinates are stored as PostGIS geometries to enable sub-millisecond geofencing.
4. **Client Layer:**
   - **EOC Web Dashboard:** A single-page dashboard featuring reactive incident trackers, radar graphs, and simulation consoles.
   - **CrisisLink Mobile Application:** A sleek, glassmorphism-styled iOS/Android app built using Flutter and Riverpod, providing citizens with live evacuation routes, family safety status updates, and a manual database ingestion sweep button.

---

## 🤖 The 14-Agent Intelligence Pipeline

The cognitive core of CIRO+ consists of **14 specialized agents** powered by the **Google Gemini API** (`gemini-2.5-flash`). The agents are executed in a sequential and parallel cognitive pipeline to ensure that no decision is made without rigorous multi-layered scrutiny.

To guarantee absolute operational transparency and regulatory compliance, **every single agent generates an explicit JSON-structured `reasoning` trace**, which is committed directly to the database.

| # | Agent Name | Operational Role | Inputs Ingested | Output Schema & Reasoning Actions |
| :--- | :--- | :--- | :--- | :--- |
| **1** | **Ingestion Agent** | Multilingual NLP Parser | Raw telemetry text, social feeds, citizen sms (Roman Urdu, English slang) | Detects event class, extracts geographic entities, normalizes/translates to English text, outputs coordinate estimates. |
| **2** | **Credibility Agent** | Trust & Source Evaluator | normalized text, origin source category (e.g. anonymous social, 1122 log) | Calculates source confidence (0.0-1.0), urgency level, contradiction risks, and duplicate report likelihood. |
| **3** | **Verification Agent** | Facts Cross-Checker | Current weather status, regional seasonal baseline, credibility scores | Outputs verification status (`verified`, `partially_verified`, `unverified`, `contradicted`) and recommends escalation. |
| **4** | **Detection Agent** | Classification Engine | Verified signal, extracted location, corroborating indicators | Defines primary crisis type (Flood, Protest, Fire, etc.), sets severity (`low` to `critical`), and flags potential cascade risks. |
| **5** | **Situation Analysis Agent** | Impact Contextualizer | Detected crisis parameters, geographic area type, severity | Estimates affected population count, calculates impact radius, lists infrastructure at risk, and constructs a root-cause hypothesis. |
| **6** | **Forecasting Agent** | Predictive Modeler | Current incident details, active evolving weather/traffic patterns | Projects crisis spread (km), duration (hours), peak time estimation, and probability of immediate escalation. |
| **7** | **Precaution Agent** | Safety Advisory Board | Forecast models, risk coordinates, audience type | Generates safety checklists categorized by audience (Residents, Commuters, Rescuers) and urgency levels. |
| **8** | **Action Planner Agent** | Tactical Coordinator | Current situation summaries, incident forecasts, and safety advisories | Synthesizes a primary action strategy (evacuation bounds, rerouting paths) and drafts alternate fallback plans. |
| **9** | **Resource Allocator Agent** | Asset dispatcher | Primary action plan, active depot list, ambulance/fire station coordinates | Dispatches specific units (boats, fire trucks, medical teams) from physical depots. Projects arrival ETAs and flags inventory shortfalls. |
| **10** | **Simulation Agent** | Before/After Outcomes Modeler | Planned actions, resource deployments, current impact radius | Predicts recovery outcomes, estimates traffic congestion relief, casualty reductions, and highlights unintended negative consequences. |
| **11** | **Impact Assessment Agent** | Cost-Benefit Assessor | Before/after simulation metrics, resource cost indexes | Evaluates overall response effectiveness, estimates operational cost in local currency (PKR), and calculates total lives protected. |
| **12** | **Trigger Recommendation Agent** | IF-THEN Rules Engine | Current crisis state, forecast parameters, simulation assessments | Builds automated system rules (e.g., *IF water level exceeds 2.5m THEN dispatch alert*) and adjusts system watch levels (Green to Red). |
| **13** | **Communication Agent** | Multilingual Broadcaster | Strategic plans, incident details, target audience profiles | Drafts character-constrained SMS alerts and push notifications in both English and Urdu (*انتباہ: جی-10 میں سیلاب۔ علاقے سے دور رہیں*). |
| **14** | **Audit / Trace Agent** | Pipeline Performance Auditor | Cumulative context of all preceding 13 agent runs | Formulates a structured trace log, rates overall pipeline confidence, flags cognitive bottlenecks, and suggests system enhancements. |

---

## 📊 Dual-Simulator Architectures

To help incident commanders explore response configurations and predict hazard containment, CIRO+ integrates a dual-simulator system:

### 1. Interactive Generic Simulator (`POST /actions/simulate-generic`)
This simulator runs dynamic, real-time scenarios directly from the Flutter application and EOC Web Interface. Users adjust interactive sliders to explore response strategies:
- **Resource Allocation (%)** — Adjusts rescue team sizes and logistics assets.
- **Road Closures (Count)** — Reroutes commuter routes and coordinates emergency corridors.
- **Medical Deployment (%)** — Scales on-site field clinics and ambulance dispatches.
- **Fuel Availability (%)** — Adjusts backup generators and emergency transport fuel levels.

Adjusting these values triggers the `SimulationAgent` and `ImpactAssessmentAgent` to compute a 4-axis performance vector returned as a structured model:
- **Congestion Reduction (%)**
- **Casualty Minimization**
- **Recovery Duration (Hours)**
- **Resource Utilization Load (%)**
- **AI Recommendation** — Synthesizes before/after reports and recommends actions.

### 2. Side-by-Side Parallel Strategy Simulator (`POST /actions/simulate/strategies`)
To evaluate alternative strategies during active incidents, the backend features a side-by-side simulator. When an active incident ID is passed, the engine uses a Python `ThreadPoolExecutor` to run three simulation threads in parallel:

```python
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
    f_agg = executor.submit(orchestrator.run_sequential, [SimulationAgent()], aggressive_input)
    f_bal = executor.submit(orchestrator.run_sequential, [SimulationAgent()], balanced_input)
    f_con = executor.submit(orchestrator.run_sequential, [SimulationAgent()], conservative_input)
```

- **Aggressive Strategy:** Mandatory evacuations, maximum resource mobilization, and high resource usage to achieve rapid recovery.
- **Balanced Strategy:** Reroutes traffic, deploys targeted rescue units, and optimizes speed-to-resource safety margins.
- **Conservative Strategy:** Preserves resources, issues public advisories, and monitors hazard boundaries.

---

## 👨‍👩‍👧 Family Safety & Geofencing (PostGIS Spatial Queries)

CIRO+ features an active geofencing and spatial safety tracking service powered by **PostgreSQL with the PostGIS extension**. 

```
[Incident: G-10 Flood] ─── Affected Radius (1,500 meters) ───┐
                                                            │
                                        [Family Member: Sarah]
                                        Location: Lat: 33.682, Lng: 73.045
                                        Spatial Check: ST_DWithin = TRUE -> AT RISK!
```

- **Geographic Data Binding:** Family members register their real-time coordinates, which are stored as a geographic point type in PostgreSQL: `location GEOMETRY(POINT, 4326)`.
- **Dynamic Safety Geofencing (`GET /tracking/status/{id}`):** When a status check is requested, the system performs a high-performance spatial join query using the **PostGIS `ST_DWithin`** function:
  ```sql
  SELECT EXISTS (
      SELECT 1 
      FROM incidents i
      WHERE ST_DWithin(
          family_member.location::geography, 
          i.geom::geography, 
          i.affected_radius_m
      ) AND i.status != 'resolved'
  );
  ```
  If a family member falls within the active radius of an incident, their safety status dynamically transitions to `AT RISK`, notifying family circles and displaying emergency warnings on the mobile app.

---

## 🔌 Hybrid Data Ingestion: Real vs. Mocked APIs

CIRO+ utilizes a hybrid ingestion engine to maintain a steady stream of data. The system automatically switches between live API calls and high-fidelity mock generators to support both field deployments and offline simulations.

### 1. Real-World Live API Integrations
- **Weather & Atmospheric Conditions:** Ingests live data from [OpenWeatherMap API](https://openweathermap.org/) and [WeatherAPI](https://www.weatherapi.com/) to monitor precipitation rates, wind speeds, temperature spikes, and pressure differentials.
- **Public Sentiment & News Signals:** Ingests data from [Reddit RSS Scraper](https://www.reddit.com/) and [GDELT Project API](https://www.gdeltproject.org/) (Global Database of Events, Language, and Tone) to scan public sentiment, news bulletins, and local citizen reports.
- **Traffic Routing & Congestion Index:** Queries [TomTom Traffic Flow API](https://developer.tomtom.com/) and [OpenRouteService](https://openrouteservice.org/) to retrieve traffic congestion ratios, road blockages, and bypass routes.
- **Air Quality & Pollution Levels:** Ingests real-time particulate indices and PM2.5 counts using [OpenAQ API](https://openaq.org/).

### 2. High-Fidelity Mock & Simulation Fallbacks
If API credentials are not configured or the network is offline, the backend uses simulated generators:
- **1122 Dispatch Telephony:** Generates synthetic emergency call logs, translating citizen descriptions into structured events.
- **IoT Environmental Sensors:** Simulates digital sensor readings, including river water heights and electrical grid failure points.
- **Economic Ingestion Feeds:** Simulates retail fuel indices (gasoline/diesel prices) and currency exchange variations to test resource cost estimates.

---

## 📱 CrisisLink Flutter Mobile Client

The mobile companion application is a high-fidelity client styled with premium glassmorphic aesthetics.

### 1. Premium Visual Aesthetics
- **Cohesive Dark HSL Palette:** Deep navy backgrounds (`0xFF0D1B2A`), translucent glass overlays (`0x1AFFFFFF` with a `25.0` image blur), emerald green accents (`0xFF2EC4B6`), warning amber highlights (`0xFFF5A623`), and thin neon borders.
- **Fluid Layouts:** Uses micro-animations, glassmorphic cards, custom radar canvases, and status badges.

### 2. Unified Riverpod State Architecture
State management is built on **Riverpod**, ensuring unidirectional data flows:
- `apiServiceProvider`: Manages the type-safe client connection to the FastAPI backend.
- `syncProgressProvider`: A global `StateProvider<bool>` tracking active network sweeps.
- `refreshTriggerProvider`: A reactive state notifier that triggers widget rebuilds when incidents update.

### 3. Decoupled Manual Parsing
To prevent compiler issues and runtime errors from changes to the backend schema, CIRO+ uses handwritten Dart parsing classes instead of reflection-based build generators:
```dart
factory Incident.fromJson(Map<String, dynamic> json) {
  return Incident(
    id: json['id'] as int? ?? 0,
    crisisType: json['crisis_type'] as String? ?? 'unknown',
    severity: json['severity'] as String? ?? 'low',
    locationText: json['location_text'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    affectedRadiusM: (json['affected_radius_m'] as num?)?.toDouble() ?? 1000.0,
    precautionSummary: json['precaution_summary'] as String? ?? '',
    forecastSummary: json['forecast_summary'] as String? ?? '',
    status: json['status'] as String? ?? 'active',
  );
}
```

### 4. Interactive "Update Data" Ingestion Flow
The profile screen features an **"Update Data"** button designed to synchronize the mobile client with the backend's data crawlers.

```
[Profile Screen: Tap "Update Data"] ──► Set syncProgressProvider = TRUE (Shows "Updating..." & Spinner)
                                                    │
                                                    ▼
                                       HTTP POST /signals/fetch/all ──► Backend sweeps live APIs
                                                    │
                                                    ▼
[Incident Feed: Auto-Refreshes] ◄── Set syncProgressProvider = FALSE (Triggers refreshTriggerProvider)
```

1. **User Action:** The user taps the **"Update Data"** button on the Profile Screen.
2. **UI Lock:** The button changes to an active loading state (displays a spinner and "Updating..." label) and the global `syncProgressProvider` is set to `true`.
3. **Data Ingestion:** The client calls `POST /signals/fetch/all` on the backend, which launches a background task to fetch data from live APIs and update the database.
4. **Data Sync:** Once the backend returns a successful status, the mobile client updates `syncProgressProvider` to `false` and triggers `refreshTriggerProvider` to refresh the active incident feeds.

---

## 🔌 API Endpoint Directory

The client layers connect to the backend using 10 dedicated routers.

### 1. System Operations
- `GET /health` — Check database connection, PostGIS availability, and API health.
- `GET /system/status` — Get backend version and active services status.

### 2. Signals & Data Crawling
- `POST /signals` — Ingest a single raw signal payload.
- `POST /signals/fetch/all` — Trigger the background crawler to fetch data from all live APIs.
- `POST /signals/mock/emergency` — Generate a synthetic 1122 emergency dispatch log.

### 3. Incidents & Forecasts
- `GET /incidents` — List all active, verified, or resolved incidents.
- `GET /incidents/{id}` — Get detailed metadata and coordinates for a specific incident.
- `GET /incidents/{id}/forecast` — Get AI-generated forecasts and cascade risk evaluations.
- `GET /incidents/{id}/precautions` — Get ranked precautions and advisories for a specific incident.

### 4. Simulators & Actions
- `POST /actions/plan` — Generate tactical response plans.
- `POST /actions/simulate` — Simulate a response plan using the Simulation Agent.
- `POST /actions/simulate-generic` — Run the standalone simulator using custom inputs.
- `POST /actions/simulate/strategies` — Run parallel side-by-side strategy simulations.
- `POST /actions/execute` — Execute a response plan and generate communication templates.

### 5. Verification & Safety Tracking
- `POST /verification/verify` — Manually trigger the Verification Agent to audit an incident.
- `GET /tracking/status/{id}` — Check family member status using PostGIS geofencing.

---

## 🚀 Getting Started & Deployment

### Backend Setup
1. **Prerequisites:** Install Python 3.10+ and a PostgreSQL instance with the PostGIS extension.
2. **Environment Variables:** Copy `.env.example` to `.env` and configure your API keys:
   ```env
   DATABASE_URL=postgresql://user:password@localhost:5432/ciro_db
   GEMINI_API_KEY=AIzaSyYourGeminiKeyHere
   OPENWEATHER_API_KEY=your_key
   TOMTOM_API_KEY=your_key
   ```
3. **Installation:** Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. **Run Server:** Launch the FastAPI application:
   ```bash
   uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
   ```
5. **Interactive Docs:** Access the Swagger API documentation at `http://localhost:8000/docs`.

### Flutter Mobile Client Setup
1. **Prerequisites:** Install the Flutter SDK (3.22.0+ recommended) and configure your emulator or device.
2. **Target Backend URL:** Open `lib/core/constants.dart` and configure the backend URL:
   ```dart
   const String kApiBaseUrl = 'http://localhost:8000'; // Or your staging IP
   ```
3. **Dependency Sync:** Fetch Dart packages:
   ```bash
   flutter pub get
   ```
4. **Launch Application:** Run the app on your connected device:
   ```bash
   flutter run
   ```

---

*Developed by team Antigravity.*
