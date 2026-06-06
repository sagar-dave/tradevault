from pydantic import BaseModel

class TradeCreate(BaseModel):
    ticker: str
    strategy: str
    entry_price: float