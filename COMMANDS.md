# Backend Management Commands (Windows/PowerShell)

## 1. Find the Backend Process
The backend runs on port **8080**.

### PowerShell
```powershell
netstat -ano | findstr :8080
```
*Look for the PID (Process ID) in the last column.*

## 2. Kill the Backend Process
Once you have the PID from the previous step:

### Command Prompt (cmd)
```cmd
taskkill /PID <PID> /F
```

### PowerShell
```powershell
Stop-Process -Id <PID> -Force
```

### One-Liner (PowerShell) - *Find and Kill immediately*
```powershell
Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }
```

## 3. Run the Backend
Navigate to the backend directory and run the application.

```powershell
cd backend
python main.py
```
*The server will start at `http://127.0.0.1:8080`.*
*FastAPI Documentation (Swagger UI): `http://127.0.0.1:8080/docs`*
