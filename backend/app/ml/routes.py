from fastapi import APIRouter, WebSocket, BackgroundTasks
from fastapi.responses import JSONResponse
from fastapi.responses import StreamingResponse
import json
from pydantic import BaseModel
import uuid
from typing import Dict, Optional
import asyncio

from app.ml.face_recognition import FaceSorter
from app.ml.person_indexer import PersonIndexer

router = APIRouter(prefix="/ml", tags=["ml"])

# per-task progress queues + owning loop for thread-safe publishing
_TASKS: Dict[str, dict] = {}

def publish(task_id: str, event: dict):
    task = _TASKS.get(task_id)
    if not task:
        return
    q: asyncio.Queue = task["queue"]
    loop: asyncio.AbstractEventLoop = task["loop"]
    # Thread-safe enqueue from background thread
    loop.call_soon_threadsafe(q.put_nowait, event)

class SortLocalRequest(BaseModel):
    training_folders: Dict[str, str]  # {person_name: folder_path}
    unsorted_folder: str
    output_base: str
    unknown_folder: str

class IndexDbRequest(BaseModel):
    user_id: str
    folder: str
    training_folders: Optional[Dict[str, str]] = None

@router.post("/sort-local")
async def sort_local(req: SortLocalRequest, background_tasks: BackgroundTasks):
    sorter = FaceSorter()
    task_id = str(uuid.uuid4())
    loop = asyncio.get_running_loop()
    q: asyncio.Queue = asyncio.Queue()
    _TASKS[task_id] = {"queue": q, "loop": loop}

    def progress_cb(ev: dict):
        ev["task_id"] = task_id
        publish(task_id, ev)

    def run():
        sorter.train_from_folders(req.training_folders, progress_cb)
        summary = sorter.sort_folder(req.unsorted_folder, req.output_base, req.unknown_folder, progress_cb)
        publish(task_id, {"status": "done", "summary": summary, "task_id": task_id})

    background_tasks.add_task(run)
    return {"status": "started", "task_id": task_id}

@router.post("/index-db")
async def index_db(req: IndexDbRequest, background_tasks: BackgroundTasks):
    sorter = FaceSorter()
    indexer = PersonIndexer(sorter=sorter)
    task_id = str(uuid.uuid4())
    loop = asyncio.get_running_loop()
    q: asyncio.Queue = asyncio.Queue()
    _TASKS[task_id] = {"queue": q, "loop": loop}

    def run():
        if req.training_folders:
            sorter.train_from_folders(req.training_folders, lambda ev: publish(task_id, {"status": "train", **ev}))
        summary = indexer.index_folder(req.user_id, req.folder)
        publish(task_id, {"status": "done", "summary": summary, "task_id": task_id})

    background_tasks.add_task(run)
    return {"status": "started", "task_id": task_id}

@router.websocket("/progress/{task_id}")
async def ws_progress(ws: WebSocket, task_id: str):
    await ws.accept()
    task = _TASKS.get(task_id)
    q = task["queue"] if task else None
    if not q:
        await ws.send_json({"error": "invalid_task"})
        await ws.close()
        return
    try:
        while True:
            ev = await q.get()
            await ws.send_json(ev)
            if ev.get("status") == "done":
                break
    finally:
        _TASKS.pop(task_id, None)
        await ws.close()

@router.get("/progress-sse/{task_id}")
async def progress_sse(task_id: str):
    task = _TASKS.get(task_id)
    q = task["queue"] if task else None

    async def event_gen():
        if not q:
            yield "event: error\ndata: {\"error\":\"invalid_task\"}\n\n"
            return
        while True:
            ev = await q.get()
            yield f"data: {json.dumps(ev)}\n\n"
            if ev.get("status") == "done":
                break

    return StreamingResponse(event_gen(), media_type="text/event-stream")