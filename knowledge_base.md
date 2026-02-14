# Project Knowledge Base

This file serves as a persistent memory for the project. It documents errors, root causes, solutions, and architectural decisions to prevent regression and speed up future development.

## Common Issues & Solutions

### Backend

#### Service Account Path (Vertex AI)
*   **Context**: 500 Internal Server Error when initializing Vertex AI.
*   **Root Cause**: Relative paths for `service-account.json` may fail depending on the execution context (especially in Cloud Functions).
*   **Solution**: Use an **explicit absolute path** for the `service-account.json` file in `main.py` using `base_dir = os.path.dirname(os.path.abspath(__file__))`.
*   **Production Hardening**: Ensure the file is not ignored during deployment (see Deployment & Environment section).

#### Image Upload (MIME Types)
*   **Context**: 400 Error: "unable to submit request because it has a mime type parameter with value application".
*   **Root Cause**: Incorrect MIME type handling in `FactCheckService` for multipart requests.
*   **Solution**: Ensure the correct MIME type is explicitly configured when constructing the multipart request.

#### Backend Shutdown
*   **Context**: Need to stop the running backend process.
*   **Solution**: Use the documented stop command (see `DEPLOYMENT_GUIDE.md`) or kill the process by ID.

### Frontend (Flutter)

#### Text Highlighting (VeriScanInteractiveText)
*   **Context**: Overlaps between adjacent highlighted lines/sentences.
*   **Solution**: Adjust the vertical height of the highlight block to be **less than true line height**. This creates clear vertical gaps while maintaining horizontal fill.

#### Input Field Glitch
*   **Context**: "Two layers of text" visual glitch in input fields.
*   **Solution**: Manually control hint text visibility based on whether the user has input text, rather than relying solely on default widget behavior.

#### Widget Tests
*   **Context**: "MyApp isn't a class" error in `widget_test.dart`.
*   **Solution**: Ensure the test file imports and refers to the correct root widget class name used in `main.dart`.

### Deployment & Environment

#### Firebase CLI on Windows
*   **Context**: Deployment issues with Firebase CLI.
*   **Root Cause**: Windows compatibility and path issues.
*   **Learnings**: Ensure backend dependencies are in a virtual environment. Some commands may need to be run manually if the agent environment lacks permissions or specific shell configurations.

#### Cloud Function CORS 500 Error
*   **Context**: Backend crashes with `AttributeError: 'bool' object has no attribute 'cors_methods'` after deployment.
*   **Root Cause**: The `cors=True` setting in the `@https_fn.on_request` decorator can occasionally fail depending on the SDK version or framework initialization.
*   **Solution**: Switch to **Manual CORS Handling**. Implement an `if req.method == 'OPTIONS':` block and explicitly add `headers={'Access-Control-Allow-Origin': '*'}` to all HTTP responses.

#### Missing Credentials in Production
*   **Context**: "Credentials file not found" error on the deployed server.
*   **Root Cause**: `service-account.json` was excluded from the deployment bundle by default `.gitignore` rules.
*   **Solution**: 
    1.  Create a `.gcloudignore` file in the `backend/` directory.
    2.  Add `!service-account.json` to explicitly whitelist the file for upload.
    3.  (Optional) Add a custom header or error response with `traceback.format_exc()` to debug silent 500 errors in live environments.

#### Citation Management
*   **Logic**: Use a robust "String Match" with fallback for citation injection.
*   **Anchors**: Map citation chunks to numerical anchors `[x]`. Ensure Vertex AI grounding metadata is correctly processed.

### System Behavior

#### Trust Score (Confidence Score)
*   **Definition**: A value from 0.0 to 1.0 displayed as a percentage ("TRUST SCORE") in the UI.
*   **Calculation**: **Model-Generated** by Gemini 2.0 Flash Lite.
*   **Prompt Instruction**: "Assign a confidence score from 0.0 to 1.0 based on the strength of grounding citations."
*   **Code Location**: `backend/main.py` (System Instruction) -> `AnalysisResponse.confidence_score` -> `frontend/lib/widgets/confidence_gauge.dart`.
#### Mouse Tracker Assertion Error (Web)
*   **Context**: `Assertion failed: ... mouse_tracker.dart:199:12` occurs during layout shifts (e.g., bar expansion or result loading) while the mouse is moving.
*   **Root Cause**: Flutter's hit-test tree becoming desynchronized during rapid widget tree mutations or animations.
*   **Solution**: 
    1.  Wrap dynamic/shifting components in `RepaintBoundary`.
    2.  Use `ValueKey` to stabilize the identity of interactive elements (buttons, chips).
    3.  Add `AnimatedSize` with a stable curve (e.g., `Curves.fastOutSlowIn`) to smooth transitions.

### Deployment & Environment

#### Firebase 2nd Gen Function URL
*   **Observation**: Standard `cloudfunctions.net` URL might not work for 2nd gen functions.
*   **Discovery**: The function URL is often `https://[function-name]-[hash]-[region].a.run.app`.
*   **Configuration**: Update `FactCheckService` with the correct endpoint found in the Firebase Console/CLI output.
