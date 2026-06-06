from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.trade_model import TradeModel
from app.schemas.trade_schema import TradeCreate

router = APIRouter()

@router.get("/trades")
def get_trades(db: Session = Depends(get_db)):
	return db.query(TradeModel).all()

@router.post("/trades")
def create_trade(trade: TradeCreate,  db: Session = Depends(get_db)):
	new_trade = TradeModel(
		ticker=trade.ticker,
		strategy=trade.strategy,
		entry_price=trade.entry_price
	)
	db.add(new_trade)
	db.commit()
	db.refresh(new_trade)
	return new_trade

@router.get("/trades/{trade_id}")
def get_trade(trade_id: int, db: Session = Depends(get_db)):
	trade = db.query(TradeModel).filter(TradeModel.id == trade_id).first()
	if trade is None:
		raise HTTPException(status_code=404, detail="Trade not found")
	return trade

@router.delete("/trades/{trade_id}")
def delete_trade(trade_id: int, db: Session = Depends(get_db)):
	trade = db.query(TradeModel).filter(TradeModel.id == trade_id).first()
	if trade is None:
		raise HTTPException(status_code=404, detail="Trade not found")
	db.delete(trade)
	db.commit()
	return {"message": f"Trade {trade_id} deleted successfully"}

@router.put("/trades/{trade_id}")
def update_trade(trade_id: int, updated_trade: TradeCreate, db: Session = Depends(get_db)):
	trade = db.query(TradeModel).filter(TradeModel.id == trade_id).first()
	if trade is None:
		raise HTTPException(status_code=404, detail="Trade not found")
	trade.ticker = updated_trade.ticker
	trade.strategy = updated_trade.strategy
	trade.entry_price = updated_trade.entry_price
	db.commit()
	db.refresh(trade)
	return trade