from sqlalchemy import Column, Integer, String, Float, true

from app.database import Base

class TradeModel(Base):
    __tablename__ = "trades"

    id = Column(Integer, primary_key=True, index=True)
    ticker = Column(String, nullable=False)
    strategy = Column(String, nullable=False)
    entry_price = Column(Float, nullable=False)