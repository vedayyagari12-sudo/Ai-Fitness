from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime, timedelta
from typing import List

from .database import SessionLocal, engine, Base
from .models import User, Workout
from .schemas import (
    UserCreate, UserResponse,
    WorkoutCreate, WorkoutResponse, WorkoutUpdate,
    ExerciseStats, WeeklySummary
)

Base.metadata.create_all(bind=engine)

app = FastAPI()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


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
def create_workout(workout: WorkoutCreate, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == workout.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    new_workout = Workout(**workout.model_dump())
    db.add(new_workout)
    db.commit()
    db.refresh(new_workout)
    return workout_to_response(new_workout)


@app.get("/workouts", response_model=List[WorkoutResponse])
def get_all_workouts(db: Session = Depends(get_db)):
    return [workout_to_response(w) for w in db.query(Workout).all()]


@app.get("/workouts/user/{user_id}", response_model=List[WorkoutResponse])
def get_user_workouts(user_id: int, db: Session = Depends(get_db)):
    return [workout_to_response(w) for w in db.query(Workout).filter(Workout.user_id == user_id).all()]


@app.get("/workouts/{workout_id}", response_model=WorkoutResponse)
def get_workout(workout_id: int, db: Session = Depends(get_db)):
    workout = db.query(Workout).filter(Workout.id == workout_id).first()
    if not workout:
        raise HTTPException(status_code=404, detail="Workout not found")
    return workout_to_response(workout)


@app.put("/workouts/{workout_id}", response_model=WorkoutResponse)
def update_workout(workout_id: int, workout: WorkoutUpdate, db: Session = Depends(get_db)):
    db_workout = db.query(Workout).filter(Workout.id == workout_id).first()
    if not db_workout:
        raise HTTPException(status_code=404, detail="Workout not found")
    for key, value in workout.model_dump(exclude_unset=True).items():
        setattr(db_workout, key, value)
    db.commit()
    db.refresh(db_workout)
    return workout_to_response(db_workout)


@app.get("/users/{user_id}/exercises/{exercise}/last", response_model=WorkoutResponse)
def get_last_workout_for_exercise(user_id: int, exercise: str, db: Session = Depends(get_db)):
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
def get_exercise_stats(user_id: int, exercise: str, db: Session = Depends(get_db)):
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
def get_weekly_summary(user_id: int, weeks: int = 4, db: Session = Depends(get_db)):
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