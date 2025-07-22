FROM python:3.10-slim

RUN apt-get update && apt-get install -y ffmpeg git wget unzip

# Whisper e dependências
COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
