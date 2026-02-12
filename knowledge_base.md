# Project Knowledge Base

This file serves as a persistent memory for the project. It documents errors, root causes, solutions, and architectural decisions to prevent regression and speed up future development.

## Common Issues & Solutions

### Backend

#### Service Account Path (Vertex AI)
*   **Context**: 500 Internal Server Error when initializing Vertex AI.
*   **Root Cause**: Relative paths for `service-account.json` may fail depending on the execution context.
*   **Solution**: Use an **explicit absolute path** for the `service-account.json` file in `main.py`.

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

#### Citation Management
*   **Logic**: Use a robust "String Match" with fallback for citation injection.
*   **Anchors**: Map citation chunks to numerical anchors `[x]`. Ensure Vertex AI grounding metadata is correctly processed.

### System Behavior

#### Trust Score (Confidence Score)
*   **Definition**: A value from 0.0 to 1.0 displayed as a percentage ("TRUST SCORE") in the UI.
*   **Calculation**: **Model-Generated** by Gemini 2.0 Flash Lite.
*   **Prompt Instruction**: "Assign a confidence score from 0.0 to 1.0 based on the strength of grounding citations."
*   **Code Location**: `backend/main.py` (System Instruction) -> `AnalysisResponse.confidence_score` -> `frontend/lib/widgets/confidence_gauge.dart`.
