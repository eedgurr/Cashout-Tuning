from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
import os
import shutil
from supabase import create_client, Client
from data_processing_service import parse_html_file, parse_manual_pdf

# Supabase setup:
SUPABASE_URL = "your-supabase-url"  # Replace with env var or actual URL
SUPABASE_KEY = "your-supabase-key"  # Replace with env var or actual key
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Create the FastAPI app:
app = FastAPI(title="Cashout Performance Tuning Backend")

# Add a uploads directory creation:
UPLOAD_DIR = "./uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

# Add the upload endpoint:
@app.post("/upload-tuning-file/")
async def upload_tuning_file(file: UploadFile = File(...)):
    try:
        file_path = os.path.join(UPLOAD_DIR, file.filename)
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        metadata = None
        if file.filename.lower().endswith('.html'):
            metadata = parse_html_file(file_path)
            supabase.table("tuning_html_metadata").insert(metadata).execute()
        elif file.filename.lower().endswith('.pdf'):
            metadata = parse_manual_pdf(file_path)
            supabase.table("manuals").insert(metadata).execute()
        else:
            raise ValueError("Unsupported file type. Supported: .html, .pdf")
        
        os.remove(file_path)
        
        if 'error' in metadata:
            raise HTTPException(status_code=400, detail=metadata['error'])
        
        return JSONResponse(status_code=200, content={"status": "success", "metadata": metadata})
    
    except Exception as e:
        if os.path.exists(file_path):
            os.remove(file_path)
        raise HTTPException(status_code=500, detail=str(e))

# To run: uvicorn main:app --reload
# Test with curl: curl -X POST "http://localhost:8000/upload-tuning-file/" -F "file=@path/to/sample.html"
# Ensure Supabase tables exist: tuning_html_metadata and manuals.
