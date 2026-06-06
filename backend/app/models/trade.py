from pydantic import BaseModel

class Trade(BaseModel):
    id: int
    ticker: str
    strategy: str
    entry_price: float