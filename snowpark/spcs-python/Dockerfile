FROM python:3.12-slim

RUN useradd -m app

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY imf_datamapper_api_spcs.py .

USER app

CMD ["python", "imf_datamapper_api_spcs.py"]
