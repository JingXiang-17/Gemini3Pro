import httpx
import asyncio
import json
import os
import glob
import mimetypes

async def test_upload_real_files():
    url = "http://127.0.0.1:8000/analyze"
    
    # Path to assets (relative to project root/tests)
    # If running from project root: tests/assets/
    # If running from tests/: assets/
    assets_dir = os.path.join(os.getcwd(), "tests", "assets")
    
    if not os.path.exists(assets_dir):
        # Fallback if cwd is already tests/
        assets_dir = os.path.join(os.getcwd(), "assets")
        
    print(f"Scanning for files in: {assets_dir}")
    
    # Get all files except README.md
    asset_files = [f for f in glob.glob(os.path.join(assets_dir, "*")) if not f.endswith("README.md")]
    
    if not asset_files:
        print("No test files found in tests/assets/. Please move your images/PDFs there.")
        return

    # Prepare metadata
    metadata = {
        "request_id": "real-file-test",
        "text_claim": "Checking these uploaded documents/images for consistency.",
        "url": None
    }
    
    files_payload = []
    for file_path in asset_files:
        filename = os.path.basename(file_path)
        mime_type, _ = mimetypes.guess_type(file_path)
        if not mime_type:
            mime_type = "application/octet-stream"
            
        print(f"Adding file: {filename} ({mime_type})")
        with open(file_path, "rb") as f:
            content = f.read()
            files_payload.append(("files", (filename, content, mime_type)))
    
    data = {
        "metadata": json.dumps(metadata)
    }
    
    print("\nSending multipart request to FastAPI...")
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(url, data=data, files=files_payload)
            
            print(f"Status Code: {response.status_code}")
            if response.status_code == 200:
                print("SUCCESS: Analysis completed.")
                result = response.json()
                print("\n--- Verdict ---")
                print(f"Verdict: {result.get('verdict')}")
                print(f"Confidence: {result.get('confidence_score')}")
                print(f"Analysis: {result.get('analysis')}")
            else:
                print(f"FAILED: {response.text}")
                
    except Exception as e:
        print(f"Error during test: {e}")

if __name__ == "__main__":
    asyncio.run(test_upload_real_files())
