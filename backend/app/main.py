from fastapi import FastAPI
from app.routes.trades import router as trades_router
from app.database import engine, Base
from app.models.trade_model import TradeModel
from prometheus_fastapi_instrumentator import Instrumentator

import socket

Base.metadata.create_all(bind=engine)

app = FastAPI()
Instrumentator().instrument(app).expose(app)

app.include_router(trades_router)

@app.get("/")
def root():
    return {
        "message": "Welcome to TradeVault API v3"
    }


@app.get("/health")
def health_check():
    return {"status": "healthy"}