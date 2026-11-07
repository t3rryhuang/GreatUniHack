"""Vercel serverless entrypoint: exposes the FastAPI app from main.py."""
import os
import sys

# Make test-backend/ importable (main.py, services/, analysis/)
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from main import app  # noqa: E402,F401
