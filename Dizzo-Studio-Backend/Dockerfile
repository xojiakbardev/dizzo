# gltf-transform Draco-compresses uploaded 3D models (app/services/model_compression.py).
# Both images are Debian bookworm, so the node binary runs in the Python one.
FROM node:20-bookworm-slim AS gltf
RUN npm install -g --omit=dev --no-fund --no-audit @gltf-transform/cli@4.5.1

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

COPY --from=gltf /usr/local/bin/node /usr/local/bin/node
COPY --from=gltf /usr/local/lib/node_modules/@gltf-transform /usr/local/lib/node_modules/@gltf-transform
RUN ln -s /usr/local/lib/node_modules/@gltf-transform/cli/bin/cli.js /usr/local/bin/gltf-transform \
    && gltf-transform --version

COPY alembic.ini ./
COPY migrations ./migrations
COPY app ./app
COPY bot ./bot
RUN mkdir -p media

EXPOSE 8000
# Migrate first; the server only starts once the schema is at head.
CMD ["sh", "-c", "alembic upgrade head && exec uvicorn app.main:app --host 0.0.0.0 --port 8000"]
