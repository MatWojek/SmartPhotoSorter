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


def _get_task(task_id: str) -> Optional[dict]:
    return _TASKS.get(task_id)


def _maybe_cleanup(task_id: str) -> None:
    task = _get_task(task_id)
    if not task:
        return
    if task.get("done") and (task.get("active", 0) <= 0):
        _TASKS.pop(task_id, None)

def publish(task_id: str, event: dict):
    task = _get_task(task_id)
    if not task:
        return
    q: asyncio.Queue = task["queue"]
    loop: asyncio.AbstractEventLoop = task["loop"]
    if event.get("status") == "done":
        task["done"] = True
    # Thread-safe enqueue from background thread
    loop.call_soon_threadsafe(q.put_nowait, event)

class SortLocalRequest(BaseModel):
    training_folders: Optional[Dict[str, str]] = None
    unsorted_folder: str
    output_base: str
    unknown_folder: str
    user_id: Optional[str] = None
    remove_duplicates: bool = True
    sort_photos: bool = True
    match_threshold: float = 0.35

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
    _TASKS[task_id] = {"queue": q, "loop": loop, "active": 0, "done": False}

    def progress_cb(ev: dict):
        ev["task_id"] = task_id
        publish(task_id, ev)

    # Preload embeddings from DB if user_id given
    if req.user_id:
        sorter.load_from_db(req.user_id)

    def sort_run():
        summary = sorter.sort_folder(
            req.unsorted_folder,
            req.output_base,
            req.unknown_folder,
            progress_cb,
            user_id=req.user_id,
            remove_duplicates=req.remove_duplicates,
            sort_photos=req.sort_photos,
            match_threshold=req.match_threshold,
        )
        publish(task_id, {"status": "done", "summary": summary, "task_id": task_id})

    def train_update_run():
        if req.training_folders:
            sorter.train_from_folders(req.training_folders, progress_cb, user_id=req.user_id)
        elif req.user_id:
            sorter.ensure_trained_for_user(req.user_id, progress_cb)

    background_tasks.add_task(train_update_run)
    background_tasks.add_task(sort_run)
    return {"status": "started", "task_id": task_id}

@router.post("/index-db")
async def index_db(req: IndexDbRequest, background_tasks: BackgroundTasks):
    sorter = FaceSorter()
    indexer = PersonIndexer(sorter=sorter)
    task_id = str(uuid.uuid4())
    loop = asyncio.get_running_loop()
    q: asyncio.Queue = asyncio.Queue()
    _TASKS[task_id] = {"queue": q, "loop": loop, "active": 0, "done": False}

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
    task = _get_task(task_id)
    q = task["queue"] if task else None
    if not q:
        await ws.send_json({"error": "invalid_task"})
        await ws.close()
        return
    task["active"] = int(task.get("active", 0)) + 1
    try:
        while True:
            ev = await q.get()
            await ws.send_json(ev)
            if ev.get("status") == "done":
                break
    finally:
        task["active"] = int(task.get("active", 0)) - 1
        _maybe_cleanup(task_id)
        await ws.close()

@router.get("/progress-sse/{task_id}")
async def progress_sse(task_id: str):
    task = _get_task(task_id)
    q = task["queue"] if task else None

    async def event_gen():
        if not q:
            yield "event: error\ndata: {\"error\":\"invalid_task\"}\n\n"
            return
        task["active"] = int(task.get("active", 0)) + 1
        try:
            while True:
                ev = await q.get()
                yield f"data: {json.dumps(ev)}\n\n"
                if ev.get("status") == "done":
                    break
        finally:
            task["active"] = int(task.get("active", 0)) - 1
            _maybe_cleanup(task_id)

    return StreamingResponse(event_gen(), media_type="text/event-stream")