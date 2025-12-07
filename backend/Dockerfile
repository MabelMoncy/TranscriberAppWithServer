# 1. Base Image: Use a lightweight official Python Linux image
FROM python:3.10-slim

# 2. Setup Work Directory
WORKDIR /app

# 3. Install System Dependencies (if needed)
# (Your app is simple, so we might not need this, but good practice)
RUN apt-get update && apt-get install -y gcc

# 4. Copy Requirements
COPY requirements.txt .

# 5. Install Python Libraries
RUN pip install --no-cache-dir -r requirements.txt

# 6. Copy Your Code
COPY . .

# 7. Expose the Port (Cloud Run usually expects 8080)
ENV PORT=8080

# 8. Run the Server
# "0.0.0.0" means "Listen to the outside world"
CMD exec uvicorn main:app --host 0.0.0.0 --port $PORT