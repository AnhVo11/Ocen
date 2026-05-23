# OCEN — WhatsApp Smart Scheduling Assistant

A WhatsApp-based scheduling assistant for a busy executive in Vietnam. Secretaries and drivers
send schedule updates via WhatsApp; the system checks for conflicts, validates travel feasibility
(car vs. flight), classifies work events, and dispatches smart reminders to the executive.

## Architecture

- **FastAPI** webhook receives Twilio WhatsApp messages
- **State machine** (per sender) guides data entry: title → date → time → location → notes → confirm
- **Conflict detection** flags overlapping calendar events
- **Travel feasibility** uses Google Maps (< 100 km) or Amadeus flights (≥ 100 km)
- **Work classifier** tags events using bilingual (VN/EN) keyword matching
- **APScheduler** dispatches reminders: 24 h + 3 h before travel events, 30 min before local events
- **PostgreSQL** persists schedules, contacts, work notes, and reminders
- **Redis** available for caching / future rate-limiting

## Quick Start

```bash
# 1. Copy and fill in credentials
cp .env.example .env

# 2. Start all services
docker compose up --build

# 3. Run database migrations
docker compose exec app alembic upgrade head

# 4. Expose the webhook (e.g. via ngrok) and set in Twilio console:
#    POST https://<your-ngrok-url>/webhook/whatsapp
ngrok http 8000
```

## Roles

| Role       | WhatsApp Number     | Permissions                          |
|------------|---------------------|--------------------------------------|
| executive  | EXECUTIVE_WHATSAPP  | Receives reminders only              |
| secretary  | SECRETARY_WHATSAPP  | Add / list schedules                 |
| driver     | DRIVER_WHATSAPP     | Add / list schedules                 |

Contacts are seeded into the `contacts` table. Add rows matching each WhatsApp number.

## Bot Commands (for secretary / driver)

| Command              | Action                         |
|----------------------|--------------------------------|
| `new` / `thêm`       | Start adding a new event       |
| `list` / `danh sách` | Show upcoming events           |
| `cancel` / `hủy`     | Cancel current operation       |
| `help` / `giúp đỡ`  | Show help message              |

## Environment Variables

See `.env.example` for all required variables.

## Running Tests

```bash
pip install -r requirements.txt
pytest tests/ -v
```

## Database Migrations

```bash
# Create a new migration after changing models
alembic revision --autogenerate -m "description"

# Apply migrations
alembic upgrade head

# Rollback one step
alembic downgrade -1
```
