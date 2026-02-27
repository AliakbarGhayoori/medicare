#!/bin/bash
export MEDICARE_ENV_FILE=.env.live
cd /Users/aliakbarghayouri/Projects/medicare/backend
exec .venv/bin/uvicorn src.main:app --host 127.0.0.1 --port 8000
