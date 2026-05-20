import os
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

# Load .env file if present
load_dotenv()

# Build DATABASE_URL dynamically from environment variables
user = os.getenv("POSTGRES_USER", "ciro_user")
password = os.getenv("POSTGRES_PASSWORD", "ciro_password")
db_name = os.getenv("POSTGRES_DB", "ciro_db")
host = os.getenv("POSTGRES_HOST", "localhost")
port = os.getenv("POSTGRES_PORT", "5432")

# Check if connection is via Cloud SQL Unix Socket
if host.startswith("/cloudsql/"):
    DATABASE_URL = f"postgresql://{user}:{password}@/{db_name}?host={host}"
else:
    DATABASE_URL = f"postgresql://{user}:{password}@{host}:{port}/{db_name}"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

