from fastapi import FastAPI, Depends, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from sqlalchemy import func as sqlfunc
from datetime import datetime, timedelta, date, timezone
from typing import List
from functools import lru_cache
from jwt import PyJWKClient
from jwt import decode as jwt_decode
from collections import defaultdict, OrderedDict
import os
import re
import time
import logging
import google.generativeai as genai
import base64
import json
import httpx

from .database import SessionLocal, engine, Base
from .models import User, Workout
from .schemas import (
    UserCreate, UserResponse,
    WorkoutCreate, WorkoutResponse, WorkoutUpdate,
    WorkoutBatchCreate,
    ExerciseStats, WeeklySummary,
    BodyweightLogCreate, DashboardResponse, DashboardChart, TodayStats,
)

Base.metadata.create_all(bind=engine)

logger = logging.getLogger("fitai")

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

security = HTTPBearer()
SUPABASE_URL = "https://jfopizywtgaqhkbkjlyz.supabase.co"
JWKS_URL = f"{SUPABASE_URL}/auth/v1/.well-known/jwks.json"
ISSUER = f"{SUPABASE_URL}/auth/v1"


@lru_cache(maxsize=1)
def get_jwks_client():
    return PyJWKClient(JWKS_URL)


def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials
    try:
        jwks_client = get_jwks_client()
        signing_key = jwks_client.get_signing_key_from_jwt(token).key
        payload = jwt_decode(
            token,
            signing_key,
            algorithms=["ES256", "RS256"],
            issuer=ISSUER,
            audience="authenticated",
        )
        return payload
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {str(e)}")


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_user_id(user) -> str:
    uid = user.get("sub")
    if not uid:
        raise HTTPException(status_code=401, detail="Invalid token: missing user id")
    return uid


def supabase_headers():
    return {
        "apikey": os.getenv("SUPABASE_ANON_KEY"),
        "Authorization": f"Bearer {os.getenv('SUPABASE_ANON_KEY')}",
        "Content-Type": "application/json",
    }


def supabase_admin_headers():
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_ANON_KEY")
    return {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }


def supabase_user_headers(user_token: str):
    return {
        "apikey": os.getenv("SUPABASE_ANON_KEY"),
        "Authorization": f"Bearer {user_token}",
        "Content-Type": "application/json",
    }


def calculate_volume(workout: Workout):
    if workout.sets and workout.reps and workout.weight:
        return workout.sets * workout.reps * workout.weight
    return None


def workout_to_response(workout: Workout):
    return {
        "id": workout.id,
        "user_id": workout.user_id,
        "exercise": workout.exercise,
        "sets": workout.sets,
        "reps": workout.reps,
        "weight": workout.weight,
        "duration": workout.duration,
        "volume": calculate_volume(workout),
        "created_at": workout.created_at.isoformat() if workout.created_at else None,
    }


def ensure_user_access(requested_user_id: str, token_user: dict):
    token_uid = get_user_id(token_user)
    if requested_user_id != token_uid:
        raise HTTPException(status_code=403, detail="Forbidden")


def last_n_day_labels(n: int = 7) -> list[str]:
    today = date.today()
    return [(today - timedelta(days=n - 1 - i)).strftime("%a") for i in range(n)]


def last_n_dates(n: int = 7) -> list[date]:
    today = date.today()
    return [today - timedelta(days=n - 1 - i) for i in range(n)]


def parse_body_fat(value) -> float | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    match = re.search(r"(\d+(?:\.\d+)?)", str(value))
    return float(match.group(1)) if match else None


def parse_weekly_goal(workout_frequency) -> int:
    """Map a profile workout_frequency string ("1-2", "3-5", "6+") to a weekly session goal."""
    freq = str(workout_frequency or "").lower()
    if any(x in freq for x in ["6+", "6 ", "7", "daily"]):
        return 6
    if any(x in freq for x in ["3-5", "3", "4", "5"]):
        return 4
    if any(x in freq for x in ["1-2", "1", "2"]):
        return 2
    return 4


def estimate_tdee(
    weight_kg: float | None,
    gender: str | None = None,
    age: int | None = None,
    height_cm: float | None = None,
    workout_frequency: str | None = None,
) -> float:
    if not weight_kg:
        return 2200.0
    w = float(weight_kg)
    h = float(height_cm or 170)
    a = int(age or 25)
    if str(gender or "").lower() in ("male", "m", "man"):
        bmr = 10 * w + 6.25 * h - 5 * a + 5
    else:
        bmr = 10 * w + 6.25 * h - 5 * a - 161
    freq = str(workout_frequency or "").lower()
    if any(x in freq for x in ["6+", "6 ", "7", "daily"]):
        mult = 1.725
    elif any(x in freq for x in ["3-5", "3", "4", "5"]):
        mult = 1.55
    else:
        mult = 1.375
    return max(1200.0, round(bmr * mult))


async def fetch_supabase_table(
    table: str, query: str, token: str | None = None
) -> list[dict]:
    headers = supabase_user_headers(token) if token else supabase_headers()
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{SUPABASE_URL}/rest/v1/{table}?{query}",
            headers=headers,
        )
        if response.status_code == 200:
            return response.json()
        return []


def build_dashboard_charts(goal: str, data: dict) -> list[dict]:
    goal_key = (goal or "maintain").lower()
    day_labels = data["day_labels"]
    dates = data["dates"]

    if goal_key in ("bulk", "weight gain"):
        weekly_volume = []
        for d in dates:
            day_workouts = [w for w in data["workouts"] if w.created_at.date() == d]
            weekly_volume.append(sum(calculate_volume(w) or 0 for w in day_workouts))

        return [
            {"id": "daily_calories", "type": "bar", "title": "Daily Calories This Week",
             "labels": day_labels, "values": data["daily_calories"]},
            {"id": "daily_protein", "type": "bar", "title": "Daily Protein (g) This Week",
             "labels": day_labels, "values": data["daily_protein"]},
            {"id": "weekly_volume", "type": "line", "title": "Daily Workout Volume",
             "labels": day_labels, "values": weekly_volume},
            {"id": "bodyweight_trend", "type": "line", "title": "Bodyweight Trend (30 days)",
             "labels": data["weight_labels"], "values": data["weight_values"]},
        ]

    if goal_key in ("cut", "lose weight"):
        return [
            {"id": "calorie_deficit", "type": "bar", "title": "Daily Calorie Deficit",
             "labels": day_labels, "values": data["daily_deficit"]},
            {"id": "bodyweight_trend", "type": "line", "title": "Bodyweight Trend (30 days)",
             "labels": data["weight_labels"], "values": data["weight_values"]},
            {"id": "weekly_sessions", "type": "bar", "title": "Workout Sessions This Week",
             "labels": day_labels, "values": data["daily_sessions"]},
            {"id": "body_fat_trend", "type": "line", "title": "Body Fat Estimate Trend",
             "labels": data["bf_labels"], "values": data["bf_values"]},
        ]

    return [
        {"id": "workout_consistency", "type": "bar", "title": "Workout Consistency This Week",
         "labels": day_labels, "values": data["daily_sessions"]},
        {"id": "strength_progression", "type": "line", "title": "Strength Progression (Top Exercise)",
         "labels": data["strength_labels"], "values": data["strength_values"]},
        {"id": "calorie_balance", "type": "bar", "title": "Daily Calorie Balance",
         "labels": day_labels, "values": data["daily_balance"]},
        {"id": "volume_trend", "type": "line", "title": "Weekly Volume Trend",
         "labels": day_labels, "values": data["daily_volume"]},
    ]


@app.get("/streak/{user_id}")
async def get_streak(
    user_id: str,
    db: Session = Depends(get_db),
    credentials: HTTPAuthorizationCredentials = Depends(security),
    user=Depends(verify_token),
):
    ensure_user_access(user_id, user)
    today = date.today()

    # Collect active dates from workouts table (PostgreSQL)
    workout_rows = (
        db.query(Workout.created_at)
        .filter(Workout.user_id == user_id)
        .all()
    )
    workout_dates = {r[0].date() for r in workout_rows if r[0]}

    # Collect active dates from calorie_logs table (Supabase)
    calorie_rows = await fetch_supabase_table(
        "calorie_logs",
        f"user_id=eq.{user_id}&select=created_at",
        token=credentials.credentials,
    )
    calorie_dates = set()
    for row in calorie_rows:
        raw = row.get("created_at")
        if raw:
            try:
                calorie_dates.add(date.fromisoformat(raw[:10]))
            except ValueError:
                pass

    all_active_dates = workout_dates | calorie_dates

    # Activity today
    activity_today = []
    if today in workout_dates:
        activity_today.append("workout")
    if today in calorie_dates:
        activity_today.append("meal")

    streak_at_risk = today not in all_active_dates

    # Current streak — count consecutive days ending today or yesterday
    current_streak = 0
    check = today
    while check in all_active_dates:
        current_streak += 1
        check = check - timedelta(days=1)
    if current_streak == 0:
        yesterday = today - timedelta(days=1)
        check = yesterday
        while check in all_active_dates:
            current_streak += 1
            check = check - timedelta(days=1)

    # Longest streak — scan all dates
    longest_streak = 0
    if all_active_dates:
        sorted_dates = sorted(all_active_dates)
        run = 1
        best = 1
        for i in range(1, len(sorted_dates)):
            if (sorted_dates[i] - sorted_dates[i - 1]).days == 1:
                run += 1
                best = max(best, run)
            else:
                run = 1
        longest_streak = best

    last_active = max(all_active_dates) if all_active_dates else None

    # Weekly activity grid (last 7 days, index 0 = 6 days ago, index 6 = today)
    weekly_activity = [
        (today - timedelta(days=6 - i)) in all_active_dates
        for i in range(7)
    ]

    return {
        "current_streak": current_streak,
        "longest_streak": longest_streak,
        "last_active_date": last_active.isoformat() if last_active else None,
        "streak_at_risk": streak_at_risk,
        "activity_today": activity_today,
        "weekly_activity": weekly_activity,
    }


@app.get("/")
def root():
    return {"status": "ok", "message": "FitAI backend is running"}


@app.get("/test-db")
def test_db(db: Session = Depends(get_db)):
    return {"message": "Database connected!"}
    

@app.post("/users", response_model=UserResponse)
def create_user(user: UserCreate, db: Session = Depends(get_db)):
    new_user = User(name=user.name, email=user.email, age=user.age)
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user


@app.post("/workouts", response_model=WorkoutResponse)
async def create_workout(
    workout: WorkoutCreate,
    db: Session = Depends(get_db),
    user=Depends(verify_token),
):
    user_id = get_user_id(user)
    workout_data = workout.model_dump()
    if workout_data.get("exercise"):
        workout_data["exercise"] = workout_data["exercise"].strip().title()
    new_workout = Workout(user_id=user_id, **workout_data)
    db.add(new_workout)
    db.commit()
    db.refresh(new_workout)
    return workout_to_response(new_workout)


@app.post("/workouts/batch", response_model=List[WorkoutResponse])
async def create_workouts_batch(
    batch: WorkoutBatchCreate,
    db: Session = Depends(get_db),
    user=Depends(verify_token),
):
    user_id = get_user_id(user)
    saved = []
    for item in batch.exercises:
        new_workout = Workout(user_id=user_id, **item.model_dump())
        db.add(new_workout)
        db.flush()
        saved.append(workout_to_response(new_workout))
    db.commit()
    return saved


@app.get("/workouts", response_model=List[WorkoutResponse])
async def get_all_workouts(
    db: Session = Depends(get_db),
    user=Depends(verify_token),
):
    user_id = get_user_id(user)
    workouts = db.query(Workout).filter(Workout.user_id == user_id).all()
    return [workout_to_response(w) for w in workouts]


@app.get("/workouts/user/{user_id}", response_model=List[WorkoutResponse])
async def get_user_workouts(
    user_id: str,
    db: Session = Depends(get_db),
    user=Depends(verify_token),
):
    ensure_user_access(user_id, user)
    workouts = db.query(Workout).filter(Workout.user_id == user_id).all()
    return [workout_to_response(w) for w in workouts]


@app.get("/workouts/{workout_id}", response_model=WorkoutResponse)
async def get_workout(
    workout_id: int,
    db: Session = Depends(get_db),
    user=Depends(verify_token),
):
    workout = db.query(Workout).filter(Workout.id == workout_id).first()
    if not workout:
        raise HTTPException(status_code=404, detail="Workout not found")
    ensure_user_access(workout.user_id, user)
    return workout_to_response(workout)


@app.put("/workouts/{workout_id}", response_model=WorkoutResponse)
async def update_workout(
    workout_id: int,
    workout: WorkoutUpdate,
    db: Session = Depends(get_db),
    user=Depends(verify_token),
):
    db_workout = db.query(Workout).filter(Workout.id == workout_id).first()
    if not db_workout:
        raise HTTPException(status_code=404, detail="Workout not found")
    ensure_user_access(db_workout.user_id, user)
    for key, value in workout.model_dump(exclude_unset=True).items():
        setattr(db_workout, key, value)
    db.commit()
    db.refresh(db_workout)
    return workout_to_response(db_workout)


@app.delete("/workouts/{workout_id}")
async def delete_workout(
    workout_id: int,
    db: Session = Depends(get_db),
    user=Depends(verify_token),
):
    workout = db.query(Workout).filter(Workout.id == workout_id).first()
    if not workout:
        raise HTTPException(status_code=404, detail="Workout not found")
    ensure_user_access(workout.user_id, user)
    db.delete(workout)
    db.commit()
    return {"deleted": True}


@app.get("/users/{user_id}/exercises/{exercise}/last", response_model=WorkoutResponse)
async def get_last_workout_for_exercise(
    user_id: str,
    exercise: str,
    db: Session = Depends(get_db),
    user=Depends(verify_token),
):
    ensure_user_access(user_id, user)
    workout = (
        db.query(Workout)
        .filter(Workout.user_id == user_id, sqlfunc.lower(Workout.exercise) == exercise.lower().strip())
        .order_by(Workout.id.desc())
        .first()
    )
    if not workout:
        raise HTTPException(status_code=404, detail="No workout found for that exercise")
    return workout_to_response(workout)


@app.get("/users/{user_id}/exercises/{exercise}/stats", response_model=ExerciseStats)
async def get_exercise_stats(
    user_id: str,
    exercise: str,
    db: Session = Depends(get_db),
    user=Depends(verify_token),
):
    ensure_user_access(user_id, user)
    workouts = (
        db.query(Workout)
        .filter(Workout.user_id == user_id, sqlfunc.lower(Workout.exercise) == exercise.lower().strip())
        .all()
    )
    if not workouts:
        raise HTTPException(status_code=404, detail="No workouts found for that exercise")
    last = workouts[-1]
    max_weight = max((w.weight for w in workouts if w.weight), default=None)
    max_volume = max((calculate_volume(w) for w in workouts if calculate_volume(w)), default=None)
    return {
        "exercise": exercise,
        "last_weight": last.weight,
        "last_reps": last.reps,
        "last_sets": last.sets,
        "max_weight": max_weight,
        "max_volume": max_volume,
        "total_sessions": len(workouts),
    }


@app.get("/users/{user_id}/exercises")
async def get_user_exercises(
    user_id: str,
    db: Session = Depends(get_db),
    user=Depends(verify_token),
):
    ensure_user_access(user_id, user)
    rows = db.query(Workout.exercise).filter(Workout.user_id == user_id).distinct().all()
    names = sorted({r[0] for r in rows if r[0]})
    return {"exercises": names}


@app.get("/users/{user_id}/summary/weekly", response_model=List[WeeklySummary])
async def get_weekly_summary(
    user_id: str,
    weeks: int = 4,
    db: Session = Depends(get_db),
    user=Depends(verify_token),
):
    ensure_user_access(user_id, user)
    results = []
    today = datetime.utcnow().date()
    for i in range(weeks):
        week_start = today - timedelta(days=today.weekday() + 7 * i)
        week_end = week_start + timedelta(days=6)
        workouts = (
            db.query(Workout)
            .filter(
                Workout.user_id == user_id,
                Workout.created_at >= datetime.combine(week_start, datetime.min.time()),
                Workout.created_at <= datetime.combine(week_end, datetime.max.time()),
            )
            .all()
        )
        results.append({
            "week_start": str(week_start),
            "total_volume": sum(calculate_volume(w) or 0 for w in workouts),
            "total_sessions": len(workouts),
        })
    return results


@app.post("/bodyweight/log")
async def log_bodyweight(
    log: BodyweightLogCreate,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    user=Depends(verify_token),
):
    user_id = get_user_id(user)
    uhdr = supabase_user_headers(credentials.credentials)
    today = datetime.now(timezone.utc).date().isoformat()
    async with httpx.AsyncClient() as client:
        check = await client.get(
            f"{SUPABASE_URL}/rest/v1/bodyweight_logs",
            headers=uhdr,
            params={"user_id": f"eq.{user_id}", "created_at": f"gte.{today}T00:00:00", "select": "id"},
        )
        existing = check.json() if check.status_code == 200 else []
        if existing:
            row_id = existing[0]["id"]
            resp = await client.patch(
                f"{SUPABASE_URL}/rest/v1/bodyweight_logs?id=eq.{row_id}",
                headers={**uhdr, "Prefer": "return=minimal"},
                json={"weight_kg": log.weight_kg},
            )
        else:
            resp = await client.post(
                f"{SUPABASE_URL}/rest/v1/bodyweight_logs",
                headers={**uhdr, "Prefer": "return=minimal"},
                json={"user_id": user_id, "weight_kg": log.weight_kg},
            )
    if resp.status_code not in (200, 201, 204):
        raise HTTPException(status_code=500, detail=f"Failed to save bodyweight log: {resp.text}")
    return {"saved": True, "weight_kg": log.weight_kg, "date": today}


@app.get("/bodyweight/today/{user_id}")
async def get_today_bodyweight(
    user_id: str,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    user=Depends(verify_token),
):
    ensure_user_access(user_id, user)
    today = datetime.now(timezone.utc).date().isoformat()
    logs = await fetch_supabase_table(
        "bodyweight_logs",
        f"user_id=eq.{user_id}&created_at=gte.{today}T00:00:00&select=weight_kg&limit=1",
        token=credentials.credentials,
    )
    if logs:
        return {"logged_today": True, "weight_kg": logs[0]["weight_kg"]}
    return {"logged_today": False, "weight_kg": None}


@app.get("/bodyweight/history/{user_id}")
async def get_bodyweight_history(
    user_id: str,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    user=Depends(verify_token),
):
    ensure_user_access(user_id, user)
    month_ago = (datetime.utcnow() - timedelta(days=29)).date().isoformat()
    logs = await fetch_supabase_table(
        "bodyweight_logs",
        f"user_id=eq.{user_id}&created_at=gte.{month_ago}T00:00:00&order=created_at.asc&select=weight_kg,created_at",
        token=credentials.credentials,
    )
    return {
        "entries": [
            {"weight_kg": float(l.get("weight_kg") or 0), "created_at": l.get("created_at")}
            for l in logs
        ]
    }


@app.get("/dashboard/{user_id}", response_model=DashboardResponse)
async def get_dashboard(
    user_id: str,
    db: Session = Depends(get_db),
    credentials: HTTPAuthorizationCredentials = Depends(security),
    user=Depends(verify_token),
):
    ensure_user_access(user_id, user)

    profiles = await fetch_supabase_table(
        "user_profiles",
        f"id=eq.{user_id}&select=goal,weight_kg,gender,age,height_cm,workout_frequency",
        token=credentials.credentials,
    )
    profile = profiles[0] if profiles else {}
    goal = profile.get("goal", "maintain")
    profile_weight = profile.get("weight_kg")
    tdee = estimate_tdee(
        profile_weight,
        gender=profile.get("gender"),
        age=profile.get("age"),
        height_cm=profile.get("height_cm"),
        workout_frequency=profile.get("workout_frequency"),
    )

    week_ago = (datetime.utcnow() - timedelta(days=6)).date().isoformat()
    month_ago = (datetime.utcnow() - timedelta(days=29)).date().isoformat()

    calorie_logs = await fetch_supabase_table(
        "calorie_logs",
        f"user_id=eq.{user_id}&created_at=gte.{week_ago}T00:00:00&select=calories,protein_g,carbs_g,fat_g,food_name,created_at",
        token=credentials.credentials,
    )
    bodyweight_logs = await fetch_supabase_table(
        "bodyweight_logs",
        f"user_id=eq.{user_id}&created_at=gte.{month_ago}T00:00:00&order=created_at.asc&select=weight_kg,created_at",
        token=credentials.credentials,
    )
    physique_scans = await fetch_supabase_table(
        "physique_scans",
        f"user_id=eq.{user_id}&order=created_at.asc&select=body_fat_estimate,created_at",
        token=credentials.credentials,
    )

    workouts = (
        db.query(Workout)
        .filter(
            Workout.user_id == user_id,
            Workout.created_at >= datetime.utcnow() - timedelta(days=30),
        )
        .order_by(Workout.created_at.asc())
        .all()
    )

    day_labels = last_n_day_labels(7)
    dates = last_n_dates(7)

    daily_calories = []
    daily_protein = []
    daily_deficit = []
    daily_balance = []
    daily_sessions = []
    daily_volume = []

    for d in dates:
        day_cals = [
            c for c in calorie_logs
            if c.get("created_at", "")[:10] == d.isoformat()
        ]
        cal_sum = sum(float(c.get("calories") or 0) for c in day_cals)
        protein_sum = sum(float(c.get("protein_g") or 0) for c in day_cals)
        day_workouts = [w for w in workouts if w.created_at.date() == d]

        daily_calories.append(cal_sum)
        daily_protein.append(protein_sum)
        daily_deficit.append(tdee - cal_sum)  # signed: negative = surplus, positive = deficit
        daily_balance.append(cal_sum - tdee)
        daily_sessions.append(float(len(day_workouts)))
        daily_volume.append(sum(calculate_volume(w) or 0 for w in day_workouts))

    weight_labels = []
    weight_values = []
    for log in bodyweight_logs:
        created = log.get("created_at", "")[:10]
        weight_labels.append(created[5:] if len(created) >= 10 else created)
        weight_values.append(float(log.get("weight_kg") or 0))

    bf_labels = []
    bf_values = []
    for scan in physique_scans:
        bf = parse_body_fat(scan.get("body_fat_estimate"))
        if bf is None:
            continue
        created = scan.get("created_at", "")[:10]
        bf_labels.append(created[5:] if len(created) >= 10 else created)
        bf_values.append(bf)

    exercise_max: dict[str, list[tuple[date, float]]] = defaultdict(list)
    for w in workouts:
        if w.weight:
            exercise_max[w.exercise].append((w.created_at.date(), w.weight))

    strength_labels = []
    strength_values = []
    if exercise_max:
        top_exercise = max(exercise_max.items(), key=lambda x: len(x[1]))[0]
        series = sorted(exercise_max[top_exercise], key=lambda x: x[0])[-8:]
        strength_labels = [d.strftime("%m/%d") for d, _ in series]
        strength_values = [float(w) for _, w in series]

    chart_data = {
        "day_labels": day_labels,
        "dates": dates,
        "daily_calories": daily_calories,
        "daily_protein": daily_protein,
        "daily_deficit": daily_deficit,
        "daily_balance": daily_balance,
        "daily_sessions": daily_sessions,
        "daily_volume": daily_volume,
        "weight_labels": weight_labels or ["—"],
        "weight_values": weight_values or [0.0],
        "bf_labels": bf_labels or ["—"],
        "bf_values": bf_values or [0.0],
        "strength_labels": strength_labels or day_labels,
        "strength_values": strength_values or [0.0] * len(day_labels),
        "workouts": workouts,
    }

    charts = build_dashboard_charts(goal, chart_data)

    # Sum today's carbs and fat from calorie logs
    today_str = dates[-1].isoformat() if dates else date.today().isoformat()
    today_carbs = sum(
        float(c.get("carbs_g") or 0)
        for c in calorie_logs
        if c.get("created_at", "")[:10] == today_str
    )
    today_fat = sum(
        float(c.get("fat_g") or 0)
        for c in calorie_logs
        if c.get("created_at", "")[:10] == today_str
    )

    latest_weight = weight_values[-1] if weight_values else 0.0
    weight_change_total = (
        weight_values[-1] - weight_values[0] if len(weight_values) >= 2 else 0.0
    )
    latest_bf = bf_values[-1] if bf_values else 0.0
    bf_change = bf_values[-1] - bf_values[-2] if len(bf_values) >= 2 else 0.0
    today_volume = daily_volume[-1] if daily_volume else 0.0

    recent_meals = [
        {
            "food_name": c.get("food_name") or "Meal",
            "calories": float(c.get("calories") or 0),
            "created_at": c.get("created_at"),
        }
        for c in sorted(
            calorie_logs, key=lambda x: x.get("created_at", ""), reverse=True
        )[:3]
    ]
    total_scans = len(physique_scans)
    recent_scans = [
        {
            "number": total_scans - i,
            "body_fat": parse_body_fat(sc.get("body_fat_estimate")) or 0.0,
            "created_at": sc.get("created_at"),
        }
        for i, sc in enumerate(physique_scans[::-1][:2])
    ]

    if not any(c.get("id") == "body_fat_trend" for c in charts):
        charts.append(
            {
                "id": "body_fat_trend",
                "type": "line",
                "title": "Body Fat Trend",
                "labels": bf_labels or ["—"],
                "values": bf_values or [0.0],
            }
        )

    today_stats = TodayStats(
        calories=daily_calories[-1] if daily_calories else 0.0,
        protein=daily_protein[-1] if daily_protein else 0.0,
        carbs=today_carbs,
        fat=today_fat,
        sessions=int(daily_sessions[-1]) if daily_sessions else 0,
        calorie_target=tdee,
        protein_target=round((profile_weight or 70) * 1.8, 0),
        weight=latest_weight,
        weight_change=weight_change_total,
        body_fat=latest_bf,
        body_fat_change=bf_change,
        volume=today_volume,
    )
    weekly_goal = parse_weekly_goal(profile.get("workout_frequency"))
    sessions_this_week = sum(1 for s in daily_sessions if s > 0)

    trends = {
        "weight": {"labels": weight_labels, "values": weight_values},
        "calories": {"labels": day_labels, "values": daily_calories},
        "volume": {"labels": day_labels, "values": daily_volume},
    }

    return DashboardResponse(
        goal=goal,
        charts=charts,
        today_stats=today_stats,
        recent_meals=recent_meals,
        recent_scans=recent_scans,
        weekly_goal=weekly_goal,
        sessions_this_week=sessions_this_week,
        trends=trends,
    )


@app.post("/calories/scan")
async def scan_calories(
    file: UploadFile = File(...),
    user=Depends(verify_token),
):
    genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
    model = genai.GenerativeModel("gemini-2.5-flash")

    image_data = await file.read()
    base64_image = base64.b64encode(image_data).decode('utf-8')

    response = model.generate_content([
        {"mime_type": "image/jpeg", "data": base64_image},
        """Analyze this food image and return ONLY a JSON object like this:
        {
            "food_name": "name of the dish as a whole",
            "calories": 000,
            "protein_g": 00,
            "carbs_g": 00,
            "fat_g": 00,
            "serving_size": "description of portion",
            "items": [
                {"name": "individual ingredient/component", "grams": 000, "confidence": 0-100, "calories": 000}
            ]
        }
        List each visually distinct component of the meal as an item with your
        confidence (0-100) that you identified it correctly. Item calories should
        roughly sum to the total. Be as accurate as possible. Return only JSON, no other text.""",
    ])

    result = response.text
    clean = result.replace("```json", "").replace("```", "").strip()
    return json.loads(clean)


@app.post("/calories/scan/text")
async def scan_calories_text(request: dict, _user=Depends(verify_token)):
    description = request.get("description", "").strip()
    if not description:
        raise HTTPException(status_code=400, detail="description required")
    genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
    model = genai.GenerativeModel("gemini-2.5-flash")
    response = model.generate_content(
        f'The user described their meal as: "{description}"\n'
        "Return ONLY valid JSON (no markdown fences):\n"
        '{"food_name":"...","calories":0,"protein_g":0,"carbs_g":0,"fat_g":0,"serving_size":"estimated portion",'
        '"items":[{"name":"component","grams":0,"confidence":0,"calories":0}]}\n'
        "List each meal component as an item with grams, a 0-100 confidence and its calories."
    )
    clean = response.text.replace("```json", "").replace("```", "").strip()
    try:
        return json.loads(clean)
    except (json.JSONDecodeError, ValueError):
        logger.warning("scan_calories_text: could not parse Gemini response: %r", clean)
        raise HTTPException(
            status_code=502,
            detail="Could not analyse that meal description. Please try rephrasing it.",
        )


@app.post("/calories/log")
async def log_calories(
    log: dict,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    user=Depends(verify_token),
):
    db_user_id = get_user_id(user)
    uhdr = supabase_user_headers(credentials.credentials)
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{SUPABASE_URL}/rest/v1/calorie_logs",
            headers={**uhdr, "Prefer": "return=minimal"},
            json={
                "user_id": db_user_id,
                "food_name": log.get("food_name"),
                "calories": log.get("calories"),
                "protein_g": log.get("protein_g"),
                "carbs_g": log.get("carbs_g"),
                "fat_g": log.get("fat_g"),
                "serving_size": log.get("serving_size"),
            },
        )
    ok = response.status_code in (200, 201, 204)
    if not ok:
        return {"saved": False, "error": f"{response.status_code}: {response.text}"}
    return {"saved": True}


@app.post("/physique/scan")
async def scan_physique(
    files: List[UploadFile] = File(...),
    credentials: HTTPAuthorizationCredentials = Depends(security),
    user=Depends(verify_token),
):
    user_id = get_user_id(user)

    genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
    model = genai.GenerativeModel("gemini-2.5-flash")

    image_parts = []
    for file in files:
        image_data = await file.read()
        base64_image = base64.b64encode(image_data).decode('utf-8')
        image_parts.append({"mime_type": "image/jpeg", "data": base64_image})

    prompt = """You are an expert fitness coach and physique analyst. Analyze ONLY what is clearly visible in these physique photos.

CRITICAL RULES:
- Only score muscle groups that are clearly visible
- If a muscle group is not visible or unclear, set it to null
- Never assume or estimate what you cannot see
- Be objective and constructive

Return ONLY this JSON with no other text:
{
    "overall_score": <0-100 based only on what is visible>,
    "body_fat_estimate": "<range like 10-12%> or null if unclear",
    "symmetry_score": <0-10> or null if both sides not visible,
    "body_type": "<ectomorph/mesomorph/endomorph> or null if unclear",
    "muscle_groups": {
        "chest": {"score": <0-10>, "feedback": "<specific feedback>"} or null if not visible,
        "back": {"score": <0-10>, "feedback": "<specific feedback>"} or null if not visible,
        "shoulders": {"score": <0-10>, "feedback": "<specific feedback>"} or null if not visible,
        "arms": {"score": <0-10>, "feedback": "<specific feedback>"} or null if not visible,
        "legs": {"score": <0-10>, "feedback": "<specific feedback>"} or null if not visible,
        "core": {"score": <0-10>, "feedback": "<specific feedback>"} or null if not visible
    },
    "posture": {
        "overall": "<good/fair/poor>",
        "head_position": "<forward/neutral/back> or null if not visible",
        "shoulder_alignment": "<rounded/neutral/back> or null if not visible",
        "hip_alignment": "<tilted/neutral> or null if not visible",
        "feedback": "<specific posture feedback based only on what is visible>"
    },
    "visible_angles": ["<front/back/side - list what angles were provided>"],
    "strengths": ["<strength 1>", "<strength 2>"],
    "weaknesses": ["<weakness 1>", "<weakness 2>"],
    "recommendations": ["<actionable tip 1>", "<actionable tip 2>", "<actionable tip 3>"],
    "note": "<any important note about what could not be assessed due to photo angles>"
}"""

    content = image_parts + [prompt]
    response = model.generate_content(content)

    result = response.text
    clean = result.replace("```json", "").replace("```", "").strip()
    scan_data = json.loads(clean)

    saved = await _insert_physique_scan(
        user_id, scan_data, credentials.credentials
    )
    scan_data["saved"] = saved
    return scan_data


def _physique_scan_row(user_id: str, scan_data: dict) -> dict:
    muscle_groups = scan_data.get("muscle_groups", {}) or {}
    return {
        "user_id": user_id,
        "overall_score": scan_data.get("overall_score"),
        "body_fat_estimate": scan_data.get("body_fat_estimate"),
        "symmetry_score": scan_data.get("symmetry_score"),
        "body_type": scan_data.get("body_type"),
        "chest_score": (muscle_groups.get("chest") or {}).get("score"),
        "back_score": (muscle_groups.get("back") or {}).get("score"),
        "shoulders_score": (muscle_groups.get("shoulders") or {}).get("score"),
        "arms_score": (muscle_groups.get("arms") or {}).get("score"),
        "legs_score": (muscle_groups.get("legs") or {}).get("score"),
        "core_score": (muscle_groups.get("core") or {}).get("score"),
        "posture_check": json.dumps(scan_data.get("posture")),
        "strengths": scan_data.get("strengths"),
        "weaknesses": scan_data.get("weaknesses"),
        "recommendations": scan_data.get("recommendations"),
    }


async def _insert_physique_scan(user_id: str, scan_data: dict, token: str) -> bool:
    """Insert with the USER'S JWT, not the anon key — physique_scans has an
    RLS policy scoped to auth.uid() = user_id, so an anon-key insert is
    silently rejected by Postgres and the scan never actually saves."""
    uhdr = supabase_user_headers(token)
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{SUPABASE_URL}/rest/v1/physique_scans",
            headers={**uhdr, "Prefer": "return=minimal"},
            json=_physique_scan_row(user_id, scan_data),
        )
    saved = resp.status_code in (200, 201, 204)
    if not saved:
        logger.warning(
            "physique scan insert failed for user %s: %s %s",
            user_id, resp.status_code, resp.text,
        )
    return saved


@app.post("/physique/scans")
async def save_physique_scan(
    scan_data: dict,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    user=Depends(verify_token),
):
    """Persist an already-analyzed scan (retry path after a failed insert
    during /physique/scan) — no AI call, so retries are free."""
    user_id = get_user_id(user)
    saved = await _insert_physique_scan(
        user_id, scan_data, credentials.credentials
    )
    return {"saved": saved}


@app.delete("/physique/scans/{scan_id}")
async def delete_physique_scan(
    scan_id: str,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    user=Depends(verify_token),
):
    user_id = get_user_id(user)
    rows = await fetch_supabase_table(
        "physique_scans",
        f"id=eq.{scan_id}&select=id,user_id",
        token=credentials.credentials,
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Scan not found")
    ensure_user_access(str(rows[0].get("user_id")), user)
    uhdr = supabase_user_headers(credentials.credentials)
    async with httpx.AsyncClient() as client:
        resp = await client.delete(
            f"{SUPABASE_URL}/rest/v1/physique_scans?id=eq.{scan_id}&user_id=eq.{user_id}",
            headers=uhdr,
        )
    if resp.status_code not in (200, 204):
        raise HTTPException(status_code=500, detail="Failed to delete scan")
    return {"deleted": True}


def _physique_priority(score) -> str:
    if score is None:
        return None
    if score <= 4:
        return "HIGH PRIORITY — triple volume"
    if score <= 6:
        return "MEDIUM PRIORITY — double volume"
    if score <= 8:
        return "NORMAL — standard volume"
    return "STRONG — maintenance only"


_EXERCISE_MUSCLE_KEYWORDS: list[tuple[list[str], str]] = [
    (["squat", "leg press", "lunge", "leg curl", "leg extension", "calf", "hamstring", "glute", "quad"], "legs"),
    (["bench", "chest", "fly", "pec", "push-up", "pushup", "dip"], "chest"),
    (["row", "pulldown", "pull-up", "pullup", "lat ", "back", "deadlift", "rhomboid", "trap"], "back"),
    (["shoulder", "overhead", "lateral raise", "front raise", "shrug", "military"], "shoulders"),
    (["curl", "tricep", "bicep", "arm", "hammer", "skull"], "arms"),
    (["plank", "crunch", "sit-up", "situp", "ab ", "abs", "core", "oblique", "russian twist"], "core"),
]


def _exercises_to_muscle_groups(exercise_names: list[str]) -> set[str]:
    recovering = set()
    for name in exercise_names:
        lower = name.lower()
        for keywords, group in _EXERCISE_MUSCLE_KEYWORDS:
            if any(k in lower for k in keywords):
                recovering.add(group)
                break
    return recovering


@app.post("/workouts/generate")
async def generate_workout(
    request: dict,
    db: Session = Depends(get_db),
    credentials: HTTPAuthorizationCredentials = Depends(security),
    user=Depends(verify_token),
):
    user_id = get_user_id(user)

    genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
    model = genai.GenerativeModel("gemini-2.5-flash")

    goal = request.get("goal", "general fitness")
    equipment = request.get("equipment", "full gym")
    duration = request.get("duration", 60)
    focus = request.get("focus", "full body")

    # ── 1. Fetch latest physique scan ────────────────────────────────────────
    scan_rows = await fetch_supabase_table(
        "physique_scans",
        f"user_id=eq.{user_id}&order=created_at.desc&limit=1&select=chest_score,back_score,shoulders_score,arms_score,legs_score,core_score",
        token=credentials.credentials,
    )
    scan = scan_rows[0] if scan_rows else None

    muscle_scores = {
        "Legs":      scan.get("legs_score")      if scan else None,
        "Back":      scan.get("back_score")       if scan else None,
        "Chest":     scan.get("chest_score")      if scan else None,
        "Arms":      scan.get("arms_score")       if scan else None,
        "Shoulders": scan.get("shoulders_score")  if scan else None,
        "Core":      scan.get("core_score")       if scan else None,
    }

    # ── 2. Fetch user profile ────────────────────────────────────────────────
    profile_rows = await fetch_supabase_table(
        "user_profiles",
        f"id=eq.{user_id}&select=goal,fitness_level,age,weight_kg,equipment&limit=1",
        token=credentials.credentials,
    )
    profile = profile_rows[0] if profile_rows else {}
    profile_goal      = profile.get("goal")      or goal
    fitness_level     = profile.get("fitness_level") or "Intermediate"
    age               = profile.get("age")
    weight_kg         = profile.get("weight_kg")
    profile_equipment = profile.get("equipment") or equipment

    # ── 3. Fetch workouts from last 48 hours ─────────────────────────────────
    cutoff = datetime.now(timezone.utc) - timedelta(hours=48)
    recent_workouts = (
        db.query(Workout.exercise)
        .filter(Workout.user_id == user_id, Workout.created_at >= cutoff)
        .all()
    )
    recent_exercises = [r[0] for r in recent_workouts if r[0]]
    recovering_groups = _exercises_to_muscle_groups(recent_exercises)

    # ── 4. Build context strings ─────────────────────────────────────────────
    profile_block = f"""User Profile:
- Goal: {profile_goal}
- Fitness level: {fitness_level}
- Age: {age if age else 'not specified'}
- Weight: {weight_kg if weight_kg else 'not specified'} kg
- Equipment: {profile_equipment}"""

    has_scan = scan is not None
    if has_scan:
        priority_lines = []
        for muscle, score in muscle_scores.items():
            priority = _physique_priority(score)
            if priority is None:
                priority_lines.append(f"- {muscle}: not assessed — skip")
            else:
                score_str = f"{score}/10"
                priority_lines.append(f"- {muscle}: {score_str} — {priority}")
        physique_block = "Physique Priority Map:\n" + "\n".join(priority_lines)
    else:
        physique_block = "Physique Priority Map: No scan available — generate a balanced full body workout."

    if recovering_groups:
        recovery_block = (
            "Recovery Status (trained in last 48 hrs — do NOT make these the primary focus today):\n"
            + "\n".join(f"- {g.capitalize()}" for g in sorted(recovering_groups))
        )
    else:
        recovery_block = "Recovery Status: No muscles trained in last 48 hrs — all fresh."

    goal_key = str(profile_goal or "").lower()
    if "bulk" in goal_key or "muscle" in goal_key:
        goal_block = """Goal-specific rules (BULK):
- Prioritize compound lifts (squat, bench, deadlift, rows, overhead press)
- Keep reps in the 6-12 range for hypertrophy
- Apply progressive overload: if a previous weight is known, suggest +2.5kg
- Use higher overall volume
- Include one tip about maintaining a calorie surplus for muscle growth"""
    elif "cut" in goal_key or "fat" in goal_key or "lose" in goal_key:
        goal_block = """Goal-specific rules (CUT):
- Keep heavy compound lifts to preserve muscle mass
- Slightly reduce total volume vs a bulk
- Include one tip about protein intake (2.2g per kg bodyweight) to prevent muscle loss
- Do NOT suggest excessive cardio"""
    else:
        goal_block = """Goal-specific rules (ATHLETIC / MAINTAIN):
- Mix strength work and power/explosive movements
- Include unilateral exercises (lunges, single-arm rows, split squats)
- Vary rep ranges across exercises"""

    instructions_block = f"""Instructions:
- Prioritize HIGH and MEDIUM muscles with more sets and volume
- Give STRONG muscles 1-2 maintenance sets only
- Avoid RECOVERING muscles as primary movers today
- Select exercise difficulty appropriate for fitness level
- Choose exercises compatible with available equipment

{goal_block}"""

    scan_tip = (
        "" if has_scan
        else '\n    "scan_recommendation": "Do a Physique Scan to get a fully personalized workout tailored to your specific muscle imbalances",'
    )

    prompt = f"""You are an expert personal trainer. Create a workout plan and return ONLY a JSON object:
    {{
        "workout_name": "<creative workout name>",
        "duration_minutes": {duration},
        "goal": "{profile_goal}",
        "focus": "{focus}",{scan_tip}
        "why_this_session": "<2-3 sentences explaining WHY this session was built this way: reference the specific lagging muscles from the physique priority map, recovery status, and the user's goal. Speak directly to the user.>",
        "warmup": [
            {{"exercise": "<name>", "duration": "<time>", "instructions": "<how to>"}}
        ],
        "main_workout": [
            {{"exercise": "<name>", "sets": <number>, "reps": "<number or range>", "weight": <number or null>, "rest_seconds": <number>, "instructions": "<how to>", "muscle_group": "<primary muscle>"}}
        ],
        "cooldown": [
            {{"exercise": "<name>", "duration": "<time>", "instructions": "<how to>"}}
        ],
        "tips": ["<tip 1>", "<tip 2>", "<tip 3>"]
    }}

{profile_block}

{physique_block}

{recovery_block}

{instructions_block}

    Workout duration: {duration} minutes
    Focus area: {focus}

    Make it specific, progressive, and effective. Only return JSON."""

    response = model.generate_content(prompt)
    result = response.text
    clean = result.replace("```json", "").replace("```", "").strip()
    workout = json.loads(clean)
    if has_scan:
        weak = [m for m, s in muscle_scores.items() if s is not None and s <= 6]
        fallback_why = (
            f"Built around your latest physique scan — extra volume for {', '.join(weak).lower()}."
            if weak
            else "Built from your latest physique scan with balanced volume across muscle groups."
        )
    else:
        fallback_why = "A balanced session for your goal — take a physique scan to get targeted programming."
    workout.setdefault("why_this_session", fallback_why)
    return workout


@app.get("/muscle-balance/{user_id}")
async def get_muscle_balance(
    user_id: str,
    db: Session = Depends(get_db),
    user=Depends(verify_token),
):
    ensure_user_access(user_id, user)
    cutoff = datetime.now(timezone.utc) - timedelta(days=30)
    workouts = (
        db.query(Workout)
        .filter(Workout.user_id == user_id, Workout.created_at >= cutoff)
        .all()
    )
    groups: dict[str, int] = {"chest": 0, "back": 0, "legs": 0, "shoulders": 0, "arms": 0, "core": 0}
    for w in workouts:
        for g in _exercises_to_muscle_groups([w.exercise or ""]):
            if g in groups:
                groups[g] += 1
    return {"groups": groups, "total": sum(groups.values())}


_ai_summary_cache: "OrderedDict[str, tuple[str, float]]" = OrderedDict()
_AI_SUMMARY_CACHE_MAX = 500


@app.get("/ai-summary/{user_id}")
async def get_ai_summary(
    user_id: str,
    db: Session = Depends(get_db),
    credentials: HTTPAuthorizationCredentials = Depends(security),
    user=Depends(verify_token),
):
    ensure_user_access(user_id, user)

    cached = _ai_summary_cache.get(user_id)
    if cached and (time.time() - cached[1]) < 21600:
        _ai_summary_cache.move_to_end(user_id)
        return {"summary": cached[0]}

    week_ago = datetime.now(timezone.utc) - timedelta(days=7)
    workouts = (
        db.query(Workout)
        .filter(Workout.user_id == user_id, Workout.created_at >= week_ago)
        .all()
    )
    profiles = await fetch_supabase_table(
        "user_profiles", f"id=eq.{user_id}&select=goal,weight_kg",
        token=credentials.credentials,
    )
    goal = profiles[0].get("goal", "maintain") if profiles else "maintain"
    n_workouts = len(workouts)
    calorie_logs = await fetch_supabase_table(
        "calorie_logs",
        f"user_id=eq.{user_id}&created_at=gte.{week_ago.date().isoformat()}T00:00:00&select=calories",
        token=credentials.credentials,
    )
    avg_cals = int(sum(float(c.get("calories") or 0) for c in calorie_logs) / 7) if calorie_logs else 0

    prompt = (
        f"User fitness goal: {goal}. This week: {n_workouts} workouts, avg {avg_cals} calories/day. "
        f"Write exactly 2 short encouraging sentences summarising their week and motivating them. "
        f"Be specific, positive, and personal. No emojis."
    )
    try:
        genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
        model = genai.GenerativeModel("gemini-2.5-flash")
        response = model.generate_content(prompt)
        summary = response.text.strip()
    except Exception:
        logger.exception("get_ai_summary: Gemini call failed for user %s", user_id)
        summary = f"You logged {n_workouts} workout{'s' if n_workouts != 1 else ''} this week. Keep building on that momentum!"

    _ai_summary_cache[user_id] = (summary, time.time())
    _ai_summary_cache.move_to_end(user_id)
    while len(_ai_summary_cache) > _AI_SUMMARY_CACHE_MAX:
        _ai_summary_cache.popitem(last=False)
    return {"summary": summary}


@app.delete("/account")
async def delete_account(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
    user=Depends(verify_token),
):
    """Delete all user data and auth account. Requires valid JWT."""
    user_id = get_user_id(user)
    uhdr = supabase_user_headers(credentials.credentials)

    # 1. Delete workouts from local PostgreSQL
    db.query(Workout).filter(Workout.user_id == user_id).delete()
    db.commit()

    # 2. Delete rows from all Supabase tables using user JWT (RLS: user can delete own rows)
    #    Tables keyed by a `user_id` column:
    user_keyed_tables = [
        "calorie_logs",
        "bodyweight_logs",
        "physique_scans",
    ]
    async with httpx.AsyncClient() as client:
        for table in user_keyed_tables:
            resp = await client.delete(
                f"{SUPABASE_URL}/rest/v1/{table}?user_id=eq.{user_id}",
                headers=uhdr,
            )
            if resp.status_code not in (200, 204):
                # Log but continue — partial deletion is better than no deletion
                print(f"Warning: delete from {table} returned {resp.status_code}: {resp.text}")

        # user_profiles is keyed by `id` (the user's UUID), not `user_id`.
        prof_resp = await client.delete(
            f"{SUPABASE_URL}/rest/v1/user_profiles?id=eq.{user_id}",
            headers=uhdr,
        )
        if prof_resp.status_code not in (200, 204):
            print(f"Warning: delete from user_profiles returned {prof_resp.status_code}: {prof_resp.text}")

        # 3. Delete auth user via service role key (optional — requires env var)
        service_role_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        if service_role_key:
            await client.delete(
                f"{SUPABASE_URL}/auth/v1/admin/users/{user_id}",
                headers={
                    "apikey": service_role_key,
                    "Authorization": f"Bearer {service_role_key}",
                },
            )

    return {"success": True, "message": "Account and all data deleted."}
