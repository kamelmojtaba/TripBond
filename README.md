# TripBond

**AI-powered group travel planner that turns conflicting preferences into perfectly balanced itineraries.**

Plan smarter. Decide together. Travel better.

---

## The Problem

Planning group trips is chaotic:
- Everyone has different preferences
- Too many disconnected tools
- No fair way to make decisions

## The Solution

TripBond combines AI + collaboration to:
- Understand each traveler's personality and preferences
- Balance group decisions fairly
- Generate optimized itineraries
- Adapt to real-time context (weather, time, location)

All in ONE platform.

---

## Features

### AI-Powered Planning
- Personalized recommendations (Decision Tree + Random Forest)
- Group preference aggregation (fairness-aware)
- Itinerary optimization (Genetic Algorithm)

### Group Travel Made Easy
- Create trips and invite members
- Voting system for decisions
- Balanced recommendations (no user ignored)

### Explore & Discover
- POI explorer with photos and details
- Nearby attractions and smart suggestions
- Save favorites

### Social Experience
- In-app chat and conversations
- Notifications and updates
- Feedback and ratings

### Seamless UX
- Cross-platform (iOS, Android, Web, Desktop)
- Smooth animations
- Responsive design

---

## Why TripBond?

| Feature | Traditional Apps | TripBond |
|---------|------------------|----------|
| Group Planning | ❌ | ✅ |
| Fair Decision Making | ❌ | ✅ |
| AI Personalization | Limited | ✅ |
| Real-time Adaptation | ❌ | ✅ |
| All-in-one Platform | ❌ | ✅ |

---

## How It Works

1. **User Profiling** - Personality + preferences (Big Five + behavior)
2. **Group Modeling** - Combine users using fairness strategies
3. **Context Awareness** - Adjust using weather, time, and location
4. **Itinerary Generation** - Optimized plans using AI models
5. **Continuous Learning** - Improves using feedback

---

## Performance

- **Accuracy**: 83.63%
- **ROC-AUC**: 85.88%

Strong predictive performance and effective group recommendation quality.

---

## What Makes TripBond Unique?

- Combines AI personalization + group fairness
- Uses hybrid models (RF + GA + CF)
- Supports real-time adaptive itineraries
- Designed for collaborative decision-making

---

## Tech Stack

**Backend**: FastAPI, SQLAlchemy, JWT Auth
**Frontend**: Flutter, Riverpod, Cross-platform
**Database**: Supabase (PostgreSQL with RLS)

### AI
- Random Forest (preference prediction)
- Decision Trees (explainability)
- Genetic Algorithm (itinerary optimization)
- Collaborative Filtering (learning)

### External APIs
- Google Places
- Foursquare
- Geoapify
- TomTom

### Infrastructure
- Docker
- WebSockets (chat)
- PowerShell automation scripts

---

## System Architecture

### Backend Services
- AI recommendation engine
- Itinerary generation
- Authentication and security
- Notifications and email
- External API integrations

### Frontend Services
- Trip management
- Chat and messaging
- POI exploration and maps
- AI interaction layer
- State management

---

## Project Structure

```
tripbond-app/
├── backend/              # FastAPI backend
├── tripbond_ai_backend/  # AI/ML service
├── frontend/             # Flutter app
└── test_*.py             # Tests
```

---

## Database Overview

**Core tables**:
- profiles
- trips
- trip_members
- personality_scores
- user_preferences
- suggestions + voting
- chat (messages & conversations)
- feedback

Includes Supabase Row-Level Security (RLS)

---

## Quick Start

### One-Command Setup (Windows)

```powershell
.\start-dev.ps1
.\start-full-stack.ps1
```

### Manual Setup

**Backend**
```bash
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python run_migration.py
uvicorn app.main:app --reload
```

**Frontend**
```bash
cd frontend
flutter pub get
flutter run
```

**AI Backend** (optional)
```bash
cd tripbond_ai_backend
python run_ai.py
```

---

## API Documentation

**Swagger**: http://localhost:8000/docs
**ReDoc**: http://localhost:8000/redoc

---

## Testing

```bash
pytest
flutter test
```

---

## Roadmap

- Companion matching (AI bonding system)
- Real-time itinerary updates
- Expense splitting
- Payment integration
- Interactive maps

---

## Contributing

1. Fork the repo
2. Create branch (feature/name)
3. Commit changes
4. Open Pull Request

---

## Team

- Jory Alshathri
- Ghala Alroumaih
- Dana Alanzi
- Basmah Aljishi
- Hawaraa Aljanabi

---

## License

Academic and research use only.

---

**Time to Bond!**
