from pydantic import BaseModel, ConfigDict


class UserCreate(BaseModel):
    name: str
    email: str
    age: int


class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    age: int

    model_config = ConfigDict(from_attributes=True)


class WorkoutCreate(BaseModel):
    exercise: str
    sets: int | None = None
    reps: int | None = None
    weight: float | None = None
    duration: int | None = None


class WorkoutBatchItem(BaseModel):
    exercise: str
    sets: int | None = None
    reps: int | None = None
    weight: float | None = None
    duration: int | None = None


class WorkoutBatchCreate(BaseModel):
    exercises: list[WorkoutBatchItem]


class WorkoutUpdate(BaseModel):
    exercise: str | None = None
    sets: int | None = None
    reps: int | None = None
    weight: float | None = None
    duration: int | None = None


class WorkoutResponse(BaseModel):
    id: int
    user_id: str
    exercise: str
    sets: int | None = None
    reps: int | None = None
    weight: float | None = None
    duration: int | None = None
    volume: float | None = None

    model_config = ConfigDict(from_attributes=True)


class ExerciseStats(BaseModel):
    exercise: str
    last_weight: float | None = None
    last_reps: int | None = None
    last_sets: int | None = None
    max_weight: float | None = None
    max_volume: float | None = None
    total_sessions: int = 0

    model_config = ConfigDict(from_attributes=True)


class WeeklySummary(BaseModel):
    week_start: str
    total_volume: float
    total_sessions: int


class BodyweightLogCreate(BaseModel):
    weight_kg: float


class DashboardChart(BaseModel):
    id: str
    type: str
    title: str
    labels: list[str]
    values: list[float]


class DashboardResponse(BaseModel):
    goal: str
    charts: list[DashboardChart]
