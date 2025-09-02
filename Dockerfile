FROM python:3.13-slim
COPY . /app
WORKDIR /app
RUN pip install -r requirements.txt
ENTRYPOINT ["python", "run.py", "--host", "https://danilonovais-n8n-dan.hf.space", "--port", "6543"]
