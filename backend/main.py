from fastapi import FastAPI, Depends, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, date
from typing import List
from functools import lru_cache
from jwt import PyJWKClient
from jwt import decode as jwt_decode
from collections import defaultdict
import os
import re
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
    BodyweightLogCreate, DashboardResponse, DashboardChart,
)

Base.metadata.create_all(bind=engine)

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


def estimate_tdee(weight_kg: float | None) -> float:
    if not weight_kg:
        return 2200.0
    return max(1400.0, weight_kg * 32.0)


async def fetch_supabase_table(table: str, query: str) -> list[dict]:
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{SUPABASE_URL}/rest/v1/{table}?{query}",
            headers=supabase_headers(),
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


@app.get("/")
def root():
    return {"status": "ok", "message": "AI Fitness backend is running"}


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
    new_workout = Workout(user_id=user_id, **workout.model_dump())
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
        .filter(Workout.user_id == user_id, Workout.exercise == exercise)
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
        .filter(Workout.user_id == user_id, Workout.exercise == exercise)
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
    user=Depends(verify_token),
):
    user_id = get_user_id(user)
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{SUPABASE_URL}/rest/v1/bodyweight_logs",
            headers={**supabase_headers(), "Prefer": "return=minimal"},
            json={"user_id": user_id, "weight_kg": log.weight_kg},
        )
    if response.status_code not in (200, 201):
        raise HTTPException(status_code=500, detail="Failed to save bodyweight log")
    return {"saved": True}


@app.get("/dashboard/{user_id}", response_model=DashboardResponse)
async def get_dashboard(
    user_id: str,
    db: Session = Depends(get_db),
    user=Depends(verify_token),
):
    ensure_user_access(user_id, user)

    profiles = await fetch_supabase_table(
        "user_profiles", f"id=eq.{user_id}&select=goal,weight_kg"
    )
    goal = profiles[0].get("goal", "maintain") if profiles else "maintain"
    profile_weight = profiles[0].get("weight_kg") if profiles else None
    tdee = estimate_tdee(profile_weight)

    week_ago = (datetime.utcnow() - timedelta(days=6)).date().isoformat()
    month_ago = (datetime.utcnow() - timedelta(days=29)).date().isoformat()

    calorie_logs = await fetch_supabase_table(
        "calorie_logs",
        f"user_id=eq.{user_id}&created_at=gte.{week_ago}T00:00:00&select=calories,protein_g,created_at",
    )
    bodyweight_logs = await fetch_supabase_table(
        "bodyweight_logs",
        f"user_id=eq.{user_id}&created_at=gte.{month_ago}T00:00:00&order=created_at.asc&select=weight_kg,created_at",
    )
    physique_scans = await fetch_supabase_table(
        "physique_scans",
        f"user_id=eq.{user_id}&order=created_at.asc&select=body_fat_estimate,created_at",
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
        daily_deficit.append(max(0.0, tdee - cal_sum))
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
    return {"goal": goal, "charts": charts}


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
            "food_name": "name of the food",
            "calories": 000,
            "protein_g": 00,
            "carbs_g": 00,
            "fat_g": 00,
            "serving_size": "description of portion"
        }
        Be as accurate as possible. Return only JSON, no other text.""",
    ])

    result = response.text
    clean = result.replace("```json", "").replace("```", "").strip()
    return json.loads(clean)


@app.post("/calories/log")
async def log_calories(log: dict, user=Depends(verify_token)):
    db_user_id = get_user_id(user)
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{SUPABASE_URL}/rest/v1/calorie_logs",
            headers={**supabase_headers(), "Prefer": "return=minimal"},
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
    return {"saved": response.status_code in (200, 201)}


@app.post("/physique/scan")
async def scan_physique(
    files: List[UploadFile] = File(...),
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

    muscle_groups = scan_data.get("muscle_groups", {}) or {}

    async with httpx.AsyncClient() as client:
        await client.post(
            f"{SUPABASE_URL}/rest/v1/physique_scans",
            headers={**supabase_headers(), "Prefer": "return=minimal"},
            json={
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
            },
        )

    return scan_data


@app.post("/workouts/generate")
async def generate_workout(request: dict, user=Depends(verify_token)):
    user_id = get_user_id(user)

    genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
    model = genai.GenerativeModel("gemini-2.5-flash")

    goal = request.get("goal", "general fitness")
    equipment = request.get("equipment", "full gym")
    duration = request.get("duration", 60)
    focus = request.get("focus", "full body")

    physique_context = ""
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{SUPABASE_URL}/rest/v1/physique_scans?user_id=eq.{user_id}&order=created_at.desc&limit=1",
            headers=supabase_headers(),
        )
        if response.status_code == 200:
            scans = response.json()
            if scans:
                scan = scans[0]
                weak_muscles = []
                for muscle in ['chest', 'back', 'shoulders', 'arms', 'legs', 'core']:
                    score = scan.get(f"{muscle}_score")
                    if score is not None and score <= 5:
                        weak_muscles.append(muscle)
                if weak_muscles:
                    physique_context = f"Priority muscles to develop: {', '.join(weak_muscles)}."

    prompt = f"""You are an expert personal trainer. Create a workout plan and return ONLY a JSON object:
    {{
        "workout_name": "<creative workout name>",
        "duration_minutes": {duration},
        "goal": "{goal}",
        "focus": "{focus}",
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

    User goal: {goal}
    Equipment available: {equipment}
    Workout duration: {duration} minutes
    Focus area: {focus}
    {physique_context}

    Make it specific, progressive, and effective. Only return JSON."""

    response = model.generate_content(prompt)
    result = response.text
    clean = result.replace("```json", "").replace("```", "").strip()
    return json.loads(clean)
