from sqlalchemy import Column, Integer, String, Float, DateTime
from datetime import datetime
from .database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    email = Column(String, unique=True, index=True)
    age = Column(Integer)


class Workout(Base):
    __tablename__ = "workouts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, index=True)
    exercise = Column(String)
    sets = Column(Integer)
    reps = Column(Integer)
    weight = Column(Float)
    duration = Column(Integer)
    created_at = Column(DateTime, default=datetime.utcnow)
