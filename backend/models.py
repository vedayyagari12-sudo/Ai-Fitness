from sqlalchemy import Column, Index, Integer, String, Float, DateTime
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

    __table_args__ = (
        # Every read of this table filters on user_id AND a created_at range
        # (dashboard: last 30 days; streak: the user's history; the strength
        # trend: the last 8 weeks), then sorts by created_at.
        #
        # The single-column index on user_id above cannot serve that. Postgres
        # can use it to find the user's rows, but then has to fetch and filter
        # every one of them by date and sort the survivors — so the work grows
        # with a user's total history rather than with the window asked for.
        # A composite index in this order answers the filter and returns the
        # rows already ordered, which removes the sort as well.
        Index("ix_workouts_user_id_created_at", "user_id", "created_at"),
    )
