# cv-orchestrator

Python perception orchestrator. **Cloud dev path** implements sampling FSM and homography math without Triton.

```powershell
cd services/edge/cv-orchestrator
pip install -e ".[dev]"
pytest
python -m orchestrator.main --person --hand-in-shelf
```

Tickets: RIP-2-030 (FSM), RIP-2-050..055 (homography stub).
