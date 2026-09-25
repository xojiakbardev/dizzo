FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app

COPY pyproject.toml ./
RUN pip install --no-cache-dir --upgrade pip && pip install --no-cache-dir \
    "fastapi>=0.115,<1.0" "uvicorn[standard]>=0.30,<1.0" \
    "pydantic-settings>=2.6,<3.0" "sqlalchemy[asyncio]>=2.0,<3.0" "alembic>=1.13,<2.0" \
    "asyncpg>=0.29,<1.0" "aiosqlite>=0.20,<1.0" "PyJWT>=2.8,<3.0" \
    "cryptography>=42,<46" \
    "bcrypt>=4.1,<5.0" "httpx>=0.27,<1.0" "email-validator>=2.2,<3.0" "boto3>=1.34,<2.0" \
    "pillow>=11,<13"
RUN pip install --no-cache-dir "aiogram>=3.13,<4.0"

COPY alembic.ini ./
COPY migrations ./migrations
COPY app ./app
COPY bot ./bot
RUN mkdir -p media

EXPOSE 8000
# Migrate first; the server only starts once the schema is at head.
CMD ["sh", "-c", "alembic upgrade head && exec uvicorn app.main:app --host 0.0.0.0 --port 8000"]
