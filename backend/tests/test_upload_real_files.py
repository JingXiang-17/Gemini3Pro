import httpx
import asyncio
import json
import os

async def test_complex_multimodal_upload():
    # Local server URL
    url = "http://127.0.0.1:8080/analyze"
    
    # Path to real assets
    assets_dir = r"C:\Users\User\Documents\Gemini3Pro\tests\assets"
    
    # 1. Read User Claim
    claim_path = os.path.join(assets_dir, "user_claim.txt")
    if os.path.exists(claim_path):
        with open(claim_path, "r", encoding="utf-8") as f:
            text_claim = f.read().strip()
    else:
        text_claim = "No claim provided in user_claim.txt"
        print(f"Warning: {claim_path} not found.")

    # 2. Read Research Links
    links_path = os.path.join(assets_dir, "research_links.txt")
    provided_urls = []
    if os.path.exists(links_path):
        with open(links_path, "r", encoding="utf-8") as f:
            provided_urls = [line.strip() for line in f if line.strip().startswith("http")]
    else:
        print(f"Warning: {links_path} not found.")

    # 3. Collect Files (2 PDFs, 2 Images)
    files_to_upload = []
    
    # Specific files requested
    file_names = [
        "The_Spread_Of_Covid-19_Fake_News_On_Social_Media_A.pdf",
        "4-VB_COVID-19 and fake news dissemination among Malaysians – Motives and its sociodemographic correlates.pdf",
        "breaking-news.jpg",
        "fpubh-09-560592-g001.jpg"
    ]
    
    for fname in file_names:
        fpath = os.path.join(assets_dir, fname)
        if os.path.exists(fpath):
            mime_type = "application/pdf" if fname.endswith(".pdf") else "image/jpeg"
            with open(fpath, "rb") as f:
                content = f.read()
                files_to_upload.append(("files", (fname, content, mime_type)))
                print(f"Attached: {fname} ({len(content)} bytes)")
        else:
            print(f"Error: Required file {fname} not found in {assets_dir}")
            return

    # 4. Prepare Metadata
    metadata = {
        "request_id": "kita-hack-complex-test",
        "text_claim": text_claim,
        "urls": provided_urls
    }
    
    data = {
        "metadata": json.dumps(metadata)
    }
    
    print("\nStarting Multiple Upload Test...")
    print(f"Text Claim: '{text_claim[:50]}...'")
    print(f"URLs Count: {len(provided_urls)}")
    print(f"Files Count: {len(files_to_upload)}")
    
    try:
        async with httpx.AsyncClient(timeout=180.0) as client:
            response = await client.post(url, data=data, files=files_to_upload)
            print(f"\nStatus Code: {response.status_code}")
            
            if response.status_code == 200:
                res_json = response.json()
                print("\n--- COMPLEX AUDIT RESULTS ---")
                print(f"Verdict: {res_json.get('verdict')}")
                print(f"Confidence: {res_json.get('confidence_score')}")
                print(f"Analysis: {res_json.get('analysis')}")
                
                print("\nKey Findings:")
                for finding in res_json.get('key_findings', []):
                    print(f"- {finding}")
                    
                print("\nGrounding Citations:")
                for citation in res_json.get('grounding_citations', []):
                    print(f"- {citation.get('title')}: {citation.get('url')}")
            else:
                print(f"FAILED: {response.text}")
                
    except Exception as e:
        print(f"Error during test execution: {e}")

if __name__ == "__main__":
    asyncio.run(test_complex_multimodal_upload())
