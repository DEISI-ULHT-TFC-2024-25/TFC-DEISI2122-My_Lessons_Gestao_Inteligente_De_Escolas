# 1) Base: Flutter SDK + Debian slim
FROM cirrusci/flutter:stable

# 2) Install Python & create a venv
USER root
RUN apt-get update && \
    apt-get install -y python3-venv python3-pip && \
    rm -rf /var/lib/apt/lists/*

# create and activate venv at /opt/venv
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

# 3) Pre-install Python deps to speed up rebuilds
WORKDIR /workspace/mylessons_backend
COPY mylessons_backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4) Switch back to workspace root
WORKDIR /workspace

# expose Django port
EXPOSE 8000
