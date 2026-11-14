import sys
import os
from pathlib import Path

# Redirect stdout and stderr to a log file so it runs cleanly in background
log_path = Path(__file__).parent / "server.log"
log_file = open(log_path, "a", encoding="utf-8")
sys.stdout = log_file
sys.stderr = log_file

import uvicorn

if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, access_log=True)
